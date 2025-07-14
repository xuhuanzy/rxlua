---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require("luakit.class")
local new = Class.new

-- #region _Timer

---@param self Timer._Timer
local function singleTick(self)
    local success, err = pcall(self.observer.onNext, self.observer, self.count)
    if success then
        self.count = self.count + 1
        success, err = pcall(self.observer.onCompleted, self.observer)
    end
    self:dispose()
    if not success then
        error(err)
    end
end

---@param self Timer._Timer
local function periodicTick(self)
    self.observer:onNext(self.count)
    self.count = self.count + 1
end


---@class Timer._Timer: IDisposable
---@field private observer Observer<void>
---@field private timer ITimer
local _Timer = Class.declare("Rxlua.Timer._Timer")

function _Timer:__init(observer)
    self.observer = observer
    self.count = 0
end

function _Timer:setTimer(timer)
    self.timer = timer
end

function _Timer:completeDispose()
    self.observer:onCompleted()
    self:dispose()
end

function _Timer:dispose()
    if self.timer then
        self.timer:dispose()
        self.timer = nil
    end
end

-- #endregion

-- #region TimerObservable
---@class Timer.TimerObservable: Observable<integer>
---@field private dueTime number
---@field private period? number
---@field private timeProvider TimeProvider
local TimerObservable = Class.declare("Rxlua.Timer.TimerObservable", Observable)

function TimerObservable:__init(dueTime, period, timeProvider)
    self.dueTime = dueTime
    self.period = period
    self.timeProvider = timeProvider
end

function TimerObservable:subscribeCore(observer)
    local state = new(_Timer)(observer)

    local timer = self.timeProvider:createTimer(
        (self.period == nil) and singleTick or periodicTick,
        state,
        -1,
        -1
    )
    state:setTimer(timer)

    if self.period == nil then
        timer:change(self.dueTime, -1)
    else
        timer:change(self.dueTime, self.period)
    end

    return state
end

-- #endregion

--- 创建一个 Observable, 在指定的 dueTime 后发出一个值, 然后根据可选的 period 重复发出.
---@param dueTime number 首次发出值前的延迟时间(毫秒).
---@param period? number 后续发出值的间隔时间(毫秒). 如果为 nil, 则只发出一次.
---@param timeProvider TimeProvider 时间提供者.
---@return Observable<integer> # 发出的值是从 0 开始计数的整数.
local function timer(dueTime, period, timeProvider)
    return new(TimerObservable)(dueTime, period, timeProvider)
end

--- 创建一个 Observable, 按指定的时间间隔发出连续的整数.
---@param period number 发出值的间隔时间(毫秒).
---@param timeProvider TimeProvider 时间提供者.
---@return Observable<integer> # 发出的值是从 0 开始计数的整数.
local function interval(period, timeProvider)
    return new(TimerObservable)(period, period, timeProvider)
end

return { timer = timer, interval = interval }
