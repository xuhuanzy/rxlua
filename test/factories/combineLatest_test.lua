local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local Exception = require("luakit.exception")
local of = Rxlua.of
local combineLatest = Rxlua.combineLatest
local subject = Rxlua.subject

describe('combineLatest', function()
    describe('factory', function()
        test("基本功能测试", function()
            local s1 = subject()
            local s2 = subject()
            local values = {}

            combineLatest(s1, s2):subscribe(function(value)
                table.insert(values, value)
            end)

            s1:onNext(1)
            expect(#values):toBe(0)

            s2:onNext('a')
            expect(values):toEqual({ { 1, 'a' } })

            s1:onNext(2)
            expect(values):toEqual({ { 1, 'a' }, { 2, 'a' } })

            s2:onNext('b')
            expect(values):toEqual({ { 1, 'a' }, { 2, 'a' }, { 2, 'b' } })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            combineLatest(s1, s2):subscribe({ completed = function() completed = true end })

            s1:onNext(1)
            s2:onNext('a')

            s1:onCompleted()
            expect(completed):toBe(false)

            s2:onNext('b')
            s2:onCompleted()
            expect(completed):toBe(true)
        end)

        test("空源直接完成", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            combineLatest(s1, s2):subscribe({ completed = function() completed = true end })

            s1:onNext(1)
            s2:onCompleted() -- s2 never had a value
            expect(completed):toBe(true)
        end)

        test("空输入测试", function()
            local completed = false
            combineLatest():subscribe({ completed = function() completed = true end })
            expect(completed):toBe(true)
        end)

        test("错误处理", function()
            local s1 = subject()
            local s2 = subject()
            local err = nil

            combineLatest(s1, s2):subscribe({ errorResume = function(e) err = e.message end })

            s1:onErrorResume(Exception("error"))
            expect(err):toBe("error")
        end)
    end)

    describe('operator', function()
        test("基本功能测试", function()
            local s1 = subject()
            local values = {}

            of(1, 2):combineLatest(s1):subscribe(function(value)
                table.insert(values, value)
            end)

            s1:onNext('a')
            expect(values):toEqual({ { 2, 'a' } })

            s1:onNext('b')
            expect(values):toEqual({ { 2, 'a' }, { 2, 'b' } })
        end)
    end)
end)
