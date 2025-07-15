---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require("luakit.class")
local Result = require("rxlua.internal.result")
local new = Class.new

-- #region _TakeUntilStopper
---@class TakeUntil._TakeUntilStopper<TOther>: Observer<TOther>
---@field private parent TakeUntil._TakeUntil<any>
local _TakeUntilStopper = Class.declare("Rxlua.TakeUntil._TakeUntilStopper", Observer)

function _TakeUntilStopper:__init(parent)
    self.parent = parent
end

function _TakeUntilStopper:onNextCore(value)
    -- 由于`autoDisposeOnCompleted`默认为`true`, 所以`onCompleted`会自动调用`disposeCore`释放自身, 此时`self.parent`会被释放.
    self.parent:onCompleted(Result.success())
    self:dispose()
end

function _TakeUntilStopper:onErrorResumeCore(error)
    self.parent:onErrorResume(error)
end

function _TakeUntilStopper:onCompletedCore(result)
    self.parent:onCompleted(result)
end

-- #endregion

-- #region _TakeUntil
---@class TakeUntil._TakeUntil<T>: Observer<T>
---@field private observer Observer<T>
---@field public stopper TakeUntil._TakeUntilStopper<any>
local _TakeUntil = Class.declare("Rxlua.TakeUntil._TakeUntil", Observer)

function _TakeUntil:__init(observer)
    self.observer = observer
    self.stopper = new(_TakeUntilStopper)(self)
end

function _TakeUntil:onNextCore(value)
    self.observer:onNext(value)
end

function _TakeUntil:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

function _TakeUntil:onCompletedCore(result)
    self.observer:onCompleted(result)
end

function _TakeUntil:disposeCore()
    self.stopper:dispose()
end

-- #endregion

-- #region TakeUntilObservable
---@class TakeUntil<T, TOther>: Observable<T>
---@field private source Observable<T>
---@field private other Observable<TOther>
local TakeUntilObservable = Class.declare("Rxlua.TakeUntil", Observable)

function TakeUntilObservable:__init(source, other)
    self.source = source
    self.other = other
end

function TakeUntilObservable:subscribeCore(observer)
    local takeUntil = new(_TakeUntil)(observer)
    local stopperSubscription = self.other:subscribe(takeUntil.stopper)

    local success, sourceSubscription = pcall(self.source.subscribe, self.source, takeUntil)
    if not success then
        stopperSubscription:dispose()
        error()
    end
    ---@cast sourceSubscription -string
    return sourceSubscription
end

-- #endregion


---如果提供的 observable 发出值则完成. 作用相当于截止阀.
---@generic TOther
---@param other Observable<TOther> 用于发出停止信号的 Observable.
---@return Observable<T>
function Observable:takeUntil(other)
    return new(TakeUntilObservable)(self, other)
end
