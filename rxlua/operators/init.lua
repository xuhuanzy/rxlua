---@namespace Rxlua

local of = require('rxlua.operators.of')
require('rxlua.operators.skip')

---@export namespace
local Operators = {}

---创建一个Observable, 依次发出指定的值然后完成.
---@generic T
---@param ... T 要发出的值
---@return Observable<T>
function Operators.of(...)
    return of(...)
end

return Operators
