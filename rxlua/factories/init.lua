local empty = require('rxlua.factories.empty')
local fromEvent = require('rxlua.factories.fromEvent')
local range = require('rxlua.factories.range')
local of = require('rxlua.factories.of')
local merge = require('rxlua.factories.merge')
local concat = require('rxlua.factories.concat')

---@namespace Rxlua

---@export namespace
local export = {}


export.of = of
export.range = range
export.fromEvent = fromEvent
export.empty = empty
export.merge = merge
export.concat = concat
return export
