---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require('luakit.class')
local new = Class.new

---#region WhereObserver

---@class WhereObserver<T>: Observer<T>
---@field private observer Observer<T>
---@field private index integer 索引, 下标从1开始
local WhereObserver = Class.declare('Rxlua.WhereObserver', Observer)

---@param observer Observer<T>
---@param predicate fun(value: T, index?: integer): boolean
function WhereObserver:__init(observer, predicate)
    self.observer = observer
    self.predicate = predicate
    self.index = 1
end

---@param value T
function WhereObserver:onNextCore(value)
    local success = self.predicate(value, self.index)
    self.index = self.index + 1
    if success then
        self.observer:onNext(value)
    end
end

---@param error any
function WhereObserver:onErrorResumeCore(error)
    self.observer:onErrorResume(error)
end

---@param result Result
function WhereObserver:onCompletedCore(result)
    self.observer:onCompleted(result)
end

---#endregion

---#region Where

---@class Where<T>: Observable<T>
---@field source Observable<T>
local Where = Class.declare('Rxlua.Where', {
    super = Observable,
    enableSuperChaining = true,
})

---@param source Observable<T>
---@param predicate fun(value: T, index?: integer): boolean
function Where:__init(source, predicate)
    self.source = source
    self.predicate = predicate
end

---@param observer Observer<T>
---@return IDisposable
function Where:subscribeCore(observer)
    local whereObserver = new(WhereObserver)(observer, self.predicate)
    -- 源订阅 where 的观察者
    return self.source:subscribe(whereObserver)
end

---#endregion

---#region 导出到 Observable

---根据断言函数过滤源序列中的元素
---@param predicate fun(value: T, index?: integer): boolean 用于测试每个源元素是否满足条件(可选接收索引, 从1开始)
---@return Observable<T>
function Observable:where(predicate)
    -- 优化 where.where
    if getmetatable(self) == Where then
        ---@cast self Where<T>
        local p = self.predicate
        -- 使用的是源序列的 source, 即获取最初的 Observable 对象而不是被 .where 包装后的对象.
        return new(Where)(self.source, function(value, index)
            return p(value, index) and predicate(value, index)
        end)
    end
    return new(Where)(self, predicate)
end

---#endregion
