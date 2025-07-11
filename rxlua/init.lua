---@namespace Rxlua

local new = require("luakit.class").new
local Observable = require("rxlua.observable")
local ReactiveProperty = require("rxlua.reactiveProperty")
local Subject = require("rxlua.subject")
local ReplaySubject = require("rxlua.replaySubject")
local Factories = require('rxlua.factories')
local Operators = require('rxlua.operators')

-- 刷新 Observable 类的继承关系, 确保所有新添加的方法被子类继承
local Class = require('luakit.class')
Class.refreshInheritance(Observable)

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

---创建`ReplaySubject`
---@generic T
---@param bufferSize? integer 缓冲区大小限制，默认为无限
---@param window? number 时间窗口（毫秒），默认为无限
---@param timeProvider? TimeProvider 时间提供者，默认使用 SocketTimeProvider
---@return ReplaySubject<T>
function Rxlua.replaySubject(bufferSize, window, timeProvider)
    return new("Rxlua.ReplaySubject")(bufferSize, window, timeProvider)
end

Rxlua.of = Factories.of
Rxlua.range = Factories.range
Rxlua.fromEvent = Factories.fromEvent
Rxlua.empty = Factories.empty
return Rxlua
