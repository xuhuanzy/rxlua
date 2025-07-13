---@namespace Rxlua

local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local toLiveList = require("test.utils").toLiveList

local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe("Scan", function()
    test("With Seed", function()
        local source = Rxlua.of(1, 2, 3, 4)
        local scanned = source:scan(function(acc, v) return acc + v end, 10)
        local list = toLiveList(scanned)

        expect(list.values):toEqual({ 11, 13, 16, 20 })
        expect(list.completed):toBe(true)
    end)

    test("Without Seed", function()
        local source = Rxlua.of(1, 2, 3, 4)
        local scanned = source:scan(function(acc, v) return acc + v end)
        local list = toLiveList(scanned)

        expect(list.values):toEqual({ 1, 3, 6, 10 })
        expect(list.completed):toBe(true)
    end)

    test("Empty Source", function()
        local source = Rxlua.empty()
        local scanned = source:scan(function(acc, v) return acc + v end, 10)
        local list = toLiveList(scanned)

        expect(list.values):toEqual({})
        expect(list.completed):toBe(true)
    end)

    test("Error Propagation", function()
        local source = Rxlua.subject()
        local scanned = source:scan(function(acc, v) return acc + v end)
        local list = toLiveList(scanned)

        source:onErrorResume("Test Error")

        expect(list.error):toBe("Test Error")
    end)
end)
