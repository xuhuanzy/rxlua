local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe
local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('throttleLast', function()
    test('基本功能', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onNext(3)

        expect(results):toEqual({})

        timeProvider:advance(100)

        expect(results):toEqual({ 3 })

        source:onNext(4)
        source:onNext(5)

        timeProvider:advance(100)

        expect(results):toEqual({ 3, 5 })
    end)

    test('完成时发出最后一个值', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onCompleted(Result.success())

        expect(results):toEqual({ 2 })
    end)

    test('订阅取消', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        local subscription = source
            :throttleLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        subscription:dispose()

        timeProvider:advance(100)

        expect(results):toEqual({})
    end)
end)
