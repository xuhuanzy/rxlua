---@namespace Rxlua
---@using Luakit


---@class ObserverParams<T>
---@field next? fun(value: T) 下一个值的回调
---@field errorResume? fun(error: IException) 错误恢复的回调
---@field completed? fun(result: Result) 完成回调

---@class ISubject<T>
---@field onNext fun(self: self, value: T) 发送下一个值
---@field onErrorResume fun(self: self, error: IException) 发送错误但继续订阅
---@field onCompleted fun(self: self, result?: Result) 发送完成信号
---@field subscribe fun(self: self, observer: Observer<T>): IDisposable


---@class IDisposable
---@field dispose fun() 取消订阅的函数
