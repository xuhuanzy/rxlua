local NOOP = require("luakit.general").NOOP
---@namespace Luakit

---#region 类型声明

---@class CancelTokenSource
---@field public token CancelToken
---@field private _isCancelled boolean 是否已取消
---@field private _registrations table<CancelTokenRegistration, true> 取消回调表, 弱引用.
local CancelTokenSource = {}
CancelTokenSource.__index = CancelTokenSource

---@class CancelToken
---@field package _source? CancelTokenSource 取消令牌源. 如果为空, 则表示不可取消.
---@field public canBeCanceled boolean
local CancelToken = {}
CancelToken.__index = CancelToken

---@class CancelTokenRegistration
---@field private _source? CancelTokenSource 取消令牌源, 可空的
---@field package _callback fun(state?: table) 取消回调, 允许传入状态
---@field package _state? table 状态
---@field private _disposed? boolean 是否已释放
local CancelTokenRegistration = {}
CancelTokenRegistration.__index = CancelTokenRegistration

---#endregion

---#CancelToken 取消令牌类

---@param source CancelTokenSource?
---@return CancelToken
function CancelToken.new(source)
    return setmetatable({
        _source = source,
    }, CancelToken)
end

---是否已取消
---@return boolean
function CancelToken:isCancelled()
    if not self._source then return false end
    return self._source:isCancelled()
end

---是否可取消
---@return boolean
function CancelToken:canBeCanceled()
    return self._source ~= nil
end

---注册取消回调, 如果已取消, 则立即执行回调.
---@param callback fun(state?: table) 取消回调, 允许传入状态
---@param state? table 状态
---@return CancelTokenRegistration
function CancelToken:register(callback, state)
    if not self._source then
        return CancelTokenRegistration.new(nil, NOOP, nil)
    end
    return self._source:register(callback, state)
end

---如果已取消, 则抛出错误.
function CancelToken:throwIfCancelled()
    if self:isCancelled() then
        error("CancelToken Operation Canceled")
    end
end

---#endregion 取消令牌类


---#CancelTokenSource 取消令牌源类

---@return CancelTokenSource
function CancelTokenSource.new()
    local instance = setmetatable({
        _registrations = setmetatable({}, { __mode = "k" }),
    }, CancelTokenSource)
    instance.token = CancelToken.new(instance)
    return instance
end

---是否已取消
---@return boolean
function CancelTokenSource:isCancelled()
    return self._isCancelled or false
end

---取消令牌源, 将对所有注册的取消回调执行回调.
function CancelTokenSource:cancel()
    if self._disposed or self._isCancelled then
        return
    end

    self._isCancelled = true

    local callbacks = self._registrations
    self._registrations = nil
    for registration, _ in pairs(callbacks) do
        registration._callback(registration._state)
    end
end

---注册取消回调, 如果已取消, 则立即执行回调.
---@param callback fun(state?: table) 取消回调, 允许传入状态
---@param state? table 状态
---@return CancelTokenRegistration
function CancelTokenSource:register(callback, state)
    if self._disposed then
        error("无法注册取消回调, 取消令牌源已释放.", 2)
    end

    if self._isCancelled then
        callback(state)
        return CancelTokenRegistration.new(self, NOOP, state)
    end

    local registration = CancelTokenRegistration.new(self, callback, state)
    self._registrations[registration] = true
    return registration
end

---@package
---@param registration CancelTokenRegistration
function CancelTokenSource:unregister(registration)
    self._registrations[registration] = nil
end

function CancelTokenSource:dispose()
    if self._disposed then
        return
    end

    self._disposed = true
    self._registrations = nil
end

---#endregion 取消令牌源类

---#CancelTokenRegistration 取消令牌注册器类

---@param source? CancelTokenSource 取消令牌源, 可空的
---@param callback fun(state?: table) 取消回调, 允许传入状态
---@param state? table 状态
---@return CancelTokenRegistration
function CancelTokenRegistration.new(source, callback, state)
    return setmetatable({
        _source = source,
        _callback = callback,
        _state = state,
    }, CancelTokenRegistration)
end

function CancelTokenRegistration:dispose()
    if self._disposed then
        return
    end

    if self._source then
        self._source:unregister(self)
    end

    self._disposed = true
    self._source = nil
end

---#endregion

---@export global
return {
    CancelTokenSource = CancelTokenSource,
    CancelToken = CancelToken,
}
