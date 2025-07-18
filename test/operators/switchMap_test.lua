local TestFramework = require("luakit.test")
local expect = TestFramework.expect
local test = TestFramework.test
local describe = TestFramework.describe
local Rxlua = require("rxlua")
local of = Rxlua.of
local subject = Rxlua.subject
require("rxlua.operators.map")
require("rxlua.operators.switchMap")

describe('switchMap', function()
    test("基本切换功能", function()
        local values = {}
        local s1 = subject()
        local s2 = subject()

        s1:switchMap(function(x)
            if x == 1 then return of('a', 'b') end
            if x == 2 then return s2 end
            return of('d', 'e')
        end):subscribe(function(v) table.insert(values, v) end)

        s1:onNext(1)
        expect(values):toEqual({ 'a', 'b' })

        s1:onNext(2)
        s2:onNext('c')
        expect(values):toEqual({ 'a', 'b', 'c' })

        s1:onNext(3)
        expect(values):toEqual({ 'a', 'b', 'c', 'd', 'e' })
    end)

    test("外部源完成时机", function()
        local completed = false
        local s1 = subject()
        local s2 = subject()

        s1:switchMap(function() return s2 end)
            :subscribe({ completed = function() completed = true end })

        s1:onNext(1)
        s1:onCompleted()
        expect(completed):toBe(false) -- Inner (s2) is still running

        s2:onNext('a')
        s2:onCompleted()
        expect(completed):toBe(true) -- Now both are completed
    end)

    test("内部源未完成时切换", function()
        local values = {}
        local s1 = subject()
        local s2 = subject()
        local s3 = subject()

        s1:switchMap(function(x)
            if x == 1 then return s2 end
            return s3
        end):subscribe(function(v) table.insert(values, v) end)

        s1:onNext(1)
        s2:onNext('a')
        expect(values):toEqual({ 'a' })

        s1:onNext(2)   -- Switch to s3
        s2:onNext('b') -- This value should be ignored
        s3:onNext('c')
        expect(values):toEqual({ 'a', 'c' })
    end)

    test("错误处理 - 外部源", function()
        local err = nil
        local s1 = subject()
        s1:switchMap(function() return of(1) end)
            :subscribe({ errorResume = function(e) err = e.message end })

        s1:onErrorResume({
            type = "Exception",
            message = "error",
        })
        expect(err):toBe('error')
    end)

    test("错误处理 - 内部源", function()
        local err = nil
        local s1 = subject()
        local s2 = subject()
        s1:switchMap(function() return s2 end)
            :subscribe({ errorResume = function(e) err = e.message end })

        s1:onNext(1)
        s2:onErrorResume({
            type = "Exception",
            message = "inner error",
        })
        expect(err):toBe('inner error')
    end)

    test("一致性测试", function()
        local values = {}
        local completed = false

        -- 1. 创建一个 Subject，它将发出 Observables
        local sources = subject()

        -- 2. 使用 switchMap 模拟 Switch 的行为
        -- project 函数直接返回接收到的 Observable
        sources:switchMap(function(obs) return obs end)
            :subscribe({
                next = function(v) table.insert(values, v) end,
                completed = function() completed = true end
            })

        local source1 = subject()
        local source2 = subject()

        -- 3. sources 发出第一个内部 Observable (source1)
        sources:onNext(source1)

        -- 4. 此时不应有任何值发出
        expect(#values):toBe(0)

        -- 5. source1 发出值
        source1:onNext(1)
        source1:onNext(2)

        -- 6. sources 发出第二个内部 Observable (source2)，切换发生
        sources:onNext(source2)

        -- 7. source2 发出值
        source2:onNext(10)

        -- 8. source1 再次发出值，此值应被忽略
        source1:onNext(3)

        -- 9. 验证最终的值序列
        expect(values):toEqual({ 1, 2, 10 })

        -- 10. 内部 sources 完成，不应导致最终完成
        source1:onCompleted()
        source2:onCompleted()
        expect(completed):toBe(false)

        -- 11. 外部 sources 完成，此时应最终完成
        sources:onCompleted()
        expect(completed):toBe(true)
    end)
end)
