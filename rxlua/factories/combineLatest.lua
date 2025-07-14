---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")

local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _CombineLatestObserver

---@class CombineLatest.CombineLatestObserver<T>: Observer<T>
---@field private parent CombineLatest._CombineLatest<T>
---@field public value T
---@field public hasValue boolean
local CombineLatestObserver = Class.declare("Rxlua.CombineLatest.CombineLatestObserver", Observer)

---@param parent CombineLatest._CombineLatest<T>
function CombineLatestObserver:__init(parent)
    self.parent = parent
    self.hasValue = false
end

---@param value T
function CombineLatestObserver:onNextCore(value)
    self.value = value
    self.hasValue = true
    self.parent:tryPublishOnNext()
end

---@param error any
function CombineLatestObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

---@param result Result
function CombineLatestObserver:onCompletedCore(result)
    self.parent:tryPublishOnCompleted(result, not self.hasValue)
end

-- #endregion

-- #region _CombineLatest

---@class CombineLatest._CombineLatest<T>: IDisposable
---@field public observer Observer<T[]>
---@field private sources Observable<T>[]
---@field private observers CombineLatest.CombineLatestObserver<T>[]
---@field private hasValueAll boolean
---@field private completedCount integer
local _CombineLatest = Class.declare("Rxlua.CombineLatest._CombineLatest")

---@param observer Observer<T[]>
---@param sources Observable<T>[]
function _CombineLatest:__init(observer, sources)
    self.observer = observer
    self.sources = sources
    self.observers = {}
    if #sources == 0 then
        return
    end
    for _ in ipairs(sources) do
        table.insert(self.observers, new(CombineLatestObserver)(self))
    end
    self.hasValueAll = false
    self.completedCount = 0
end

do
    ---@param self CombineLatest._CombineLatest
    local function tryRun(self)
        for i, source in ipairs(self.sources) do
            source:subscribe(self.observers[i])
        end
    end

    function _CombineLatest:run()
        if #self.observers == 0 then
            self.observer:onCompleted()
            return require("rxlua.factories.empty")()
        end

        local success = pcall(tryRun, self)
        if not success then
            self:dispose()
            error()
        end
        return self
    end
end


function _CombineLatest:tryPublishOnNext()
    if not self.hasValueAll then
        for _, obs in ipairs(self.observers) do
            if not obs.hasValue then
                return
            end
        end
        self.hasValueAll = true
    end

    local values = {}
    for _, obs in ipairs(self.observers) do
        table.insert(values, obs.value)
    end
    self.observer:onNext(values)
end

---@param result Result
---@param isEmpty boolean
function _CombineLatest:tryPublishOnCompleted(result, isEmpty)
    if result:isFailure() then
        self.observer:onCompleted(result)
        self:dispose()
    else
        self.completedCount = self.completedCount + 1
        if isEmpty or self.completedCount == #self.sources then
            self.observer:onCompleted()
            self:dispose()
        end
    end
end

function _CombineLatest:dispose()
    for _, obs in ipairs(self.observers) do
        obs:dispose()
    end
end

-- #endregion

-- #region CombineLatestObservable

---@class CombineLatest<T>: Observable<T[]>
---@field private sources Observable<T>[]
local CombineLatestObservable = Class.declare("Rxlua.CombineLatest", Observable)

---@param sources Observable<T>[]
function CombineLatestObservable:__init(sources)
    self.sources = sources
end

function CombineLatestObservable:subscribeCore(observer)
    local combineLatestState = new(_CombineLatest)(observer, self.sources)
    return combineLatestState:run()
end

-- #endregion

---当任何一个源`Observable`发出一个值时, 将所有源的最新值组合成一个数组发出.
---@generic T
---@param ... Observable<T>
---@return Observable<T[]>
---@export namespace
local function combineLatest(...)
    local sources = { ... }
    return new(CombineLatestObservable)(sources)
end

return combineLatest
