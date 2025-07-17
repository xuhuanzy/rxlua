local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local timerModule = require("rxlua.factories.timer")
local timer = timerModule.timer
local interval = timerModule.interval

describe('timer and interval', function()
    local timeProvider ---@type Rxlua.FakeTimeProvider

    local function beforeEach()
        timeProvider = new(FakeTimeProvider)()
    end

    describe("timer", function()
        test("一次性定时器", function()
            beforeEach()
            local values = {}
            local completed = false

            timer(100, nil, timeProvider)
                :subscribe({
                    next = function(v)
                        table.insert(values, v)
                    end,
                    completed = function() completed = true end
                })

            expect(#values):toBe(0)
            expect(completed):toBe(false)

            timeProvider:advance(99)
            expect(#values):toBe(0)
            expect(completed):toBe(false)

            timeProvider:advance(1)
            expect(values):toEqual({ 0 })
            expect(completed):toBe(true)
        end)

        test("周期性定时器", function()
            beforeEach()
            local values = {}
            timer(100, 50, timeProvider):subscribe(function(v) table.insert(values, v) end)

            timeProvider:advance(100)
            expect(values):toEqual({ 0 })

            timeProvider:advance(50)
            expect(values):toEqual({ 0, 1 })

            timeProvider:advance(50)
            expect(values):toEqual({ 0, 1, 2 })
        end)

        test("dispose 可以取消定时器", function()
            beforeEach()
            local values = {}
            local subscription = timer(100, 50, timeProvider):subscribe(function(v) table.insert(values, v) end)

            timeProvider:advance(100)
            expect(values):toEqual({ 0 })

            subscription:dispose()

            timeProvider:advance(100)
            expect(values):toEqual({ 0 }) -- 值不再增加
        end)
    end)

    describe("interval", function()
        test("基本间隔功能", function()
            beforeEach()
            local values = {}
            interval(100, timeProvider):subscribe(function(v) table.insert(values, v) end)

            timeProvider:advance(100)
            expect(values):toEqual({ 0 })

            timeProvider:advance(100)
            expect(values):toEqual({ 0, 1 })

            timeProvider:advance(50)
            expect(values):toEqual({ 0, 1 }) -- 时间未到，值不变

            timeProvider:advance(50)
            expect(values):toEqual({ 0, 1, 2 })
        end)
    end)
end)
