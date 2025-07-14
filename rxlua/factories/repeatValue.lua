---@namespace Rxlua

local Observable = require("rxlua.observable")
local emptyDisposable = require("rxlua.shared").emptyDisposable
local Class = require('luakit.class')
local empty = require('rxlua.factories.empty')
local new = Class.new

---@class RepeatValue<T>: Observable<T>
local RepeatValue = Class.declare('Rxlua.RepeatValue', Observable)

---@param value T
---@param count integer
function RepeatValue:__init(value, count)
    self.value = value
    self.count = count
end

---@param observer Observer<T>
---@return IDisposable
function RepeatValue:subscribeCore(observer)
    for i = 1, self.count do
        observer:onNext(self.value)
    end
    observer:onCompleted()
    return emptyDisposable
end

---创建一个发出重复值的 Observable
---@generic T
---@param value T 要重复发出的值
---@param count integer 重复次数
---@return Observable<T>
local function repeatValue(value, count)
    if count < 0 then
        error("count 不能为负数")
    end
    if count == 0 then
        return empty()
    end
    return new(RepeatValue)(value, count)
end

return repeatValue