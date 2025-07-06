---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local Result = require('rxlua.result')
local emptyDisposable = require("rxlua.shared").emptyDisposable


---内部使用的观察者节点
---@class Subject.ObserverNode<T>: IDisposable
---@field observer Observer<T> 观察者
---@field parent? Subject<T> 父级 Subject
---@field previous? Subject.ObserverNode 前一个节点
---@field next? Subject.ObserverNode 下一个节点
---@field version number 节点版本号
local SubjectObserverNode = {}
SubjectObserverNode.__index = SubjectObserverNode

---主题, 用于支持多播事件.
---@class Subject<T>: Observable<T>, ISubject<T>
---@field private completeState integer 完成状态
---@field package root? Subject.ObserverNode 观察者根节点
---@field private version number 版本号，用于处理迭代期间的修改
local Subject = Class.declare('Rxlua.Subject', Observable)

-- 完成状态枚举
local NotCompleted = 0     -- 未完成
local CompletedSuccess = 1 -- 完成成功
local CompletedFailure = 2 -- 完成失败
local Disposed = 3         -- 已释放

---构造函数
function Subject:__init()
    self.completeState = NotCompleted
    self.error = nil
    self.root = nil
    self.version = 1
end

---检查是否已释放
---@return boolean
function Subject:isDisposed()
    return self.completeState == Disposed
end

---检查是否已完成或已释放
---@return boolean
function Subject:isCompletedOrDisposed()
    return self.completeState ~= NotCompleted
end

---检查是否已完成
---@return boolean
function Subject:isCompleted()
    return self.completeState == CompletedSuccess or self.completeState == CompletedFailure
end

---发送下一个值
---@param value T
function Subject:onNext(value)
    if self:isCompleted() then
        return
    end

    local currentVersion = self:getVersion()
    local node = self.root
    while node do
        if node.version > currentVersion then
            break
        end
        node.observer:onNext(value)
        node = node.next
    end
end

---发送错误但继续订阅
---@param error any
function Subject:onErrorResume(error)
    if self:isCompleted() then
        return
    end

    local currentVersion = self:getVersion()
    local node = self.root
    while node do
        if node.version > currentVersion then
            break
        end
        node.observer:onErrorResume(error)
        node = node.next
    end
end

---完成 Subject
---@param result Result
function Subject:onCompleted(result)
    if self:isCompleted() then
        return
    end

    -- 设置完成状态
    self.completeState = result:isSuccess() and CompletedSuccess or CompletedFailure
    if result:isFailure() then
        self.error = result.exception
    end

    local currentVersion = self:getVersion()
    local node = self.root
    while node do
        if node.version > currentVersion then
            break
        end
        node.observer:onCompleted(result)
        node = node.next
    end
end

---订阅核心逻辑
---@param observer Observer<T>
---@return IDisposable
function Subject:subscribeCore(observer)
    -- 检查是否已完成
    local result = self:tryGetResult()
    if result then
        observer:onCompleted(result)
        return emptyDisposable
    end

    local subscription = SubjectObserverNode.new(self, observer, self.version)

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
function Subject:tryGetResult()
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

---检查是否已释放，如果是则抛出异常
---@private
function Subject:throwIfDisposed()
    if self:isDisposed() then
        error("无法访问已释放的对象")
    end
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调，默认为`true`.
function Subject:dispose(callOnCompleted)
    if callOnCompleted == nil then
        callOnCompleted = true
    end
    local alreadyCompleted = self:isCompleted()

    if self.completeState == Disposed then
        return
    end

    self.completeState = Disposed
    local node = self.root
    self.root = nil

    if not alreadyCompleted and callOnCompleted then
        local currentVersion = self:getVersion()
        while node do
            if node.version > currentVersion then
                break
            end
            node.observer:onCompleted(Result.success())
            node = node.next
        end
    end
end

do
    local maxinteger = math.maxinteger

    ---获取当前版本号
    ---@return number
    ---@private
    function Subject:getVersion()
        local currentVersion
        if self.version >= maxinteger then
            self:resetAllObserverVersion()
            currentVersion = 0
        else
            currentVersion = self.version
            self.version = self.version + 1
        end
        return currentVersion
    end
end

---重置所有观察者版本号
---@private
function Subject:resetAllObserverVersion()
    local node = self.root
    while node do
        node.version = 0
        node = node.next
    end
    self.version = 1
end

-- #region SubjectObserverNode

---构造函数
---@generic T
---@param parent Subject<T>
---@param observer Observer<T>
---@param version number
---@return Subject.ObserverNode
function SubjectObserverNode.new(parent, observer, version)
    ---@class (constructor) Subject.ObserverNode
    local self = {
        observer = observer,
        parent = parent,
        previous = nil,
        next = nil,
        version = version
    }

    -- 添加到父级的观察者链表
    if not parent.root then
        -- 单个节点
        parent.root = self
    else
        -- previous 是最后一个节点，如果为 nil 则根节点就是最后一个
        local lastNode = parent.root.previous or parent.root

        lastNode.next = self
        self.previous = lastNode
        parent.root.previous = self
    end

    return setmetatable(self, SubjectObserverNode)
end

---释放观察者节点
function SubjectObserverNode:dispose()
    local p = self.parent
    if not p then
        return
    end
    self.parent = nil

    -- 从父级链表中移除节点
    if p:isCompletedOrDisposed() then
        return
    end

    if self == p.root then
        if not self.previous or not self.next then
            -- 单个节点的情况
            p.root = nil
        else
            -- 根节点被移除，下一个节点成为根节点
            local root = self.next

            -- 单个节点
            if not root.next then
                root.previous = nil
            else
                root.previous = self.previous -- 作为最后一个节点
            end

            p.root = root
        end
    else
        -- 节点不是根节点，前一个节点必须存在
        ---@cast self.previous -?
        self.previous.next = self.next
        if self.next then
            self.next.previous = self.previous
        else
            -- 下一个节点不存在，前一个是最后一个节点，需要修改根节点
            ---@cast p.root -?
            p.root.previous = self.previous
        end
    end
end

-- #endregion SubjectObserverNode

return Subject
