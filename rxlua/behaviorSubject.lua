---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local CompleteState = require('rxlua.internal.completeState')
local emptyDisposable = require("rxlua.shared").emptyDisposable

---内部使用的观察者节点
---@class BehaviorSubject.Subscription<T>: IDisposable
---@field observer Observer<T> 观察者
---@field parent? BehaviorSubject<T> 父级 BehaviorSubject
local BehaviorSubjectSubscription = {}
BehaviorSubjectSubscription.__index = BehaviorSubjectSubscription

---行为主题. 拥有一个当前值, 新的订阅者会立即收到这个当前值.
---@class BehaviorSubject<T>: Observable<T>, ISubject<T>
---@field private latestValue T 当前值
---@field private completeState CompleteState 完成状态管理器
---@field package list table<BehaviorSubject.Subscription<T>, boolean> 订阅列表
---@field private version number 版本号，用于处理迭代期间的修改
local BehaviorSubject = Class.declare('Rxlua.BehaviorSubject', {
    super = Observable,
    enableSuperChaining = true,
})

---构造函数
---@param initialValue T 初始值
function BehaviorSubject:__init(initialValue)
    self.latestValue = initialValue
    self.completeState = CompleteState.new()
    self.list = {}
    self.version = 1
end

---获取当前值
---@return T
function BehaviorSubject:getValue()
    local result = self.completeState:tryGetResult()
    if result and result:isFailure() then
        error(result.exception)
    end
    return self.latestValue
end

---发送下一个值
---@param value T
function BehaviorSubject:onNext(value)
    if self.completeState:isCompleted() then
        return
    end

    -- 更新当前值
    self.latestValue = value

    -- 通知所有观察者
    for subscription in pairs(self.list) do
        subscription.observer:onNext(value)
    end
end

---发送错误但继续订阅
---@param error any
function BehaviorSubject:onErrorResume(error)
    if self.completeState:isCompleted() then
        return
    end

    for subscription in pairs(self.list) do
        subscription.observer:onErrorResume(error)
    end
end

---完成 BehaviorSubject
---@param result Result
function BehaviorSubject:onCompleted(result)
    local status = self.completeState:trySetResult(result)
    if status ~= "Done" then
        return -- 已经完成
    end

    for subscription in pairs(self.list) do
        subscription.observer:onCompleted(result)
    end
end

---订阅核心逻辑
---@param observer Observer<T>
---@return IDisposable
function BehaviorSubject:subscribeCore(observer)
    -- 检查是否已完成
    local result = self.completeState:tryGetResult()
    if result then
        -- 如果已经完成, 则不发送当前值
        observer:onCompleted(result)
        return emptyDisposable
    end

    -- 立即发送当前值
    observer:onNext(self.latestValue)

    local subscription = BehaviorSubjectSubscription.new(self, observer, self.version)

    -- 再次检查是否在添加期间完成
    result = self.completeState:tryGetResult()
    if result then
        subscription.observer:onCompleted(result)
        subscription:dispose()
        return emptyDisposable
    end

    return subscription
end

---检查是否已释放，如果是则抛出异常
---@private
function BehaviorSubject:throwIfDisposed()
    if self.completeState:isDisposed() then
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

    if not alreadyCompleted and callOnCompleted then
        for subscription in pairs(self.list) do
            subscription.observer:onCompleted()
        end
    end

    self.list = nil
    self.latestValue = nil
end

-- #region BehaviorSubjectSubscription

---构造函数
---@generic T
---@param parent BehaviorSubject<T>
---@param observer Observer<T>
---@param version number
---@return BehaviorSubject.Subscription
function BehaviorSubjectSubscription.new(parent, observer, version)
    ---@class (constructor) BehaviorSubject.Subscription
    local self = {
        observer = observer,
        parent = parent,
    }

    parent.list[self] = true
    return setmetatable(self, BehaviorSubjectSubscription)
end

---释放观察者节点
function BehaviorSubjectSubscription:dispose()
    local p = self.parent
    self.parent = nil
    if not p then
        return
    end
    p.list[self] = nil
end

-- #endregion BehaviorSubjectObserverNode

return BehaviorSubject
