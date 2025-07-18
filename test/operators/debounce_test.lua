local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('debounce', function()
    test('基本的去抖动功能', function()
        local results = {}

        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :debounce(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onNext(3)

        timeProvider:advance(100)

        expect(results):toEqual({ 3 })

        source:onNext(4)
        timeProvider:advance(100)

        expect(results):toEqual({ 3, 4 })
    end)


    test('在完成时发出最后一个值', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :debounce(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onCompleted(Result.success())


        expect(results[1]):toBe(2)
    end)

    test('错误传播', function()
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :debounce(100, timeProvider)
            :subscribe({
                next        = function(_) end,
                errorResume = function(err) error = err end,
                completed   = function(_) end
            })

        -- 发生完成信号时, 即使通知结果是错误的也不会执行`errorResume`
        source:onCompleted(Result.failure({
            type = "Exception",
            message = "test error",
        }))

        expect(error):toBe(nil)
    end)
end)
