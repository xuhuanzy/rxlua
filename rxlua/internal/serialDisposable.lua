---@namespace Rxlua

local Class = require("luakit.class")

---@class SerialDisposable: IDisposable
---@field private disposable IDisposable? 当前持有的 disposable
---@field private isDisposed boolean 是否已释放
local SerialDisposable = Class.declare("Rxlua.SerialDisposable")

function SerialDisposable:__init()
    self.isDisposed = false
end

---@return IDisposable?
function SerialDisposable:getDisposable()
    return self.disposable
end

---设置新的 disposable 并处置旧值. 如果`SerialDisposable`已经处置了, 那将会直接处置新值.
---@param value IDisposable
function SerialDisposable:setDisposable(value)
    local shouldDispose = self.isDisposed
    if not shouldDispose then
        local old = self.disposable
        self.disposable = value
        if old then
            old:dispose()
        end
    end

    -- 如果已经释放了, 那么直接释放新值
    if shouldDispose and value then
        value:dispose()
    end
end

function SerialDisposable:dispose()
    if self.isDisposed then
        return
    end

    self.isDisposed = true
    local old = self.disposable
    self.disposable = nil
    if old then
        old:dispose()
    end
end

return SerialDisposable
