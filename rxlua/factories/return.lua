---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Class = require("luakit.class")
local emptyDisposable = require("rxlua.shared").emptyDisposable
local new = require("luakit.class").new
local getDefaultTimeProvider = require("rxlua.internal.timeProvider").getDefaultTimeProvider

---#region ImmediateScheduleReturn

---@class ImmediateScheduleReturn<T>: Observable<T>
---@field private value T
local ImmediateScheduleReturn = Class.declare('Rxlua.ImmediateScheduleReturn', {
    super = Observable,
    enableSuperChaining = true,
})

---@param value T
---@return ImmediateScheduleReturn<T>
function ImmediateScheduleReturn.new(value)
    return setmetatable({ value = value }, ImmediateScheduleReturn)
end

---@param observer Observer<T>
---@return IDisposable
function ImmediateScheduleReturn:subscribeCore(observer)
    observer:onNext(self.value)
    observer:onCompleted()
    return emptyDisposable
end

---#endregion

---#region ReturnUnit 返回一个空白的 Observable.

---@class ReturnUnit<T>: Observable<T>
---@field private value T
local ReturnUnit = Class.declare('Rxlua.ReturnUnit', {
    super = Observable,
    enableSuperChaining = true,
})
ReturnUnit.Instance = setmetatable({}, ReturnUnit)

---@param observer Observer<T>
---@return IDisposable
function ReturnUnit:subscribeCore(observer)
    observer:onNext(nil)
    observer:onCompleted()
    return emptyDisposable
end

---返回一个表示无值的单例 Observable. 用于返回`Observer`而不需要返回数据.
---@return ReturnUnit<nil>
local function returnUnit()
    ---@diagnostic disable-next-line: return-type-mismatch
    return ReturnUnit.Instance
end

---#endregion




---#region _Return

---@param self Return._Return
local function nextTick(self)
    self.observer:onNext(self.value)
    self.observer:onCompleted()
end

---@class Return._Return<T>: IDisposable
---@field package observer Observer<T>
---@field package value T
---@field package timer ITimer?
local _Return = Class.declare("Rxlua.Return._Return")

---@generic T
---@param value T
---@param observer Observer<T>
function _Return:__init(value, observer)
    self.value = value
    self.observer = observer
end

function _Return:completeDispose()
    self.observer:onCompleted()
    self:dispose()
end

function _Return:dispose()
    if self.timer then
        self.timer:dispose()
        self.timer = nil
    end
end

---#endregion

---@class Return<T>: Observable<T>
---@field private value T
---@field private dueTime number
---@field private timeProvider TimeProvider
local Return = Class.declare("Rxlua.Return", {
    super = Observable,
    enableSuperChaining = true,
})

---@param value T
---@param dueTime number
---@param timeProvider TimeProvider
function Return:__init(value, dueTime, timeProvider)
    self.value = value
    self.dueTime = dueTime
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function Return:subscribeCore(observer)
    local state = new(_Return)(self.value, observer)
    state.timer = self.timeProvider:createTimer(nextTick, state, -1, -1)
    state.timer:change(self.dueTime, -1)
    return state
end

---#endregion

---创建一个 Observable, 在指定时间后发出值, 如果时间小于等于 0, 则立即发出值.
---@generic T
---@param value T 值.
---@param dueTime? number 延迟时间. 默认为`0`, 即立即发出值.
---@param timeProvider? TimeProvider 时间提供者.
---@return Observable<T>
local function returnValue(value, dueTime, timeProvider)
    if dueTime and dueTime > 0 then
        return new(Return)(value, dueTime, timeProvider or getDefaultTimeProvider())
    else
        return ImmediateScheduleReturn.new(value)
    end
end

return {
    returnValue = returnValue,
    returnUnit = returnUnit,
}
