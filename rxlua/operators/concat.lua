---@namespace Rxlua
---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local concatFactory = require("rxlua.factories.concat")

---@generic T
---@param ... Observable<T>
---@return Observable<T>
function Observable:concat(...)
    return concatFactory(self, ...)
end
