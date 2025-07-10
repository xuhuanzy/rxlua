---@namespace Rxlua

local new = require("luakit.class").new
local Observable = require("rxlua.observable")
local ReactiveProperty = require("rxlua.reactiveProperty")
local Subject = require("rxlua.subject")
local Factories = require('rxlua.factories')
local Operators = require('rxlua.operators')

---@export
local Rxlua = {}

Rxlua.Observable = Observable

---创建`ReactiveProperty`
---@generic T
---@param value? T 初始值
---@return ReactiveProperty<T>
function Rxlua.reactiveProperty(value)
    return new("Rxlua.ReactiveProperty")(value)
end

---创建`Subject`
---@generic T
---@return Subject<T>
function Rxlua.subject()
    return new("Rxlua.Subject")()
end

Rxlua.of = Factories.of
return Rxlua
