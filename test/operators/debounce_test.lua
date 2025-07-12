local TestFramework = require('luakit.test')
local test = TestFramework.test
local expect = TestFramework.expect
local Timer = require('luakit.timer')
local socket = require('socket')

local Rxlua = require('rxlua')

test('debounce - 基本的去抖动功能', function()
    local results = {}

    local source = Rxlua.subject()

    source
        :debounce(100)
        :subscribe(function(x) table.insert(results, x) end)

    source:onNext(1)
    socket.sleep(0.05) -- 50ms
    source:onNext(2)
    socket.sleep(0.05) -- 50ms
    source:onNext(3)

    -- Wait for debounce time
    socket.sleep(0.15) -- 150ms
    Timer.tick()

    expect(results):toEqual({ 3 })

    source:onNext(4)
    socket.sleep(0.15) -- 150ms
    Timer.tick()

    expect(results):toEqual({ 3, 4 })
end)

local Result = require("rxlua.internal.result")

test('debounce - 在完成时发出最后一个值', function()
    local results = {}
    local source = Rxlua.subject()

    source
        :debounce(100)
        :subscribe(function(x) table.insert(results, x) end)

    source:onNext(1)
    source:onNext(2)
    source:onCompleted(Result.success())

    Timer.tick()

    expect(results[1]):toBe(2)
end)

test('debounce - 错误传播', function()
    local error
    local source = Rxlua.subject()

    source
        :debounce(100)
        :subscribe({
            errorResume = function(err) error = err end
        })

    source:onCompleted(Result.failure("test error"))

    Timer.tick()

    expect(error):toBe("test error")
end)
