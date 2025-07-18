---@namespace Rxlua
---@using Luakit

local Class = require('luakit.class')
local ResultSuccess = require('rxlua.internal.result').success
local getUnhandledExceptionHandler = require("rxlua.observableSystem").getUnhandledExceptionHandler

---观察者. 数据的消费者或者事件的接收者.
---@class Observer<T>: IDisposable
---@field public calledOnCompleted boolean 是否已调用完成
---@field public disposed boolean 是否已释放
---@field public autoDisposeOnCompleted boolean 启用/禁用完成后自动释放
local Observer = Class.declare('Rxlua.Observer')

Observer.autoDisposeOnCompleted = true

---设置源订阅的释放函数
---@param disposable IDisposable
function Observer:setSourceSubscription(disposable)
    -- 源订阅的释放函数
    self.sourceSubscription = disposable
end

---处理下一个值
---@param value T
function Observer:onNext(value)
    if self.disposed or self.calledOnCompleted then
        return
    end

    local ok, err = pcall(self.onNextCore, self, value)

    if not ok then
        ---@cast err -?
        self:onErrorResume({
            type = "Exception",
            message = err,
        })
    end
end

---@param value T
---@return void
function Observer:onNextCore(value)
    error('onNextCore 必须由子类实现')
end

---处理错误但不会终止订阅
---@param err IException
function Observer:onErrorResume(err)
    if self.disposed or self.calledOnCompleted then
        return
    end

    local ok, ex = pcall(self.onErrorResumeCore, self, err)

    if not ok then
        ---@cast ex string
        getUnhandledExceptionHandler()({
            type = "Exception",
            message = ex,
        })
    end
end

---@param err IException
function Observer:onErrorResumeCore(err)
    error('onErrorResumeCore 必须由子类实现')
end

---完成订阅. 但他相当于传统Rx库`OnCompleted`与`OnError`的组合. <br/>
---`result`具有成功或失败两种状态, 例如`throw`会发出失败的结果给`onCompleted`而不是`onErrorResume`.
---@param result? Result
function Observer:onCompleted(result)
    if result == nil then
        result = ResultSuccess()
    end
    if self.calledOnCompleted then
        return
    end
    self.calledOnCompleted = true

    if self.disposed then
        return
    end

    local disposeOnFinally = self.autoDisposeOnCompleted

    local ok, err = pcall(self.onCompletedCore, self, result)

    if disposeOnFinally then
        self:dispose()
    end

    if not ok then
        disposeOnFinally = true
        print('Unhandled exception in onCompleted:', err)
    end
end

---@param result Result
function Observer:onCompletedCore(result)
    error('onCompletedCore 必须由子类实现')
end

---释放观察者
function Observer:dispose()
    if self.disposed then
        return
    end
    self.disposed = true

    self:disposeCore()                    -- 释放自身
    if self.sourceSubscription then
        self.sourceSubscription:dispose() -- 释放源订阅
    end
end

function Observer:disposeCore()
end

return Observer
