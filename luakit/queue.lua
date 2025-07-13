---@namespace Luakit

---@class Queue<T>
---@field private _data T[] 队列数据
---@field private _head integer 队首索引, 从1开始
---@field private _tail integer 队尾索引
local Queue = {}
Queue.__index = Queue


---构造函数
---@return Queue<T>
function Queue.new()
    local self = setmetatable({
        _data = {},
        _head = 1,
        _tail = 0,
    }, Queue)
    return self
end

---入队
---@param value T
function Queue:enqueue(value)
    self._tail = self._tail + 1
    self._data[self._tail] = value
end

---出队
---@return T
function Queue:dequeue()
    if self._head > self._tail then
        return nil
    end
    local value = self._data[self._head]
    self._data[self._head] = nil
    self._head = self._head + 1
    if self._head > self._tail then
        self._head = 1
        self._tail = 0
        self._data = {}
    end
    return value
end

---查看队首元素但不移除
---@return T?
function Queue:peek()
    if self._head > self._tail then
        return nil
    end
    return self._data[self._head]
end

---队列是否为空
---@return boolean
function Queue:isEmpty()
    return self._head > self._tail
end

---队列长度
---@return integer
function Queue:size()
    return self._tail + 1 - self._head
end

---清空队列
function Queue:clear()
    self._data = {}
    self._head = 1
    self._tail = 0
end

---遍历
---@return fun(): integer, T
function Queue:ipairs()
    local index = self._head
    local data = self._data
    local tail = self._tail
    return function()
        if index > tail then
            return nil
        end
        local value = data[index]
        local oldIndex = index
        index = index + 1
        return oldIndex, value
    end
end

return Queue
