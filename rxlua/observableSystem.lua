---@namespace Rxlua

---@export namespace
---@class ObservableSystem
local ObservableSystem = {}

---"未处理的异常"的处理函数. 可以修改.
---@package
---@param error any
local unhandledException = function(error)
    print('Rxlua UnhandledException:', error)
end

---设置默认的未处理异常处理函数.
---@param handler fun(error: any)
function ObservableSystem.setUnhandledExceptionHandler(handler)
    unhandledException = handler
end

function ObservableSystem.getUnhandledExceptionHandler()
    return unhandledException
end


---#region defaultFrameProvider

---默认帧提供者实例, 默认没有任何实现, 必须要通过 setDefaultFrameProvider 设置
---@type FrameProvider
local DefaultFrameProvider

---获取默认帧提供者
---@return FrameProvider
function ObservableSystem.getDefaultFrameProvider()
    if not DefaultFrameProvider then
        error("未设置 ObservableSystem.DefaultFrameProvider.")
    end
    return DefaultFrameProvider
end

---设置默认帧提供者
---@param provider FrameProvider
function ObservableSystem.setDefaultFrameProvider(provider)
    DefaultFrameProvider = provider
end

---#endregion

return ObservableSystem
