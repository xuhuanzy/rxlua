---@namespace Rxlua
---@using Luakit


---@class ObserverParams<T, TState>
---@field next? fun(value: T) 下一个值的回调
---@field errorResume? fun(error: Exception) 错误恢复的回调
---@field completed? fun(result: Result) 完成回调
---@field state? TState 初始化时传入的值.

---@class ISubject<T>
---@field onNext fun(self: self, value: T) 发送下一个值
---@field onErrorResume fun(self: self, error: Exception) 发送错误但继续订阅
---@field onCompleted fun(self: self, result?: Result) 发送完成信号
---@field subscribe fun(self: self, observer: Observer<T>): IDisposable


---@class IDisposable
---@field dispose fun() 取消订阅的函数

---`ReactiveCommand`构造参数
---@class ReactiveCommand.Params<T, TOutput>
---@field canExecuteSource? Observable<boolean> 可执行状态源.
---@field initialCanExecute? boolean 初始可执行状态. 默认`true`.
---@field execute? fun(value: T) 执行函数.
---@field convert? fun(input: T): TOutput 转换函数, 如果提供了该函数, 则`execute`执行时参数会被转换为`TOutput`类型.

---@class ICommand
---@field canExecuteChanged table<fun(sender: table, args: any...), true> 可执行状态改变时回调组
---@field canExecute fun(self: self, parameter: any): boolean 判断命令在当前状态下是否可执行
---@field execute fun(self: self, parameter: any) 执行命令
