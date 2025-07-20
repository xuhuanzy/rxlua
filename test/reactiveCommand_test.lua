local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local ReactiveCommand = require("rxlua.reactiveCommand")
local new = require("luakit.class").new

local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe

describe('ReactiveCommand', function()
    test("基本构造和执行", function()
        local command = new(ReactiveCommand)()
        local values = {}

        -- 订阅命令
        local subscription = command:subscribe(function(value)
            table.insert(values, value)
        end)

        -- 执行命令
        command:execute("test")
        command:execute("hello")

        expect(#values):toBe(2)
        expect(values[1]):toBe("test")
        expect(values[2]):toBe("hello")

        subscription:dispose()
        command:dispose()
    end)

    test("CanExecute状态管理", function()
        local command = new(ReactiveCommand)({
            initialCanExecute = false
        })

        expect(command:canExecute()):toBe(false)
        expect(command:isDisabled()):toBe(true)

        command:changeCanExecute(true)
        expect(command:canExecute()):toBe(true)
        expect(command:isDisabled()):toBe(false)

        command:dispose()
    end)

    test("CanExecuteChanged回调", function()
        local command = new(ReactiveCommand)()
        local callbackCalled = false

        command:addCanExecuteCallback(function()
            callbackCalled = true
        end)

        command:changeCanExecute(false)
        expect(callbackCalled):toBe(true)


        command:dispose()
    end)

    test("带执行函数的构造", function()
        local executed = false
        local executedValue = nil

        local command = new(ReactiveCommand)({
            execute = function(value)
                executed = true
                executedValue = value
            end
        })

        command:execute("test")

        expect(executed):toBe(true)
        expect(executedValue):toBe("test")

        command:dispose()
    end)

    test("canExecuteSource订阅", function()
        local canExecuteSubject = Rxlua.subject()
        local command = new(ReactiveCommand)({
            canExecuteSource = canExecuteSubject,
            initialCanExecute = true
        })

        expect(command:canExecute()):toBe(true)

        canExecuteSubject:onNext(false)
        expect(command:canExecute()):toBe(false)

        canExecuteSubject:onNext(true)
        expect(command:canExecute()):toBe(true)

        command:dispose()
        canExecuteSubject:dispose()
    end)

    test("多个订阅者", function()
        local command = new(ReactiveCommand)()
        local values1 = {}
        local values2 = {}

        local sub1 = command:subscribe(function(value)
            table.insert(values1, value)
        end)

        local sub2 = command:subscribe(function(value)
            table.insert(values2, value)
        end)

        command:execute("test")

        expect(#values1):toBe(1)
        expect(#values2):toBe(1)
        expect(values1[1]):toBe("test")
        expect(values2[1]):toBe("test")

        sub1:dispose()
        sub2:dispose()
        command:dispose()
    end)

    test("dispose后的行为", function()
        local command = new(ReactiveCommand)()
        local values = {}

        local subscription = command:subscribe(function(value)
            table.insert(values, value)
        end)

        command:dispose()
        expect(function()
            command:execute("test")
        end):toThrow("无法访问已释放的对象")

        expect(#values):toBe(0)

        subscription:dispose()
    end)
end)

describe('ReactiveCommandWithConvert', function()
    test("基本转换功能", function()
        local command = new(ReactiveCommand)({
            convert = function(input)
                return input * 2
            end
        })

        local values = {}
        local subscription = command:subscribe(function(value)
            table.insert(values, value)
        end)

        command:execute(5)
        command:execute(10)

        expect(#values):toBe(2)
        expect(values[1]):toBe(10)
        expect(values[2]):toBe(20)

        subscription:dispose()
        command:dispose()
    end)

    test("字符串转换", function()
        local command = new(ReactiveCommand)({
            convert = function(input)
                return "Hello " .. input
            end
        })

        local values = {}
        local subscription = command:subscribe(function(value)
            table.insert(values, value)
        end)

        command:execute("World")

        expect(#values):toBe(1)
        expect(values[1]):toBe("Hello World")

        subscription:dispose()
        command:dispose()
    end)
end)

describe('ReactiveCommand扩展方法', function()
    test("toReactiveCommand", function()
        local canExecuteSubject = Rxlua.subject()
        local command = canExecuteSubject:toReactiveCommand({
            initialCanExecute = false
        })

        expect(command:canExecute()):toBe(false)

        canExecuteSubject:onNext(true)
        expect(command:canExecute()):toBe(true)

        command:dispose()
        canExecuteSubject:dispose()
    end)

    test("toReactiveCommandWithExecute", function()
        local canExecuteSubject = Rxlua.subject()
        local executed = false

        local command = canExecuteSubject:toReactiveCommand({
            execute = function(value)
                executed = true
            end
        })

        command:execute("test")
        expect(executed):toBe(true)

        command:dispose()
        canExecuteSubject:dispose()
    end)

    test("toReactiveCommandWithConvert", function()
        local canExecuteSubject = Rxlua.subject()
        local command = canExecuteSubject:toReactiveCommand({
            convert = function(input)
                return input * 3
            end
        })

        local values = {}
        local subscription = command:subscribe(function(value)
            table.insert(values, value)
        end)

        command:execute(7)

        expect(#values):toBe(1)
        expect(values[1]):toBe(21)

        subscription:dispose()
        command:dispose()
        canExecuteSubject:dispose()
    end)
end)
