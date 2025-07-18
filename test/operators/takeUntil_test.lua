local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local subject = Rxlua.subject
require("rxlua.operators.takeUntil")

describe('takeUntil', function()
    test("当 other 发出 onNext 时停止", function()
        local values = {}
        local completed = false
        local s1 = subject()
        local s2 = subject()

        s1:takeUntil(s2):subscribe({
            next = function(v) table.insert(values, v) end,
            completed = function() completed = true end
        })

        s1:onNext(1)
        s1:onNext(2)
        expect(values):toEqual({ 1, 2 })
        expect(completed):toBe(false)

        s2:onNext("stop") -- other 发出值，主序列应完成
        expect(completed):toBe(true)

        s1:onNext(3) -- 此值应被忽略
        expect(values):toEqual({ 1, 2 })
    end)

    test("当 other 发出 onError 时停止", function()
        local values = {}
        local err = nil
        local s1 = subject()
        local s2 = subject()

        s1:takeUntil(s2):subscribe({
            next = function(v) table.insert(values, v) end,
            errorResume = function(e) err = e.message end
        })

        s1:onNext(1)
        s2:onErrorResume({
            type = "Exception",
            message = "error",
        })

        expect(values):toEqual({ 1 })
        expect(err):toBe("error")
    end)

    test("当 source 完成时正常完成", function()
        local values = {}
        local completed = false
        local s1 = subject()
        local s2 = subject()

        s1:takeUntil(s2):subscribe({
            next = function(v) table.insert(values, v) end,
            completed = function() completed = true end
        })

        s1:onNext(1)
        s1:onCompleted()

        expect(values):toEqual({ 1 })
        expect(completed):toBe(true)
    end)
end)
