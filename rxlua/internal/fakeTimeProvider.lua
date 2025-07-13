---@namespace Rxlua

local Class = require('luakit.class')
local Timer = require("rxlua.internal.time")


---@class FakeTimeProvider: TimeProvider
---@field private _now number 当前时间
---@field private _waiters table<Time.Waiter, boolean> 等待中的计时器
---@field private _autoAdvanceAmount number 自动推进的时间量
---@field private _wakeWaitersGate boolean
local FakeTimeProvider = Class.declare('Rxlua.FakeTimeProvider')

---@param startDateTime? number 初始时间
function FakeTimeProvider:__init(startDateTime)
    self._now = startDateTime or 0
    self._waiters = {}
    self._autoAdvanceAmount = 0
    self._wakeWaitersGate = false
end

---获取当前时间戳
---@return number
function FakeTimeProvider:getTimestamp()
    local now = self._now
    self._now = self._now + self._autoAdvanceAmount
    self:_wakeWaiters()
    return now
end

---计算时间差
---@param startTimestamp number 开始时间戳
---@param endTimestamp? number 结束时间戳
---@return number
function FakeTimeProvider:getElapsedTime(startTimestamp, endTimestamp)
    endTimestamp = endTimestamp or self:getTimestamp()
    return endTimestamp - startTimestamp
end

---推进时间
---@param delta number 推进的时间量
function FakeTimeProvider:advance(delta)
    if delta < 0 then
        error("Cannot go back in time.")
    end
    self._now = self._now + delta
    self:_wakeWaiters()
end

---设置当前时间戳
---@param timestamp number 时间戳
function FakeTimeProvider:setUtcNow(timestamp)
    if timestamp < self._now then
        error("Cannot go back in time. Current time is " .. self._now)
    end
    self._now = timestamp
    self:_wakeWaiters()
end

---创建一个计时器
---@param callback fun(state: any) 回调
---@param state any 要传递给回调的对象, 允许为`nil`
---@param dueTime number 调用回调前的延迟时间, 为`0`时立即调用, 为`-1`时不会调用
---@param period number 计时器回调间隔, 为`-1`时只会调用一次
---@return ITimer
function FakeTimeProvider:createTimer(callback, state, dueTime, period)
    local timer = Timer.new(self, callback, state)
    timer:change(dueTime, period)
    return timer
end

---添加一个等待者
---@param waiter Time.Waiter
---@param dueTime number 调用回调之前延迟的时间, 为`0`时立即调用
function FakeTimeProvider:addWaiter(waiter, dueTime)
    waiter.scheduledOn = self._now
    waiter.wakeupTime = self._now + dueTime
    self._waiters[waiter] = true
    self:_wakeWaiters()
end

function FakeTimeProvider:removeWaiter(waiter)
    self._waiters[waiter] = nil
end

---唤醒等待者
---@private
function FakeTimeProvider:_wakeWaiters()
    if self._wakeWaitersGate then
        return
    end
    self._wakeWaitersGate = true
    while true do
        local selectedWaiter = nil
        for waiter, _ in pairs(self._waiters) do
            if waiter.wakeupTime <= self._now then
                if selectedWaiter == nil or
                    waiter.wakeupTime < selectedWaiter.wakeupTime or
                    (waiter.wakeupTime == selectedWaiter.wakeupTime and waiter.scheduledOn < selectedWaiter.scheduledOn) then
                    selectedWaiter = waiter
                end
            end
        end

        if selectedWaiter == nil then
            self._wakeWaitersGate = false
            break
        end
        ---@cast selectedWaiter Time.Waiter

        local nowTicks = self._now
        selectedWaiter:invokeCallback()
        local nowTicksAfter = self._now

        if selectedWaiter.period > 0 then
            selectedWaiter.scheduledOn = nowTicksAfter
            if nowTicks ~= nowTicksAfter then
                selectedWaiter.wakeupTime = nowTicksAfter + selectedWaiter.period
            else
                selectedWaiter.wakeupTime = selectedWaiter.wakeupTime + selectedWaiter.period
            end
        else
            self:removeWaiter(selectedWaiter)
        end
    end
end

return FakeTimeProvider
