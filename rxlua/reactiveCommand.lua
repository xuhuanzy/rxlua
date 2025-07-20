---@namespace Rxlua

local Class = require('luakit.class')
local CompleteState = require('rxlua.internal.completeState')
local new = require('luakit.class').new
---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local Disposable = require("rxlua.disposable")

---@class ReactiveCommand.Subscription<T>: IDisposable
---@field observer Observer<T> 观察者
---@field removeKey integer 移除键
---@field parent ReactiveCommand<T>? 父命令
local ReactiveCommandSubscription = Class.declare('Rxlua.ReactiveCommand.Subscription')


---响应式命令, 支持可执行状态管理和多订阅者
---@class ReactiveCommand<T, TOutput>: Observable<TOutput>, IDisposable
---@field package list table<ReactiveCommand.Subscription<T>, true> 订阅者列表
---@field completeState CompleteState 完成状态管理器
---@field private _canExecute boolean 可执行状态
---@field subscription IDisposable 内部订阅. 来自于`canExecuteSource`或`onNext`
---@field private canExecuteCallbacks table<fun(sender: table), true> 可执行状态改变时回调
---@field convert? fun(input: T): TOutput 转换函数, 如果提供了该函数, 则`execute`执行时参数会被转换为`TOutput`类型.
local ReactiveCommand = Class.declare('Rxlua.ReactiveCommand', {
    super = Observable,
    enableSuperChaining = true
})

---@generic T
---@param newCanExecute boolean 新的可执行状态
---@param state ReactiveCommand<T> 命令
local function canExecuteSourceNext(newCanExecute, state)
    state:changeCanExecute(newCanExecute)
end

---构造函数
---@param params? Rxlua.ReactiveCommand.Params<T> 构造参数
function ReactiveCommand:__init(params)
    params = params or {}
    ---@cast params Rxlua.ReactiveCommand.Params<T>

    self.list = {}
    self.completeState = CompleteState.new()

    self._canExecute = params.initialCanExecute ~= false -- 默认为`true`
    self.canExecuteCallbacks = {}
    self.convert = params.convert

    -- 如果提供了`canExecuteSource`, 订阅它
    if params.canExecuteSource then
        self.subscription = params.canExecuteSource:subscribe({
            state = self,
            next = canExecuteSourceNext
        })
    end
    if params.execute then
        local subscription = self:subscribe(params.execute)
        if self.subscription then
            self:combineSubscription(subscription)
        else
            self.subscription = subscription
        end
    end

    if not self.subscription then
        self.subscription = Disposable.Empty
    end
end

---检查是否可执行
---@return boolean
function ReactiveCommand:canExecute()
    return self._canExecute
end

---检查是否已禁用
---@return boolean
function ReactiveCommand:isDisabled()
    return not self._canExecute
end

---改变可执行状态
---@param newCanExecute boolean 新的可执行状态
function ReactiveCommand:changeCanExecute(newCanExecute)
    if self._canExecute == newCanExecute then
        return
    end
    self._canExecute = newCanExecute
    -- 触发回调
    for callback, _ in pairs(self.canExecuteCallbacks) do
        callback(self)
    end
end

---添加可执行状态改变时回调
---@param callback fun(sender: ReactiveCommand<T>) 回调函数
---@return fun(sender: ReactiveCommand<T>) # 返回回调函数方便移除
function ReactiveCommand:addCanExecuteCallback(callback)
    self.canExecuteCallbacks[callback] = true
    return callback
end

---移除可执行状态改变时回调
---@param callback fun(sender: ReactiveCommand<T>) 回调函数
function ReactiveCommand:removeCanExecuteCallback(callback)
    self.canExecuteCallbacks[callback] = nil
end

---执行命令
---@param parameter T? 参数
function ReactiveCommand:execute(parameter)
    if self.completeState:isCompleted() then
        return
    end
    local convert = self.convert

    -- 遍历所有订阅者并发送值
    for subscription, _ in pairs(self.list) do
        if subscription then
            if convert then
                subscription.observer:onNext(convert(parameter))
            else
                subscription.observer:onNext(parameter)
            end
        end
    end
end

---合并订阅
---@param disposable IDisposable 要合并的订阅
function ReactiveCommand:combineSubscription(disposable)
    self.subscription = Disposable.combine(self.subscription, disposable)
end

---订阅核心逻辑
---@param observer Observer<T> 观察者
---@return IDisposable
function ReactiveCommand:subscribeCore(observer)
    -- 检查是否已完成
    local result = self.completeState:tryGetResult()
    if result then
        observer:onCompleted(result)
        return Disposable.Empty
    end

    -- 创建订阅
    local subscription = new(ReactiveCommandSubscription)(self, observer)

    -- 再次检查是否在添加期间完成
    result = self.completeState:tryGetResult()
    if result then
        subscription.observer:onCompleted(result)
        subscription:dispose()
        return Disposable.Empty
    end

    return subscription
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调, 默认为`true`
function ReactiveCommand:dispose(callOnCompleted)
    callOnCompleted = callOnCompleted ~= false -- 默认为`true`

    local success, alreadyCompleted = self.completeState:trySetDisposed()
    if success then
        if callOnCompleted and not alreadyCompleted then
            -- 通知所有订阅者完成
            for subscription, _ in pairs(self.list) do
                if subscription then
                    subscription.observer:onCompleted()
                end
            end
        end
        -- 清理资源

        self.list = nil
        self.canExecuteCallbacks = nil

        if self.subscription then
            self.subscription:dispose()
            self.subscription = nil
        end
    end
end

-- #region ReactiveCommandSubscription

---@param parent ReactiveCommand<T> 父命令
---@param observer Observer<T> 观察者
function ReactiveCommandSubscription:__init(parent, observer)
    self.parent = parent
    self.observer = observer

    parent.list[self] = true
end

---释放订阅
function ReactiveCommandSubscription:dispose()
    local parent = self.parent
    if not parent then
        return
    end

    -- 从父命令的订阅列表中移除
    parent.list[self] = nil
    self.parent = nil
end

-- #endregion


---#region ReactiveCommandExtensions 扩展方法

---将`Observable<boolean>`转换为`ReactiveCommand`
---@generic TOutput
---@param self Observable<boolean> 可执行状态源
---@param params? ReactiveCommand.Params<T, TOutput> 构造参数. `canExecuteSource`会被强制设置为`self`.
---@return ReactiveCommand<T> command 响应式命令
function Observable.toReactiveCommand(self, params)
    params = params or {}
    ---@cast params ReactiveCommand.Params<T>
    params.canExecuteSource = self
    return new(ReactiveCommand)(params)
end

---#endregion

return ReactiveCommand
