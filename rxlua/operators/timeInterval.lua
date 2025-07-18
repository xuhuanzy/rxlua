---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new
local getDefaultTimeProvider = require("rxlua.internal.timeProvider").getDefaultTimeProvider

---#region TimeIntervalObserver

---@class TimeIntervalObserver<T>: Observer<T>
---@field package observer Observer<{interval: number, value: T}>
---@field package timeProvider TimeProvider
---@field package previousTimestamp number
local TimeIntervalObserver = Class.declare('Rxlua.TimeIntervalObserver', Observer)

---@param observer Observer<{interval: number, value: T}>
---@param timeProvider TimeProvider
function TimeIntervalObserver:__init(observer, timeProvider)
    self.observer = observer
    self.timeProvider = timeProvider
    self.previousTimestamp = timeProvider:getTimestamp()
end

---@param value T
---@protected
function TimeIntervalObserver:onNextCore(value)
    local currentTimestamp = self.timeProvider:getTimestamp()
    local elapsed = self.timeProvider:getElapsedTime(self.previousTimestamp, currentTimestamp)
    self.previousTimestamp = currentTimestamp

    self.observer:onNext({ interval = elapsed, value = value })
end

---@param error IException
---@protected
function TimeIntervalObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function TimeIntervalObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region TimeInterval

---@class TimeInterval<T>: Observable<{interval: number, value: T}>
---@field private source Observable<T>
---@field private timeProvider TimeProvider
local TimeInterval = Class.declare('Rxlua.TimeInterval', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param timeProvider TimeProvider
function TimeInterval:__init(source, timeProvider)
    self.source = source
    self.timeProvider = timeProvider
end

---@param observer Observer<{interval: number, value: T}>
---@return IDisposable
function TimeInterval:subscribeCore(observer)
    return self.source:subscribe(new(TimeIntervalObserver)(observer, self.timeProvider))
end

---#endregion

---#region 导出到 Observable

--- 记录源 Observable 发出的值之间的时间间隔.
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<{interval: number, value: T}>
function Observable:timeInterval(timeProvider)
    timeProvider = timeProvider or getDefaultTimeProvider()
    return new(TimeInterval)(self, timeProvider)
end

---#endregion
