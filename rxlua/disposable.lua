local Class = require("luakit.class")
local new = require("luakit.class").new
---@namespace Rxlua
local NOOP = require("luakit.general").NOOP

---空释放器
---@class EmptyDisposable: IDisposable
local EmptyDisposable = { dispose = NOOP }


---实例化时传入一个回调函数, 当释放时将自动调用该回调函数.
---@class AnonymousDisposable<T>: IDisposable
local AnonymousDisposable = Class.declare('Rxlua.AnonymousDisposable')

---@param onDisposed fun(state?: T)
---@param state T
function AnonymousDisposable:__init(onDisposed, state)
    self.onDisposed = onDisposed
    self.state = state
end

function AnonymousDisposable:dispose()
    self.onDisposed(self.state)
    self.onDisposed = nil
end

---简单的可丢弃对象组合器, 当其在释放时, 会自动释放内部所有可丢弃对象.
---@class CombinedDisposable: IDisposable
---@field private disposables table<IDisposable, boolean>
local CombinedDisposable = Class.declare('Rxlua.CombinedDisposable')

function CombinedDisposable:__init()
    self.disposables = {}
end

---添加可丢弃对象
---@param disposable IDisposable
function CombinedDisposable:add(disposable)
    if not self.disposables then
        error("CombinedDisposable 已释放, 无法添加可丢弃对象")
    end
    if not self.disposables[disposable] then
        self.disposables[disposable] = true
    end
end

function CombinedDisposable:dispose()
    for disposable, _ in pairs(self.disposables) do
        disposable:dispose()
    end
    self.disposables = nil
end

---#region 静态方法

---创建一个可丢弃对象组合器, 当其在释放时, 会自动释放内部所有可丢弃对象.
---@param ... IDisposable
---@return IDisposable
local function combine(...)
    local disposables = { ... }
    local combined = new(CombinedDisposable)()
    for _, disposable in ipairs(disposables) do
        combined:add(disposable)
    end
    return combined
end

---为函数创建一个可丢弃对象, 当其在释放时, 会自动调用传入的回调函数.
---@generic T
---@param onDisposed fun(state?: T)
---@param state? T
---@return IDisposable
local function create(onDisposed, state)
    return new(AnonymousDisposable)(onDisposed, state)
end

---#endregion

return {
    Empty = EmptyDisposable,
    combine = combine,
    create = create
}
