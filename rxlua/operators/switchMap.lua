---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local SerialDisposable = require("rxlua.internal.serialDisposable")
local Class = require("luakit.class")
local new = Class.new

-- #region _SwitchMapInnerObserver
---@class SwitchMap._SwitchMapInnerObserver<R>: Observer<R>
---@field private parent SwitchMap._SwitchMap<any, R>
---@field private id integer
local SwitchMapInnerObserver = Class.declare("Rxlua.SwitchMap._SwitchMapInnerObserver", Observer)

function SwitchMapInnerObserver:__init(parent, id)
    self.parent = parent
    self.id = id
end

function SwitchMapInnerObserver:onNextCore(value)
    if self.parent.id == self.id then
        self.parent.observer:onNext(value)
    end
end

function SwitchMapInnerObserver:onErrorResumeCore(error)
    if self.parent.id == self.id then
        self.parent.observer:onErrorResume(error)
    end
end

function SwitchMapInnerObserver:onCompletedCore(result)
    if self.parent.id == self.id then
        self.parent.isInnerCompleted = true
        if self.parent.isOuterCompleted then
            self.parent.observer:onCompleted(result)
        end
    end
end

-- #endregion

-- #region _SwitchMap
---@class SwitchMap._SwitchMap<T, R>: Observer<T>
---@field public observer Observer<R>
---@field private project fun(value: T): Observable<R>
---@field public id integer
---@field private innerSubscription SerialDisposable
---@field public isOuterCompleted boolean
---@field public isInnerCompleted boolean
local _SwitchMap = Class.declare("Rxlua.SwitchMap._SwitchMap", Observer)

function _SwitchMap:__init(observer, project)
    self.observer = observer
    self.project = project
    self.id = 0
    self.innerSubscription = new(SerialDisposable)()
    self.isOuterCompleted = false
    self.isInnerCompleted = true
end

function _SwitchMap:onNextCore(value)
    self.id = self.id + 1
    local innerId = self.id
    self.isInnerCompleted = false

    local success, innerObservable = pcall(self.project, value)
    if not success then
        self.observer:onErrorResume(innerObservable)
        return
    end

    local innerObserver = new(SwitchMapInnerObserver)(self, innerId)
    self.innerSubscription:setDisposable(innerObservable:subscribe(innerObserver))
end

function _SwitchMap:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

function _SwitchMap:onCompletedCore(result)
    self.isOuterCompleted = true
    if self.isInnerCompleted then
        self.observer:onCompleted(result)
    end
end

-- #endregion

-- #region SwitchMapObservable
---@class SwitchMap<T, R>: Observable<R>
---@field private source Observable<T>
---@field private project fun(value: T): Observable<R>
local SwitchMapObservable = Class.declare("Rxlua.SwitchMap", Observable)

function SwitchMapObservable:__init(source, project)
    self.source = source
    self.project = project
end

function SwitchMapObservable:subscribeCore(observer)
    return self.source:subscribe(new(_SwitchMap)(observer, self.project))
end

-- #endregion

---将源 Observable 发出的每个值投影到一个新的 Observable, 并仅从最近投影的 Observable 发出值.
---@generic R
---@param project fun(value: T): Observable<R> 一个将源 Observable 发出的每个值转换为 Observable 的函数.
---@return Observable<R>
function Observable:switchMap(project)
    return new(SwitchMapObservable)(self, project)
end
