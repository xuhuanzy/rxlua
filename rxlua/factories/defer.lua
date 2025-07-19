---@namespace Rxlua

local Observable = require("rxlua.observable")
local Result = require("rxlua.internal.result")
local Class = require("luakit.class")
local Exception = require("luakit.exception")
local new = require("luakit.class").new

-- #region DeferObservable

---@class Defer<T>: Observable<T>
---@field private observableFactory fun(): Observable<T>
local DeferObservable = Class.declare("Rxlua.Defer", {
    super = Observable,
    enableSuperChaining = true,
})

---@param observableFactory fun(): Observable<T>
---@param rawObserver boolean
function DeferObservable:__init(observableFactory, rawObserver)
    self.observableFactory = observableFactory
    self.rawObserver = rawObserver
end

function DeferObservable:subscribeCore(observer)
    local success, result = pcall(self.observableFactory)

    if not success then
        ---@cast result string
        observer:onCompleted(Result.failure(Exception(result)))
        return require("rxlua.factories.empty")()
    end
    ---@cast result -string
    return result:subscribe(self.rawObserver and observer or observer:wrap())
end

-- #endregion

---延迟执行一个Observable工厂函数, 直到有观察者订阅时才创建Observable.
---@generic T
---@param observableFactory fun(): Observable<T>
---@param rawObserver? boolean
---@return Observable<T>
---@export namespace
local function defer(observableFactory, rawObserver)
    return new(DeferObservable)(observableFactory, rawObserver or false)
end

return defer
