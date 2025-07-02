local Class = require("luakit.class")
local Observer = require("rxlua.observer")
local ObservableSystem = require("rxlua.observableSystem")
local new = require("luakit.class").new

---@export namespace
local export = {}

---@namespace Rxlua

---@class AnonymousObserver<T>: Observer<T>
local AnonymousObserver = Class.declare('Rxlua.AnonymousObserver', Observer)

---@param next fun( value: T)
---@param errorResume fun(error: any)
---@param completed fun(result: Result)
function AnonymousObserver:__init(next, errorResume, completed)
    self.next = next
    self.errorResume = errorResume
    self.completed = completed
end

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
    return new(AnonymousObserver)(next, errorResume or ObservableSystem.getUnhandledExceptionHandler(),
        completed or ObservableSystem.handleResult)
end



export.createAnonymousObserver = createAnonymousObserver
return export
