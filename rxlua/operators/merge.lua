---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local mergeFactory = require('rxlua.factories.merge')

---将另一个Observable与源Observable合并.
---@generic T
---@param other Observable<T> 要合并的另一个Observable.
---@return Observable<T>
function Observable:merge(other)
    return mergeFactory(self, other)
end
