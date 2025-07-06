---@namespace Rxlua

local new = require("luakit.class").new
local ReactiveProperty = require("rxlua.reactiveProperty")
local Subject = require("rxlua.subject")

---@export
local RxLua = {}

---创建`ReactiveProperty`
---@generic T
---@param value? T 初始值
---@return ReactiveProperty<T>
function RxLua.reactiveProperty(value)
    return new("Rxlua.ReactiveProperty")(value)
end

---创建`Subject`
---@generic T
---@return Subject<T>
function RxLua.subject()
    return new("Rxlua.Subject")()
end

return RxLua
