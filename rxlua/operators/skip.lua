---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new


---@class SkipObserver<T>: Observer<T>
---@field private observer Observer<T>
---@field private remaining integer
local SkipObserver = Class.declare('Rxlua.SkipObserver', Observer)

---@param observer Observer<T>
---@param count integer
function SkipObserver:__init(observer, count)
    self.observer = observer
    self.remaining = count
end

---@generic T
---@param value T
function SkipObserver:onNextCore(value)
    if self.remaining > 0 then
        self.remaining = self.remaining - 1
    else
        self.observer:onNext(value)
    end
end

---@param error any
function SkipObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function SkipObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---@class Skip<T>: Observable<T>
---@field private source Observable<T>
---@field private count integer
local Skip = Class.declare('Rxlua.Skip', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param count integer
function Skip:__init(source, count)
    self.source = source
    self.count = count
end

---@param observer Observer<T>
---@return IDisposable
function Skip:subscribeCore(observer)
    local skipObserver = new(SkipObserver)(observer, self.count)
    return self.source:subscribe(skipObserver)
end

---#region 导出到 Observable

---跳过源序列中指定数量的元素
---@param count integer 要跳过的元素数量, 必须大于等于0
---@return Observable<T>
function Observable:skip(count)
    if count < 0 then
        error("count 必须大于等于 0", 2)
    end

    return new(Skip)(self, count)
end

---#endregion
