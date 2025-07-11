local Class = require("luakit.class")
local Observer = require("rxlua.observer")
local getUnhandledExceptionHandler = require("rxlua.observableSystem").getUnhandledExceptionHandler
local handleResult = require("rxlua.observableSystem").handleResult
local new = require("luakit.class").new

---@export namespace
local export = {}

---@namespace Rxlua

--[[ 不要通过 Class.new 创建该类, 该类被特殊优化过了 ]]
---@class AnonymousObserver<T>: Observer<T>
---@field next fun( value: T)
---@field errorResume fun(error: any)
---@field completed fun(result: Result)
local AnonymousObserver = Class.declare('Rxlua.AnonymousObserver', Observer)

function AnonymousObserver:onNextCore(value)
    self.next(value)
end

function AnonymousObserver:onErrorResumeCore(error)
    self.errorResume(error)
end

function AnonymousObserver:onCompletedCore(result)
    self.completed(result)
end

---@generic T
---@param next fun( value: T)
---@param errorResume? fun(error: any)
---@param completed? fun(result: Result)
---@return AnonymousObserver<T>
local function createAnonymousObserver(next, errorResume, completed)
    return new(AnonymousObserver, {
        next = next,
        errorResume = errorResume or getUnhandledExceptionHandler(),
        completed = completed or handleResult,
        __class__ = nil
    })
end

export.createAnonymousObserver = createAnonymousObserver
return export
