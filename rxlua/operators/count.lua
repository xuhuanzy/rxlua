---@namespace Rxlua

local Class = require('luakit.class')
---@class (partial) Observable<T>
local Observable = require('rxlua.observable')
local Observer = require('rxlua.observer')
local new = require('luakit.class').new

-- #region CountObserver

---@class CountObserver<T>: Observer<T>
---@field private observer Observer<integer>
---@field private count integer
local CountObserver = Class.declare('Rxlua.CountObserver', Observer)

function CountObserver:__init(observer)
    self.observer = observer
    self.count = 0
end

function CountObserver:onNextCore(value)
    self.count = self.count + 1
end

function CountObserver:onErrorResumeCore(err)
    self.observer:onErrorResume(err)
end

function CountObserver:onCompletedCore(result)
    if result:isSuccess() then
        self.observer:onNext(self.count)
        self.observer:onCompleted(result)
    else
        self.observer:onCompleted(result)
    end
end

-- #endregion

-- #region CountObservable

---@class CountObservable<T>: Observable<integer>
---@field private source Observable<T>
local CountObservable = Class.declare('Rxlua.CountObservable', Observable)

function CountObservable:__init(source)
    self.source = source
end

function CountObservable:subscribeCore(observer)
    return self.source:subscribe(new(CountObserver)(observer))
end

-- #endregion

--- 计算源 Observable 发出的值的数量, 并在源完成时发出该值.
---@return Observable<integer>
function Observable:count()
    return new(CountObservable)(self)
end
