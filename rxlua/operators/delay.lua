---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new
local Queue = require('luakit.queue')
local Result = require('rxlua.internal.result')
local Exception = require("luakit.exception")
local getUnhandledExceptionHandler = require("rxlua.observableSystem").getUnhandledExceptionHandler

---#region DelayObserver

local function raiseOnNext(this, notification)
    if notification.kind == 'N' then
        this.observer:onNext(notification.value)
    elseif notification.kind == 'E' then
        this.observer:onErrorResume(notification.error)
    elseif notification.kind == 'C' then
        local success, result = pcall(this.observer.onCompleted, this.observer, notification.result)
        this:dispose()
        if not success then
            error(result)
        end
    end
end

-- 这是一个静态函数, 作为 timer 的回调
local function drainMessages(this)
    ---@cast this DelayObserver
    local value
    while true do
        if this.disposed then return end

        local msg = this.queue:peek()
        if not msg then
            this.running = false
            return
        end

        local elapsed = this.timeProvider:getElapsedTime(msg.timestamp)
        if elapsed >= this.dueTime then
            value = this.queue:dequeue().notification
        else
            -- 重新设置计时器以在剩余时间后再次触发
            this.timer:change(this.dueTime - elapsed, -1)
            return
        end
        local success, result = pcall(raiseOnNext, this, value)
        if not success then
            ---@cast result string
            getUnhandledExceptionHandler()(Exception(result))
        end
    end
end

---@class DelayObserver<T>: Observer<T>
---@field package dueTime number
---@field package timeProvider TimeProvider
---@field package queue Queue<{timestamp: number, notification: {kind: 'N'|'E'|'C', value?: T, error?: any, result?: Result}}>
---@field package timer ITimer
---@field package running boolean
local DelayObserver = Class.declare('Rxlua.DelayObserver', Observer)

DelayObserver.autoDisposeOnCompleted = false

---@param observer Observer<T>
---@param dueTime number
---@param timeProvider TimeProvider
function DelayObserver:__init(observer, dueTime, timeProvider)
    self.observer = observer
    self.dueTime = dueTime
    self.timeProvider = timeProvider
    self.queue = Queue.new()
    -- 创建一个计时器, 但不立即启动
    self.timer = self.timeProvider:createTimer(drainMessages, self, -1, -1)
end

---@generic T
---@param this DelayObserver
---@param notification {kind: 'N'|'E'|'C', value?: T, error?: any, result?: Result}
local function enqueueAndStart(this, notification)
    this.queue:enqueue({ timestamp = this.timeProvider:getTimestamp(), notification = notification })
    if this.queue:size() == 1 and not this.running then
        this.running = true
        this.timer:change(0, -1) -- 启动排水
    end
end

---@param value T
---@protected
function DelayObserver:onNextCore(value)
    enqueueAndStart(self, { kind = 'N', value = value })
end

---@param error Exception
---@protected
function DelayObserver:onErrorResumeCore(error)
    -- 错误通常立即传播, 但 Delay 的逻辑是也延迟错误
    enqueueAndStart(self, { kind = 'E', error = error })
end

---@param result Result
---@protected
function DelayObserver:onCompletedCore(result)
    enqueueAndStart(self, { kind = 'C', result = result })
end

---@protected
function DelayObserver:disposeCore()
    self.timer:dispose()
    self.queue:clear()
end

---#endregion

---#region Delay

---@class Delay<T>: Observable<T>
---@field private source Observable<T>
---@field private dueTime number
---@field private timeProvider TimeProvider
local Delay = Class.declare('Rxlua.Delay', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param dueTime number
---@param timeProvider TimeProvider
function Delay:__init(source, dueTime, timeProvider)
    self.source = source
    self.dueTime = dueTime
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function Delay:subscribeCore(observer)
    local delayObserver = new(DelayObserver)(observer, self.dueTime, self.timeProvider)
    return self.source:subscribe(delayObserver)
end

---#endregion

---#region 导出到 Observable

---将源可观察序列的每个元素的发出时间延迟指定的时间.
---@param dueTime number 延迟时间(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:delay(dueTime, timeProvider)
    if dueTime < 0 then
        dueTime = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(Delay)(self, dueTime, timeProvider)
end

---#endregion
