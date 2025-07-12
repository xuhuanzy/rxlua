---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region ThrottleFirstObserver

local function openGate(state)
    local this = state
    ---@cast this ThrottleFirstObserver
    this.closing = false
end

---@class ThrottleFirstObserver<T>: Observer<T>
---@field package observer Observer<T>
---@field package timeSpan number
---@field package timeProvider TimeProvider
---@field package timer ITimer 计时器
---@field package closing boolean 是否关闭
local ThrottleFirstObserver = Class.declare('Rxlua.ThrottleFirstObserver', Observer)

---@param observer Observer<T>
---@param timeSpan number
---@param timeProvider TimeProvider
function ThrottleFirstObserver:__init(observer, timeSpan, timeProvider)
    self.observer = observer
    self.timeProvider = timeProvider
    self.timeSpan = timeSpan
    self.closing = false
    self.timer = timeProvider:createTimer(openGate, self, -1, -1)
end

---@param value T
---@protected
function ThrottleFirstObserver:onNextCore(value)
    if not self.closing then
        self.closing = true
        self.observer:onNext(value)
        self.timer:change(self.timeSpan, -1)
    end
end

---@param error any
---@protected
function ThrottleFirstObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function ThrottleFirstObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---@protected
function ThrottleFirstObserver:disposeCore()
    self.timer:dispose()
end

---#endregion

---#region ThrottleFirst

---@class ThrottleFirst<T>: Observable<T>
---@field private source Observable<T>
---@field private timeSpan number
---@field private timeProvider TimeProvider
local ThrottleFirst = Class.declare('Rxlua.ThrottleFirst', Observable)

---@param source Observable<T>
---@param timeSpan number
---@param timeProvider TimeProvider
function ThrottleFirst:__init(source, timeSpan, timeProvider)
    self.source = source
    self.timeSpan = timeSpan
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function ThrottleFirst:subscribeCore(observer)
    local throttleFirstObserver = new(ThrottleFirstObserver)(observer, self.timeSpan, self.timeProvider)
    return self.source:subscribe(throttleFirstObserver)
end

---#endregion

---#region 导出到 Observable

---在每个时间窗口内只发出第一个元素.
---@param timeSpan number 时间窗口(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:throttleFirst(timeSpan, timeProvider)
    if timeSpan < 0 then
        timeSpan = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(ThrottleFirst)(self, timeSpan, timeProvider)
end

---#endregion
