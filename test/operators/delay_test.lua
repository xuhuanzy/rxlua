local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('delay', function()
    test('确保所有值都被延迟', function()
        local results = {}
        local completed = false
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :delay(3, timeProvider)
            :subscribe({
                next = function(x) table.insert(results, x) end,
                completed = function() completed = true end
            })

        source:onNext(1)
        source:onNext(2)

        timeProvider:advance(1)
        expect(#results):toBe(0)

        timeProvider:advance(1)
        expect(#results):toBe(0)

        timeProvider:advance(1)
        expect(results):toEqual({ 1, 2 })


        source:onNext(3)
        source:onCompleted(Result.success())

        expect(#results):toBe(2)
        expect(completed):toBe(false)

        timeProvider:advance(3)
        expect(results):toEqual({ 1, 2, 3 })
        expect(completed):toBe(true)
    end)

    test('dueTime为0时立即发出', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :delay(0, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)

        expect(results):toEqual({ 1, 2 })
    end)

    test('延迟错误传播', function()
        local error
        local completed = false
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :delay(100, timeProvider)
            :subscribe({
                next        = function(_) end,
                errorResume = function(err) error = err.message end,
                completed   = function(_) completed = true end
            })

        source:onErrorResume({
            type = "Exception",
            message = "test error",
        })

        expect(error):toBe(nil)

        timeProvider:advance(100)

        expect(error):toBe("test error")
        expect(completed):toBe(false) -- 错误发生后不应该完成
    end)

    test('在延迟期间取消订阅', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        local subscription = source
            :delay(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)

        timeProvider:advance(50)
        subscription:dispose()

        timeProvider:advance(100)

        expect(#results):toBe(0)
    end)
end)