local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe

local Rxlua = require('rxlua')

describe('distinct', function()
    test('基本去重', function()
        local expected = {1, 2, 3, 4, 5}
        local actual = {}

        Rxlua.of(1, 2, 2, 1, 3, 3, 4, 5, 5)
            :distinct()
            :subscribe(
                function(x) table.insert(actual, x) end
            )

        expect(actual):toEqual(expected)
    end)

    test('使用比较器去重', function()
        local source = {
            { id = 1, name = "A" },
            { id = 2, name = "B" },
            { id = 1, name = "C" },
        }
        local expected = { { id = 1, name = "A" }, { id = 2, name = "B" } }
        local actual = {}

        Rxlua.of(source[1], source[2], source[3])
            :distinct(function(x, y) return x.id == y.id end)
            :subscribe(
                function(x) table.insert(actual, x) end
            )

        expect(actual):toEqual(expected)
    end)

    test('使用键选择器去重', function()
        local source = {
            { id = 1, name = "A" },
            { id = 2, name = "B" },
            { id = 3, name = "A" },
        }
        local expected = { { id = 1, name = "A" }, { id = 2, name = "B" } }
        local actual = {}

        Rxlua.of(source[1], source[2], source[3])
            :distinctBy(function(x) return x.name end)
            :subscribe(
                function(x) table.insert(actual, x) end
            )

        expect(actual):toEqual(expected)
    end)

    test('使用键选择器和比较器去重', function()
        local source = {
            { id = 1, name = "apple" },
            { id = 2, name = "Banana" },
            { id = 3, name = "Apple" },
        }
        local expected = { { id = 1, name = "apple" }, { id = 2, name = "Banana" } }
        local actual = {}

        Rxlua.of(source[1], source[2], source[3])
            :distinctBy(function(x) return x.name end, function(x, y) return string.lower(x) == string.lower(y) end)
            :subscribe(
                function(x) table.insert(actual, x) end
            )

        expect(actual):toEqual(expected)
    end)

    test('对 table 在不使用比较器时发出警告', function()
        local source = {
            { id = 1, name = "A" },
            { id = 2, name = "B" },
            { id = 1, name = "A" }, -- Same content, but different table instance
        }
        local expected = source -- Expect all items to be emitted
        local actual = {}

        -- Capture warnings
        local warnings = {}
        local original_warn = _G.warn
        _G.warn = function(msg)
            table.insert(warnings, msg)
        end

        Rxlua.of(source[1], source[2], source[3])
            :distinct()
            :subscribe(
                function(x) table.insert(actual, x) end
            )

        -- Restore original warn function
        _G.warn = original_warn

        expect(actual):toEqual(expected)
        expect(#warnings):toBe(3) -- Expect a warning for each table
    end)
end)