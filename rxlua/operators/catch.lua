---@namespace Rxlua
---@using Luakit

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

-- #region SecondObserver

---@class Catch.SecondObserver<T>: Observer<T>
local SecondObserver = Class.declare('Rxlua.Catch.SecondObserver', Observer)

---@param parent Catch._Catch<T>
function SecondObserver:__init(parent)
    self.parent = parent
end

function SecondObserver:onNextCore(value)
    self.parent.observer:onNext(value)
end

function SecondObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

function SecondObserver:onCompletedCore(result)
    self.parent.observer:onCompleted(result)
end

function SecondObserver:disposeCore()
    self.parent:dispose()
end

-- #endregion

-- #region FirstObserver

---@class Catch.FirstObserver<T>: Observer<T>
local FirstObserver = Class.declare('Rxlua.Catch.FirstObserver', Observer)

---@param parent Catch._Catch<T>
function FirstObserver:__init(parent)
    self.parent = parent
end

function FirstObserver:onNextCore(value)
    self.parent.observer:onNext(value)
end

function FirstObserver:onErrorResumeCore(error)
    self.parent.observer:onErrorResume(error)
end

function FirstObserver:onCompletedCore(result)
    if result:isFailure() then
        local error = result.exception
        local observer = new(SecondObserver, self.parent)
        if type(self.parent.errorHandler) == 'function' and error ~= nil then
            self.parent.secondSubscription = self.parent.errorHandler(error):subscribe(observer)
        else
            self.parent.secondSubscription = self.parent.errorHandler:subscribe(observer)
        end
    else
        self.parent.observer:onCompleted(result)
    end
end

-- #endregion



-- #region _Catch

---@class Catch._Catch<T>: IDisposable
---@field firstSubscription? IDisposable
---@field secondSubscription? IDisposable
local _Catch = Class.declare('Rxlua.Catch._Catch', {
    super = Observable,
    enableSuperChaining = true,
})

---@param observer Observer<T>
---@param errorHandler (fun(error: IException): Observable<T>) | Observable<T>
function _Catch:__init(observer, errorHandler)
    self.observer = observer
    self.errorHandler = errorHandler
end

---@param source Observable<T>
---@return IDisposable
function _Catch:run(source)
    return source:subscribe(new(FirstObserver, self))
end

function _Catch:dispose()
    if self.firstSubscription then
        self.firstSubscription:dispose()
    end
    if self.secondSubscription then
        self.secondSubscription:dispose()
    end
end

-- #endregion

---@class Catch<T>: Observable<T>
local Catch = Class.declare('Rxlua.Catch', {
    super = Observable,
    enableSuperChaining = true,
})

function Catch:__init(source, errorHandler)
    self.source = source
    self.errorHandler = errorHandler
end

function Catch:subscribeCore(observer)
    return self.source:subscribe(observer)
end

---通过捕获 Observable`的错误`, 将其替换为另一个`Observable`或基于错误动态生成一个新的`Observable`来处理序列中的错误.</br>
---当源`Observable`失败时, 通过参数来决定如何切换, 当参数是`Observable`时, 直接切换, 当参数是函数时, 将错误传递给函数, 并返回一个新的`Observable`.
---@param errorHandler Observable<T> | fun(error: any): Observable<T>
---@return Observable<T>
function Observable:catch(errorHandler)
    return new(Catch)(self, errorHandler)
end
