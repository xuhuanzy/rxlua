local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local of = Rxlua.of
local expect = TestFramework.expect
local test = TestFramework.test

test("skip - 基本功能测试 - 跳过前2个元素", function()
    local values = {}
    local source = of(1, 2, 3, 4, 5)
    source:skip(2):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 3, 4, 5 })
end)

test("skip - 跳过全部元素", function()
    local values = {}
    local source = of(1, 2, 3)
    source:skip(5):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(#values):toBe(0)
end)

test("skip - 跳过0个元素", function()
    local values = {}
    local source = of("a", "b", "c")
    source:skip(0):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ "a", "b", "c" })
end)

test("skip - 负数输入应该抛出错误", function()
    expect(function()
        of(1, 2, 3):skip(-1)
    end):toThrow()
end)

test("skip - 空序列处理", function()
    local values = {}
    local completed = false
    local source = of() -- 空序列
    source:skip(2):subscribe({
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

test("skip - 跳过数量大于序列长度", function()
    local values = {}
    local source = of(1, 2)
    source:skip(10):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({})
end)

test("skip - 跳过1个元素", function()
    local values = {}
    local source = of("first", "second", "third")
    source:skip(1):subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ "second", "third" })
end)
