---@namespace Rxlua
---@using Luakit

local Class = require('luakit.class')
local Result = require('rxlua.internal.result')

---可取消的帧运行器工作项基类. 当取消时, 发布 OnCompleted.
---@class CancellableFrameRunnerWorkItemBase<T>: IFrameRunnerWorkItem, IDisposable
---@field package observer Observer<T> 观察者
---@field package cancelTokenRegistration? CancelTokenRegistration 取消令牌注册的回调
---@field private isDisposed boolean 是否已释放
---@field protected moveNextCore fun(self: self, frameCount: int): boolean 核心帧运行逻辑, 由子类实现
local CancellableFrameRunnerWorkItemBase = Class.declare('Rxlua.CancellableFrameRunnerWorkItemBase')

---取消令牌注册回调
---@param state CancellableFrameRunnerWorkItemBase
local function cancelTokenRegistration(state)
    state.observer:onCompleted()
    state:dispose()
end

---@param observer Observer<T> 观察者
---@param cancelToken CancelToken 取消令牌
function CancellableFrameRunnerWorkItemBase:__init(observer, cancelToken)
    self.observer = observer
    self.isDisposed = false

    if cancelToken:canBeCanceled() then
        self.cancelTokenRegistration = cancelToken:register(cancelTokenRegistration, self)
    end
end

---帧运行器接口实现
---@param frameCount int 帧数
---@return boolean # 返回 true 继续执行, false 停止执行
function CancellableFrameRunnerWorkItemBase:moveNext(frameCount)
    if self.isDisposed then
        return false
    end

    if self.observer.disposed then
        self:dispose()
        return false
    end

    return self:moveNextCore(frameCount)
end

function CancellableFrameRunnerWorkItemBase:dispose()
    if not self.isDisposed then
        self.isDisposed = true
        if self.cancelTokenRegistration then
            self.cancelTokenRegistration:dispose()
        end
        self:disposeCore()
    end
end

function CancellableFrameRunnerWorkItemBase:disposeCore()
    -- 默认空实现, 子类可重写
end

---发布下一个值
---@param value T 值
function CancellableFrameRunnerWorkItemBase:publishOnNext(value)
    self.observer:onNext(value)
end

---发布错误但继续订阅
---@param error Exception 错误
function CancellableFrameRunnerWorkItemBase:publishOnErrorResume(error)
    self.observer:onErrorResume(error)
end

---发布完成信号
---@param error? Exception 错误
function CancellableFrameRunnerWorkItemBase:publishOnCompleted(error)
    if error then
        self.observer:onCompleted(Result.failure(error))
    else
        self.observer:onCompleted()
    end
    self:dispose()
end

return CancellableFrameRunnerWorkItemBase
