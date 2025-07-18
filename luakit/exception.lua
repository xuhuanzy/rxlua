---@namespace Luakit

---@class IException
---@field type string 异常类型
---@field message string 异常消息

---@export global
---@class Exception: IException
---@overload fun(message: string, name?: string): IException
local Exception = setmetatable({}, {
    ---@param self Exception
    ---@param message string
    ---@param name? string
    ---@return IException
    __call = function(self, message, name)
        ---@cast self Exception
        return self.new(message, name)
    end
})
Exception.__index = Exception

---@param message string
---@param name? string
---@return IException
function Exception.new(message, name)
    return setmetatable({
        name = name or "Exception",
        message = message
    }, Exception)
end

---@return string
function Exception:__tostring()
    return Exception.toString(self)
end

---@param other IException
---@return boolean
function Exception:__eq(other)
    return self.type == other.type and self.message == other.message
end

---判断是否为目标异常.
---@param target IException
---@return boolean
function Exception:is(target)
    return self.type == target.type
end

---@param error IException
---@return string
function Exception.toString(error)
    return error.type .. ": " .. error.message
end

return Exception
