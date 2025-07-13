local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local Result = require("rxlua.internal.result")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local of = Rxlua.of

describe('index', function()
    test("基本功能测试", function()
        local values = {}
        local source = of("a", "b", "c")
        source:index():subscribe(function(item)
            table.insert(values, item)
        end)

        expect(values):toEqual({ { index = 1, value = "a" }, { index = 2, value = "b" }, { index = 3, value = "c" } })
    end)

    test("只使用索引", function()
        local indices = {}
        local source = of("a", "b", "c")
        source:index():subscribe(function(item)
            table.insert(indices, item.index)
        end)

        expect(indices):toEqual({ 1, 2, 3 })
    end)

    test("链式调用", function()
        local values = {}
        local source = of(10, 20, 30)
        source:index()
            :where(function(item) return item.index > 1 end)
            :select(function(item) return item.value * item.index end)
            :subscribe(function(value)
                table.insert(values, value)
            end)

        -- 20*2=40, 30*3=90
        expect(values):toEqual({ 40, 90 })
    end)

    test("空序列", function()
        local values = {}
        local source = Rxlua.empty()
        source:index():subscribe(function(item)
            table.insert(values, item)
        end)

        expect(values):toEqual({})
    end)

    test("错误处理", function()
        local errorValue = nil
        local source = Rxlua.subject()
        source:index():subscribe({
            next = function(value) end,
            errorResume = function(err)
                errorValue = err
            end
        })

        source:onNext("a")
        source:onErrorResume("error")
        expect(errorValue):toEqual("error")
    end)

    test("完成处理", function()
        local completed = false
        local source = Rxlua.subject()
        source:index():subscribe({
            next = function(value) end,
            completed = function()
                completed = true
            end
        })

        source:onNext("a")
        source:onCompleted(Result.success())
        expect(completed):toEqual(true)
    end)
end)