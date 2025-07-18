---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local SerialDisposable = require("rxlua.internal.serialDisposable")
local Class = require("luakit.class")
local new = Class.new

-- #region _SwitchMapInnerObserver
---@class SwitchMap.SwitchObserver<R>: Observer<R>
---@field private parent SwitchMap._SwitchMap<any, R>
---@field private id integer
local SwitchObserver = Class.declare("Rxlua.SwitchMap.SwitchObserver", Observer)

function SwitchObserver:__init(parent, id)
    self.parent = parent
    self.id = id
end

function SwitchObserver:onNextCore(value)
    if self.parent.id == self.id then -- 如未匹配, 则已开始订阅新的内部内容
        self.parent.observer:onNext(value)
    end
end

function SwitchObserver:onErrorResumeCore(error)
    if self.parent.id == self.id then
        self.parent.observer:onErrorResume(error)
    end
end

function SwitchObserver:onCompletedCore(result)
    if self.parent.id == self.id then
        if result:isFailure() then
            self.parent.observer:onCompleted(result)
        else
            -- 若外部已停止, 则完成.
            self.parent.runningInner = false
            if self.parent.stoppedOuter then
                self.parent.observer:onCompleted(result)
            end
        end
    end
end

-- #endregion

-- #region _SwitchMap
---@class SwitchMap._SwitchMap<T, R>: Observer<T>
---@field public observer Observer<R>
---@field private project fun(value: T): Observable<R>
---@field public id integer
---@field public runningInner boolean
---@field public stoppedOuter boolean
local _SwitchMap = Class.declare("Rxlua.SwitchMap._SwitchMap", Observer)

---内部运行时保持观察者在完成时不被自动释放.
_SwitchMap.autoDisposeOnCompleted = false

---@param observer Observer<R>
---@param project fun(value: T): Observable<R>
function _SwitchMap:__init(observer, project)
    self.observer = observer
    self.project = project
    self.id = 0
    self.subscription = new(SerialDisposable)()
end

function _SwitchMap:onNextCore(value)
    self.id = self.id + 1
    self.runningInner = true

    local success, innerObservable = pcall(self.project, value)
    ---@cast value nil
    if not success then
        self:dispose()
        error(innerObservable)
    end

    local observer = new(SwitchObserver)(self, self.id)
    self.subscription:setDisposable(observer) -- 在观察者之前处理
    innerObservable:subscribe(observer)
end

function _SwitchMap:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

function _SwitchMap:onCompletedCore(result)
    if result:isFailure() then
        pcall(self.observer.onCompleted, self.observer, result)
        self:dispose()
        return
    end
    self.stoppedOuter = true
    if not self.runningInner then
        pcall(self.observer.onCompleted, self.observer)
        self:dispose()
    end
end

function _SwitchMap:disposeCore()
    self.subscription:dispose()
end

-- #endregion

-- #region SwitchMapObservable
---@class SwitchMap<T, R>: Observable<R>
---@field private source Observable<T>
---@field private project fun(value: T): Observable<R>
local SwitchMapObservable = Class.declare("Rxlua.SwitchMap", {
    super = Observable,
    enableSuperChaining = true,
})

function SwitchMapObservable:__init(source, project)
    self.source = source
    self.project = project
end

function SwitchMapObservable:subscribeCore(observer)
    return self.source:subscribe(new(_SwitchMap)(observer, self.project))
end

-- #endregion

---将源 Observable 发出的值映射为内部 Observable, 并仅从最近映射的内部 Observable 发出值. <br/>
---在源每次发出时, 会动态切换内部 Observable(取消上一个订阅, 订阅新的).
---@generic R
---@param project fun(value: T): Observable<R> 一个将源 Observable 发出的每个值转换为 Observable 的函数.
---@return Observable<R>
function Observable:switchMap(project)
    return new(SwitchMapObservable)(self, project)
end
