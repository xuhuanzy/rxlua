---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _ZipLatestObserver

---@class ZipLatest.ZipLatestObserver<T>: Observer<T>
---@field private parent ZipLatest._ZipLatest<T>
---@field public value T
---@field public hasValue boolean
---@field public isCompleted boolean
local ZipLatestObserver = Class.declare("Rxlua.ZipLatest.ZipLatestObserver", Observer)

---@param parent ZipLatest._ZipLatest<T>
function ZipLatestObserver:__init(parent)
    self.parent = parent
    self.hasValue = false
    self.isCompleted = false
end

---消费当前值
---@return T 
function ZipLatestObserver:getValue()
    local v = self.value
    self.value = nil
    self.hasValue = false
    return v
end

---@param value T
function ZipLatestObserver:onNextCore(value)
    self.value = value
    self.hasValue = true
    self.parent:tryPublishOnNext()
end

---@param error any
function ZipLatestObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

---@param result Result
function ZipLatestObserver:onCompletedCore(result)
    self.isCompleted = true
    self.parent:tryPublishOnCompleted(result, not self.hasValue)
end

-- #endregion

-- #region _ZipLatest

---@class ZipLatest._ZipLatest<T>: IDisposable
---@field public observer Observer<T[]>
---@field private sources Observable<T>[]
---@field private observers ZipLatest.ZipLatestObserver<T>[]
local _ZipLatest = Class.declare("Rxlua.ZipLatest._ZipLatest")

---@param observer Observer<T[]>
---@param sources Observable<T>[]
function _ZipLatest:__init(observer, sources)
    self.observer = observer
    self.sources = sources
    self.observers = {}
    for _ in ipairs(sources) do
        table.insert(self.observers, new(ZipLatestObserver)(self))
    end
end

do
    ---@param self ZipLatest._ZipLatest
    local function tryRun(self)
        for i, source in ipairs(self.sources) do
            source:subscribe(self.observers[i])
        end
    end

    function _ZipLatest:run()
        if #self.sources == 0 then
            self.observer:onCompleted()
            return self
        end
        local success, err = pcall(tryRun, self)
        if not success then
            self:dispose()
            error(err)
        end
        return self
    end
end

function _ZipLatest:tryPublishOnNext()
    local hasCompletedObserver = false
    for _, obs in ipairs(self.observers) do
        if not obs.hasValue then
            return
        end
        if obs.isCompleted then
            hasCompletedObserver = true
        end
    end

    local values = {}
    for _, obs in ipairs(self.observers) do
        table.insert(values, obs:getValue())
    end
    self.observer:onNext(values)

    if hasCompletedObserver then
        self.observer:onCompleted()
        self:dispose()
    end
end

---@param result Result
---@param isEmpty boolean
function _ZipLatest:tryPublishOnCompleted(result, isEmpty)
    if result:isFailure() then
        self.observer:onCompleted(result)
        self:dispose()
        return
    end

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

function _ZipLatest:dispose()
    for _, obs in ipairs(self.observers) do
        obs:dispose()
    end
end

-- #endregion

-- #region ZipLatestObservable

---@class ZipLatest<T>: Observable<T[]>
---@field private sources Observable<T>[]
local ZipLatestObservable = Class.declare("Rxlua.ZipLatest", Observable)

---@param sources Observable<T>[]
function ZipLatestObservable:__init(sources)
    self.sources = sources
end

function ZipLatestObservable:subscribeCore(observer)
    local zipLatestState = new(_ZipLatest)(observer, self.sources)
    return zipLatestState:run()
end

-- #endregion

---类似`Zip`, 但它只关心每个源的最新值, 所有旧值都会被丢弃. </br>
---完成信号的发出时机:
---1. 任意源发出完成信号时, 如果该源已不存在值, 则`zipLatest`会发出完成信号.
---2. 所有源都发出完成信号.
---@generic T
---@param ... Observable<T>
---@return Observable<T[]>
---@export namespace
local function zipLatest(...)
    local sources = { ... }
    return new(ZipLatestObservable)(sources)
end

return zipLatest
