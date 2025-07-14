local empty = require('rxlua.factories.empty')
local fromEvent = require('rxlua.factories.fromEvent')
local range = require('rxlua.factories.range')
local of = require('rxlua.factories.of')
local merge = require('rxlua.factories.merge')
local concat = require('rxlua.factories.concat')
local zip = require('rxlua.factories.zip')
local combineLatest = require('rxlua.factories.combineLatest')
local zipLatest = require('rxlua.factories.zipLatest')
local defer = require('rxlua.factories.defer')

---@namespace Rxlua

---@export namespace
local export = {}


export.of = of
export.range = range
export.fromEvent = fromEvent
export.empty = empty
export.merge = merge
export.concat = concat
export.zip = zip
export.combineLatest = combineLatest
export.zipLatest = zipLatest
export.defer = defer
return export
