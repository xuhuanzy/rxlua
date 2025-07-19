---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region TapObserver

---@class TapObserver<T>: Observer<T>
local TapObserver = Class.declare('Rxlua.TapObserver', Observer)

---@param observer Observer<T>
---@param state? any
---@param onNext? fun(value: T, state: any)
---@param onErrorResume? fun(error: any, state: any)
---@param onCompleted? fun(result: Result, state: any)
---@param onDispose? fun(state: any)
function TapObserver:__init(observer, state, onNext, onErrorResume, onCompleted, onDispose)
    self.observer = observer
    self.state = state
    self.__onNext = onNext
    self.__onErrorResume = onErrorResume
    self.__onCompleted = onCompleted
    self.__onDispose = onDispose
end

---@param value T
function TapObserver:onNextCore(value)
    if self.__onNext then
        self.__onNext(value, self.state)
    end
    self.observer:onNext(value)
end

---@param error Luakit.Exception
function TapObserver:onErrorResumeCore(error)
    if self.__onErrorResume then
        self.__onErrorResume(error, self.state)
    end
    self.observer:onErrorResume(error)
end

---@param result Result
function TapObserver:onCompletedCore(result)
    if self.__onCompleted then
        self.__onCompleted(result, self.state)
    end
    self.observer:onCompleted(result)
end

function TapObserver:disposeCore()
    if self.__onDispose then
        self.__onDispose(self.state)
    end
end

---#endregion

---#region Tap

---@class Tap<T>: Observable<T>
local Tap = Class.declare('Rxlua.Tap', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param state? any
---@param onNext? fun(value: T, state: any)
---@param onErrorResume? fun(error: any, state: any)
---@param onCompleted? fun(result: Result, state: any)
---@param onDispose? fun(state: any)
---@param onSubscribe? fun(state: any)
function Tap:__init(source, state, onNext, onErrorResume, onCompleted, onDispose, onSubscribe)
    self.source = source
    self.state = state
    self.__onNext = onNext
    self.__onErrorResume = onErrorResume
    self.__onCompleted = onCompleted
    self.__onDispose = onDispose
    self.__onSubscribe = onSubscribe
end

---@param observer Observer<T>
---@return IDisposable
function Tap:subscribeCore(observer)
    if self.__onSubscribe then
        self.__onSubscribe(self.state)
    end
    local tapObserver = new(TapObserver)(
        observer,
        self.state,
        self.__onNext,
        self.__onErrorResume,
        self.__onCompleted,
        self.__onDispose
    )
    return self.source:subscribe(tapObserver)
end

---#endregion

---#region 导出到 Observable

---@class Observable.TapCallbacks<T>
---@field state? any 状态, 通常是传一个对象
---@field onNext? fun(value: T, state: any)
---@field onErrorResume? fun(error: any, state: any)
---@field onCompleted? fun(result: Result, state: any)
---@field onDispose? fun(state: any)
---@field onSubscribe? fun(state: any)

---在源序列的生命周期内执行指定的操作.
---@param callbacks Observable.TapCallbacks<T>
---@return Observable<T>
function Observable:tap(callbacks)
    return new(Tap)(self,
        callbacks.state,
        callbacks.onNext,
        callbacks.onErrorResume,
        callbacks.onCompleted,
        callbacks.onDispose,
        callbacks.onSubscribe
    )
end

---#endregion
