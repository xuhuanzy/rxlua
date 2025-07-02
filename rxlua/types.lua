---@namespace Rxlua


---@class ObserverParams<T>
---@field next fun( value: T) 下一个值的回调
---@field errorResume? fun(error: any) 错误恢复的回调
---@field completed? fun(result: Result) 完成回调
