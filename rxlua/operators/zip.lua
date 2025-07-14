---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local zipFactory = require("rxlua.factories.zip")

---@generic T
---@param ... Observable<any>
---@return Observable<any[]>
function Observable:zip(...)
    return zipFactory(self, ...)
end
