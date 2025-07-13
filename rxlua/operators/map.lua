---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region MapObserver

---@class MapObserver<T, R>: Observer<T>
---@field private observer Observer<R>
---@field private index integer 索引, 从1开始
local MapObserver = Class.declare('Rxlua.MapObserver', Observer)

---@param observer Observer<R>
---@param map fun(value: T, index?: integer): R
function MapObserver:__init(observer, map)
    self.observer = observer
    self.map = map
    self.index = 1
end

---@param value T
function MapObserver:onNextCore(value)
    local result = self.map(value, self.index)
    self.observer:onNext(result)
    self.index = self.index + 1
end

---@param error any
function MapObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function MapObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region Map

---@class Map<T, R>: Observable<R>
---@field private source Observable<T>
local Map = Class.declare('Rxlua.Map', Observable)

---@param source Observable<T>
---@param map fun(value: T, index?: integer): R
function Map:__init(source, map)
    self.source = source
    self.map = map
end

---@param observer Observer<R>
---@return IDisposable
function Map:subscribeCore(observer)
    local mapObserver = new(MapObserver)(observer, self.map)
    return self.source:subscribe(mapObserver)
end

---#endregion

---#region 导出到 Observable

---将源序列中的每个元素转换成另一种形式.
---@generic R
---@param map fun(value: T, index?: integer): R 转换函数, 可选接收索引(索引从1开始)
---@return Observable<R>
function Observable:map(map)
    return new(Map)(self, map)
end

---#endregion
