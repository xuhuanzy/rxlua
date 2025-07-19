---@namespace Rxlua

local returnOnCompleted = require("rxlua.factories.returnOnCompleted")
local Result = require("rxlua.internal.result")
local Exception = require("luakit.exception")

---创建一个 Observable, 它会立即或在指定延迟后以指定的异常终止.
---@generic T
---@param exception string | Luakit.Exception 异常信息.
---@param dueTime? number 延迟时间(毫秒). 默认为 0, 即立即失败.
---@param timeProvider? TimeProvider 时间提供者.
---@return Observable<T>
local function throw(exception, dueTime, timeProvider)
    if type(exception) == "string" then
        exception = Exception(exception)
    end
    local result = Result.failure(exception)
    return returnOnCompleted(result, dueTime, timeProvider)
end

return throw
