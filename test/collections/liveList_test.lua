local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local LiveList = require("rxlua.collections.liveList")
local new = require("luakit.class").new

local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('LiveList', function()
    test("无限制模式基本功能", function()
        local liveList = new(LiveList)(Rxlua.of(1, 2, 3))

        -- 等待数据填充
        expect(liveList:getCount()):toBe(3)
        expect(liveList:get(1)):toBe(1)
        expect(liveList:get(2)):toBe(2)
        expect(liveList:get(3)):toBe(3)
    end)

    test("固定大小模式基本功能", function()
        local liveList = new(LiveList)(Rxlua.of(1, 2, 3, 4, 5), 3)

        -- 应该只保留最后3个元素
        expect(liveList:getCount()):toBe(3)
        expect(liveList:get(1)):toBe(3)
        expect(liveList:get(2)):toBe(4)
        expect(liveList:get(3)):toBe(5)
    end)

    test("toLiveList扩展方法", function()
        do
            local liveList = Rxlua.of(1, 2, 3):toLiveList()

            expect(liveList:getCount()):toBe(3)
            expect(liveList:get(1)):toBe(1)
            expect(liveList:get(2)):toBe(2)
            expect(liveList:get(3)):toBe(3)
        end


        do
            local liveList = Rxlua.of(1, 2, 3, 4, 5):toLiveList(3)

            expect(liveList:getCount()):toBe(3)
            expect(liveList:get(1)):toBe(3)
            expect(liveList:get(2)):toBe(4)
            expect(liveList:get(3)):toBe(5)
        end
    end)

    test("toLiveListWithBuffer扩展方法", function()

    end)

    test("forEach方法", function()
        local liveList = Rxlua.of(1, 2, 3):toLiveList()
        local sum = 0

        liveList:forEach(function(value)
            sum = sum + value
        end)

        expect(sum):toBe(6)
    end)

    test("toArray方法", function()
        local liveList = Rxlua.of(1, 2, 3):toLiveList()
        local array = liveList:toArray()

        expect(#array):toBe(3)
        expect(array[1]):toBe(1)
        expect(array[2]):toBe(2)
        expect(array[3]):toBe(3)
    end)

    test("clear方法", function()
        local liveList = Rxlua.of(1, 2, 3):toLiveList()

        expect(liveList:getCount()):toBe(3)
        liveList:clear()
        expect(liveList:getCount()):toBe(0)
    end)

    test("dispose方法", function()
        local liveList = Rxlua.of(1, 2, 3):toLiveList()

        expect(liveList.sourceSubscription ~= nil):toBe(true)
        liveList:dispose()
        expect(liveList.sourceSubscription):toBe(nil)
    end)
end)
