---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local empty = require("rxlua.factories.empty")
local new = Class.new

---#region TakeObserver

---@class TakeObserver<T>: Observer<T>
---@field private observer Observer<T>
---@field private remaining integer
local TakeObserver = Class.declare('Rxlua.TakeObserver', Observer)

---@param observer Observer<T>
---@param count integer
function TakeObserver:__init(observer, count)
    self.observer = observer
    self.remaining = count
end

---@generic T
---@param value T
function TakeObserver:onNextCore(value)
    if self.remaining > 0 then
        self.remaining = self.remaining - 1
        self.observer:onNext(value)
        if self.remaining == 0 then
            self.observer:onCompleted()
        end
    end
end

---@param error any
function TakeObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function TakeObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion TakeObserver


---#region Take

---@class Take<T>: Observable<T>
---@field private source Observable<T>
---@field private count integer
local Take = Class.declare('Rxlua.Take', Observable)

---@param source Observable<T>
---@param count integer
function Take:__init(source, count)
    self.source = source
    self.count = count
end

---@param observer Observer<T>
---@return IDisposable
function Take:subscribeCore(observer)
    local takeObserver = new(TakeObserver)(observer, self.count)
    return self.source:subscribe(takeObserver)
end

---#endregion

---#region 导出到 Observable

---从源序列中获取指定数量的元素
---@param count integer 要获取的元素数量, 必须大于等于0
---@return Observable<T>
function Observable:take(count)
    if count < 0 then
        error("count 必须大于等于 0", 2)
    end

    if count == 0 then
        return empty()
    end

    return new(Take)(self, count)
end

---#endregion
