---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region FromEventPattern

---@class FromEventPattern<TDelegate>: IDisposable
local FromEventPattern = Class.declare('Rxlua.FromEventPattern')

---@param observer Observer<TDelegate>
---@param addHandler fun(handler: TDelegate)
---@param removeHandler fun(handler: TDelegate)
function FromEventPattern:__init(observer, addHandler, removeHandler)
    self.observer = observer
    self.removeHandler = removeHandler

    -- 事件在触发时将会调用这个函数, 因此需要闭包
    self.registeredHandler = function()
        if self.observer then
            -- 这里只是在通知观察者, 一个事件发生了
            self.observer:onNext(nil)
        end
    end

    -- 与事件系统进行链接
    addHandler(self.registeredHandler)
end

function FromEventPattern:completeDispose()
    if self.observer then
        self.observer:onCompleted()
        self:dispose()
    end
end

function FromEventPattern:dispose()
    local removeHandler = self.removeHandler
    if removeHandler then
        self.observer = nil
        self.removeHandler = nil
        removeHandler(self.registeredHandler)
    end
end

---#endregion FromEventPattern

---#region FromEvent

---@class FromEvent<T>: Observable<nil>
local FromEvent = Class.declare('Rxlua.FromEvent', Observable)

---@param addHandler fun(handler: T) 添加事件处理器的函数
---@param removeHandler fun(handler: T) 移除事件处理器的函数
function FromEvent:__init(addHandler, removeHandler)
    self.addHandler = addHandler
    self.removeHandler = removeHandler
end

---@param observer Observer<T>
---@return IDisposable
function FromEvent:subscribeCore(observer)
    return new(FromEventPattern)(observer, self.addHandler, self.removeHandler)
end

---#endregion FromEvent

---#region 导出到 Observable

---@class FromEventParam<T>
---@field addHandler fun(handler: T) 添加事件处理器的函数
---@field removeHandler fun(handler: T) 移除事件处理器的函数

---@param param FromEventParam<T>
---@return Observable<T>
function Observable.fromEvent(param)
    return new(FromEvent)(param.addHandler, param.removeHandler)
end

---#endregion
