---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local Result = require('rxlua.result')
local emptyDisposable = require("rxlua.shared").emptyDisposable
local createRingBuffer = require('rxlua.internal.ringBuffer').createRingBuffer
local TimeProvider = require('rxlua.internal.timeProvider')

---重播主题的观察者节点
---@class ReplaySubject.ObserverNode<T>: IDisposable
---@field observer Observer<T> 观察者
---@field parent? ReplaySubject<T> 父级 ReplaySubject
---@field previous? ReplaySubject.ObserverNode 前一个节点
---@field next? ReplaySubject.ObserverNode 下一个节点
local ReplaySubjectObserverNode = {}
ReplaySubjectObserverNode.__index = ReplaySubjectObserverNode

---重播主题, 用于支持缓冲区重播的多播事件
---@class ReplaySubject<T>: Observable<T>, ISubject<T>
---@field private bufferSize integer 缓冲区大小限制, 默认为`2147483647`
---@field private window number 时间窗口(毫秒), 默认为`2147483647`
---@field private timeProvider? TimeProvider 时间提供者
---@field private replayBuffer RingBuffer<{timestamp: number, value: T}> 重播缓冲区
---@field private completeState integer 完成状态
---@field package root? ReplaySubject.ObserverNode 观察者根节点
local ReplaySubject = Class.declare('Rxlua.ReplaySubject', Observable)

-- 完成状态枚举
local NotCompleted = 0     -- 未完成
local CompletedSuccess = 1 -- 完成成功
local CompletedFailure = 2 -- 完成失败
local Disposed = 3         -- 已释放

local IntMaxValue = 2147483647

---构造函数
---@param bufferSize? integer 缓冲区大小限制, 默认为`2147483647`
---@param window? number 时间窗口(毫秒), 默认为`2147483647`
---@param timeProvider? TimeProvider 时间提供者, 允许为`nil`
function ReplaySubject:__init(bufferSize, window, timeProvider)
    self.bufferSize = bufferSize or IntMaxValue
    self.window = window or IntMaxValue

    -- 只有在指定了时间窗口时才需要时间提供者
    if window then
        self.timeProvider = timeProvider or TimeProvider.getDefaultTimeProvider()
    end

    self.replayBuffer = createRingBuffer(self.bufferSize < 8 and self.bufferSize or 8)

    -- 初始化状态
    self.completeState = NotCompleted
    self.error = nil
    self.root = nil
end

---检查是否已释放
---@return boolean
function ReplaySubject:isDisposed()
    return self.completeState == Disposed
end

---检查是否已完成或已释放
---@return boolean
function ReplaySubject:isCompletedOrDisposed()
    return self.completeState ~= NotCompleted
end

---检查是否已完成
---@return boolean
function ReplaySubject:isCompleted()
    return self.completeState == CompletedSuccess or self.completeState == CompletedFailure
end

---根据时间和数量限制清理缓冲区
---@private
function ReplaySubject:trim()
    -- 按数量限制清理
    while self.replayBuffer:getSize() > self.bufferSize do
        self.replayBuffer:removeFirst()
    end

    -- 按时间窗口清理
    if self.timeProvider and self.window < IntMaxValue then
        local now = self.timeProvider:getTimestamp()
        while not self.replayBuffer:isEmpty() do
            local item = self.replayBuffer:getFirst() ---@cast item -?
            local elapsed = self.timeProvider:getElapsedTime(item.timestamp, now)
            if elapsed >= self.window then
                self.replayBuffer:removeFirst()
            else
                break
            end
        end
    end
end

---发送下一个值
---@param value T
function ReplaySubject:onNext(value)
    if self:isCompleted() then
        return
    end

    -- 获取时间戳
    local timestamp = self.timeProvider and self.timeProvider:getTimestamp() or 0

    -- 添加到缓冲区
    self.replayBuffer:addLast({
        timestamp = timestamp,
        value = value
    })

    -- 清理缓冲区
    self:trim()

    -- 通知所有当前观察者
    local node = self.root
    local last = node and node.previous
    while node do
        node.observer:onNext(value)
        if node == last then
            break
        end
        node = node.next
    end
end

---发送错误但继续订阅
---@param error any
function ReplaySubject:onErrorResume(error)
    if self:isCompleted() then
        return
    end

    local node = self.root
    local last = node and node.previous
    while node do
        node.observer:onErrorResume(error)
        if node == last then
            break
        end
        node = node.next
    end
