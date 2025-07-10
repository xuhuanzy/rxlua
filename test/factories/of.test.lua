local TestFramework = require("luakit.test")
local RxLua = require("rxlua")
local of = require("rxlua").of
local expect = TestFramework.expect
local test = TestFramework.test

test("of - 基本功能测试 - 数字序列", function()
    local values = {}
    of(1, 2, 3, 4, 5):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 1, 2, 3, 4, 5 })
end)

test("of - 字符串序列测试", function()
    local strings = {}
    RxLua.of("hello", "world", "rxlua"):subscribe(function(value)
        table.insert(strings, value)
    end)

    expect(strings):toEqual({ "hello", "world", "rxlua" })
end)

test("of - 空序列测试", function()
    local values = {}
    local completed = false
    RxLua.of():subscribe({
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

test("of - 单个值测试", function()
    local values = {}
    RxLua.of(42):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 42 })
end)

test("of - 完成回调测试", function()
    local completed = false
    local completionResult = nil

    of("test"):subscribe({
        next = function(value) end,
        completed = function(result)
            completed = true
            completionResult = result
        end
    })
    ---@cast completionResult -?

    expect(completed):toBe(true)
    expect(completionResult:isSuccess()):toBe(true)
end)

TestFramework.testPrintStats()
