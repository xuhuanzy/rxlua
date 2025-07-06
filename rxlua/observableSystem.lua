---@namespace Rxlua

---@export namespace
---@class ObservableSystem
local ObservableSystem = {}

---"未处理的异常"的处理函数. 可以修改.
---@package
---@param error any
local function unhandledException(error)
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

---@param result Result
local function handleResult(result)
    if result:isFailure() then
        ObservableSystem.getUnhandledExceptionHandler()(result)
    end
end

ObservableSystem.handleResult = handleResult
return ObservableSystem
