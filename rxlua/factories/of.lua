---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local emptyDisposable = require("rxlua.shared").emptyDisposable
local new = require("luakit.class").new

---@generic T
---@param observer Observer<T>
---@param values T[]
---@return IDisposable
local function subscribeToArray(observer, values)
    -- 依次发出所有值
    for i, value in ipairs(values) do
        observer:onNext(value)
    end

    -- 完成观察
    observer:onCompleted()

    return emptyDisposable
end

---@generic T
---@param ... T 要发出的值
---@return Observable<T>
local function fromArrayLike(...)
    local values = { ... }
    local observable = new(Observable)
    observable.subscribeCore = function(self, observer)
        return subscribeToArray(observer, values)
    end
    return observable
end

---创建一个Observable, 依次发出指定的值然后完成.
---@generic T
---@param ... T 要发出的值
---@return Observable<T>
---@export namespace
local function of(...)
    return fromArrayLike(...)
end

return of
