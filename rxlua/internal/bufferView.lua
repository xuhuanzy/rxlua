---@namespace Rxlua

---@class BufferView<T>: {buffer: T[], start: integer, len: integer}
---@field buffer T[] 缓冲区, 必须是只读的
---@field start integer 起始索引, 从 1 开始
---@field len integer 长度
local BufferView = {}
BufferView.__index = BufferView

---@param buffer T[] 缓冲区
---@param start integer 起始索引, 从 1 开始
---@param len integer 长度
---@return BufferView<T>
function BufferView:new(buffer, start, len)
    return setmetatable({ buffer = buffer, start = start, len = len }, BufferView)
end

function BufferView:__len()
    return self.len
end

return BufferView
