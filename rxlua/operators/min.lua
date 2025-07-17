---@namespace Rxlua

local Class = require('luakit.class')
---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local Observer = require('rxlua.observer')
local new = require('luakit.class').new

-- #region MinObserver

---@class MinObserver<T>: Observer<T>
---@field private min T
---@field private hasValue boolean
local MinObserver = Class.declare('Rxlua.MinObserver', Observer)

---@param observer Observer<T>
---@param comparer fun(a: T, b: T): boolean
function MinObserver:__init(observer, comparer)
    self.observer = observer
    self.hasValue = false
    self.comparer = comparer
end

function MinObserver:onNextCore(value)
    if not self.hasValue then
        self.hasValue = true
        self.min = value
    elseif self.comparer(value, self.min) then
        self.min = value
    end
end

function MinObserver:onErrorResumeCore(err)
    self.observer:onErrorResume(err)
end

function MinObserver:onCompletedCore(result)
    if result:isSuccess() then
        if self.hasValue then
            self.observer:onNext(self.min)
            self.observer:onCompleted(result)
        else
            -- 没有值时不发送 next 信号, 直接完成
            self.observer:onCompleted(result)
        end
    else
        self.observer:onCompleted(result)
    end
end

-- #endregion

-- #region MinObservable

local defaultComparer = function(a, b) return a < b end

---@class MinObservable<T>: Observable<T>
---@field private source Observable<T>
---@field private comparer? fun(a: T, b: T): boolean
local MinObservable = Class.declare('Rxlua.MinObservable', {
    super = Observable,
    enableSuperChaining = true,
})

function MinObservable:__init(source, comparer)
    self.source = source
    self.comparer = comparer
end

function MinObservable:subscribeCore(observer)
    return self.source:subscribe(new(MinObserver)(observer, self.comparer or defaultComparer))
end

-- #endregion

--- 找到源 Observable 发出的最小值, 并在源完成时发出该值.
---@param comparer? fun(a: T, b: T): boolean 可选的比较器函数.
---@return Observable<T>
function Observable:min(comparer)
    return new(MinObservable)(self, comparer)
end
