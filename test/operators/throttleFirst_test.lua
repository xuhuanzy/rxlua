local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new

describe('throttleFirst', function()
    test('基本的节流功能', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirst(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onNext(3)

        expect(results):toEqual({ 1 })

        timeProvider:advance(100)

        source:onNext(4)
        expect(results):toEqual({ 1, 4 })
    end)

    test('连续触发', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirst(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        timeProvider:advance(50)
        source:onNext(2)
        timeProvider:advance(50)
        source:onNext(3)

        expect(results):toEqual({ 1, 3 })

        timeProvider:advance(100)
        source:onNext(4)

        expect(results):toEqual({ 1, 3, 4 })
    end)

    local Result = require("rxlua.internal.result")

    test('错误传播', function()
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirst(100, timeProvider)
            :subscribe({
                next = function(_) end,
                errorResume = function(err) error = err end,
                completed = function(_) end
            })

        source:onCompleted(Result.failure({
            type = "Exception",
            message = "test error",
        }))

        expect(error):toBe(nil)
    end)

    test('订阅取消', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        local subscription = source
            :throttleFirst(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        subscription:dispose()
        source:onNext(2)
        timeProvider:advance(100)

        expect(results):toEqual({ 1 })
    end)
end)
