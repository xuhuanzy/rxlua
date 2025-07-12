---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region DistinctObserver

---@class DistinctObserver<T, TKey>: Observer<T>
---@field private observer Observer<T>
---@field private set table<TKey, boolean>
local DistinctObserver = Class.declare('Rxlua.DistinctObserver', Observer)

---@param observer Observer<T>
---@param keySelector? fun(value: T): TKey
---@param comparer? fun(x: TKey, y: TKey): boolean
function DistinctObserver:__init(observer, keySelector, comparer)
    self.observer = observer
    self.keySelector = keySelector
    self.comparer = comparer
    self.set = {}
end

---@param value T
function DistinctObserver:onNextCore(value)
    local key = self.keySelector and self.keySelector(value) or value

    if not self.comparer and type(key) == "table" then
        warn("Warning: 当值类型为`table`时, distinct() 与 distinctBy() 必须提供一个比较器用于解决相等性问题.")
    end

    local seen = false
    if self.comparer then
        local comparer = self.comparer
        for seenKey, _ in pairs(self.set) do
            if comparer(seenKey, key) then
                seen = true
                break
            end
        end
    else
        seen = self.set[key]
    end

    if not seen then
        self.set[key] = true
        self.observer:onNext(value)
    end
end

---@param error any
function DistinctObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function DistinctObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region Distinct

---@class Distinct<T, TKey>: Observable<T>
---@field private source Observable<T>
local Distinct = Class.declare('Rxlua.Distinct', Observable)

---@param source Observable<T>
---@param keySelector? fun(value: T): TKey
---@param comparer? fun(x: TKey, y: TKey): boolean
function Distinct:__init(source, keySelector, comparer)
    self.source = source
    self.keySelector = keySelector
    self.comparer = comparer
end

---@param observer Observer<T>
---@return IDisposable
function Distinct:subscribeCore(observer)
    local distinctObserver = new(DistinctObserver)(observer, self.keySelector, self.comparer)
    return self.source:subscribe(distinctObserver)
end

---#endregion

---#region 导出到 Observable

---返回源序列中的非重复元素.
---@generic T
---@param comparer? fun(x: T, y: T): boolean 相等比较器
---@return Observable<T>
function Observable:distinct(comparer)
    return new(Distinct)(self, nil, comparer)
end

---根据指定的键选择器函数, 返回源序列中的非重复元素. <br>
---@generic TSource, TKey
---@param keySelector fun(value: TSource): TKey 指定键用于判断是否重复
---@param comparer? fun(x: TKey, y: TKey): boolean 相等比较器
---@return Observable<TSource>
function Observable:distinctBy(keySelector, comparer)
    return new(Distinct)(self, keySelector, comparer)
end

---#endregion
