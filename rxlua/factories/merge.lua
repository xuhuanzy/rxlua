---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local CompositeDisposable = require("rxlua.internal.compositeDisposable")
local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _MergeObserver

---@class Merge.MergeObserver<T>: Observer<T>
---@field private parent Merge._Merge<T>
local MergeObserver = Class.declare("Rxlua.Merge.MergeObserver", Observer)

---@param parent Merge._Merge<T>
function MergeObserver:__init(parent)
    self.parent = parent
end

---@param value T
function MergeObserver:onNextCore(value)
    self.parent.observer:onNext(value)
end

---@param error any
function MergeObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

---@param result Result
function MergeObserver:onCompletedCore(result)
    if result:isFailure() then
        -- 出现错误, 直接完成
        self.parent.observer:onCompleted(result)
    else
        -- 所有源头都完成, 尝试发布完成
        self.parent:tryPublishCompleted()
    end
end

-- #endregion

-- #region _Merge

---@class Merge._Merge<T>: IDisposable
---@field public observer Observer<T>
---@field public disposable CompositeDisposable
---@field private sourceCount integer
---@field private completedCount integer 完成计数
local _Merge = Class.declare("Rxlua.Merge._Merge")

---@param observer Observer<T>
function _Merge:__init(observer)
    self.observer = observer
    self.sourceCount = -1
    self.completedCount = 0
end

---设置源数量
---@param count integer
function _Merge:setSourceCount(count)
    self.sourceCount = count
    if self.sourceCount == self.completedCount then
        self.observer:onCompleted()
        self:dispose()
    end
end

---当所有源头完成时才会视为完成
function _Merge:tryPublishCompleted()
    self.completedCount = self.completedCount + 1
    if self.completedCount == self.sourceCount then
        self.observer:onCompleted()
        self:dispose()
    end
end

function _Merge:dispose()
    self.disposable:dispose()
end

-- #endregion

-- #region MergeObservable

---@class Merge<T>: Observable<T>
---@field private sources Observable<T>[]
local Merge = Class.declare("Rxlua.Merge", Observable)

---@param sources Observable<T>[]
function Merge:__init(sources)
    self.sources = sources
end

function Merge:subscribeCore(observer)
    local mergeState = new(_Merge)(observer)
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

---将多个`Observable`合并为一个, 新的`Observable`会发出任何源`Observable`发出的值.<br/>
---当所有源`Observable`都完成时, 新的`Observable`才会完成.
---@generic T
---@param ... Observable<T>
---@return Observable<T>
---@export namespace
local function merge(...)
    local sources = { ... }
    if #sources == 0 then
        return require("rxlua.factories.empty")()
    end
    return new(Merge)(sources)
end

return merge
