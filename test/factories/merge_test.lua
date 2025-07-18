local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local of = Rxlua.of
local merge = Rxlua.merge
local subject = Rxlua.subject

describe('merge', function()
    describe('factory', function()
        test("基本功能测试", function()
            local values = {}
            merge(of(1, 2), of(3, 4)):subscribe(function(value)
                table.insert(values, value)
            end)

            table.sort(values)
            expect(values):toEqual({ 1, 2, 3, 4 })
        end)

        test("多个Observable合并", function()
            local values = {}
            merge(of(1), of(2, 3), of(4, 5, 6)):subscribe(function(value)
                table.insert(values, value)
            end)

            table.sort(values)
            expect(values):toEqual({ 1, 2, 3, 4, 5, 6 })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            merge(s1, s2):subscribe({
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

        test("空输入测试", function()
            local completed = false
            merge():subscribe({
                completed = function()
                    completed = true
                end
            })
            expect(completed):toBe(true)
        end)

        test("包含空Observable", function()
            local values = {}
            merge(of(), of(1, 2)):subscribe(function(value)
                table.insert(values, value)
            end)

            table.sort(values)
            expect(values):toEqual({ 1, 2 })
        end)

        test("错误处理", function()
            local s1 = subject()
            local s2 = subject()
            local err = nil

            merge(s1, s2):subscribe({
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
            of(1, 2):merge(of(3, 4)):subscribe(function(value)
                table.insert(values, value)
            end)

            table.sort(values)
            expect(values):toEqual({ 1, 2, 3, 4 })
        end)

        test("完成时机测试", function()
            local s1 = subject()
            local s2 = subject()
            local completed = false

            s1:merge(s2):subscribe({
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
