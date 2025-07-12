local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect

local Rxlua = require('rxlua')

test('distinctUntilChanged - 基本去重', function()
    local actual = {}

    Rxlua.of(1, 1, 2, 2, 1, 3, 3, 2, 2)
        :distinctUntilChanged()
        :subscribe(
            function(x) table.insert(actual, x) end
        )

    expect(actual):toEqual({ 1, 2, 1, 3, 2 })
end)

test('distinctUntilChanged - 使用比较器去重', function()
    local source = {
        { id = 1, name = "A" },
        { id = 1, name = "B" },
        { id = 2, name = "C" },
    }
    local expected = { { id = 1, name = "A" }, { id = 2, name = "C" } }
    local actual = {}

    Rxlua.of(source[1], source[2], source[3])
        :distinctUntilChanged(function(x, y) return x.id == y.id end)
        :subscribe(
            function(x) table.insert(actual, x) end
        )

    expect(actual):toEqual(expected)
end)

test('distinctUntilChanged - 使用键选择器去重', function()
    local source = {
        { id = 1, name = "A" },
        { id = 2, name = "A" },
        { id = 3, name = "B" },
    }
    local expected = { { id = 1, name = "A" }, { id = 3, name = "B" } }
    local actual = {}

    Rxlua.of(source[1], source[2], source[3])
        :distinctUntilChangedBy(function(x) return x.name end)
        :subscribe(
            function(x) table.insert(actual, x) end
        )

    expect(actual):toEqual(expected)
end)

test('distinctUntilChanged - 使用键选择器和比较器去重', function()
    local source = {
        { id = 1, name = "apple" },
        { id = 2, name = "Apple" },
        { id = 3, name = "Banana" },
    }
    local expected = { { id = 1, name = "apple" }, { id = 3, name = "Banana" } }
    local actual = {}

    Rxlua.of(source[1], source[2], source[3])
        :distinctUntilChangedBy(function(x) return x.name end,
            function(x, y) return string.lower(x) == string.lower(y) end)
        :subscribe(
            function(x) table.insert(actual, x) end
        )

    expect(actual):toEqual(expected)
end)
