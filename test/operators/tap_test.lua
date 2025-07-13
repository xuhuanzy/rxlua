local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test
local of = Rxlua.of
local describe = TestFramework.describe

describe('tap', function()
    test("onNext", function()
        local values = {}
        local tapValues = {}
        local source = of(1, 2, 3)
        source:tap({
            onNext = function(value)
                table.insert(tapValues, value)
            end
        }):subscribe(function(value)
            table.insert(values, value)
        end)
        expect(values):toEqual({ 1, 2, 3 })
        expect(tapValues):toEqual({ 1, 2, 3 })
    end)

    test("onCompleted", function()
        local completed = false
        local tapCompleted = false
        local source = of(1, 2, 3)
        source:tap({
            onCompleted = function()
                tapCompleted = true
            end
        }):subscribe({
            next = function() end,
            completed = function()
                completed = true
            end
        })
        expect(completed):toBe(true)
        expect(tapCompleted):toBe(true)
    end)

    test("onErrorResume", function()
        local error = false
        local tapError = false
        local subject = Rxlua.subject()
        subject:tap({
            onErrorResume = function()
                tapError = true
            end
        }):subscribe({
            next = function() end,
            errorResume = function()
                error = true
            end
        })
        subject:onErrorResume("error")
        expect(error):toBe(true)
        expect(tapError):toBe(true)
    end)

    test("onDispose", function()
        local disposed = false
        local subject = Rxlua.subject()
        local subscription = subject:tap({
            onDispose = function()
                disposed = true
            end
        }):subscribe(function()

        end)
        subscription:dispose()
        expect(disposed):toBe(true)
    end)

    test("onSubscribe", function()
        local subscribed = false
        local source = of(1, 2, 3)
        source:tap({
            onSubscribe = function()
                subscribed = true
            end
        }):subscribe(function()

        end)
        expect(subscribed):toBe(true)
    end)

    test("state", function()
        local state = { count = 0 }
        local source = of(1, 2, 3)
        source:tap({
            state = state,
            onNext = function(value, s)
                s.count = s.count + value
            end,
            onCompleted = function(result, s)
                s.count = s.count + 10
            end
        }):subscribe(function()

        end)
        expect(state.count):toBe(16)
    end)

    test("链式", function()
        local values = {}
        local tapValues = {}
        local source = of(1, 2, 3, 4, 5, 6)
        source:where(function(x) return x % 2 == 0 end)
            :tap({ onNext = function(v) table.insert(tapValues, v) end })
            :map(function(x) return x * 10 end)
            :subscribe(function(v) table.insert(values, v) end)

        expect(tapValues):toEqual({ 2, 4, 6 })
        expect(values):toEqual({ 20, 40, 60 })
    end)
end)
