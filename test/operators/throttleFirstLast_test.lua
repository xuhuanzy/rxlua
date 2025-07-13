local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local describe = TestFramework.describe
local Rxlua = require('rxlua')
local FakeTimeProvider = require("rxlua.internal.fakeTimeProvider")
local new = require("luakit.class").new
local Result = require("rxlua.internal.result")

describe('throttleFirstLast', function()
    test('基本功能', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirstLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1) -- 立即发出
        source:onNext(2)
        source:onNext(3) -- 最后一个值

        expect(results):toEqual({ 1 })

        timeProvider:advance(100) -- 时间窗口结束, 发出最后一个值

        expect(results):toEqual({ 1, 3 })

        source:onNext(4) -- 新的窗口开始, 立即发出
        expect(results):toEqual({ 1, 3, 4 })

        timeProvider:advance(100)
        expect(results):toEqual({ 1, 3, 4 })
    end)

    test('窗口内只有一个值', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirstLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        expect(results):toEqual({ 1 })

        timeProvider:advance(100)
        expect(results):toEqual({ 1 })
    end)

    test('完成时发出最后一个值', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        source
            :throttleFirstLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        source:onCompleted(Result.success())

        expect(results):toEqual({ 1, 2 })
    end)

    test('订阅取消', function()
        local results = {}
        local source = Rxlua.subject()
        local timeProvider = new(FakeTimeProvider)()

        local subscription = source
            :throttleFirstLast(100, timeProvider)
            :subscribe(function(x) table.insert(results, x) end)

        source:onNext(1)
        source:onNext(2)
        subscription:dispose()

        timeProvider:advance(100)

        expect(results):toEqual({ 1 })
    end)
end)
