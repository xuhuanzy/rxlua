---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Class = require('luakit.class')
local new = Class.new


---@type Empty
local instance

---@class Empty<T>: Observable<T>
local Empty = Class.declare('Rxlua.Empty', {
    super = Observable,
    enableSuperChaining = true,
})


---@param observer Observer<T>
---@return IDisposable
function Empty:subscribeCore(observer)
    -- 直接执行完成, 因为 Empty 是空的, 所以不需要处理任何值.
    observer:onCompleted()
    return instance
end

instance = new(Empty)()

---获取空的 Observable
---@generic T
---@return Observable<T>
local function empty()
    return instance
end

return empty
