---@namespace Rxlua

local Class = require('luakit.class')
local pcall = pcall
local tableRemove = table.remove

---@class CompositeDisposable: IDisposable
---@field private _gate table a lock object
---@field private _disposables IDisposable[]? the list of disposables
---@field private _isDisposed boolean
---@field private _count integer
local CompositeDisposable = Class.declare('Rxlua.CompositeDisposable')

function CompositeDisposable:__init()
    self._gate = {}
    self._disposables = {}
    self._isDisposed = false
    self._count = 0
end

---Adds a disposable to the CompositeDisposable or disposes the disposable if the CompositeDisposable is disposed.
---@param item IDisposable The disposable to add.
function CompositeDisposable:add(item)
    if not item or not item.dispose then
        return
    end

    local shouldDispose = false

    if self._isDisposed then
        shouldDispose = true
    else
        ---@cast self._disposables -?
        self._disposables[#self._disposables + 1] = item
        self._count = self._count + 1
    end

    if shouldDispose then
        item:dispose()
    end
end

---Removes and disposes the first occurrence of a disposable from the CompositeDisposable.
---@param item IDisposable The disposable to remove.
---@return boolean true if the disposable was found and removed; otherwise, false.
function CompositeDisposable:remove(item)
    if self._isDisposed then
        return false
    end

    local shouldDispose = false
    do
        -- lock
        local found = false
        for i = #self._disposables, 1, -1 do
            ---@cast self._disposables -?
            if self._disposables[i] == item then
                tableRemove(self._disposables, i)
                self._count = self._count - 1
                found = true
                shouldDispose = true
                break
            end
        end
        -- unlock
        if not found then
            return false
        end
    end

    if shouldDispose then
        item:dispose()
    end

    return true
end

---Disposes all disposables in the group and clears the list.
function CompositeDisposable:dispose()
    local oldDisposables
    do
        -- lock
        if self._isDisposed then
            return
        end
        self._isDisposed = true
        oldDisposables = self._disposables
        self._disposables = nil
        self._count = 0
        -- unlock
    end

    if not oldDisposables then
        return
    end

    for _, d in ipairs(oldDisposables) do
        d:dispose()
    end
end

---Removes and disposes all disposables from the CompositeDisposable, but does not dispose the CompositeDisposable itself.
function CompositeDisposable:clear()
    local oldDisposables
    do
        -- lock
        if self._isDisposed then
            return
        end
        oldDisposables = self._disposables
        self._disposables = {}
        self._count = 0
        -- unlock
    end

    for _, d in ipairs(oldDisposables) do
        d:dispose()
    end
end

---Gets the number of disposables contained in the CompositeDisposable.
---@return integer
function CompositeDisposable:getCount()
    return self._count
end

---Gets a value that indicates whether the object is disposed.
---@return boolean
function CompositeDisposable:isDisposed()
    return self._isDisposed
end

return CompositeDisposable
