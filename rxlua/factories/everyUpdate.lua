---@namespace Rxlua
---@using Luakit

local Observable = require("rxlua.observable")
local Class = require("luakit.class")
local new = Class.new
local super = Class.super
local CancellableFrameRunnerWorkItemBase = require("rxlua.internal.cancellableFrameRunnerWorkItemBase")
local ObservableSystem = require("rxlua.observableSystem")
local CancelToken = require("luakit.cancelToken").CancelToken
local empty = require("rxlua.factories.empty")

-- #region EveryUpdateRunnerWorkItem

---每帧更新运行器工作项
---@class EveryUpdate.RunnerWorkItem<T>: CancellableFrameRunnerWorkItemBase<T>
local EveryUpdateRunnerWorkItem = Class.declare("Rxlua.EveryUpdate.RunnerWorkItem", CancellableFrameRunnerWorkItemBase)

---@param observer Observer<nil> 观察者
---@param cancelToken CancelToken 取消令牌
function EveryUpdateRunnerWorkItem:__init(observer, cancelToken)
    super(self) --[[@as CancellableFrameRunnerWorkItemBase]](observer, cancelToken)
end

---核心帧运行逻辑
---@return boolean @ 返回 true 继续执行, false 停止执行
function EveryUpdateRunnerWorkItem:moveNextCore()
    self:publishOnNext(nil)
    return true
end

-- #endregion



-- #region EveryUpdate

---每帧更新的 Observable
---@class EveryUpdate: Observable<nil>
---@field private frameProvider FrameProvider 帧提供者
---@field private cancelToken CancelToken 取消令牌
local EveryUpdate = Class.declare("Rxlua.EveryUpdate", {
    super = Observable,
    enableSuperChaining = true,
})

---构造函数
---@param frameProvider FrameProvider 帧提供者
---@param cancelToken CancelToken 取消令牌
function EveryUpdate:__init(frameProvider, cancelToken)
    self.frameProvider = frameProvider
    self.cancelToken = cancelToken
end

---订阅核心逻辑
---@param observer Observer<nil> 观察者
---@return IDisposable
function EveryUpdate:subscribeCore(observer)
    local runner = new(EveryUpdateRunnerWorkItem)(observer, self.cancelToken)
    self.frameProvider:register(runner)
    return runner
end

-- #endregion



-- #region Factory Function

---创建一个每帧都发出值的 Observable
---@param frameProvider? FrameProvider 帧提供者, 默认使用 ObservableSystem.getDefaultFrameProvider()
---@param cancellationToken? CancelToken 取消令牌, 默认为不可取消的令牌
---@return Observable<nil>
local function everyUpdate(frameProvider, cancellationToken)
    -- 设置默认值
    frameProvider = frameProvider or ObservableSystem.getDefaultFrameProvider()
    cancellationToken = cancellationToken or CancelToken.new(nil)

    -- 如果取消令牌已经被取消, 返回空的 Observable
    if cancellationToken:isCancelled() then
        return empty()
    end

    return new(EveryUpdate)(frameProvider, cancellationToken)
end

-- #endregion

return everyUpdate
