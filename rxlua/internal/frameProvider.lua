---@namespace Rxlua
local Class = require('luakit.class')
local getUnhandledExceptionHandler = require("rxlua.observableSystem").getUnhandledExceptionHandler

---@class IFrameRunnerWorkItem
---@field moveNext fun(self: IFrameRunnerWorkItem, frameCount: number): boolean 帧回调函数. 返回 true 继续执行, false 停止执行

---@class FrameProvider
---@field public getFrameCount fun(self: FrameProvider): number 获取当前帧数
---@field public register fun(self: FrameProvider, callback: IFrameRunnerWorkItem) 注册帧回调


---@class FakeFrameProvider: FrameProvider
---@field private _frameCount integer 当前帧数
---@field private _callbacks table<IFrameRunnerWorkItem, boolean> 回调集合
local FakeFrameProvider = Class.declare('Rxlua.FakeFrameProvider')

---构造函数
---@param frameCount? integer 初始帧数, 默认为 0
function FakeFrameProvider:__init(frameCount)
    self._frameCount = frameCount or 0
    self._callbacks = {}
end

---获取当前帧数
---@return number
function FakeFrameProvider:getFrameCount()
    return self._frameCount
end

---注册帧回调
---@param callback IFrameRunnerWorkItem
function FakeFrameProvider:register(callback)
    self._callbacks[callback] = true
end

---推进帧数, 如果不传入参数, 则推进一帧.
---@param advanceCount? int 要推进的帧数, 不允许小于 0
function FakeFrameProvider:advance(advanceCount)
    advanceCount = advanceCount or 1
    for _ = 1, advanceCount do
        self:runLoop()
    end
end

---获取已注册的回调数量
---@return number
function FakeFrameProvider:getRegisteredCount()
    local count = 0
    for _ in pairs(self._callbacks) do
        count = count + 1
    end
    return count
end

---执行一次帧循环
---@private
function FakeFrameProvider:runLoop()
    local toRemove = {}

    -- 执行所有回调
    for callback, _ in pairs(self._callbacks) do
        local success, shouldContinue = pcall(callback.moveNext, callback, self._frameCount)

        if not success then
            ---@cast shouldContinue string
            -- 发生异常, 移除回调并处理异常
            table.insert(toRemove, callback)
            pcall(getUnhandledExceptionHandler(), {
                type = "Exception",
                message = shouldContinue,
            })
        elseif not shouldContinue then
            -- 回调返回 false, 移除回调
            table.insert(toRemove, callback)
        end
    end

    -- 移除需要删除的回调
    for _, callback in ipairs(toRemove) do
        self._callbacks[callback] = nil
    end

    -- 增加帧数
    self._frameCount = self._frameCount + 1
end

return FakeFrameProvider
