local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local Class = require("luakit.class")

local throw = Rxlua.throw

describe('throw', function()
    test("立即抛出异常", function()
        local err
        local error = "error"
        throw(error):subscribe({
            completed = function(result)
                err = result.exception
            end
        })
        -- 因为立即抛出, 所以不会触发 completed 回调
        expect(err):toBe(error)
    end)

    test("延迟抛出异常", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local err
        local error = "error"

        throw(error, 500, timeProvider):subscribe({
            completed = function(result)
                err = result.exception
            end
        })

        expect(err):toBe(nil)

        timeProvider:advance(499)
        expect(err):toBe(nil)

        timeProvider:advance(1)
        expect(err):toBe(error)
    end)

    test("延迟任务取消订阅", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local err

        local subscription = throw("error", 500, timeProvider):subscribe({
            completed = function(result)
                err = result.exception
            end
        })

        timeProvider:advance(200)
        subscription:dispose()

        timeProvider:advance(300)
        expect(err):toBe(nil)
    end)
end)
