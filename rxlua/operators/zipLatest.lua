---@namespace Rxlua
---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local zipLatestFactory = require("rxlua.factories.zipLatest")

---@generic T
---@param ... Observable<any>
---@return Observable<any[]>
function Observable:zipLatest(...)
    return zipLatestFactory(self, ...)
end
