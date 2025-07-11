local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local Result = require('rxlua.internal.result')
local expect = TestFramework.expect
local test = TestFramework.test

print("=== BehaviorSubject 测试 ===")

test("behaviorSubject - 基本构造和当前值访问", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")

    -- 测试 getValue 方法
    expect(behaviorSubject:getValue()):toBe("initial")

    behaviorSubject:dispose()
end)

test("behaviorSubject - 新订阅者立即收到当前值", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}

    -- 订阅者应该立即收到当前值
    local subscription = behaviorSubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ "initial" })

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 订阅后接收后续值", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}

    local subscription = behaviorSubject:subscribe(function(value)
        table.insert(values, value)
    end)

    -- 发送新值
    behaviorSubject:onNext("second")
    behaviorSubject:onNext("third")

    expect(values):toEqual({ "initial", "second", "third" })

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - onNext 更新当前值", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")

    expect(behaviorSubject:getValue()):toBe("initial")

    behaviorSubject:onNext("updated")
    expect(behaviorSubject:getValue()):toBe("updated")

    behaviorSubject:onNext("w")
    expect(behaviorSubject:getValue()):toBe("w")

    behaviorSubject:dispose()
end)

test("behaviorSubject - 多个订阅者都收到当前值和后续值", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values1 = {}
    local values2 = {}

    -- 第一个订阅者
    local subscription1 = behaviorSubject:subscribe(function(value)
        table.insert(values1, value)
    end)

    -- 发送一个值
    behaviorSubject:onNext("first")

    -- 第二个订阅者（应该收到当前值）
    local subscription2 = behaviorSubject:subscribe(function(value)
        table.insert(values2, value)
    end)

    -- 发送另一个值
    behaviorSubject:onNext("second")

    expect(values1):toEqual({ "initial", "first", "second" })
    expect(values2):toEqual({ "first", "second" })

    subscription1:dispose()
    subscription2:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 错误处理", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}
    local errors = {}

    local subscription = behaviorSubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        errorResume = function(error)
            table.insert(errors, error)
        end
    })

    behaviorSubject:onNext("before error")
    behaviorSubject:onErrorResume("test error")
    behaviorSubject:onNext("after error")

    expect(values):toEqual({ "initial", "before error", "after error" })
    expect(errors):toEqual({ "test error" })

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 完成状态处理", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}
    local completed = false
    local completionResult = nil

    local subscription = behaviorSubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completed = true
            completionResult = result
        end
    })

    behaviorSubject:onNext("before complete")
    behaviorSubject:onCompleted(Result.success())

    expect(values):toEqual({ "initial", "before complete" })
    expect(completed):toBe(true)
    expect(completionResult):toBe(Result.success())

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 迟到订阅者在完成后的行为", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}
    local completed = false

    -- 更新值并完成
    behaviorSubject:onNext("new")
    behaviorSubject:onNext("final")
    behaviorSubject:onCompleted(Result.success())

    -- 迟到的订阅者只能收到完成信号
    local lateSubscription = behaviorSubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completed = true
        end
    })

    expect(values):toEqual({})
    expect(completed):toBe(true)

    lateSubscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 完成后忽略新值", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}
    local completionCount = 0

    local subscription = behaviorSubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completionCount = completionCount + 1
        end
    })

    behaviorSubject:onNext("before complete")
    behaviorSubject:onCompleted(Result.success())

    -- 尝试在完成后发送值（应该被忽略）
    behaviorSubject:onNext("after complete")
    behaviorSubject:onCompleted(Result.success())

    expect(values):toEqual({ "initial", "before complete" })
    expect(completionCount):toBe(1)

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 失败状态下的 getValue", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")

    -- 以失败状态完成
    behaviorSubject:onCompleted(Result.failure("test error"))

    -- getValue 应该抛出异常
    expect(function()
        behaviorSubject:getValue()
    end):toThrow()

    behaviorSubject:dispose()
end)

test("behaviorSubject - dispose 后的行为", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")
    local values = {}
    local completedCount = 0

    local subscription = behaviorSubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completedCount = completedCount + 1
        end
    })

    behaviorSubject:onNext("before dispose")
    behaviorSubject:dispose()

    -- dispose 后尝试发送值, 异常
    expect(function()
        behaviorSubject:onNext("after dispose")
    end):toThrow("无法访问已释放的对象")

    expect(values):toEqual({ "initial", "before dispose" })
    expect(completedCount):toBe(1)

    subscription:dispose()
end)

test("behaviorSubject - nil 值处理", function()
    local behaviorSubject = Rxlua.behaviorSubject(nil)
    local values = {}

    local subscription = behaviorSubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(behaviorSubject:getValue()):toBe(nil)
    expect(values):toEqual({ nil })

    ---@diagnostic disable-next-line: param-type-not-match
    behaviorSubject:onNext("not nil")
    expect(behaviorSubject:getValue()):toBe("not nil")

    behaviorSubject:onNext(nil)
    expect(behaviorSubject:getValue()):toBe(nil)

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - dispose 后访问抛出异常", function()
    local behaviorSubject = Rxlua.behaviorSubject("initial")

    behaviorSubject:dispose()

    -- dispose 后调用 getValue 应该抛出异常
    expect(function()
        behaviorSubject:getValue()
    end):toThrow()

    behaviorSubject:dispose()
end)

test("behaviorSubject - 与 Subject 的区别", function()
    local subject = Rxlua.subject()
    local behaviorSubject = Rxlua.behaviorSubject("initial")

    local subjectValues = {}
    local behaviorValues = {}

    -- 先发送一些值
    subject:onNext("early")
    behaviorSubject:onNext("early")

    -- 然后订阅
    local subjectSub = subject:subscribe(function(value)
        table.insert(subjectValues, value)
    end)

    local behaviorSub = behaviorSubject:subscribe(function(value)
        table.insert(behaviorValues, value)
    end)

    -- Subject 的迟到订阅者不会收到之前的值
    expect(subjectValues):toEqual({})

    -- BehaviorSubject 的订阅者会立即收到当前值
    expect(behaviorValues):toEqual({ "early" })

    subjectSub:dispose()
    behaviorSub:dispose()
    subject:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 数值类型处理", function()
    local behaviorSubject = Rxlua.behaviorSubject(0 --[[@as number]])
    local values = {}

    local subscription = behaviorSubject:subscribe(function(value)
        table.insert(values, value)
    end)

    behaviorSubject:onNext(1)
    behaviorSubject:onNext(-1)
    behaviorSubject:onNext(3.14)

    expect(values):toEqual({ 0, 1, -1, 3.14 })
    expect(behaviorSubject:getValue()):toBe(3.14)

    subscription:dispose()
    behaviorSubject:dispose()
end)

test("behaviorSubject - 表类型处理", function()
    local initialTable = { name = "initial" }
    local behaviorSubject = Rxlua.behaviorSubject(initialTable)
    local values = {}

    local subscription = behaviorSubject:subscribe(function(value)
        table.insert(values, value)
    end)

    local newTable = { name = "updated", id = 123 }
    behaviorSubject:onNext(newTable)

    expect(#values):toBe(2)
    expect(values[1]):toBe(initialTable)
    expect(values[2]):toBe(newTable)
    expect(behaviorSubject:getValue()):toBe(newTable)

    subscription:dispose()
    behaviorSubject:dispose()
end)
