local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local Class = require("luakit.class")

-- 由于 return 是 Lua 的关键字，我们将其重命名为 returnValue
local returnValue = require("rxlua.factories.return").returnValue

describe('return', function()
    test("立即返回值", function()
        local values = {}
        returnValue(42):subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ 42 })
    end)

    test("立即返回 nil", function()
        local values = {}
        local completed = false
        returnValue(nil):subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function()
                completed = true
            end
        })
        expect(values):toEqual({ nil })
        expect(completed):toBe(true)
    end)

    test("延迟返回值", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local values = {}
        local completed = false

        returnValue(100, 500, timeProvider):subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function()
                completed = true
            end
        })

        expect(#values):toBe(0)
        expect(completed):toBe(false)

        timeProvider:advance(499)
        expect(#values):toBe(0)
        expect(completed):toBe(false)

        timeProvider:advance(1)
        expect(values):toEqual({ 100 })
        expect(completed):toBe(true)
    end)

    test("延迟任务取消订阅", function()
        local timeProvider = Class.new(FakeTimeProvider)(0)
        local values = {}
        local completed = false

        local subscription = returnValue(100, 500, timeProvider):subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function()
                completed = true
            end
        })

        timeProvider:advance(200)
        subscription:dispose()

        timeProvider:advance(300)
        expect(#values):toBe(0)
        expect(completed):toBe(false)
    end)

    test("布尔值 true", function()
        local values = {}
        returnValue(true):subscribe(function(v) table.insert(values, v) end)
        expect(values):toEqual({ true })
    end)

    test("布尔值 false", function()
        local values = {}
        returnValue(false):subscribe(function(v) table.insert(values, v) end)
        expect(values):toEqual({ false })
    end)
end)
