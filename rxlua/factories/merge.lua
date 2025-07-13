---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local CompositeDisposable = require("rxlua.internal.compositeDisposable")
local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _MergeObserver

---@class _MergeObserver<T>: Observer<T>
---@field private parent _Merge<T>
local MergeObserver = Class.declare("Rxlua._MergeObserver", Observer)

function MergeObserver:__init(parent)
    self.parent = parent
end

function MergeObserver:onNextCore(value)
    self.parent.observer:onNext(value)
end

function MergeObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

function MergeObserver:onCompletedCore(result)
    if result:isFailure() then
        self.parent.observer:onCompleted(result)
    else
        self.parent:tryPublishCompleted()
    end
end

-- #endregion

-- #region _Merge

---@class _Merge<T>: IDisposable
---@field public observer Observer<T>
---@field public disposable IDisposable
---@field private sourceCount integer
---@field private completedCount integer
local Merge = Class.declare("Rxlua._Merge")

function Merge:__init(observer)
    self.observer = observer
    self.sourceCount = -1
    self.completedCount = 0
end

function Merge:setSourceCount(count)
    self.sourceCount = count
    if self.sourceCount == self.completedCount then
        self.observer:onCompleted()
        self:dispose()
    end
end

function Merge:tryPublishCompleted()
    self.completedCount = self.completedCount + 1
    if self.completedCount == self.sourceCount then
        self.observer:onCompleted()
        self:dispose()
    end
end

function Merge:dispose()
    if self.disposable then
        self.disposable:dispose()
    end
end

-- #endregion

-- #region MergeObservable

---@class MergeObservable<T>: Observable<T>
---@field private sources Observable<T>[]
local MergeObservable = Class.declare("Rxlua.MergeObservable", Observable)

function MergeObservable:__init(sources)
    self.sources = sources
end

function MergeObservable:subscribeCore(observer)
    local mergeState = new(Merge)(observer)
    local compositeDisposable = new(CompositeDisposable)()

    local count = 0
    for _, item in ipairs(self.sources) do
        compositeDisposable:add(item:subscribe(new(MergeObserver)(mergeState)))
        count = count + 1
    end

    mergeState.disposable = compositeDisposable
    mergeState:setSourceCount(count)

    return mergeState
end

-- #endregion

---@export namespace
---将多个Observable合并为一个, 新的Observable会发出任何源Observable发出的值.
---当所有源Observable都完成时, 新的Observable才会完成.
---@generic T
---@param ... Observable<T> 要合并的Observable
---@return Observable<T>
local function merge(...)
    local sources = { ... }
    if #sources == 0 then
        local empty = require("rxlua.factories.empty")
        return empty()
    end
    return new(MergeObservable)(sources)
end

return merge
