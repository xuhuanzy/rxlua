local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local of = Rxlua.of
local concat = Rxlua.concat
local subject = Rxlua.subject

describe('concat', function()
    describe('factory', function()
        test("基本功能测试", function()
            local values = {}
            concat(of(1, 2), of(3, 4)):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ 1, 2, 3, 4 })
        end)

        test("多个Observable连接", function()
            local values = {}
            concat(of(1), of(2, 3), of(4, 5, 6)):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ 1, 2, 3, 4, 5, 6 })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false
            local values = {}

            concat(s1, s2):subscribe({
                next = function(v) table.insert(values, v) end,
                completed = function()
                    completed = true
                end
            })

            s1:onNext(1)
            expect(completed):toBe(false)
            expect(values):toEqual({ 1 })

            s2:onNext(2) -- s1 未完成, s2 的事件不会被接收
            expect(completed):toBe(false)
            expect(values):toEqual({ 1 })

            s1:onCompleted()
            expect(completed):toBe(false)

            s2:onNext(3)
            expect(values):toEqual({ 1, 3 })

            s2:onCompleted()
            expect(completed):toBe(true)
        end)

        test("空输入测试", function()
            local completed = false
            concat():subscribe({
                completed = function()
                    completed = true
                end
            })
            expect(completed):toBe(true)
        end)

        test("包含空Observable", function()
            local values = {}
            concat(of(), of(1, 2)):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ 1, 2 })
        end)

        test("错误处理", function()
            local s1 = subject()
            local s2 = subject()
            local err = nil

            concat(s1, s2):subscribe({
                errorResume = function(e)
                    err = e.message
                end
            })

            s1:onErrorResume({
                type = "Exception",
                message = "error",
            })
            expect(err):toBe("error")
        end)
    end)

    describe('operator', function()
        test("基本功能测试", function()
            local values = {}
            of(1, 2):concat(of(3, 4)):subscribe(function(value)
                table.insert(values, value)
            end)
            expect(values):toEqual({ 1, 2, 3, 4 })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            s1:concat(s2):subscribe({
                completed = function()
                    completed = true
                end
            })

            s1:onNext(1)
            expect(completed):toBe(false)

            s2:onNext(2)
            expect(completed):toBe(false)

            s1:onCompleted()
            expect(completed):toBe(false)

            s2:onCompleted()
            expect(completed):toBe(true)
        end)
    end)
end)
