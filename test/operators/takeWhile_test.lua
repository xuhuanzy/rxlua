local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe
local Rxlua = require('rxlua')
local Exception = require("luakit.exception")
local of = Rxlua.of
local subject = Rxlua.subject

describe('takeWhile', function()
    test('当断言为 false 时停止', function()
        local results = {}
        of(1, 2, 3, 4, 5):takeWhile(function(x) return x < 4 end):subscribe(function(x)
            table.insert(results, x)
        end)
        expect(results):toEqual({ 1, 2, 3 })
    end)

    test('使用索引', function()
        local results = {}
        of(10, 20, 30, 40, 50):takeWhile(function(x, i) return i <= 3 end):subscribe(function(x)
            table.insert(results, x)
        end)
        expect(results):toEqual({ 10, 20, 30 })
    end)

    test('所有值都满足条件', function()
        local results = {}
        local completed = false
        of(1, 2, 3):takeWhile(function(x) return x < 10 end):subscribe({
            next = function(v) table.insert(results, v) end,
            completed = function() completed = true end
        })
        expect(results):toEqual({ 1, 2, 3 })
        expect(completed):toBe(true)
    end)

    test('第一个值就不满足条件', function()
        local results = {}
        local completed = false
        of(10, 1, 2):takeWhile(function(x) return x < 10 end):subscribe({
            next = function(v) table.insert(results, v) end,
            completed = function() completed = true end
        })
        expect(results):toEqual({})
        expect(completed):toBe(true)
    end)

    test('空序列', function()
        local results = {}
        local completed = false
        Rxlua.empty():takeWhile(function(x) return true end):subscribe({
            next = function(v) table.insert(results, v) end,
            completed = function() completed = true end
        })
        expect(results):toEqual({})
        expect(completed):toBe(true)
    end)

    test('错误传递', function()
        local err = nil
        local s = subject()
        s:takeWhile(function(x) return true end):subscribe({
            errorResume = function(e) err = e.message end
        })
        s:onErrorResume(Exception("Test Error"))
        expect(err):toBe('Test Error')
    end)

    test('断言函数中出错', function()
        local err = nil
        of(1, 2, 3):takeWhile(function(x)
            if x == 3 then error('Predicate Error') end
            return true
        end):subscribe({ errorResume = function(e) err = e end })
        expect('Predicate Error'):notToBe(nil)
    end)
end)
