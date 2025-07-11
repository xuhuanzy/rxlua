---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local CompleteState = require('rxlua.internal.completeState')
local emptyDisposable = require("rxlua.shared").emptyDisposable
local createRingBuffer = require('rxlua.internal.ringBuffer').createRingBuffer
local TimeProvider = require('rxlua.internal.timeProvider')

---重播主题的订阅
---@class ReplaySubject.Subscription<T>: IDisposable
---@field observer Observer<T> 观察者
---@field parent? ReplaySubject<T> 父级 ReplaySubject
local ReplaySubjectSubscription = {}
ReplaySubjectSubscription.__index = ReplaySubjectSubscription

---重播主题, 用于支持缓冲区重播的多播事件
---@class ReplaySubject<T>: Observable<T>, ISubject<T>
---@field private bufferSize integer 缓冲区大小限制, 默认为`2147483647`
---@field private window number 时间窗口(毫秒), 默认为`2147483647`
---@field private timeProvider? TimeProvider 时间提供者
---@field private replayBuffer RingBuffer<{timestamp: number, value: T}> 重播缓冲区
---@field private completeState CompleteState 完成状态管理器
---@field package list table<ReplaySubject.Subscription<T>, boolean> 订阅列表
local ReplaySubject = Class.declare('Rxlua.ReplaySubject', Observable)

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
    self.completeState = CompleteState.new()
    self.list = {}
end

---检查是否已释放
---@return boolean
function ReplaySubject:isDisposed()
    return self.completeState:isDisposed()
end

---检查是否已完成或已释放
---@return boolean
function ReplaySubject:isCompletedOrDisposed()
    return self.completeState:isCompletedOrDisposed()
end

---检查是否已完成
---@return boolean
function ReplaySubject:isCompleted()
    return self.completeState:isCompleted()
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
    local list = self.list
    for subscription in pairs(list) do
        subscription.observer:onNext(value)
    end
end

---发送错误但继续订阅
---@param error any
function ReplaySubject:onErrorResume(error)
    if self:isDisposed() then
        return -- 已释放，直接返回，不抛出异常
    end
    
    if self:isCompleted() then
        return
    end

    local list = self.list
    for subscription in pairs(list) do
        subscription.observer:onErrorResume(error)
    end
end

---完成 ReplaySubject
---@param result Result
function ReplaySubject:onCompleted(result)
    
    -- 使用CompleteState来设置完成状态
    local status = self.completeState:trySetResult(result)
    if status ~= "Done" then
        return -- 已经完成了，不需要再处理
    end

    -- 通知所有观察者
    local list = self.list
    for subscription in pairs(list) do
        subscription.observer:onCompleted(result)
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
    local subscription = ReplaySubjectSubscription.new(self, observer)

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
    return self.completeState:tryGetResult()
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

    local success, alreadyCompleted = self.completeState:trySetDisposed()
    if not success then
        return -- 已经被释放了
    end

    local list = self.list

    -- 如果需要调用完成回调, 且尚未完成
    if callOnCompleted and not alreadyCompleted then
        for subscription in pairs(list) do
            subscription.observer:onCompleted()
        end
    end

    self.list = nil

    -- 清理缓冲区
    self.replayBuffer:clear()
end

-- #region ReplaySubjectSubscription

---@generic T
---@param parent ReplaySubject<T>
---@param observer Observer<T>
---@return ReplaySubject.Subscription
function ReplaySubjectSubscription.new(parent, observer)
    ---@class (constructor) ReplaySubject.Subscription
    local self = {
        observer = observer,
        parent = parent,
    }
    parent.list[self] = true
    return setmetatable(self, ReplaySubjectSubscription)
end

---释放订阅
function ReplaySubjectSubscription:dispose()
    local p = self.parent
    self.parent = nil
    if not p then
        return
    end
    p.list[self] = nil
end

-- #endregion ReplaySubjectSubscription

return ReplaySubject
