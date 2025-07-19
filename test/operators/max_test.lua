local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local Exception = require("luakit.exception")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('max', function()
    test("基本功能", function()
        local values = {}
        Rxlua.of(5, 2, 8, 1, 9, 4):max():subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ 9 })
    end)

    test("空序列", function()
        local values = {}
        local completed = false
        Rxlua.empty():max():subscribe({
            next = function(value) table.insert(values, value) end,
            completed = function() completed = true end
        })
        expect(values):toEqual({})
        expect(completed):toBe(true)
    end)

    test("自定义比较器", function()
        local values = {}
        local source = { { v = 3 }, { v = 1 }, { v = 5 } }
        Rxlua.of(source[1], source[2], source[3]):max(function(a, b) return a.v > b.v end):subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ { v = 5 } })
    end)

    test("错误传播", function()
        local err = nil
        local subject = Rxlua.subject()
        subject:max():subscribe({
            errorResume = function(e) err = e.message end
        })
        subject:onErrorResume(Exception("error"))
        expect(err):toBe("error")
    end)
end)
