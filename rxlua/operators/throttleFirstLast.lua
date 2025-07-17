---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region ThrottleFirstLastObserver

local function raiseOnNext(state)
    local this = state
    ---@cast this ThrottleFirstLastObserver

    this.timerIsRunning = false
    if this.hasValue then
        this.observer:onNext(this.lastValue)
        this.hasValue = false
        this.lastValue = nil
    end
end

---@class ThrottleFirstLastObserver<T>: Observer<T>
---@field package observer Observer<T>
---@field package interval number
---@field package timeProvider TimeProvider
---@field package timer ITimer
---@field package lastValue T?
---@field package hasValue boolean
---@field package timerIsRunning boolean
local ThrottleFirstLastObserver = Class.declare('Rxlua.ThrottleFirstLastObserver', Observer)

---@param observer Observer<T>
---@param interval number
---@param timeProvider TimeProvider
function ThrottleFirstLastObserver:__init(observer, interval, timeProvider)
    self.observer = observer
    self.interval = interval
    self.timeProvider = timeProvider
    self.timer = timeProvider:createTimer(raiseOnNext, self, -1, -1)
    self.hasValue = false
    self.timerIsRunning = false
end

---@param value T
---@protected
function ThrottleFirstLastObserver:onNextCore(value)
    if not self.timerIsRunning then
        self.timerIsRunning = true
        self.observer:onNext(value)
        self.timer:change(self.interval, -1)
    else
        self.hasValue = true
        self.lastValue = value
    end
end

---@param error any
---@protected
function ThrottleFirstLastObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function ThrottleFirstLastObserver:onCompletedCore(result)
    if self.hasValue then
        self.observer:onNext(self.lastValue)
        self.hasValue = false
        self.lastValue = nil
    end
    self.observer:onCompleted(result)
end

---@protected
function ThrottleFirstLastObserver:disposeCore()
    self.timer:dispose()
end

---#endregion

---#region ThrottleFirstLast

---@class ThrottleFirstLast<T>: Observable<T>
---@field private source Observable<T>
---@field private interval number
---@field private timeProvider TimeProvider
local ThrottleFirstLast = Class.declare('Rxlua.ThrottleFirstLast', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param interval number
---@param timeProvider TimeProvider
function ThrottleFirstLast:__init(source, interval, timeProvider)
    self.source = source
    self.interval = interval
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function ThrottleFirstLast:subscribeCore(observer)
    return self.source:subscribe(new(ThrottleFirstLastObserver)(observer, self.interval, self.timeProvider))
end

---#endregion

---#region 导出到 Observable

--- 在一个时间窗口内, 发出第一个和最后一个值.
---@param interval number 时间窗口(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:throttleFirstLast(interval, timeProvider)
    if interval < 0 then
        interval = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(ThrottleFirstLast)(self, interval, timeProvider)
end

---#endregion
