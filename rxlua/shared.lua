local NOOP = require("luakit.general").NOOP


---@namespace Rxlua

---@export namespace
local export = {}

---@class IDisposable
---@field dispose fun() 取消订阅的函数








export.emptyDisposable = { dispose = NOOP } ---@type IDisposable
return export
