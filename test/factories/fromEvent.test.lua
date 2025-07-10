local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test
local fromEvent = Rxlua.fromEvent

print("=== FromEvent 工厂方法测试 ===")

test("fromEvent - 基本事件订阅", function()
    local values = {}
    local handlers = {}

    -- 模拟简单的事件系统
    local function addHandler(handler)
        table.insert(handlers, handler)
    end

    local function removeHandler(handler)
        for i, h in ipairs(handlers) do
            if h == handler then
                table.remove(handlers, i)
                break
            end
        end
    end

    local function triggerEvent()
        for _, handler in ipairs(handlers) do
            handler()
        end
    end

    -- 创建 Observable
    local subscription = fromEvent({
        addHandler = addHandler,
        removeHandler = removeHandler
    }):subscribe(function(value)
        table.insert(values, value)
    end)

    -- 触发事件
    triggerEvent()
    triggerEvent()

    -- 验证接收到的值 (fromEvent 发送 nil)
    expect(values):toEqual({ nil, nil })

    -- 取消订阅
    subscription:dispose()

    -- 验证处理器已被移除
    expect(#handlers):toBe(0)
end)

test("fromEvent - 多个订阅者", function()
    local values1 = {}
    local values2 = {}
    local handlers = {}

    local function addHandler(handler)
        table.insert(handlers, handler)
    end

    local function removeHandler(handler)
        for i, h in ipairs(handlers) do
            if h == handler then
                table.remove(handlers, i)
                break
            end
        end
    end

    local function triggerEvent()
        for _, handler in ipairs(handlers) do
            handler()
        end
    end

    local observable = fromEvent({
        addHandler = addHandler,
        removeHandler = removeHandler
    })

    local sub1 = observable:subscribe(function(value)
        table.insert(values1, value)
    end)

    local sub2 = observable:subscribe(function(value)
        table.insert(values2, value)
    end)

    triggerEvent()

    expect(values1):toEqual({ nil })
    expect(values2):toEqual({ nil })
    expect(#handlers):toBe(2) -- 应该有两个处理器

    sub1:dispose()
    sub2:dispose()
    expect(#handlers):toBe(0) -- 所有处理器都应该被移除
end)

test("fromEvent - 部分取消订阅", function()
    local values1 = {}
    local values2 = {}
    local handlers = {}

    local function addHandler(handler)
        table.insert(handlers, handler)
    end

    local function removeHandler(handler)
        for i, h in ipairs(handlers) do
            if h == handler then
                table.remove(handlers, i)
                break
            end
        end
    end

    local function triggerEvent()
        for _, handler in ipairs(handlers) do
            handler()
        end
    end

    local observable = fromEvent({
        addHandler = addHandler,
        removeHandler = removeHandler
    })

    local sub1 = observable:subscribe(function(value)
        table.insert(values1, value)
    end)

    local sub2 = observable:subscribe(function(value)
        table.insert(values2, value)
    end)

    triggerEvent()

    -- 取消第一个订阅
    sub1:dispose()
    expect(#handlers):toBe(1) -- 应该剩下一个处理器

    triggerEvent()

    expect(values1):toEqual({ nil })      -- 第一个订阅者不再接收事件
    expect(values2):toEqual({ nil, nil }) -- 第二个订阅者继续接收

    sub2:dispose()
    expect(#handlers):toBe(0) -- 最后一个处理器也被移除
end)

test("fromEvent - 错误处理", function()
    local errorOccurred = false
    local handlers = {}

    local function addHandler(handler)
        table.insert(handlers, handler)
    end

    local function removeHandler(handler)
        for i, h in ipairs(handlers) do
            if h == handler then
                table.remove(handlers, i)
                break
            end
        end
    end

    local subscription = fromEvent({
        addHandler = addHandler,
        removeHandler = removeHandler
    }):subscribe({
        next = function(value)
            error("测试错误")
        end,
        errorResume = function(err)
            errorOccurred = true
        end
    })

    -- 触发事件，应该产生错误
    for _, handler in ipairs(handlers) do
        handler()
    end

    expect(errorOccurred):toBe(true)

    subscription:dispose()
end)
