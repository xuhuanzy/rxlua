---@namespace Rxlua
---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local combineLatestFactory = require("rxlua.factories.combineLatest")

---@generic T
---@param ... Observable<any>
---@return Observable<any[]>
function Observable:combineLatest(...)
    return combineLatestFactory(self, ...)
end
