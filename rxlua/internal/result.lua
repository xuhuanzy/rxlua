local new = require("luakit.class").new
local declare = require('luakit.class').declare

---@namespace Rxlua

---表示操作结果，包含成功或失败状态
---@class Result
---@field exception? any
local Result = declare('Rxlua.Result')

---@param exception any
function Result:__init(exception)
    self.exception = exception
end

local defaultResult = new(Result)(nil)

---@return Result
function Result.success()
    return defaultResult
end

---@param exception any
---@return Result
function Result.failure(exception)
    if exception == nil then
        exception = "未知错误"
    end
    return new(Result)(exception)
end

---@return boolean
function Result:isSuccess()
    return self.exception == nil
end

---@return boolean
function Result:isFailure()
    return self.exception ~= nil
end

---@return string
function Result:__tostring()
    if self:isSuccess() then
        return "Success"
    else
        return string.format("Failure{%s}", tostring(self.exception))
    end
end

return Result
