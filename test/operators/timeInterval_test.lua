local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe
local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('timeInterval', function()
    test('基本功能', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeInterval(timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        timeProvider:advance(100)
        source:onNext(1)

        timeProvider:advance(50)
        source:onNext(2)

        timeProvider:advance(200)
        source:onNext(3)

        expect(results[1].interval):toBe(100)
        expect(results[1].value):toBe(1)

        expect(results[2].interval):toBe(50)
        expect(results[2].value):toBe(2)

        expect(results[3].interval):toBe(200)
        expect(results[3].value):toBe(3)
    end)

    test('完成和错误传播', function()
        local completed = false
        local error
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :timeInterval(timeProvider)
            :subscribe({
                next = function(_) end,
                errorResume = function(err) error = err end,
                completed = function(_) completed = true end
            })

        source:onCompleted(Result.success())
        expect(completed):toBe(true)

        source = Rxlua.subject()
        source:timeInterval(timeProvider):subscribe({
            next = function(_) end,
            errorResume = function(err) error = err end,
            completed = function(_) end
        })
        source:onCompleted(Result.failure("test error"))
        expect(error):toBe(nil) -- onCompleted with failure should not trigger errorResume
    end)
end)
