local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('count', function()
    test("基本计数功能", function()
        local values = {}
        Rxlua.of(1, 2, 3, 4, 5):count():subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ 5 })
    end)

    test("空序列", function()
        local values = {}
        Rxlua.empty():count():subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ 0 })
    end)

    test("链式调用", function()
        local values = {}
        Rxlua.range(1, 10)
            :where(function(x) return x % 2 == 0 end)
            :count()
            :subscribe(function(value)
                table.insert(values, value)
            end)
        expect(values):toEqual({ 5 })
    end)

    test("错误传播", function()
        local err = nil
        local subject = Rxlua.subject()
        subject:count():subscribe({
            errorResume = function(e) err = e.message end
        })
        subject:onErrorResume({
            type = "Exception",
            message = "error",
        })
        expect(err):toBe("error")
    end)
end)
