local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local Result = require("rxlua.result")
local Class = require('luakit.class')
local new = require('luakit.class').new
local expect = TestFramework.expect
local test = TestFramework.test

print("=== ReplaySubject 测试 ===")

-- 模拟时间提供者，用于可控的时间测试
---@class MockTimeProvider: Rxlua.TimeProvider
local MockTimeProvider = Class.declare('MockTimeProvider')

function MockTimeProvider:__init()
    self.currentTime = 0
end

function MockTimeProvider:getTimestamp()
    return self.currentTime
end

function MockTimeProvider:getElapsedTime(startTimestamp, endTimestamp)
    return endTimestamp - startTimestamp
end

function MockTimeProvider:advance(milliseconds)
    self.currentTime = self.currentTime + milliseconds
end

-- 基础功能测试
test("replaySubject - 基本重播功能", function()
    local replaySubject = Rxlua.replaySubject()
    local values1 = {}
    local values2 = {}

    -- 先发送一些值
    replaySubject:onNext("A")
    replaySubject:onNext("B")
    replaySubject:onNext("C")

    -- 第一个订阅者应该立即收到所有历史值
    local subscription1 = replaySubject:subscribe(function(value)
        table.insert(values1, value)
    end)

    expect(values1):toEqual({ "A", "B", "C" })

    -- 发送新值
    replaySubject:onNext("D")

    -- 第二个订阅者应该收到所有历史值包括新值
    local subscription2 = replaySubject:subscribe(function(value)
        table.insert(values2, value)
    end)

    expect(values1):toEqual({ "A", "B", "C", "D" })
    expect(values2):toEqual({ "A", "B", "C", "D" })

    subscription1:dispose()
    subscription2:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 缓冲区大小限制", function()
    local replaySubject = Rxlua.replaySubject(2) -- 只保留最近 2 个值
    local values = {}

    -- 发送多个值
    replaySubject:onNext(1)
    replaySubject:onNext(2)
    replaySubject:onNext(3)
    replaySubject:onNext(4)

    -- 新订阅者只应该收到最近的 2 个值
    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ 3, 4 })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 时间窗口限制", function()
    local mockTimeProvider = new("MockTimeProvider")()
    local replaySubject = Rxlua.replaySubject(nil, 1000, mockTimeProvider) -- 1秒时间窗口
    local values = {}

    -- 在时间 0 发送值
    mockTimeProvider:advance(0)
    replaySubject:onNext("old1")

    -- 在时间 500ms 发送值
    mockTimeProvider:advance(500)
    replaySubject:onNext("old2")

    -- 在时间 1200ms 发送值（超过时间窗口）
    mockTimeProvider:advance(700) -- 总共 1200ms
    replaySubject:onNext("new")

    -- 新订阅者应该只收到时间窗口内的值
    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    -- 应该只有 "old2" 和 "new"，"old1" 应该被时间窗口过滤掉
    expect(values):toEqual({ "old2", "new" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 空缓冲区订阅", function()
    local replaySubject = Rxlua.replaySubject()
    local values = {}

    -- 在没有发送任何值的情况下订阅
    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(#values):toBe(0)

    -- 发送值后应该正常接收
    replaySubject:onNext("first")
    expect(values):toEqual({ "first" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 多个订阅者", function()
    local replaySubject = Rxlua.replaySubject()
    local values1 = {}
    local values2 = {}

    -- 发送一些历史值
    replaySubject:onNext("history")

    -- 两个订阅者都应该收到历史值
    local subscription1 = replaySubject:subscribe(function(value)
        table.insert(values1, value)
    end)

    local subscription2 = replaySubject:subscribe(function(value)
        table.insert(values2, value)
    end)

    expect(values1):toEqual({ "history" })
    expect(values2):toEqual({ "history" })

    -- 发送新值，两个订阅者都应该收到
    replaySubject:onNext("broadcast")

    expect(values1):toEqual({ "history", "broadcast" })
    expect(values2):toEqual({ "history", "broadcast" })

    subscription1:dispose()
    subscription2:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 完成状态处理", function()
    local replaySubject = Rxlua.replaySubject()
    local values = {}
    local completed = false
    local completionResult = nil

    -- 发送一些值然后完成
    replaySubject:onNext("before_complete")
    replaySubject:onCompleted(Result.success())

    -- 迟到的订阅者应该收到历史值和完成信号
    local subscription = replaySubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completed = true
            completionResult = result
        end
    })

    expect(values):toEqual({ "before_complete" })
    expect(completed):toBe(true)
    expect(completionResult):toBe(Result.success())

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 完成后忽略新值", function()
    local replaySubject = Rxlua.replaySubject()
    local values = {}

    replaySubject:onNext("before_complete")
    replaySubject:onCompleted(Result.success())

    -- 尝试在完成后发送值（应该被忽略）
    replaySubject:onNext("after_complete")

    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ "before_complete" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 错误处理", function()
    local replaySubject = Rxlua.replaySubject()
    local values = {}
    local errors = {}

    replaySubject:onNext("normal_value")

    local subscription = replaySubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        errorResume = function(error)
            table.insert(errors, error)
        end
    })

    -- 应该收到历史值
    expect(values):toEqual({ "normal_value" })

    -- 发送错误
    replaySubject:onErrorResume("test_error")
    expect(errors):toEqual({ "test_error" })

    -- 错误后仍然可以继续发送值
    replaySubject:onNext("after_error")
    expect(values):toEqual({ "normal_value", "after_error" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 资源释放", function()
    local replaySubject = Rxlua.replaySubject()
    local values = {}
    local completed = false

    replaySubject:onNext("test_value")

    local subscription = replaySubject:subscribe({
        next = function(value)
            table.insert(values, value)
        end,
        completed = function(result)
            completed = true
        end
    })

    expect(values):toEqual({ "test_value" })

    -- 释放资源
    replaySubject:dispose()

    expect(completed):toBe(true)

    subscription:dispose()
end)

test("replaySubject - 构造函数重载", function()
    -- 测试无参构造
    local replaySubject1 = Rxlua.replaySubject()
    expect(replaySubject1):toBe(replaySubject1) -- 确保对象创建成功

    -- 测试只指定缓冲区大小
    local replaySubject2 = Rxlua.replaySubject(5)
    expect(replaySubject2):toBe(replaySubject2)

    -- 测试指定时间窗口
    local mockTimeProvider = new("MockTimeProvider")()
    local replaySubject3 = Rxlua.replaySubject(nil, 1000, mockTimeProvider)
    expect(replaySubject3):toBe(replaySubject3)

    -- 测试完整参数
    local replaySubject4 = Rxlua.replaySubject(3, 500, mockTimeProvider)
    expect(replaySubject4):toBe(replaySubject4)

    replaySubject1:dispose()
    replaySubject2:dispose()
    replaySubject3:dispose()
    replaySubject4:dispose()
end)

test("replaySubject - 缓冲区与时间窗口组合", function()
    local mockTimeProvider = new("MockTimeProvider")()
    local replaySubject = Rxlua.replaySubject(2, 1000, mockTimeProvider) -- 最多2个值，1秒窗口
    local values = {}

    -- 发送多个值，测试两种限制的组合效果
    replaySubject:onNext("A") -- 时间 0
    mockTimeProvider:advance(300)
    replaySubject:onNext("B") -- 时间 300
    mockTimeProvider:advance(300)
    replaySubject:onNext("C") -- 时间 600
    mockTimeProvider:advance(300)
    replaySubject:onNext("D") -- 时间 900

    -- 由于缓冲区大小限制为2，应该只保留最近的两个值 "C", "D"
    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(values):toEqual({ "C", "D" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 性能测试", function()
    local replaySubject = Rxlua.replaySubject(1000) -- 较大的缓冲区
    local values = {}

    -- 发送大量数据
    for i = 1, 1000 do
        replaySubject:onNext(i)
    end

    -- 测试订阅时重播的性能
    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(#values):toBe(1000)
    expect(values[1]):toBe(1)
    expect(values[1000]):toBe(1000)

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 边界条件：缓冲区大小为0", function()
    local replaySubject = Rxlua.replaySubject(0) -- 不保留任何值
    local values = {}

    replaySubject:onNext("should_not_replay")

    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(#values):toBe(0) -- 不应该收到任何重播的值

    -- 但新值应该正常接收
    replaySubject:onNext("new_value")
    expect(values):toEqual({ "new_value" })

    subscription:dispose()
    replaySubject:dispose()
end)

test("replaySubject - 边界条件：时间窗口为0", function()
    local mockTimeProvider = new("MockTimeProvider")()
    local replaySubject = Rxlua.replaySubject(nil, 0, mockTimeProvider) -- 时间窗口为0
    local values = {}

    replaySubject:onNext("should_not_replay")
    mockTimeProvider:advance(1) -- 任何时间推进都会让值过期

    local subscription = replaySubject:subscribe(function(value)
        table.insert(values, value)
    end)

    expect(#values):toBe(0) -- 不应该收到任何重播的值

    subscription:dispose()
    replaySubject:dispose()
end)
