local exception = require("luakit.exception")
local new = require("luakit.class").new
local declare = require('luakit.class').declare

---@namespace Rxlua
---@using Luakit

---表示操作结果，包含成功或失败状态
---@class Result
---@field exception? Exception
local Result = declare('Rxlua.Result')

---@param error Exception
function Result:__init(error)
    self.exception = error
end

---@diagnostic disable-next-line: param-type-not-match
local defaultResult = new(Result)(nil)

---创建一个成功结果
---@return Result
function Result.success()
    return defaultResult
end

---创建一个失败的结果
---@param e Exception
---@return Result
function Result.failure(e)
    return new(Result)(e)
end

---@return boolean
function Result:isSuccess()
    return self.exception == nil
end

---@return boolean
function Result:isFailure()
    return self.exception ~= nil
end

---@return string?
function Result:getExceptionMessage()
    return self.exception and self.exception.message or nil
end

---@return string
function Result:__tostring()
    if self:isSuccess() then
        return "Success"
    else
        ---@cast self.exception -?
        return string.format("Failure {%s} ", exception.toString(self.exception))
    end
end

return Result
