---@using Rxlua
local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local create = Rxlua.create
local emptyDisposable = require("rxlua.shared").emptyDisposable

describe('create', function()
    test("基本功能 - 发出单个值", function()
        local values = {}
        local completed = false

        create(function(observer)
            observer:onNext(42)
            observer:onCompleted()
            return emptyDisposable
        end):subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function()
                completed = true
            end
        })

        expect(values):toEqual({ 42 })
        expect(completed):toBe(true)
    end)

    test("发出多个值", function()
        local values = {}
        local completed = false

        create(function(observer)
            observer:onNext(1)
            observer:onNext(2)
            observer:onNext(3)
            observer:onCompleted()
            return emptyDisposable
        end):subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function()
                completed = true
            end
        })

        expect(values):toEqual({ 1, 2, 3 })
        expect(completed):toBe(true)
    end)

    test("错误处理", function()
        local errorOccurred = false
        local errorMessage = ""

        create(function(observer)
            observer:onNext(1)
            observer:onErrorResume("测试错误")
            observer:onNext(2) -- 这个不应该被处理
            return emptyDisposable
        end):subscribe({
            next = function(value)
                -- 应该只收到第一个值
            end,
            errorResume = function(err)
                errorOccurred = true
                errorMessage = err
            end
        })

        expect(errorOccurred):toBe(true)
        expect(errorMessage):toBe("测试错误")
    end)

    test("资源清理", function()
        local disposed = false

        local subscription = create(function(observer)
            observer:onNext(1)
            -- 不调用 onCompleted，保持订阅活跃
            return {
                dispose = function()
                    disposed = true
                end
            }
        end):subscribe(function(value)
            -- 处理值
        end)

        subscription:dispose()
        expect(disposed):toBe(true)
    end)

    test("空 Observable", function()
        local completed = false
        local valuesReceived = 0

        create(function(observer)
            observer:onCompleted()
            return emptyDisposable
        end):subscribe({
            next = function(value)
                valuesReceived = valuesReceived + 1
            end,
            completed = function()
                completed = true
            end
        })

        expect(valuesReceived):toBe(0)
        expect(completed):toBe(true)
    end)

    test("异步行为模拟", function()
        local values = {}
        local callCount = 0

        create(function(observer)
            callCount = callCount + 1
            observer:onNext("异步值" .. callCount)
            observer:onCompleted()
            return emptyDisposable
        end):subscribe(function(value)
            table.insert(values, value)
        end)

        expect(values):toEqual({ "异步值1" })
        expect(callCount):toBe(1)
    end)
end)
