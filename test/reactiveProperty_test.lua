local TestFramework = require("luakit.test")
local Rxlua = require("rxlua")
local expect = TestFramework.expect
local test = TestFramework.test

test("reactiveProperty - 基本功能测试", function()
    local rp = Rxlua.reactiveProperty(100 --[[@as number]])
    local values = {}

    rp:subscribe({
        next = function(value)
            table.insert(values, value)
        end
    })

    rp:setValue(200)
    rp:setValue(300)

    expect(values):toEqual({ 100, 200, 300 })

    rp:dispose()
end)

test("reactiveProperty - 初始值测试", function()
    local rp = Rxlua.reactiveProperty("initial")
    local values = {}

    rp:subscribe(function(value)
        table.insert(values, value)
    end)

    -- 应该立即收到初始值
    expect(values):toEqual({ "initial" })

    rp:dispose()
end)

test("reactiveProperty - 处置后的行为", function()
    local rp = Rxlua.reactiveProperty(100)
    local values = {}

    rp:subscribe(function(value)
        table.insert(values, value)
    end)

    rp:setValue(200)
    rp:dispose()
    expect(function()
        rp:setValue(300)
    end):toThrow("无法访问已释放的对象.")
    -- 处置后不应该接收新值
    expect(values):toEqual({ 100, 200 })
end)

test("reactiveProperty - 多个订阅者", function()
    local rp = Rxlua.reactiveProperty("shared")
    local values1 = {}
    local values2 = {}

    local sub1 = rp:subscribe(function(value)
        table.insert(values1, value)
    end)

    local sub2 = rp:subscribe(function(value)
        table.insert(values2, value)
    end)

    rp:setValue("updated")

    expect(values1):toEqual({ "shared", "updated" })
    expect(values2):toEqual({ "shared", "updated" })

    sub1:dispose()
    sub2:dispose()
    rp:dispose()
end)

test("reactiveProperty - 值类型测试", function()
    local rpNumber = Rxlua.reactiveProperty(42)
    local rpString = Rxlua.reactiveProperty("hello")
    local rpBoolean = Rxlua.reactiveProperty(true)

    local numberValues = {}
    local stringValues = {}
    local booleanValues = {}

    rpNumber:subscribe(function(value)
        table.insert(numberValues, value)
    end)

    rpString:subscribe(function(value)
        table.insert(stringValues, value)
    end)

    rpBoolean:subscribe(function(value)
        table.insert(booleanValues, value)
    end)

    rpNumber:setValue(84)
    rpString:setValue("world")
    rpBoolean:setValue(false)

    expect(numberValues):toEqual({ 42, 84 })
    expect(stringValues):toEqual({ "hello", "world" })
    expect(booleanValues):toEqual({ true, false })

    rpNumber:dispose()
    rpString:dispose()
    rpBoolean:dispose()
end)
