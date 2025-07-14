local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

local Rxlua = require("rxlua")
local of = Rxlua.of
local defer = Rxlua.defer

describe('defer', function()
    test("工厂函数被延迟调用", function()
        local factoryCalled = false
        local observable = defer(function()
            factoryCalled = true
            return of(1, 2, 3)
        end)

        expect(factoryCalled):toBe(false)

        local values = {}
        observable:subscribe(function(v) table.insert(values, v) end)

        expect(factoryCalled):toBe(true)
        expect(values):toEqual({ 1, 2, 3 })
    end)

    test("每个订阅者获得独立的实例", function()
        local i = 0
        local observable = defer(function()
            i = i + 1
            return of(i)
        end)

        local values1 = {}
        observable:subscribe(function(v) table.insert(values1, v) end)
        expect(values1):toEqual({ 1 })

        local values2 = {}
        observable:subscribe(function(v) table.insert(values2, v) end)
        expect(values2):toEqual({ 2 })
    end)

end)
