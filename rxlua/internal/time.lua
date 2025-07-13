---@namespace Rxlua


---@class Time.Waiter
---@field private callback fun(state: any) 回调函数
---@field private state any 要传递给回调的对象, 允许为`nil`
---@field period number 计时器回调间隔
---@field scheduledOn number 调度时间, 用于排序
---@field wakeupTime number 唤醒时间
local Waiter = {}
Waiter.__index = Waiter

---@param callback fun(state: any)
---@param state any
---@param period number
---@return Time.Waiter
function Waiter.new(callback, state, period)
    return setmetatable({
        callback = callback,
        state = state,
        period = period,
        scheduledOn = -1,
        wakeupTime = -1,
    }, Waiter)
end

---调用回调函数
function Waiter:invokeCallback()
    self.callback(self.state)
end

---@class Time.Timer: ITimer
---@field private timeProvider FakeTimeProvider 所属的时间提供者
---@field private callback fun(state: any)
---@field private state any 要传递给回调的对象, 允许为`nil`
---@field private _waiter? Time.Waiter 等待者
local Timer = {}
Timer.__index = Timer


---@param timeProvider TimeProvider
---@param callback fun(state: any)
---@param state any
---@return Time.Timer
function Timer.new(timeProvider, callback, state)
    return setmetatable({
        timeProvider = timeProvider,
        callback = callback,
        state = state,
        _waiter = nil,
    }, Timer)
end

---更改计时器的时间
---@param dueTime number 指定时间后执行回调
---@param period number 计时器回调间隔
---@return boolean
function Timer:change(dueTime, period)
    -- 检查 timeProvider 是否存在
    local timeProvider = self.timeProvider
    if timeProvider == nil then
        return false
    end

    -- 如果已有 waiter, 先移除它
    local waiter = self._waiter
    if waiter ~= nil then
        timeProvider:removeWaiter(waiter)
        self._waiter = nil
    end

    -- 如果 dueTime < 0, 直接返回true(表示禁用计时器)
    if dueTime < 0 then
        return true
    end

    -- 如果 period < 0 或 period == -1, 设置 period 为 0 (表示只执行一次)
    if period < 0 or period == -1 then
        period = 0
    end

    -- 创建新的Waiter, 并添加到timeProvider
    local newWaiter = Waiter.new(self.callback, self.state, period)
    self._waiter = newWaiter
    timeProvider:addWaiter(newWaiter, dueTime)
    return true
end

function Timer:dispose()
    if self._waiter ~= nil and self.timeProvider ~= nil then
        self.timeProvider:removeWaiter(self._waiter)
    end
    self._waiter = nil
    self.timeProvider = nil
    self.callback = nil
    self.state = nil
end

return Timer
