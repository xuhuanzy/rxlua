---@namespace Rxlua

local Class = require('luakit.class')

---可丢弃对象的集合
---@class CompositeDisposable: IDisposable
---@field private disposables table<IDisposable, boolean>
---@field private isDisposed boolean 是否已释放
---@field private count integer
local CompositeDisposable = Class.declare('Rxlua.CompositeDisposable')

function CompositeDisposable:__init()
    self.disposables = {}
    self.isDisposed = false
    self.count = 0
end

---添加可丢弃对象, 如果`CompositeDisposable`已释放, 则自动释放该对象
---@param item IDisposable
function CompositeDisposable:add(item)
    if self.isDisposed then
        item:dispose()
        return
    end

    if self.disposables[item] == nil then
        self.disposables[item] = true
        self.count = self.count + 1
    end
end

---移除并释放可丢弃对象, 如果`CompositeDisposable`已释放, 则不做任何操作
---@param item IDisposable
---@return boolean # 是否成功移除
function CompositeDisposable:remove(item)
    if self.isDisposed then -- `CompositeDisposable`已经被释放了, 不做任何操作
        return false
    end

    if self.disposables[item] then -- 如果可丢弃对象存在, 则移除并释放
        self.disposables[item] = nil
        self.count = self.count - 1
        item:dispose()
        return true
    end

    return false
end

---释放所有可丢弃对象并释放`CompositeDisposable`本身
function CompositeDisposable:dispose()
    if self.isDisposed then
        return
    end

    self.isDisposed = true
    local oldDisposables = self.disposables
    self.disposables = nil
    self.count = 0

    for d, _ in pairs(oldDisposables) do
        d:dispose()
    end
end

---清除并释放所有可丢弃对象, 但不释放`CompositeDisposable`本身
function CompositeDisposable:clear()
    if self.isDisposed or self.count == 0 then
        return
    end

    local oldDisposables = self.disposables
    self.disposables = {}
    self.count = 0

    for d, _ in pairs(oldDisposables) do
        d:dispose()
    end
end

---获取可丢弃对象的数量
---@return integer
function CompositeDisposable:getCount()
    return self.count
end

return CompositeDisposable
