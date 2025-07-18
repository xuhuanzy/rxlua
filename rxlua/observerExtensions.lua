---@class (partial) Observer<T>
local Observer = require("rxlua.observer")
local new = require("luakit.class").new

---@namespace Rxlua

--[[ 不要通过 Class.new 创建该类, 该类被特殊优化过了 ]]
---@class WrappedObserver<T>: Observer<T>
---@field private observer Observer<T>
local WrappedObserver = require("luakit.class").declare('Rxlua.WrappedObserver', Observer)

function WrappedObserver:onNextCore(value)
    self.observer:onNext(value)
end

function WrappedObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

function WrappedObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

function WrappedObserver:disposeCore()
    self.observer:disposeCore()
end

---@param observer Observer<T>
---@return WrappedObserver<T>
function WrappedObserver.new(observer)
    return new(WrappedObserver, {
        observer = observer,
        __class__ = nil
    })
end

---@return Observer<T>
function Observer:wrap()
    return WrappedObserver.new(self)
end
