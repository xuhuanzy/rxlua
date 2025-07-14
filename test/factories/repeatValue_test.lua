local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
-- 在 init.lua 更新前, 我们需要直接 require repeatValue
local repeatValue = require("rxlua.factories.repeatValue")

describe('repeatValue', function()
    test("基本功能测试", function()
        local values = {}
        repeatValue('a', 3):subscribe(function(v) table.insert(values, v) end)
        expect(values):toEqual({'a', 'a', 'a'})
    end)

    test("count 为 0 时返回空序列", function()
        local values = {}
        local completed = false
        repeatValue('a', 0):subscribe({
            next = function(v) table.insert(values, v) end,
            completed = function() completed = true end
        })
        expect(#values):toBe(0)
        expect(completed):toBe(true)
    end)

    test("count 为负数时抛出错误", function()
        expect(function()
            repeatValue('a', -1)
        end):toThrow("count 不能为负数")
    end)

    test("完成回调被正确调用", function()
        local completed = false
        repeatValue('a', 2):subscribe({
            completed = function() completed = true end
        })
        expect(completed):toBe(true)
    end)
end)