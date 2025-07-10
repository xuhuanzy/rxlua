require('rxlua.factories.empty')
require('rxlua.factories.fromEvent')
require('rxlua.factories.range')
local of = require('rxlua.factories.of')

---@namespace Rxlua

---@export namespace
local export = {}

---创建一个Observable, 依次发出指定的值然后完成.
---@generic T
---@param ... T 要发出的值
---@return Observable<T>
function export.of(...)
    return of(...)
end

export.of = of
return export
