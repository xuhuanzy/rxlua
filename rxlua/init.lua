---@namespace Rxlua

local new = require("luakit.class").new
local ReactiveProperty = require("rxlua.reactiveProperty")

---@export
local RxLua = {}

---创建`ReactiveProperty`
---@generic T
---@param value? T 初始值
---@return ReactiveProperty<T>
function RxLua.reactiveProperty(value)
    return new("Rxlua.ReactiveProperty")(value)
end

return RxLua
