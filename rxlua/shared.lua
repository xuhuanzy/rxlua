local NOOP = require("luakit.general").NOOP


---@namespace Rxlua

---@export namespace
local export = {}







export.emptyDisposable = { dispose = NOOP } ---@type IDisposable
return export
