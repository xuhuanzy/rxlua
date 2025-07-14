---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local SerialDisposable = require("rxlua.internal.serialDisposable")
local Class = require("luakit.class")
local empty = require("rxlua.factories.empty")
local new = require("luakit.class").new

-- #region _ConcatObserver

---@class Concat.ConcatObserver<T>: Observer<T>
---@field private parent Concat._Concat<T>
local ConcatObserver = Class.declare("Rxlua.Concat.ConcatObserver", Observer)

---@param parent Concat._Concat<T>
function ConcatObserver:__init(parent)
    self.parent = parent
end

---@param value T
function ConcatObserver:onNextCore(value)
    self.parent.observer:onNext(value)
end

---@param error any
function ConcatObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

do
    ---@generic T
    ---@param observer Rxlua.Observer<T>
    ---@param result Result
    local function pcall_onCompleted(observer, result)
        observer:onCompleted(result)
    end

    ---@param result Result
    function ConcatObserver:onCompletedCore(result)
        if result:isFailure() then
            -- 出现错误, 直接完成
            local success, r = pcall(pcall_onCompleted, self.parent.observer, result)
            self:dispose()
            if not success then
                error(r)
            end
        else
            -- 尝试订阅下一个
            self.parent:subscribeNext()
        end
    end
end


-- #endregion

-- #region _Concat

---@class Concat._Concat<T>: IDisposable
---@field public observer Observer<T>
---@field package sources Observable<T>[]
---@field package disposable SerialDisposable
---@field package id integer
local _Concat = Class.declare("Rxlua.Concat._Concat")

---@param observer Observer<T>
---@param sources Observable<T>[]
function _Concat:__init(observer, sources)
    self.observer = observer
    self.sources = sources
    self.disposable = new(SerialDisposable)()
    self.id = 1
end

---@return IDisposable
function _Concat:run()
    if self.id > #self.sources then
        self.observer:onCompleted()
        return empty()
    end
    self:subscribeNext()
    return self
end

function _Concat:subscribeNext()
    if self.id > #self.sources then
        self.observer:onCompleted()
        return
    end

    local source = self.sources[self.id]
    self.id = self.id + 1
    local currentId = self.id
    local disposable = source:subscribe(new(ConcatObserver)(self))
    -- 如果当前订阅的 Observable 执行完成调用了 onCompleted, 导致 subscribeNext() 被重入调用并已经开始处理下一个 Observable, 那么我们就不需要再将当前(旧的)订阅设置给 disposable 了.
    -- 因为 SerialDisposableCore 在接收新订阅时, 会自动 Dispose 掉它之前持有的旧订阅.
    if currentId == self.id then
        self.disposable:setDisposable(disposable)
    end
end

function _Concat:dispose()
    self.disposable:dispose()
end

-- #endregion

-- #region ConcatObservable

---@class Concat<T>: Observable<T>
---@field private sources Observable<T>[]
local Concat = Class.declare("Rxlua.Concat", Observable)

---@param sources Observable<T>[]
function Concat:__init(sources)
    self.sources = sources
end

function Concat:subscribeCore(observer)
    local concatState = new(_Concat)(observer, self.sources)
    return concatState:run()
end

-- #endregion

---按顺序连接多个`Observable`, 当前一个`Observable`完成后, 才会订阅下一个`Observable`.
---@generic T
---@param ... Observable<T>
---@return Observable<T>
---@export namespace
local function concat(...)
    local sources = { ... }
    if #sources == 0 then
        return empty()
    end
    return new(Concat)(sources)
end

return concat
