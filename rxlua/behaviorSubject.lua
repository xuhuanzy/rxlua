---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local CompleteState = require('rxlua.internal.completeState')
local emptyDisposable = require("rxlua.shared").emptyDisposable

---内部使用的观察者节点
---@class BehaviorSubject.ObserverNode<T>: IDisposable
---@field observer Observer<T> 观察者
---@field parent? BehaviorSubject<T> 父级 BehaviorSubject
---@field previous? BehaviorSubject.ObserverNode 前一个节点
---@field next? BehaviorSubject.ObserverNode 下一个节点
---@field version number 节点版本号
local BehaviorSubjectObserverNode = {}
BehaviorSubjectObserverNode.__index = BehaviorSubjectObserverNode

---行为主题, 用于支持带有当前值的多播事件.
---@class BehaviorSubject<T>: Observable<T>, ISubject<T>
---@field private latestValue T 当前值
---@field private completeState CompleteState 完成状态管理器
---@field package root? BehaviorSubject.ObserverNode 观察者根节点
---@field private version number 版本号，用于处理迭代期间的修改
local BehaviorSubject = Class.declare('Rxlua.BehaviorSubject', Observable)

---构造函数
---@param initialValue T 初始值
function BehaviorSubject:__init(initialValue)
    self.latestValue = initialValue
    self.completeState = CompleteState.new()
    self.root = nil
    self.version = 1
end

---检查是否已释放
---@return boolean
function BehaviorSubject:isDisposed()
    return self.completeState:isDisposed()
end

---检查是否已完成或已释放
---@return boolean
function BehaviorSubject:isCompletedOrDisposed()
    return self.completeState:isCompletedOrDisposed()
end

---检查是否已完成
---@return boolean
function BehaviorSubject:isCompleted()
    return self.completeState:isCompleted()
end

---获取当前值
---@return T
function BehaviorSubject:getValue()
    local result = self:tryGetResult()
    if result and result:isFailure() then
        error(result.exception)
    end
    return self.latestValue
end

---发送下一个值
---@param value T
function BehaviorSubject:onNext(value)
    if self:isCompleted() then
        return
    end

    -- 更新当前值
    self.latestValue = value

    -- 通知所有观察者
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
function BehaviorSubject:onErrorResume(error)
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

---完成 BehaviorSubject
---@param result Result
function BehaviorSubject:onCompleted(result)
    -- 使用CompleteState来设置完成状态
    local status = self.completeState:trySetResult(result)
    if status ~= "Done" then
        return -- 已经完成了，不需要再处理
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
function BehaviorSubject:subscribeCore(observer)
    -- 检查是否已完成
    local result = self:tryGetResult()
    if result then
        -- 如果已经完成, 则不发送当前值
        observer:onCompleted(result)
        return emptyDisposable
    end

    -- 立即发送当前值
    observer:onNext(self.latestValue)

    local subscription = BehaviorSubjectObserverNode.new(self, observer, self.version)

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
function BehaviorSubject:tryGetResult()
    return self.completeState:tryGetResult()
end

---检查是否已释放，如果是则抛出异常
---@private
function BehaviorSubject:throwIfDisposed()
    if self:isDisposed() then
        error("无法访问已释放的对象")
    end
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调，默认为`true`.
function BehaviorSubject:dispose(callOnCompleted)
    if callOnCompleted == nil then
        callOnCompleted = true
    end

    local success, alreadyCompleted = self.completeState:trySetDisposed()
    if not success then
        return -- 已经被释放了
    end

    local node = self.root
    self.root = nil

    -- 清空当前值
    self.latestValue = nil

    if not alreadyCompleted and callOnCompleted then
        local currentVersion = self:getVersion()
        while node do
            if node.version > currentVersion then
                break
            end
            node.observer:onCompleted()
            node = node.next
        end
    end
end

do
    local maxinteger = math.maxinteger

    ---获取当前版本号
    ---@return number
    ---@private
    function BehaviorSubject:getVersion()
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
function BehaviorSubject:resetAllObserverVersion()
    local node = self.root
    while node do
        node.version = 0
        node = node.next
    end
    self.version = 1
end

-- #region BehaviorSubjectObserverNode

---构造函数
---@generic T
---@param parent BehaviorSubject<T>
---@param observer Observer<T>
---@param version number
---@return BehaviorSubject.ObserverNode
function BehaviorSubjectObserverNode.new(parent, observer, version)
    ---@class (constructor) BehaviorSubject.ObserverNode
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

    return setmetatable(self, BehaviorSubjectObserverNode)
end

---释放观察者节点
function BehaviorSubjectObserverNode:dispose()
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
        -- 节点不是根节点,前一个节点必须存在
        ---@cast self.previous -?
        self.previous.next = self.next
        if self.next then
            self.next.previous = self.previous
        else
            -- 下一个节点不存在，前一个是最后一个节点, 需要修改根节点
            ---@cast p.root -?
            p.root.previous = self.previous
        end
    end
end

-- #endregion BehaviorSubjectObserverNode

return BehaviorSubject
