---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local CompleteState = require('rxlua.internal.completeState')
local ResultSuccess = require("rxlua.internal.result").success
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
---@field package completeState CompleteState 完成状态管理器
---@field package root? Subject.ObserverNode 观察者根节点
---@field private version number 版本号, 用于处理迭代期间的修改
local Subject = Class.declare('Rxlua.Subject', {
    super = Observable,
    enableSuperChaining = true,
})

---构造函数
function Subject:__init()
    self.completeState = CompleteState.new()
    self.root = nil
    self.version = 1
end

---发送下一个值
---@param value T
function Subject:onNext(value)
    if self.completeState:isCompleted() then
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
    if self.completeState:isCompleted() then
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

---发出完成信号
---@param result? Result
function Subject:onCompleted(result)
    if result == nil then
        result = ResultSuccess()
    end
    -- 使用CompleteState来设置完成状态
    local status = self.completeState:trySetResult(result)
    if status ~= "Done" then
        return -- 已经完成了, 不需要再处理
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
    return self.completeState:tryGetResult()
end

---检查是否已释放, 如果是则抛出异常
---@private
function Subject:throwIfDisposed()
    if self.completeState:isDisposed() then
        error("无法访问已释放的对象")
    end
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调, 默认为`true`.
function Subject:dispose(callOnCompleted)
    if callOnCompleted == nil then
        callOnCompleted = true
    end

    local success, alreadyCompleted = self.completeState:trySetDisposed()
    if not success then
        return -- 已经被释放了
    end

    local node = self.root
    self.root = nil

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
        -- previous 是最后一个节点, 如果为 nil 则根节点就是最后一个
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
    if p.completeState:isCompletedOrDisposed() then
        return
    end

    if self == p.root then
        if not self.previous or not self.next then
            -- 单个节点的情况
            p.root = nil
        else
            -- 根节点被移除, 下一个节点成为根节点
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
            -- 下一个节点不存在, 前一个是最后一个节点, 需要修改根节点
            ---@cast p.root -?
            p.root.previous = self.previous
        end
    end
end

-- #endregion SubjectObserverNode

return Subject
