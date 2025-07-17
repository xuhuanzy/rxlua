local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local of = Rxlua.of

describe('catch', function()
    test("无错误的基本流程", function()
        local values = {}
        local source = of(1, 2, 3)
        local fallback = of(4, 5, 6)

        source:catch(fallback):subscribe(function(value)
            table.insert(values, value)
        end)

        expect(values):toEqual({ 1, 2, 3 })
    end)
end)
