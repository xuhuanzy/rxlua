local Class = require('luakit.class')
local TestFramework = require('luakit.test')
local FakeTimeProvider = require('rxlua.internal.fakeTimeProvider')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

describe("FakeTimeProvider", function()
    test("should advance time and trigger timer", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggered = false
        provider:createTimer(function()
            triggered = true
        end, nil, 500, -1)

        provider:advance(499)
        expect(triggered):toBe(false)

        provider:advance(1)
        expect(triggered):toBe(true)
    end)

    test("should set UTC now and trigger timer", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggered = false
        provider:createTimer(function()
            triggered = true
        end, nil, 1000, -1)

        provider:setUtcNow(999)
        expect(triggered):toBe(false)

        provider:setUtcNow(1000)
        expect(triggered):toBe(true)
    end)

    test("should handle periodic timers", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggerCount = 0
        provider:createTimer(function()
            triggerCount = triggerCount + 1
        end, nil, 100, 100)

        provider:advance(100)
        expect(triggerCount):toBe(1)

        provider:advance(100)
        expect(triggerCount):toBe(2)

        provider:advance(50)
        expect(triggerCount):toBe(2)

        provider:advance(50)
        expect(triggerCount):toBe(3)
    end)
end)