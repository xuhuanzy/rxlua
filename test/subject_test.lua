local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local Result = require('rxlua.internal.result')
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('subject', function()
    test("基本订阅和发送值", function()
        local subject = Rxlua.subject()
        local values = {}

        local subscription = subject:subscribe(function(value)
            table.insert(values, value)
        end)

        subject:onNext("Hello")
        subject:onNext("World")
        subject:onNext(42)

        expect(values):toEqual({ "Hello", "World", 42 })

        subscription:dispose()
        subject:dispose()
    end)

    test("错误处理", function()
        local subject = Rxlua.subject()
        local values = {}
        local errors = {}

        local subscription = subject:subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            errorResume = function(error)
                table.insert(errors, error)
            end
        })

        subject:onNext("Before Error")
        subject:onErrorResume("测试错误")
        subject:onNext("After Error")

        expect(values):toEqual({ "Before Error", "After Error" })
        expect(errors):toEqual({ "测试错误" })

        subscription:dispose()
        subject:dispose()
    end)

    test("完成状态", function()
        local subject = Rxlua.subject()
        local values = {}
        local completed = false
        local completionResult = nil

        local subscription = subject:subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            completed = function(result)
                completed = true
                completionResult = result
            end
        })

        subject:onNext("Test")
        subject:onCompleted(Result.success())

        expect(values):toEqual({ "Test" })
        expect(completed):toBe(true)
        expect(completionResult):toBe(Result.success())

        subscription:dispose()
        subject:dispose()
    end)

    test("完成后忽略新值", function()
        local subject = Rxlua.subject()
        local values = {}
        local errors = {}
        local completionCount = 0

        local subscription = subject:subscribe({
            next = function(value)
                table.insert(values, value)
            end,
            errorResume = function(error)
                table.insert(errors, error)
            end,
            completed = function(result)
                completionCount = completionCount + 1
            end
        })

        subject:onNext("Before Complete")
        subject:onCompleted(Result.success())

        -- 尝试在完成后发送值（应该被忽略）
        subject:onNext("After Complete")
        subject:onErrorResume("After Complete Error")
        subject:onCompleted(Result.success())

        expect(values):toEqual({ "Before Complete" })
        expect(#errors):toBe(0)
        expect(completionCount):toBe(1)

        subscription:dispose()
        subject:dispose()
    end)

    test("迟到的订阅者", function()
        local subject = Rxlua.subject()
        local values = {}

        -- 先发送一些值
        subject:onNext("Early Value")
        subject:onCompleted(Result.success())

        -- 然后订阅（迟到的订阅者）
        local lateSubscription = subject:subscribe(function(value)
            table.insert(values, value)
        end)

        -- 迟到的订阅者不应该收到之前的值
        expect(#values):toBe(0)

        lateSubscription:dispose()
        subject:dispose()
    end)

    test("多个订阅者", function()
        local subject = Rxlua.subject()
        local values1 = {}
        local values2 = {}

        local subscription1 = subject:subscribe(function(value)
            table.insert(values1, value)
        end)

        local subscription2 = subject:subscribe(function(value)
            table.insert(values2, value)
        end)

        subject:onNext("Broadcast")
        subject:onNext("Message")

        expect(values1):toEqual({ "Broadcast", "Message" })
        expect(values2):toEqual({ "Broadcast", "Message" })

        subscription1:dispose()
        subscription2:dispose()
        subject:dispose()
    end)

    test("处置后的行为", function()
        local subject = Rxlua.subject()
        local values = {}

        local subscription = subject:subscribe(function(value)
            table.insert(values, value)
        end)

        subject:onNext("Before Dispose")
        subject:dispose()
        -- 已经处置了, 再传入新值将 error
        expect(function()
            subject:onNext("After Dispose")
        end):toThrow("无法访问已释放的对象")

        -- 处置后不应该接收新值
        expect(values):toEqual({ "Before Dispose" })

        subscription:dispose()
    end)
end)