local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local Rxlua = require('rxlua')
local of = Rxlua.of
local range = Rxlua.range
local empty = Rxlua.empty

test('where - 过滤', function()
    local results = {}
    of(1, 2, 3, 4, 5):where(function(x)
        return x > 3
    end):subscribe(function(x)
        table.insert(results, x)
    end)
    expect(results):toEqual({ 4, 5 })
end)

test('where - 过滤索引', function()
    local results = {}
    of(10, 20, 30, 40, 50):where(function(x, i)
        return i > 3
    end):subscribe(function(x)
        table.insert(results, x)
    end)
    expect(results):toEqual({ 40, 50 })
end)

test('where - 链式调用', function()
    local results = {}
    range(1, 10):where(function(x)
        return x > 3
    end):where(function(x)
        return x % 2 == 0
    end):subscribe(function(x)
        table.insert(results, x)
    end)
    expect(results):toEqual({ 4, 6, 8, 10 })
end)

test('where - 没有匹配的值', function()
    local results = {}
    of(1, 2, 3):where(function(x)
        return x > 5
    end):subscribe(function(x)
        table.insert(results, x)
    end)
    expect(results):toEqual({})
end)

test('where - 完成', function()
    local completed = false
    local obs = of(1, 2, 3):where(function(x)
        return x > 0
    end)
    obs:subscribe(
        function()
            completed = true
        end
    )
    expect(completed):toBe(true)
end)


test('where - 空序列', function()
    local completed = false
    empty()
        :where(function(x) return true end):subscribe(
        function()
            completed = true
        end
    )
    expect(completed):toBe(false)
end)
