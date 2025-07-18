local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe
local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('timeout', function()
    test('无超时发生', function()
        local results = {}
        local completed = false
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeout(100, timeProvider)
            :subscribe({
                next = function(x) table.insert(results, x) end,
                completed = function() completed = true end
            })

        timeProvider:advance(50)
        source:onNext(1)
        timeProvider:advance(50)
        source:onNext(2)
        source:onCompleted(Result.success())

        expect(results):toEqual({ 1, 2 })
        expect(completed):toBe(true)
    end)

    test('发生超时', function()
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeout(100, timeProvider)
            :subscribe({
                next = function(_) end,
                completed = function(result) if result:isFailure() then error = result:getExceptionMessage() end end
            })

        timeProvider:advance(101)

        expect(error):toBe("timeout")
    end)

    test('在值之间发生超时', function()
        local results = {}
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeout(100, timeProvider)
            :subscribe({
                next = function(x) table.insert(results, x) end,
                completed = function(result) if result:isFailure() then error = result:getExceptionMessage() end end
            })

        source:onNext(1)
        timeProvider:advance(101)

        expect(results):toEqual({ 1 })
        expect(error):toBe("timeout")
    end)

    test('正常完成后不应超时', function()
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeout(100, timeProvider)
            :subscribe({
                next = function(_) end,
                completed = function(result) if result:isFailure() then error = result.exception end end
            })

        source:onCompleted(Result.success())
        timeProvider:advance(101)

        expect(error):toBe(nil)
    end)

    test('订阅取消', function()
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        local subscription = source
            :timeout(100, timeProvider)
            :subscribe({
                next = function(_) end,
                completed = function(result) if result:isFailure() then error = result.exception end end
            })

        subscription:dispose()
        timeProvider:advance(101)

        expect(error):toBe(nil)
    end)
end)