end

---完成 ReplaySubject
---@param result Result
function ReplaySubject:onCompleted(result)
    if self:isCompleted() then
        return
    end

    -- 设置完成状态
    self.completeState = result:isSuccess() and CompletedSuccess or CompletedFailure
    if result:isFailure() then
        self.error = result.exception
    end

    -- 通知所有观察者
    local node = self.root
    self.root = nil -- 完成时清空列表

    local last = node and node.previous
    while node do
        node.observer:onCompleted(result)
        if node == last then
            break
        end
        node = node.next
    end
end

---订阅核心逻辑
---@param observer Observer<T>
---@return IDisposable
function ReplaySubject:subscribeCore(observer)
    -- 首先重播缓冲区内容
    self:trim() -- 在重播前清理过期数据

    local span = self.replayBuffer:getSpan()

    for _, item in pairs(span) do
        observer:onNext(item.value)
    end

    -- 检查是否已完成
    local result = self:tryGetResult()
    if result then
        observer:onCompleted(result)
        return emptyDisposable
    end

    -- 添加到观察者列表
    local subscription = ReplaySubjectObserverNode.new(self, observer)

    -- 再次检查是否在添加期间完成
    result = self:tryGetResult()
    if result then
        subscription.observer:onCompleted(result)
        subscription:dispose()
        return emptyDisposable
    end

    return subscription
end

---尝试获取完成结果
---@return Result?
---@private
function ReplaySubject:tryGetResult()
    if self.completeState == NotCompleted then
        return nil
    elseif self.completeState == CompletedSuccess then
        return Result.success()
    elseif self.completeState == CompletedFailure then
        return Result.failure(self.error)
    elseif self.completeState == Disposed then
        error("无法访问已释放的对象")
    end
    return nil
end

---检查是否已释放, 如果是则抛出异常
---@private
function ReplaySubject:throwIfDisposed()
    if self:isDisposed() then
        error("无法访问已释放的对象")
    end
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调, 默认为`true`.
function ReplaySubject:dispose(callOnCompleted)
    if callOnCompleted == nil then
        callOnCompleted = true
    end

    if self.completeState == Disposed then
        return
    end

    local alreadyCompleted = self:isCompleted()
    local node = nil

    -- 如果需要调用完成回调且尚未完成
    if callOnCompleted and not alreadyCompleted then
        node = self.root
    end

    self.root = nil
    self.completeState = Disposed

    -- 清理缓冲区
    self.replayBuffer:clear()

    -- 通知所有观察者完成
    local last = node and node.previous
    while node do
        node.observer:onCompleted()
        if node == last then
            break
        end
        node = node.next
    end
end

-- #region ReplaySubjectObserverNode

---构造函数
---@generic T
---@param parent ReplaySubject<T>
---@param observer Observer<T>
---@return ReplaySubject.ObserverNode
function ReplaySubjectObserverNode.new(parent, observer)
    ---@class (constructor) ReplaySubject.ObserverNode
    local self = {
        parent = parent,
        observer = observer,
        previous = nil,
        next = nil
    }

    -- 添加节点到父级列表
    if not parent.root then
        -- 单个列表(前后都为nil)
        parent.root = self
    else
        -- 前一个是最后一个, 若为空则根为最后一个
        local lastNode = parent.root.previous or parent.root

        lastNode.next = self
        self.previous = lastNode
        parent.root.previous = self
    end

    return setmetatable(self, ReplaySubjectObserverNode)
end

---释放观察者节点
function ReplaySubjectObserverNode:dispose()
    local p = self.parent
    if not p then
        return
    end
    self.parent = nil

    -- 从父级列表中移除节点
    if p:isCompletedOrDisposed() then
        return
    end

    if self == p.root then
        if not self.previous or not self.next then
            -- 单个列表的情况
            p.root = nil
        else
            -- 否则, 根是下一个节点
            local root = self.next

            -- 单个列表
            if not root.next then
                root.previous = nil
            else
                root.previous = self.previous -- 作为最后一个
            end

            p.root = root
        end
    else
        -- 节点不是根, 前一个必须存在
        ---@cast self.previous -?
        self.previous.next = self.next
        if self.next then
            self.next.previous = self.previous
        else
            ---@cast p.root -?
            -- 下一个不存在, 前一个是最后一个节点, 所以修改根
            p.root.previous = self.previous
        end
    end
end

-- #endregion ReplaySubjectObserverNode

return ReplaySubject
