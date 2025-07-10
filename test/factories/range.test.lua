local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local RxLua = require("rxlua")
local range = RxLua.Observable.range

test("range - 基本功能测试 - 从0开始的5个数字", function()
    local values = {}
    range(0, 5):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 0, 1, 2, 3, 4 })
end)

test("range - 从指定起始值开始", function()
    local values = {}
    range(10, 3):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 10, 11, 12 })
end)

test("range - count为0时的空序列", function()
    local values = {}
    local completed = false
    range(5, 0):subscribe({
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

test("range - 单个值", function()
    local values = {}
    range(42, 1):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 42 })
end)

test("range - 负数范围", function()
    local values = {}
    range(-3, 4):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ -3, -2, -1, 0 })
end)

test("range - count为负数时抛出错误", function()
    expect(function()
        range(0, -1):subscribe(function(value) end)
    end):toThrow("count 不能为负数")
end)

test("range - 完成回调测试", function()
    local completed = false
    local completionResult = nil

    range(1, 2):subscribe({
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
