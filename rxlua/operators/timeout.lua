---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new
local Result = require("rxlua.internal.result")
local getDefaultTimeProvider = require("rxlua.internal.timeProvider").getDefaultTimeProvider

---#region TimeoutObserver

local function publishTimeoutError(state)
    local this = state
    ---@cast this TimeoutObserver
    this:onCompleted(Result.failure("timeout"))
end

---@class TimeoutObserver<T>: Observer<T>
---@field package observer Observer<T>
---@field package dueTime number
---@field package timeProvider TimeProvider
---@field package timer ITimer
local TimeoutObserver = Class.declare('Rxlua.TimeoutObserver', Observer)

---@param observer Observer<T>
---@param dueTime number
---@param timeProvider TimeProvider
function TimeoutObserver:__init(observer, dueTime, timeProvider)
    self.observer = observer
    self.dueTime = dueTime
    self.timeProvider = timeProvider
    self.timer = timeProvider:createTimer(publishTimeoutError, self, dueTime, -1)
end

---@param value T
---@protected
function TimeoutObserver:onNextCore(value)
    self.observer:onNext(value)
    self.timer:change(self.dueTime, -1) -- 重置计时器
end

---@param error any
---@protected
function TimeoutObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function TimeoutObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---@protected
function TimeoutObserver:disposeCore()
    self.timer:dispose()
end

---#endregion

---#region Timeout

---@class Timeout<T>: Observable<T>
---@field private source Observable<T>
---@field private dueTime number
---@field private timeProvider TimeProvider
local Timeout = Class.declare('Rxlua.Timeout', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param dueTime number
---@param timeProvider TimeProvider
function Timeout:__init(source, dueTime, timeProvider)
    self.source = source
    self.dueTime = dueTime
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function Timeout:subscribeCore(observer)
    return self.source:subscribe(new(TimeoutObserver)(observer, self.dueTime, self.timeProvider))
end

---#endregion

---#region 导出到 Observable

--- 如果在指定的时间内没有收到任何值, 则发出超时错误.
---@param dueTime number 超时时间(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:timeout(dueTime, timeProvider)
    if dueTime < 0 then
        dueTime = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(Timeout)(self, dueTime, timeProvider)
end

---#endregion
