---@namespace Rxlua

local Class = require('luakit.class')
local new = require("luakit.class").new

---时间提供者接口
---@class TimeProvider
---@field getTimestamp fun(self: TimeProvider): number 获取当前时间戳(毫秒)
---@field getElapsedTime fun(self: TimeProvider, startTimestamp: number, endTimestamp: number): number 计算时间差(毫秒)

---#region SocketTimeProvider

---基于 socket 库的默认时间提供者实现
---@class SocketTimeProvider: TimeProvider
---@field private instance SocketTimeProvider 单例实例
---@field private socket any
local SocketTimeProvider = {}
SocketTimeProvider.__index = SocketTimeProvider

function SocketTimeProvider.static()
    -- 尝试加载 socket 库
    local success, socket = pcall(require, 'socket')
    if not success then
        error("SocketTimeProvider 需要 socket 库支持. 请确保 luasocket 已安装.")
    end
    if SocketTimeProvider.instance then
        return SocketTimeProvider.instance
    end
    ---@type SocketTimeProvider
    local self = setmetatable({}, SocketTimeProvider)
    SocketTimeProvider.instance = self
    self.socket = socket
    return self
end

---获取当前时间戳(毫秒)
---@return number
function SocketTimeProvider:getTimestamp()
    return self.socket.gettime() * 1000
end

---计算两个时间戳之间的时间差(毫秒)
---@param startTimestamp number 开始时间戳
---@param endTimestamp number 结束时间戳
---@return number delta 时间差(毫秒)
function SocketTimeProvider:getElapsedTime(startTimestamp, endTimestamp)
    return endTimestamp - startTimestamp
end

---#endregion SocketTimeProvider

---默认时间提供者实例
---@type TimeProvider
local defaultTimeProvider

---获取默认时间提供者实例
---@return SocketTimeProvider
local function getDefaultTimeProvider()
    if not defaultTimeProvider then
        defaultTimeProvider = SocketTimeProvider.static()
    end
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
