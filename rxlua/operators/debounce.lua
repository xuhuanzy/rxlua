---@namespace Rxlua

---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region DebounceObserver

local function raiseOnNext(state)
    local this = state
    ---@cast this DebounceObserver
    if not this.hasValue then
        return
    end

    this.observer:onNext(this.lastValue)
    this.hasValue = false
    this.lastValue = false
end

---@class DebounceObserver<T>: Observer<T>
---@field package timer ITimer 计时器
---@field package lastValue T? 最后一个值
---@field package hasValue boolean 是否有值
local DebounceObserver = Class.declare('Rxlua.DebounceObserver', Observer)

---@param observer Observer<T>
---@param delay number
---@param timeProvider TimeProvider
function DebounceObserver:__init(observer, delay, timeProvider)
    self.observer = observer
    self.delay = delay
    self.hasValue = false
    self.timer = timeProvider:createTimer(raiseOnNext, self, delay, -1)
end

---@param value T
---@protected
function DebounceObserver:onNextCore(value)
    self.lastValue = value
    self.hasValue = true
    self.timer:change(self.delay, -1)
end

---@param error Exception
---@protected
function DebounceObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
---@protected
function DebounceObserver:onCompletedCore(result)
    if self.hasValue then
        self.observer:onNext(self.lastValue)
        self.hasValue = false
        self.lastValue = false
    end
    self.observer:onCompleted(result)
end

---@protected
function DebounceObserver:disposeCore()
    self.timer:dispose()
end

---#endregion

---#region Debounce

---@class Debounce<T>: Observable<T>
---@field private source Observable<T>
---@field private delay number
local Debounce = Class.declare('Rxlua.Debounce', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param delay number
---@param timeProvider TimeProvider
function Debounce:__init(source, delay, timeProvider)
    self.source = source
    self.delay = delay
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function Debounce:subscribeCore(observer)
    local debounceObserver = new(DebounceObserver)(observer, self.delay, self.timeProvider)
    return self.source:subscribe(debounceObserver)
end

---#endregion

---#region 导出到 Observable

---等待一个指定的时间间隔, 如果在该时间间隔内没有收到新的元素(收到新的元素时, 会重置计时器), 才会发出最新的元素. <br>
---即在事件停止触发一段时间后, 才推送最后一个事件.
---@param delay number 延迟时间(毫秒)
---@param timeProvider? TimeProvider 时间提供者
---@return Observable<T>
function Observable:debounce(delay, timeProvider)
    if delay < 0 then
        delay = 0
    end
    assert(timeProvider, "必须提供一个`TimeProvider`, 建议使用`FakeTimeProvider`")
    return new(Debounce)(self, delay, timeProvider)
end

---#endregion
