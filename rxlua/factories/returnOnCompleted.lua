---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Class = require("luakit.class")
local emptyDisposable = require("rxlua.shared").emptyDisposable
local new = require("luakit.class").new
local getDefaultTimeProvider = require("rxlua.internal.timeProvider").getDefaultTimeProvider
local Result = require("rxlua.internal.result")

---#region ImmediateScheduleReturnOnCompleted

---@class ImmediateScheduleReturnOnCompleted<T>: Observable<T>
---@field private result Result
local ImmediateScheduleReturnOnCompleted = Class.declare('Rxlua.ImmediateScheduleReturnOnCompleted', {
    super = Observable,
    enableSuperChaining = true,
})

---@param result Result
---@return ImmediateScheduleReturnOnCompleted<T>
function ImmediateScheduleReturnOnCompleted.new(result)
    return setmetatable({ result = result }, ImmediateScheduleReturnOnCompleted)
end

---@param observer Observer<T>
---@return IDisposable
function ImmediateScheduleReturnOnCompleted:subscribeCore(observer)
    observer:onCompleted(self.result)
    return emptyDisposable
end

---#endregion

---#region ImmediateScheduleReturnOnCompletedSuccess

---@class ImmediateScheduleReturnOnCompletedSuccess<T>: Observable<T>
local ImmediateScheduleReturnOnCompletedSuccess = Class.declare(
    'Rxlua.ImmediateScheduleReturnOnCompletedSuccess',
    {
        super = Observable,
        enableSuperChaining = true,
    }
)
---@diagnostic disable-next-line: assign-type-mismatch
---@type ImmediateScheduleReturnOnCompletedSuccess<T>
ImmediateScheduleReturnOnCompletedSuccess.Instance = setmetatable({}, ImmediateScheduleReturnOnCompletedSuccess)

---@param observer Observer<T>
---@return IDisposable
function ImmediateScheduleReturnOnCompletedSuccess:subscribeCore(observer)
    observer:onCompleted(Result.success())
    return emptyDisposable
end

---#endregion

---#region _ReturnOnCompleted

---@param self ReturnOnCompleted._ReturnOnCompleted
local function nextTick(self)
    pcall(function()
        self.observer:onCompleted(self.result)
    end)
    self:dispose()
end

---@class ReturnOnCompleted._ReturnOnCompleted<T>: IDisposable
---@field package observer Observer<T>
---@field package result Result
---@field package timer ITimer?
local _ReturnOnCompleted = Class.declare("Rxlua.ReturnOnCompleted._ReturnOnCompleted")

---@generic T
---@param result Result
---@param observer Observer<T>
function _ReturnOnCompleted:__init(result, observer)
    self.result = result
    self.observer = observer
end

function _ReturnOnCompleted:dispose()
    if self.timer then
        self.timer:dispose()
        self.timer = nil
    end
end

---#endregion

---@class ReturnOnCompleted<T>: Observable<T>
---@field private result Result
---@field private dueTime number
---@field private timeProvider TimeProvider
local ReturnOnCompleted = Class.declare("Rxlua.ReturnOnCompleted", {
    super = Observable,
    enableSuperChaining = true,
})

---@param result Result
---@param dueTime number
---@param timeProvider TimeProvider
function ReturnOnCompleted:__init(result, dueTime, timeProvider)
    self.result = result
    self.dueTime = dueTime
    self.timeProvider = timeProvider
end

---@param observer Observer<T>
---@return IDisposable
function ReturnOnCompleted:subscribeCore(observer)
    local state = new(_ReturnOnCompleted)(self.result, observer)
    state.timer = self.timeProvider:createTimer(nextTick, state, -1, -1)
    state.timer:change(self.dueTime, -1)
    return state
end

---#endregion

---创建一个 Observable, 在指定时间后完成, 如果时间小于等于 0, 则立即完成.
---@generic T
---@param result Result 完成时的结果.
---@param dueTime? number 延迟时间. 默认为`0`, 即立即完成.
---@param timeProvider? TimeProvider 时间提供者.
---@return Observable<T>
local function returnOnCompleted(result, dueTime, timeProvider)
    if dueTime and dueTime > 0 then
        return new(ReturnOnCompleted)(result, dueTime, timeProvider or getDefaultTimeProvider())
    else
        if result:isSuccess() then
            return ImmediateScheduleReturnOnCompletedSuccess.Instance
        else
            return ImmediateScheduleReturnOnCompleted.new(result)
        end
    end
end

return returnOnCompleted
