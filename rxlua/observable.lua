---@namespace Rxlua

local Class = require('luakit.class')
local Observer = require('rxlua.observer')
local instanceof = require("luakit.class").instanceof
local createAnonymousObserver = require("rxlua.observableSubscribeExtensions").createAnonymousObserver

local pcall = pcall
local type = type
local error = error

---可观察对象(被观察者). 数据源或事件的生产者.
---@class (partial) Observable<T>: IDisposable
---@field protected subscribeCore fun(self: Observable<T>, observer: Observer<T>): IDisposable 订阅核心逻辑, 由子类实现
local Observable = Class.declare('Rxlua.Observable')


---@generic T
---@param self Observable<T>
---@param observer Observer<T>
local function _subscribe(self, observer)
    local subscription = self:subscribeCore(observer)
    observer:setSourceSubscription(subscription)
end

---订阅观察者
---@param observer fun(value: T) | ObserverParams<T>
---@return IDisposable disposable 返回取消订阅的函数
function Observable:subscribe(observer)
    local typ = type(observer)
    if typ == 'function' then
        ---@cast observer fun(value: T)
        observer = createAnonymousObserver(observer)
    elseif typ == 'table' then
        ---@cast observer -function
        if not instanceof(observer, Observer) and (observer.next) then
            ---@cast observer ObserverParams<T>
            observer = createAnonymousObserver(observer.next, observer.errorResume, observer.completed)
        end
    end

    local ok, err = pcall(_subscribe, self, observer)

    if not ok then
        -- 订阅失败时自动释放观察者
        observer:dispose()
        error(err)
    end

    -- 返回观察者本身, 形成订阅链
    return observer
end

return Observable
