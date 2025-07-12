---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local defaultEqualityComparer = require("luakit.general").defaultEqualityComparer
local new = Class.new

---#region DistinctUntilChangedObserver

---@class DistinctUntilChangedObserver<T, TKey>: Observer<T>
---@field private observer Observer<T>
---@field private lastValue TKey
---@field private hasValue boolean
local DistinctUntilChangedObserver = Class.declare('Rxlua.DistinctUntilChangedObserver', Observer)

---@param observer Observer<T>
---@param keySelector? fun(value: T): TKey
---@param comparer? fun(x: TKey, y: TKey): boolean
function DistinctUntilChangedObserver:__init(observer, keySelector, comparer)
    self.observer = observer
    self.keySelector = keySelector
    self.comparer = comparer or defaultEqualityComparer
    self.hasValue = false
end

---@param value T
function DistinctUntilChangedObserver:onNextCore(value)
    local key = self.keySelector and self.keySelector(value) or value

    local comparer = self.comparer

    if not self.hasValue or not comparer(self.lastValue, key) then
        self.hasValue = true
        self.lastValue = key
        self.observer:onNext(value)
    end
end

---@param error any
function DistinctUntilChangedObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function DistinctUntilChangedObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region DistinctUntilChanged

---@class DistinctUntilChanged<T, TKey>: Observable<T>
---@field private source Observable<T>
local DistinctUntilChanged = Class.declare('Rxlua.DistinctUntilChanged', Observable)

---@param source Observable<T>
---@param keySelector? fun(value: T): TKey
---@param comparer? fun(x: TKey, y: TKey): boolean
function DistinctUntilChanged:__init(source, keySelector, comparer)
    self.source = source
    self.keySelector = keySelector
    self.comparer = comparer
end

---@param observer Observer<T>
---@return IDisposable
function DistinctUntilChanged:subscribeCore(observer)
    local distinctUntilChangedObserver = new(DistinctUntilChangedObserver)(observer, self.keySelector, self.comparer)
    return self.source:subscribe(distinctUntilChangedObserver)
end

---#endregion

---#region 导出到 Observable

---过滤掉连续重复的元素.
---@generic T
---@param comparer? fun(x: T, y: T): boolean 相等比较器
---@return Observable<T>
function Observable:distinctUntilChanged(comparer)
    return new(DistinctUntilChanged)(self, nil, comparer)
end

---根据指定的键选择器函数, 过滤掉连续重复的元素.
---@generic TSource, TKey
---@param keySelector fun(value: TSource): TKey 指定键用于判断是否重复
---@param comparer? fun(x: TKey, y: TKey): boolean 相等比较器
---@return Observable<TSource>
function Observable:distinctUntilChangedBy(keySelector, comparer)
    return new(DistinctUntilChanged)(self, keySelector, comparer)
end

---#endregion
