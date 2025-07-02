---@namespace Rxlua

---@export namespace
---@class ObservableSystem
---@field unhandledException fun(error: any) "未处理的异常"的处理函数
local ObservableSystem = {}


function ObservableSystem.getUnhandledExceptionHandler()
    return ObservableSystem.unhandledException
end

---@package
---@param error any
ObservableSystem.unhandledException = function(error)
    print('Rxlua UnhandledException:', error)
end


---@param result Result
local function handleResult(result)
    if result:isFailure() then
        ObservableSystem.getUnhandledExceptionHandler()(result)
    end
end


ObservableSystem.handleResult = handleResult
return ObservableSystem
