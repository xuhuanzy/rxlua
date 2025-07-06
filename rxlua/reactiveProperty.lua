---@namespace Rxlua

local Class = require('luakit.class')
local Observable = require('rxlua.observable')
local Result = require('rxlua.result')
local emptyDisposable = require("rxlua.shared").emptyDisposable

---@class ReadOnlyReactiveProperty<T>: Observable<T>
---@field currentValue T
---@field protected OnValueChanged fun(self: self, value: T) 值改变回调
---@field protected OnReceiveError fun(self: self, exception: any) 错误回调

---内部使用的节点
---@class ReactiveProperty.ObserverNode: IDisposable
---@field previous? ReactiveProperty.ObserverNode 前一个是最后一个节点或根节点(nil)
---@field next? ReactiveProperty.ObserverNode 下一个节点
local ReactivePropertyObserverNode = {}
ReactivePropertyObserverNode.__index = ReactivePropertyObserverNode


---@class ReactiveProperty<T>: ReadOnlyReactiveProperty<T>, ISubject<T>
---@field private completeState number 完成状态
---@field private error any 错误信息
---@field private currentValue T 当前值
---@field private equalityComparer fun(a: T, b: T): boolean 相等性比较器
---@field package root? ReactiveProperty.ObserverNode 观察者根节点
local ReactiveProperty = Class.declare('Rxlua.ReactiveProperty', Observable)

local NotCompleted = 0     -- 未完成
local CompletedSuccess = 1 -- 完成成功
local CompletedFailure = 2 -- 完成失败
local Disposed = 3         -- 已释放


local defaultEqualityComparer = function(a, b)
    return a == b
end

---构造函数
---@param value T 初始值
---@param equalityComparer? fun(a: T, b: T): boolean 相等性比较器
function ReactiveProperty:__init(value, equalityComparer)
    self.completeState = NotCompleted

    self.equalityComparer = equalityComparer or defaultEqualityComparer
    value = self:onValueChanging(value)
    self.currentValue = value
    self:onValueChanged(value)

    self:onNext(value)
end

---@return T
function ReactiveProperty:getValue()
    return self.currentValue
end

---@param value T
function ReactiveProperty:setValue(value)
    value = self:onValueChanging(value)

    -- 相等性检查
    if self.equalityComparer(self.currentValue, value) then
        return
    end

    self.currentValue = value
    self:onValueChanged(value)
    self:onNextCore(value)
end

---检查是否有观察者
---@return boolean
function ReactiveProperty:hasObservers()
    return self.root ~= nil
end

---检查是否已完成
---@return boolean
function ReactiveProperty:isCompleted()
    return self.completeState == CompletedSuccess or self.completeState == CompletedFailure
end

---检查是否已释放
---@return boolean
function ReactiveProperty:isDisposed()
    return self.completeState == Disposed
end

---检查是否已完成或已释放
---@return boolean
function ReactiveProperty:isCompletedOrDisposed()
    return self:isCompleted() or self:isDisposed()
end

---@protected
---值即将改变时的钩子(可重写)
---@param value T
---@return T
function ReactiveProperty:onValueChanging(value)
    return value
end

---值改变时的回调(可重写)
---@param value T
---@protected
function ReactiveProperty:onValueChanged(value)
end

---接收错误时的回调（可重写）
---@param exception any
---@protected
function ReactiveProperty:onReceiveError(exception)
    -- 可由子类重写
end

---强制通知当前值
function ReactiveProperty:forceNotify()
    self:onNext(self.currentValue)
end

---发送下一个值
---@param value T
function ReactiveProperty:onNext(value)
    self:onValueChanging(value)
    self.currentValue = value -- 在发送前设置值
    self:onValueChanged(value)
    self:onNextCore(value)
end

---发送下一个值的核心逻辑
---@param value T
---@protected
function ReactiveProperty:onNextCore(value)
    self:throwIfDisposed()
    if self:isCompleted() then
        return
    end

    local node = self.root
    local last = node and node.previous
    while node do
        node.observer:onNext(value)
        if node == last then
            return
        end
        node = node.next
    end
end

---发送错误但继续订阅
---@param error any
function ReactiveProperty:onErrorResume(error)
    self:throwIfDisposed()
    if self:isCompleted() then
        return
    end

    self:onReceiveError(error)

    local node = self.root
    local last = node and node.previous
    while node do
        node.observer:onErrorResume(error)
        if node == last then
            return
        end
        node = node.next
    end
