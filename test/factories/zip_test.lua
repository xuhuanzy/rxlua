local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local Exception = require("luakit.exception")
local of = Rxlua.of
local zip = Rxlua.zip
local subject = Rxlua.subject

describe('zip', function()
    describe('factory', function()
        test("基本功能测试", function()
            local values = {}
            zip(of(1, 2, 3), of('a', 'b', 'c')):subscribe(function(value)
                table.insert(values, value)
            end)
            
            expect(values):toEqual({ { 1, 'a' }, { 2, 'b' }, { 3, 'c' } })
        end)

        test("不同长度的Observable", function()
            local values = {}
            zip(of(1, 2), of('a', 'b', 'c')):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ { 1, 'a' }, { 2, 'b' } })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false
            local values = {}

            zip(s1, s2):subscribe({
                next = function(v) table.insert(values, v) end,
                completed = function()
                    completed = true
                end
            })

            s1:onNext(1)
            expect(completed):toBe(false)
            expect(#values):toBe(0)

            s2:onNext('a')
            expect(completed):toBe(false)
            expect(values):toEqual({ { 1, 'a' } })

            s1:onNext(2)
            expect(completed):toBe(false)
            expect(values):toEqual({ { 1, 'a' } })

            s1:onCompleted()
            expect(completed):toBe(false)

            s2:onNext('b')
            expect(values):toEqual({ { 1, 'a' }, { 2, 'b' } })
            expect(completed):toBe(true) -- s1 completed and queue is empty
        end)

        test("空输入测试", function()
            local completed = false
            zip():subscribe({
                completed = function()
                    completed = true
                end
            })
            expect(completed):toBe(true)
        end)

        test("包含空Observable", function()
            local completed = false
            zip(of(), of(1, 2)):subscribe({
                completed = function()
                    completed = true
                end
            })
            expect(completed):toBe(true)
        end)

        test("错误处理", function()
            local s1 = subject()
            local s2 = subject()
            local err = nil

            zip(s1, s2):subscribe({
                errorResume = function(e)
                    err = e.message
                end
            })

            s1:onErrorResume(Exception("error"))
            expect(err):toBe("error")
        end)
    end)

    describe('operator', function()
        test("基本功能测试", function()
            local values = {}
            of(1, 2, 3):zip(of('a', 'b', 'c')):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ { 1, 'a' }, { 2, 'b' }, { 3, 'c' } })
        end)
    end)
end)
