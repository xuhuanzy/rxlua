local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local of = Rxlua.of
local zipLatest = Rxlua.zipLatest
local subject = Rxlua.subject

describe('zipLatest', function()
    describe('factory', function()
        test("基本功能测试", function()
            local s1 = subject()
            local s2 = subject()
            local values = {}

            zipLatest(s1, s2):subscribe(function(value)
                table.insert(values, value)
            end)

            s1:onNext(1)
            expect(#values):toBe(0)

            s2:onNext('a')
            expect(values):toEqual({ { 1, 'a' } })

            s1:onNext(2) -- s2 has no new value, so no publish
            expect(values):toEqual({ { 1, 'a' } })

            s1:onNext(3) -- s1's value is updated to 3
            expect(values):toEqual({ { 1, 'a' } })

            s2:onNext('b') -- now s2 has a new value, publish
            expect(values):toEqual({ { 1, 'a' }, { 3, 'b' } })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            zipLatest(s1, s2):subscribe({ completed = function() completed = true end })

            s1:onNext(1)
            s2:onNext('a')

            s1:onNext(2)
            s1:onCompleted() -- 虽然发出了完成信号, 但此时`s1`仍有值未被消费, 所以`zipLatest`不会发出完成信号

            expect(completed):toBe(false)

            s2:onNext('b')
            expect(completed):toBe(true)
        end)

        test("空源直接完成", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            zipLatest(s1, s2):subscribe({ completed = function() completed = true end })

            s1:onNext(1)
            s2:onCompleted() -- s2 never had a value
            expect(completed):toBe(true)
        end)

        test("空输入测试", function()
            local completed = false
            zipLatest():subscribe({ completed = function() completed = true end })
            expect(completed):toBe(true)
        end)

        test("错误处理", function()
            local s1 = subject()
            local s2 = subject()
            local err = nil

            zipLatest(s1, s2):subscribe({ errorResume = function(e) err = e end })

            s1:onErrorResume("error")
            expect(err):toBe("error")
        end)
    end)

    describe('operator', function()
        test("基本功能测试", function()
            local s1 = subject()
            local values = {}

            of(1, 2):zipLatest(s1):subscribe(function(value)
                table.insert(values, value)
            end)

            s1:onNext('a')
            expect(values):toEqual({ { 2, 'a' } })

            s1:onNext('b')
            expect(values):toEqual({ { 2, 'a' } })

            of(3):zipLatest(s1):subscribe(function(v) table.insert(values, v) end)
            expect(values):toEqual({ { 2, 'a' } })
        end)
    end)
end)
