---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Class = require('luakit.class')
local new = Class.new


---@type Empty
local instance

---@class Empty<T>: Observable<T>
local Empty = Class.declare('Rxlua.Empty', Observable)


---@param observer Observer<T>
---@return IDisposable
function Empty:subscribeCore(observer)
    observer:onCompleted()
    return instance
end

instance = new(Empty)()


---#region 导出到 Observable

---创建一个空的Observable
---@generic T
---@return Observable<T>
function Observable.empty()
    return instance
end

---#endregion
