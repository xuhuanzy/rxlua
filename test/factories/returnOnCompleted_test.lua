local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local Class = require("luakit.class")

local returnOnCompleted = Rxlua.returnOnCompleted

describe('returnOnCompleted', function()
    test("立即成功完成", function()
        local completed = false
        local result ---@type Rxlua.Result
        returnOnCompleted(Rxlua.Result.success()):subscribe({
            completed = function(r)
                completed = true
                result = r
            end
        })
        expect(completed):toBe(true)
        expect(result:isSuccess()):toBe(true)
    end)

    test("立即失败完成", function()
        local completed = false
        local result ---@type Rxlua.Result
        local error = "error"
        returnOnCompleted(Rxlua.Result.failure(error)):subscribe({
            completed = function(r)
                completed = true
                result = r
            end
        })
        expect(completed):toBe(true)
        expect(result:isFailure()):toBe(true)
        expect(result.exception):toBe(error)
    end)

    test("延迟成功完成", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local completed = false
        local result ---@type Rxlua.Result

        returnOnCompleted(Rxlua.Result.success(), 500, timeProvider):subscribe({
            completed = function(r)
                completed = true
                result = r
            end
        })

        expect(completed):toBe(false)

        timeProvider:advance(499)
        expect(completed):toBe(false)

        timeProvider:advance(1)
        expect(completed):toBe(true)
        expect(result:isSuccess()):toBe(true)
    end)

    test("延迟失败完成", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local completed = false
        local result ---@type Rxlua.Result
        local error = "error"

        returnOnCompleted(Rxlua.Result.failure(error), 500, timeProvider):subscribe({
            completed = function(r)
                completed = true
                result = r
            end
        })

        expect(completed):toBe(false)

        timeProvider:advance(499)
        expect(completed):toBe(false)

        timeProvider:advance(1)
        expect(completed):toBe(true)
        expect(result:isFailure()):toBe(true)
        expect(result.exception):toBe(error)
    end)

    test("延迟任务取消订阅", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local completed = false

        local subscription = returnOnCompleted(Rxlua.Result.success(), 500, timeProvider):subscribe({
            completed = function()
                completed = true
            end
        })

        timeProvider:advance(200)
        subscription:dispose()

        timeProvider:advance(300)
        expect(completed):toBe(false)
    end)
end)
