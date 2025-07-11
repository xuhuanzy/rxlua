local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test
local of = Rxlua.of

test("select - 基本功能测试", function()
    local values = {}
    local source = of(1, 2, 3, 4, 5)
    source:select(function(value, index)
        return value * 2
    end):subscribe(function(value)
        table.insert(values, value)
    end)


    expect(values):toEqual({ 2, 4, 6, 8, 10 })
end)
