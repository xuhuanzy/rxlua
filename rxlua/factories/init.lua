local empty = require('rxlua.factories.empty')
local fromEvent = require('rxlua.factories.fromEvent')
local range = require('rxlua.factories.range')
local of = require('rxlua.factories.of')

---@namespace Rxlua

---@export namespace
local export = {}


export.of = of
export.range = range
export.fromEvent = fromEvent
export.empty = empty
return export
