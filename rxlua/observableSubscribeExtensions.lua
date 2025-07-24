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
---@field private [1] fun(value: T, state?: TState) # [next]
---@field private [2] fun(error: any, state?: TState) # [errorResume]
---@field private [3] fun(result: Result, state?: TState) # [completed]
---@field private [4]? TState # [state] 初始化时传入的值.
local AnonymousObserver = Class.declare('Rxlua.AnonymousObserver', Observer)

function AnonymousObserver:onNextCore(value)
    self[1](value, self[4])
end

function AnonymousObserver:onErrorResumeCore(error)
    self[2](error, self[4])
end

function AnonymousObserver:onCompletedCore(result)
    self[3](result, self[4])
end

---@generic T, TState
---@param next? fun( value: T)
---@param errorResume? fun(error: any)
---@param completed? fun(result: Result)
---@param state? TState
---@return AnonymousObserver<T, TState>
local function createAnonymousObserver(next, errorResume, completed, state)
    return new(AnonymousObserver, {
        [1] = next or NOOP,
        [2] = errorResume or getUnhandledExceptionHandler(),
        [3] = completed or handleResult,
        [4] = state,
        __class__ = nil
    })
end
export.createAnonymousObserver = createAnonymousObserver

---#endregion

return export
