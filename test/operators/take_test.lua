local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local of = Rxlua.of
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('take', function()
    test("基本功能测试", function()
        local values = {}
        local source = of(1, 2, 3, 4, 5)
        source:take(2):subscribe(function(value)
            table.insert(values, value)
        end)

        expect(values):toEqual({ 1, 2 })
    end)
end)