end

---完成
---@param result Result
function ReactiveProperty:onCompleted(result)
    self:throwIfDisposed()
    if self:isCompleted() then
        return
    end

    local node = nil
    if self.completeState == NotCompleted then
        self.completeState = result:isSuccess() and CompletedSuccess or CompletedFailure
        self.error = result.exception
        node = self.root
        self.root = nil -- 完成时清空列表
    else
        self:throwIfDisposed()
        return
    end

    if result:isFailure() then
        self:onReceiveError(result.exception)
    end

    local last = node and node.previous
    while node do
        node.observer:onCompleted(result)
        if node == last then
            return
        end
        node = node.next
    end
end

---订阅核心逻辑
---@param observer Observer<T>
---@return IDisposable
function ReactiveProperty:subscribeCore(observer)
    local completedResult = nil

    -- 检查是否已完成
    self:throwIfDisposed()
    if self:isCompleted() then
        -- 如果已完成, 则直接返回完成结果
        completedResult = self.error and Result.failure(self.error) or Result.success()
        if completedResult:isSuccess() then
            observer:onNext(self.currentValue)
        end
        observer:onCompleted(completedResult)
        return emptyDisposable
    end


    -- 发送当前值(在添加到观察者列表之前)
    observer:onNext(self.currentValue)

    -- 再次检查是否已完成(避免竞态条件)
    self:throwIfDisposed()
    if self:isCompleted() then
        completedResult = self.error and Result.failure(self.error) or Result.success()
        observer:onCompleted(completedResult)
        return emptyDisposable
    end

    -- 创建订阅并添加到列表
    return ReactivePropertyObserverNode.new(self, observer)
end

---检查是否已释放，如果是则抛出异常
---@private
function ReactiveProperty:throwIfDisposed()
    if self:isDisposed() then
        error("无法访问已释放的对象.")
    end
end

---释放资源
---@param callOnCompleted? boolean 是否调用完成回调，默认为`true`.
function ReactiveProperty:dispose(callOnCompleted)
    if callOnCompleted == nil then
        callOnCompleted = true
    end
    if self.completeState == Disposed then
        return
    end
    local node = nil
    -- 如果需要调用完成回调且尚未完成
    if callOnCompleted and not self:isCompleted() then
        node = self.root
    end

    self.root = nil
    self.completeState = Disposed

    -- 通知所有观察者完成
    while node do
        node.observer:onCompleted(Result.success())
        node = node.next
    end

    self:disposeCore()
end

---释放核心逻辑(可重写)
---@protected
function ReactiveProperty:disposeCore()
end

--#region ReactiveProperty.ObserverNode



---构造函数
---@generic T
---@param parent ReactiveProperty<T>
---@param observer Observer<T>
---@return ReactiveProperty.ObserverNode
function ReactivePropertyObserverNode.new(parent, observer)
    ---@class (constructor) ReactiveProperty.ObserverNode
    local self = {
        parent = parent,
        observer = observer,
        previous = nil,
        next = nil
    }

    -- 添加节点到父级列表
    if not parent.root then
        -- 单个列表（前后都为nil）
        parent.root = self
    else
        -- 前一个是最后一个, 若为空则根为最后一个
        local lastNode = parent.root.previous or parent.root

        lastNode.next = self
        self.previous = lastNode
        parent.root.previous = self
    end
    return setmetatable(self, ReactivePropertyObserverNode)
end

---释放观察者节点
function ReactivePropertyObserverNode:dispose()
    local p = self.parent
    if not p then
        return
    end
    self.parent = nil

    -- 从父级列表中移除节点
    if p:isCompletedOrDisposed() then
        return
    end

    if self == p.root then
        if not self.previous or not self.next then
            -- 单个列表的情况
            p.root = nil
        else
            -- 否则，根是下一个节点
            local root = self.next

            -- 单个列表
            if not root.next then
                root.previous = nil
            else
                root.previous = self.previous -- 作为最后一个
            end

            p.root = root
        end
    else
        -- 节点不是根，前一个必须存在
        ---@cast self.previous -?
        self.previous.next = self.next
        if self.next then
            self.next.previous = self.previous
        else
            ---@cast p.root -?
            -- 下一个不存在，前一个是最后一个节点，所以修改根
            p.root.previous = self.previous
        end
    end
end

--#endregion ObserverNode


return ReactiveProperty
