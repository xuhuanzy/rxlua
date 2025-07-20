local Class = require("luakit.class")
local Observer = require("rxlua.observer")
local ObservableSystem = require("rxlua.observableSystem")
local NOOP = require("luakit.general").NOOP
local getUnhandledExceptionHandler = require("rxlua.observableSystem").getUnhandledExceptionHandler
local new = require("luakit.class").new

---@namespace Rxlua


---@export namespace
local export = {}

---@param result Result
local function handleResult(result)
    if result:isFailure() then ---@cast result.exception -?
        ObservableSystem.getUnhandledExceptionHandler()(result.exception)
    end
end

---#region AnonymousObserver

--[[ 不要通过 Class.new 创建该类, 该类被特殊优化过了 ]]
---@class AnonymousObserver<T, TState>: Observer<T>
---@field next fun(value: T, state?: TState)
---@field errorResume fun(error: any, state?: TState)
---@field completed fun(result: Result, state?: TState)
---@field state? TState 初始化时传入的值.
local AnonymousObserver = Class.declare('Rxlua.AnonymousObserver', Observer)

function AnonymousObserver:onNextCore(value)
    self.next(value, self.state)
end

function AnonymousObserver:onErrorResumeCore(error)
    self.errorResume(error, self.state)
end

function AnonymousObserver:onCompletedCore(result)
    self.completed(result, self.state)
end

---@generic T, TState
---@param next? fun( value: T)
---@param errorResume? fun(error: any)
---@param completed? fun(result: Result)
---@param state? TState
---@return AnonymousObserver<T, TState>
local function createAnonymousObserver(next, errorResume, completed, state)
    return new(AnonymousObserver, {
        next = next or NOOP,
        errorResume = errorResume or getUnhandledExceptionHandler(),
        completed = completed or handleResult,
        state = state,
        __class__ = nil
    })
end
export.createAnonymousObserver = createAnonymousObserver

---#endregion

return export
