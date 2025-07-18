local Class = require("luakit.class")
local TestFramework = require('luakit.test')
local FakeFrameProvider = require("rxlua.internal.frameProvider")
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

-- 测试用的回调实现
---@class Rxlua.Test.FakeFrameProviderCallback: Rxlua.IFrameRunnerWorkItem
local TestCallback = {}
TestCallback.__index = TestCallback

---@param shouldContinue boolean|(fun(frameCount: number): boolean)
---@param onMoveNext? fun(frameCount: number): boolean
---@return Rxlua.Test.FakeFrameProviderCallback
function TestCallback.new(shouldContinue, onMoveNext)
    local self = setmetatable({}, TestCallback)
    self.shouldContinue = shouldContinue == nil and true or shouldContinue
    self.onMoveNext = onMoveNext
    self.callCount = 0
    self.lastFrameCount = nil
    return self
end

function TestCallback:moveNext(frameCount)
    self.callCount = self.callCount + 1
    self.lastFrameCount = frameCount

    if self.onMoveNext then
        self.onMoveNext(frameCount)
    end

    if type(self.shouldContinue) == 'function' then
        return self.shouldContinue(frameCount)
    else
        ---@cast self.shouldContinue -?
        return self.shouldContinue
    end
end

describe("FakeFrameProvider", function()
    test("should initialize with default frame count", function()
        local provider = Class.new(FakeFrameProvider)()
        expect(provider:getFrameCount()):toBe(0)
        expect(provider:getRegisteredCount()):toBe(0)
    end)

    test("should initialize with custom frame count", function()
        local provider = Class.new(FakeFrameProvider)(100)
        expect(provider:getFrameCount()):toBe(100)
    end)

    test("should register and execute callback", function()
        local provider = Class.new(FakeFrameProvider)(0)
        local callback = TestCallback.new(true)

        provider:register(callback)
        expect(provider:getRegisteredCount()):toBe(1)

        provider:advance()
        expect(callback.callCount):toBe(1)
        expect(callback.lastFrameCount):toBe(0)
        expect(provider:getFrameCount()):toBe(1)
    end)

    test("should remove callback when it returns false", function()
        local provider = Class.new(FakeFrameProvider)(0)
        local callback = TestCallback.new(false)

        provider:register(callback)
        expect(provider:getRegisteredCount()):toBe(1)

        provider:advance()
        expect(callback.callCount):toBe(1)
        expect(provider:getRegisteredCount()):toBe(0)
    end)

    test("should advance multiple frames", function()
        local provider = Class.new(FakeFrameProvider)(0)
        local callback = TestCallback.new(true)

        provider:register(callback)
        provider:advance(5)

        expect(callback.callCount):toBe(5)
        expect(provider:getFrameCount()):toBe(5)
    end)

    test("should handle multiple callbacks", function()
        local provider = Class.new(FakeFrameProvider)(0)
        local callback1 = TestCallback.new(true)
        local callback2 = TestCallback.new(function(frameCount) return frameCount < 2 end)

        provider:register(callback1)
        provider:register(callback2)
        expect(provider:getRegisteredCount()):toBe(2)

        provider:advance(3)

        expect(callback1.callCount):toBe(3)
        expect(callback2.callCount):toBe(3)           -- 调用3次, 但第3次返回false
        expect(provider:getRegisteredCount()):toBe(1) -- callback2被移除
    end)

    test("should handle callback exceptions", function()
        local provider = Class.new(FakeFrameProvider)(0)
        local errorCallback = TestCallback.new(true)
        errorCallback.moveNext = function() error("test error") end

        local normalCallback = TestCallback.new(true)

        provider:register(errorCallback)
        provider:register(normalCallback)

        provider:advance()

        -- 异常回调应该被移除, 正常回调继续执行
        expect(provider:getRegisteredCount()):toBe(1)
        expect(normalCallback.callCount):toBe(1)
    end)
end)
