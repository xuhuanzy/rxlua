---@namespace Rxlua

local Class = require('luakit.class')
---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local Observer = require('rxlua.observer')
local new = require('luakit.class').new

-- #region ScanObserver

---@class ScanObserver<TSource, TAccumulate>: Observer<TSource>
local ScanObserver = Class.declare('Rxlua.ScanObserver', Observer)

---@param observer Observer<TAccumulate>
---@param accumulator fun(acc: TAccumulate, value: TSource): TAccumulate
---@param seed? TAccumulate
function ScanObserver:__init(observer, accumulator, seed)
    self.observer = observer
    self.accumulator = accumulator
    self.state = seed
    self.hasValue = seed ~= nil
end

function ScanObserver:onNext(value)
    if not self.hasValue then
        self.hasValue = true
        self.state = value
    else
        self.state = self.accumulator(self.state, value)
    end
    self.observer:onNext(self.state)
end

function ScanObserver:onErrorResume(err)
    self.observer:onErrorResume(err)
end

function ScanObserver:onCompleted(result)
    self.observer:onCompleted(result)
end

---@class Scan<TSource, TAccumulate>: Observable<TAccumulate>
---@field private source Observable<TSource>
---@field private accumulator fun(acc: TAccumulate, value: TSource): TAccumulate
---@field private seed? TAccumulate
local Scan = Class.declare('Rxlua.Scan', Observable)

---@param source Observable<TSource>
---@param accumulator fun(acc: TAccumulate, value: TSource): TAccumulate
---@param seed? TAccumulate
function Scan:__init(source, accumulator, seed)
    self.source = source
    self.accumulator = accumulator
    self.seed = seed
end

function Scan:subscribeCore(observer)
    return self.source:subscribe(new(ScanObserver)(observer, self.accumulator, self.seed))
end

-- #endregion

---#region 导出到 Observable

---将累加器函数应用于源 Observable, 并发送每个中间结果
---@generic TSource, TAccumulate
---@param accumulator fun(acc: TSource, value: TSource): TSource 累加器函数. 第一个参数是前一个累加结果, 第二个参数是当前源值.
---@param seed? TSource 初始累加值, 当存在时累加值从该值开始, 否则从源值的第一个开始.
---@return Observable<TAccumulate>
function Observable:scan(accumulator, seed)
    return new(Scan)(self, accumulator, seed)
end

---#endregion
