---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region TakeWhileObserver

---@class TakeWhileObserver<T>: Observer<T>
---@field private observer Observer<T>
---@field private predicate fun(value: T, index?: integer): boolean
---@field private index integer
local TakeWhileObserver = Class.declare('Rxlua.TakeWhileObserver', Observer)

function TakeWhileObserver:__init(observer, predicate)
    self.observer = observer
    self.predicate = predicate
    self.index = 1
end

function TakeWhileObserver:onNextCore(value)
    if self.predicate(value, self.index) then
        self.index = self.index + 1
        self.observer:onNext(value)
    else
        self.observer:onCompleted()
    end
end

function TakeWhileObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

function TakeWhileObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region TakeWhile

---@class TakeWhile<T>: Observable<T>
---@field private source Observable<T>
---@field private predicate fun(value: T, index?: integer): boolean
local TakeWhile = Class.declare('Rxlua.TakeWhile', {
    super = Observable,
    enableSuperChaining = true,
})

function TakeWhile:__init(source, predicate)
    self.source = source
    self.predicate = predicate
end

function TakeWhile:subscribeCore(observer)
    local takeWhileObserver = new(TakeWhileObserver)(observer, self.predicate)
    return self.source:subscribe(takeWhileObserver)
end

---#endregion

---#region 导出到 Observable

---根据断言函数从源序列的开头获取元素, 直到断言不成立.
---@param predicate fun(value: T, index?: integer): boolean 一个函数, 用于测试每个源元素是否满足条件, 第二个参数是源序列中元素的从1开始的索引.
---@return Observable<T>
function Observable:takeWhile(predicate)
    return new(TakeWhile)(self, predicate)
end

---#endregion
