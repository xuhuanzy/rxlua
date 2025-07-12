---@namespace Rxlua

local Class = require('luakit.class')
local new = require("luakit.class").new

---@class ITimer: IDisposable
---@field change fun(self: ITimer, dueTime: number, period: number) 更改计时器的时间.</br> `dueTime`: 指定时间后执行回调. </br> `period`: 计时器回调间隔, -1 表示只调用一次.

---@class TimeProvider: ITimer
---@field public getTimestamp fun(self: TimeProvider): number 获取当前时间戳(毫秒)
---@field public getElapsedTime fun(self: TimeProvider, startTimestamp: number, endTimestamp: number): number 计算时间差(毫秒)
---@field public createTimer fun(self: TimeProvider, callback: fun(state: any), state: any, dueTime: number, period: number): ITimer 创建一个计时器


---#region SystemTimeProvider

---基于 socket 库的默认时间提供者实现
---@class SystemTimeProvider: TimeProvider
---@field private instance SystemTimeProvider 单例实例
local SystemTimeProvider = {}
SystemTimeProvider.__index = SystemTimeProvider

---获取当前时间戳(毫秒)
---@return number
function SystemTimeProvider:getTimestamp()
    return os.time() * 1000 -- `os.time()`获取到的是10位的秒时间戳, 需要转换为13位毫秒时间戳
end

---计算两个时间戳之间的时间差(毫秒)
---@param startTimestamp number 开始时间戳
---@param endTimestamp number 结束时间戳
---@return number delta 时间差(毫秒)
function SystemTimeProvider:getElapsedTime(startTimestamp, endTimestamp)
    return endTimestamp - startTimestamp
end

---#endregion SystemTimeProvider

---默认时间提供者实例
---@type TimeProvider
local defaultTimeProvider = setmetatable({}, SystemTimeProvider)

---获取默认时间提供者实例
---@return SystemTimeProvider
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
