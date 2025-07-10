---@namespace Rxlua

---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local emptyDisposable = require("rxlua.shared").emptyDisposable
local Class = require('luakit.class')
local empty = require('rxlua.factories.empty')
local new = Class.new

---@class Range: Observable<integer>
local Range = Class.declare('Rxlua.Range', Observable)

---@param start integer 起始值
---@param count integer 数量
---@return Range
function Range:__init(start, count)
    self.start = start
    self.count = count
    return self
end

---@param observer Observer<integer>
---@return IDisposable
function Range:subscribeCore(observer)
    for i = 0, self.count - 1 do
        observer:onNext(self.start + i)
    end
    observer:onCompleted()
    return emptyDisposable
end

---创建一个发出指定范围内连续整数的Observable
---@param start integer 起始值
---@param count integer 要发出的整数数量
---@return Observable<integer>
local function range(start, count)
    if count < 0 then
        error("count 不能为负数")
    end
    local max = start + count - 1
    if max > math.maxinteger then
        error("range 将超过最大整数值")
    end

    if count == 0 then
        return empty()
    end

    return new(Range)(start, count)
end

return range
