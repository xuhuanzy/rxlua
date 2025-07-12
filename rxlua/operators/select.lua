---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region SelectObserver

---@class SelectObserver<T, R>: Observer<T>
---@field private observer Observer<R>
---@field private index integer 索引, 从1开始
local SelectObserver = Class.declare('Rxlua.SelectObserver', Observer)

---@param observer Observer<R>
---@param selector fun(value: T, index?: integer): R
function SelectObserver:__init(observer, selector)
    self.observer = observer
    self.selector = selector
    self.index = 1
end

---@param value T
function SelectObserver:onNextCore(value)
    local result = self.selector(value, self.index)
    self.observer:onNext(result)
    self.index = self.index + 1
end

---@param error any
function SelectObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function SelectObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region Select

---@class Select<T, R>: Observable<R>
---@field private source Observable<T>
local Select = Class.declare('Rxlua.Select', Observable)

---@param source Observable<T>
---@param selector fun(value: T, index?: integer): R
function Select:__init(source, selector)
    self.source = source
    self.selector = selector
end

---@param observer Observer<R>
---@return IDisposable
function Select:subscribeCore(observer)
    local selectObserver = new(SelectObserver)(observer, self.selector)
    return self.source:subscribe(selectObserver)
end

---#endregion

---#region 导出到 Observable

---将源序列中的每个元素转换成另一种形式.
---@generic R
---@param selector fun(value: T, index?: integer): R 转换函数, 可选接收索引(索引从1开始)
---@return Observable<R>
function Observable:select(selector)
    return new(Select)(self, selector)
end

---#endregion
