---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region ThrottleLastObserver

local function raiseOnNext(state)
    local this = state
    ---@cast this ThrottleLastObserver

    if this.hasValue then
        this.observer:onNext(this.lastValue)
        this.hasValue = false
        this.lastValue = nil
    end
end

---@class ThrottleLastObserver<T>: Observer<T>
---@field package observer Observer<T>
---@field package interval number
---@field package timeProvider TimeProvider
---@field package timer ITimer
---@field package lastValue T?
---@field package hasValue boolean
local ThrottleLastObserver = Class.declare('Rxlua.ThrottleLastObserver', Observer)

---@param observer Observer<T>
---@param interval number
---@param timeProvider TimeProvider
function ThrottleLastObserver:__init(observer, interval, timeProvider)
    self.observer = observer
    self.interval = interval
    self.timeProvider = timeProvider
    self.timer = timeProvider:createTimer(raiseOnNext, self, -1, -1)
    self.hasValue = false
end

---@param value T
---@protected
function ThrottleLastObserver:onNextCore(value)
    self.lastValue = value
    if not self.hasValue then
        self.timer:change(self.interval, -1)
    end
    self.hasValue = true
end

---@param error Luakit.Exception
---@protected
function ThrottleLastObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function ThrottleLastObserver:onCompletedCore(result)
    if self.hasValue then
        self.observer:onNext(self.lastValue)
        self.hasValue = false
        self.lastValue = nil
    end
    self.observer:onCompleted(result)
end

---@protected
function ThrottleLastObserver:disposeCore()
    self.timer:dispose()
end

---#endregion

---#region ThrottleLast

---@class ThrottleLast<T>: Observable<T>
---@field private source Observable<T>
---@field private interval number
---@field private timeProvider TimeProvider
local ThrottleLast = Class.declare('Rxlua.ThrottleLast', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param interval number
---@param timeProvider TimeProvider
function ThrottleLast:__init(source, interval, timeProvider)
    self.source = source
    self.interval = interval
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function ThrottleLast:subscribeCore(observer)
    return self.source:subscribe(new(ThrottleLastObserver)(observer, self.interval, self.timeProvider))
end

---#endregion

---#region 导出到 Observable

--- 在每个时间窗口内只发出最后一个值.
---@param interval number 时间窗口(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:throttleLast(interval, timeProvider)
    if interval < 0 then
        interval = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(ThrottleLast)(self, interval, timeProvider)
end

---#endregion
