---@namespace Rxlua

---@class ITimer: IDisposable
---@field change fun(self: ITimer, dueTime: number, period: number) 更改计时器的时间.</br> `dueTime`: 指定时间后执行回调. </br> `period`: 计时器回调间隔, -1 表示只调用一次.

---@class TimeProvider: ITimer
---@field public getTimestamp fun(self: TimeProvider): number 获取当前时间戳(毫秒)
---@field public getElapsedTime fun(self: TimeProvider, startTimestamp: number, endTimestamp?: number): number 计算时间差(毫秒)
---@field public createTimer fun(self: TimeProvider, callback: fun(state: any), state: any, dueTime: number, period: number): ITimer 创建一个计时器



---默认时间提供者实例, 默认没有任何实现, 必须要通过`setDefaultTimeProvider`设置
---@type TimeProvider
local defaultTimeProvider

---获取默认时间提供者实例
---@return TimeProvider
local function getDefaultTimeProvider()
    return defaultTimeProvider
end

---设置默认时间提供者
---@param timeProvider TimeProvider
local function setDefaultTimeProvider(timeProvider)
    defaultTimeProvider = timeProvider
end

---@export namespace
local export = {}

export.getDefaultTimeProvider = getDefaultTimeProvider
export.setDefaultTimeProvider = setDefaultTimeProvider
return export
