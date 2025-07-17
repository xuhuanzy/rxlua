---@namespace Rxlua
---@using Luakit

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Queue = require("luakit.queue")
local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _ZipObserver

---@class Zip.ZipObserver<T>: Observer<T>
---@field private parent Zip._Zip<T>
---@field public values Queue<T>
---@field public isCompleted boolean
local ZipObserver = Class.declare("Rxlua.Zip.ZipObserver", Observer)

---@param parent Zip._Zip<T>
function ZipObserver:__init(parent)
    self.parent = parent
    self.values = Queue.new()
    self.isCompleted = false
end

---@return boolean hasValue 是否存在值
---@return boolean shouldComplete 应完成
function ZipObserver:hasValue()
    local count = self.values:size()
    return count ~= 0, self.isCompleted and count == 1
end

---@param value T
function ZipObserver:onNextCore(value)
    self.values:enqueue(value)
    self.parent:tryPublishOnNext()
end

---@param error any
function ZipObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

---@param result Result
function ZipObserver:onCompletedCore(result)
    self.isCompleted = true
    self.parent:tryPublishOnCompleted(result, self.values:isEmpty())
end

-- #endregion

-- #region _Zip

---@class Zip._Zip<T>: IDisposable
---@field public observer Observer<T[]>
---@field package sources Observable<T>[]
---@field package observers Zip.ZipObserver<T>[]
local _Zip = Class.declare("Rxlua.Zip._Zip")

---@param observer Observer<T[]>
---@param sources Observable<T>[]
function _Zip:__init(observer, sources)
    self.observer = observer
    self.sources = sources
    self.observers = {}
    for _ in ipairs(sources) do
        table.insert(self.observers, new(ZipObserver)(self))
    end
end

do
    ---@param self Zip._Zip
    local function tryRun(self)
        for i, source in ipairs(self.sources) do
            source:subscribe(self.observers[i])
        end
    end

    function _Zip:run()
        local success = pcall(tryRun, self)
        if not success then
            self:dispose()
            error()
        end
        return self
    end
end

function _Zip:tryPublishOnNext()
    local requireCallOnCompleted = false
    for _, obs in ipairs(self.observers) do
        local hasValue, shouldComplete = obs:hasValue()
        if not hasValue then
            return
        end
        if shouldComplete then
            requireCallOnCompleted = true
        end
    end

    local values = {}
    for _, obs in ipairs(self.observers) do
        table.insert(values, obs.values:dequeue())
    end
    self.observer:onNext(values)

    if requireCallOnCompleted then
        self.observer:onCompleted()
        self:dispose()
    end
end

---@param result Result
---@param isEmpty boolean
function _Zip:tryPublishOnCompleted(result, isEmpty)
    if result:isFailure() then
        self.observer:onCompleted(result)
        self:dispose()
    else
        local allCompleted = true
        for _, item in ipairs(self.observers) do
            if not item.isCompleted then
                allCompleted = false
                break
            end
        end
        if isEmpty or allCompleted then
            self.observer:onCompleted()
            self:dispose()
        end
    end
end

function _Zip:dispose()
    for i = 1, #self.observers do
        self.observers[i]:dispose()
    end
end

-- #endregion

-- #region ZipObservable

---@class Zip<T>: Observable<T[]>
---@field private sources Observable<T>[]
local ZipObservable = Class.declare("Rxlua.Zip", Observable)

---@param sources Observable<T>[]
function ZipObservable:__init(sources)
    self.sources = sources
end

function ZipObservable:subscribeCore(observer)
    local zipState = new(_Zip)(observer, self.sources)
    return zipState:run()
end

-- #endregion

---将多个`Observable`的值按顺序组合成数组, 只有当所有源都发出一个新值时, 才会发出组合值.
---@param ... Observable<any>
---@return Observable<any[]>
---@export namespace
local function zip(...)
    local sources = { ... }
    if #sources == 0 then
        return require("rxlua.factories.empty")()
    end
    return new(ZipObservable)(sources)
end

return zip
