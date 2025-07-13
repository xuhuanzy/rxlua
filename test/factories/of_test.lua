local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local of = Rxlua.of

describe('of', function()
    test("基本功能测试 - 数字序列", function()
        local values = {}
        of(1, 2, 3, 4, 5):subscribe(function(value)
            table.insert(values, value)
        end)

        expect(values):toEqual({ 1, 2, 3, 4, 5 })
    end)

    test("字符串序列测试", function()
        local strings = {}
        of("hello", "world", "rxlua"):subscribe(function(value)
            table.insert(strings, value)
        end)

        expect(strings):toEqual({ "hello", "world", "rxlua" })
    end)

    test("空序列测试", function()
        local values = {}
        local completed = false
        of():subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function(result)
                completed = true
            end
        })

        expect(#values):toBe(0)
        expect(completed):toBe(true)
    end)

    test("单个值测试", function()
        local values = {}
        of(42):subscribe(function(value)
            table.insert(values, value)
        end)

        expect(values):toEqual({ 42 })
    end)

    test("完成回调测试", function()
        local completed = false
        local completionResult = nil

        of("test"):subscribe({
            next = function(value) end,
            completed = function(result)
                completed = true
                completionResult = result
            end
        })
        ---@cast completionResult Rxlua.Result

        expect(completed):toBe(true)
        expect(completionResult:isSuccess()):toBe(true)
    end)
end)