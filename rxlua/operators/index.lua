---@namespace Rxlua
---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region IndexObserver

---@class IndexObserver<T>: Observer<T>
---@field private observer Observer<{index: integer, value: T}>
---@field private index integer 索引, 从1开始
local IndexObserver = Class.declare('Rxlua.IndexObserver', Observer)

---@param observer Observer<{index: integer, value: T}>
function IndexObserver:__init(observer)
    self.observer = observer
    self.index = 0
end

---@param value T
function IndexObserver:onNextCore(value)
    self.index = self.index + 1
    self.observer:onNext({ index = self.index, value = value })
end

---@param error Luakit.Exception
function IndexObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function IndexObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region Index

---@class Index<T>: Observable<{index: integer, value: T}>
---@field private source Observable<T>
local Index = Class.declare('Rxlua.Index', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
function Index:__init(source)
    self.source = source
end

---@param observer Observer<{index: integer, value: T}>
---@return IDisposable
function Index:subscribeCore(observer)
    local indexObserver = new(IndexObserver)(observer)
    return self.source:subscribe(indexObserver)
end

---#endregion

---#region 导出到 Observable

---为可观察序列的每个元素添加一个从1开始的索引.
---@return Observable<{index: integer, value: T}>
function Observable:index()
    return new(Index)(self)
end

---#endregion
