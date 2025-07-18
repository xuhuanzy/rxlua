---@namespace Rxlua

local Observable = require("rxlua.observable")
local Class = require("luakit.class")
local new = require("luakit.class").new
require("rxlua.observerExtensions") -- 确保 Observer 的 wrap 方法可用

-- #region AnonymousObservable

---@class AnonymousObservable<T>: Observable<T>
local AnonymousObservable = Class.declare("Rxlua.AnonymousObservable", {
    super = Observable,
    enableSuperChaining = true,
})

---@param subscribeFunc fun(observer: Observer<T>, state: any): IDisposable
---@param state? any
---@param rawObserver boolean
function AnonymousObservable:__init(subscribeFunc, state, rawObserver)
    self.subscribeFunc = subscribeFunc
    self.rawObserver = rawObserver or false
    self.state = state
end

---@param observer Observer<T>
---@return IDisposable
function AnonymousObservable:subscribeCore(observer)
    local targetObserver = self.rawObserver and observer or observer:wrap()
    return self.subscribeFunc(targetObserver, self.state)
end

-- #endregion

---创建一个自定义的 Observable, 通过提供的订阅函数来定义订阅行为.
---@generic T
---@param subscribeFunc fun(observer: Observer<T>, state: any): IDisposable 订阅函数, 接收观察者并返回释放函数
---@param state? any 状态, 用于在订阅时传递给订阅函数
---@param rawObserver? boolean 是否使用原始观察者, 默认为 false, 如果为 true, 则会包装观察者.
---@return Observable<T>
---@export namespace
local function create(subscribeFunc, state, rawObserver)
    return new(AnonymousObservable)(subscribeFunc, state, rawObserver or false)
end

return create
