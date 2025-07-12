
local Class = require('luakit.class')
local Test = require('luakit.test')
local FakeTimeProvider = require('rxlua.internal.fakeTimeProvider')

Test.describe("FakeTimeProvider", function()
    Test.test("should advance time and trigger timer", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggered = false
        provider:createTimer(function()
            triggered = true
        end, nil, 500, -1)

        provider:advance(499)
        Test.expect(triggered):toBe(false)

        provider:advance(1)
        Test.expect(triggered):toBe(true)
    end)

    Test.test("should set UTC now and trigger timer", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggered = false
        provider:createTimer(function()
            triggered = true
        end, nil, 1000, -1)

        provider:setUtcNow(999)
        Test.expect(triggered):toBe(false)

        provider:setUtcNow(1000)
        Test.expect(triggered):toBe(true)
    end)

    Test.test("should handle periodic timers", function()
        local provider = Class.new(FakeTimeProvider)(0)
        local triggerCount = 0
        provider:createTimer(function()
            triggerCount = triggerCount + 1
        end, nil, 100, 100)

        provider:advance(100)
        Test.expect(triggerCount):toBe(1)

        provider:advance(100)
        Test.expect(triggerCount):toBe(2)

        provider:advance(50)
        Test.expect(triggerCount):toBe(2)

        provider:advance(50)
        Test.expect(triggerCount):toBe(3)
    end)
end)
