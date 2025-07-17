---@namespace Rxlua

local Class = require('luakit.class')
---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local Observer = require('rxlua.observer')
local new = require('luakit.class').new

-- #region MaxObserver

---@class MaxObserver<T>: Observer<T>
---@field private observer Observer<T>
---@field private max T
---@field private hasValue boolean
---@field private comparer fun(a: T, b: T): boolean
local MaxObserver = Class.declare('Rxlua.MaxObserver', Observer)

---@param observer Observer<T>
---@param comparer fun(a: T, b: T): boolean
function MaxObserver:__init(observer, comparer)
    self.observer = observer
    self.hasValue = false
    self.comparer = comparer
end

function MaxObserver:onNextCore(value)
    if not self.hasValue then
        self.hasValue = true
        self.max = value
    elseif self.comparer(value, self.max) then
        self.max = value
    end
end

function MaxObserver:onErrorResumeCore(err)
    self.observer:onErrorResume(err)
end

function MaxObserver:onCompletedCore(result)
    if result:isSuccess() then
        if self.hasValue then
            self.observer:onNext(self.max)
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

-- #region MaxObservable

local defaultComparer = function(a, b) return a > b end

---@class MaxObservable<T>: Observable<T>
---@field private source Observable<T>
---@field private comparer? fun(a: T, b: T): boolean
local MaxObservable = Class.declare('Rxlua.MaxObservable', {
    super = Observable,
    enableSuperChaining = true,
})

function MaxObservable:__init(source, comparer)
    self.source = source
    self.comparer = comparer
end

function MaxObservable:subscribeCore(observer)
    return self.source:subscribe(new(MaxObserver)(observer, self.comparer or defaultComparer))
end

-- #endregion

--- 找到源 Observable 发出的最大值, 并在源完成时发出该值.
---@param comparer? fun(a: T, b: T): boolean 可选的比较器函数.
---@return Observable<T>
function Observable:max(comparer)
    return new(MaxObservable)(self, comparer)
end
