---@namespace Rxlua

local Class = require('luakit.class')
local new = require("luakit.class").new
local tableInsert = table.insert
local tableMove = table.move
local setmetatable = setmetatable
local BufferView = require('rxlua.internal.bufferView')

---环形缓冲区
---@class RingBuffer<T>
---@field private buffer T[] 内部存储数组, 索引从 1 开始
---@field private head integer 逻辑索引, 指向逻辑上第一个元素(最旧元素)的位置. 为了优化, 索引需要从0开始
---@field private count integer 当前元素数量
---@field private capacity integer 缓冲区容量(必须单独记录)
---@field private mask integer 位掩码(capacity - 1), 与 head 进行位运算以取代取模运算.
local RingBuffer = Class.declare('Rxlua.RingBuffer')

---计算缓冲区容量 (2的幂次, 最小为8)
---@param size integer 期望大小
---@return integer # 实际容量 (2的幂次)
local function calculateCapacity(size)
    if size <= 0 then
        return 8
    end

    size = size - 1
    size = size | (size >> 1)
    size = size | (size >> 2)
    size = size | (size >> 4)
    size = size | (size >> 8)
    size = size | (size >> 16)
    size = size + 1

    if size < 8 then
        size = 8
    end

    return size
end

---@param capacity? integer 初始容量
function RingBuffer:__init(capacity)
    capacity = capacity or 8
    capacity = calculateCapacity(capacity)

    self.buffer = {}
    self.head = 0
    self.count = 0
    self.capacity = capacity
    self.mask = capacity - 1
end

---确保容量足够, 必要时扩容
---@private
function RingBuffer:ensureCapacity()
    if self.count < self.capacity then
        return -- 容量足够
    end

    local oldCapacity = self.capacity
    local newCapacity = oldCapacity * 2
    local newBuffer = {}

    local head_0 = self.head
    local start_0 = head_0 & self.mask
    local end_0 = (head_0 + self.count) & self.mask

    if end_0 > start_0 then
        -- 情况1: 数据在同一个连续块中
        -- 例如: [_, _, A, B, C, _], start_0=2, end_0=5
        -- 物理索引范围是 [start_0, end_0 - 1]
        -- Lua table 索引范围是 [start_0 + 1, end_0]
        tableMove(self.buffer, start_0 + 1, end_0, 1, newBuffer)
    else
        -- 情况2: 数据环绕, 分为两个块
        -- 例如: [C, D, _, _, A, B], start_0=4, end_0=2

        -- 块1: 从 start_0 到物理数组末尾
        -- 物理索引范围 [start_0, oldCapacity - 1]
        -- Lua table 索引范围 [start_0 + 1, oldCapacity]
        local firstChunkSize = oldCapacity - start_0
        tableMove(self.buffer, start_0 + 1, oldCapacity, 1, newBuffer)

        -- 块2: 从物理数组开头到 end_0
        -- 物理索引范围 [0, end_0 - 1]
        -- Lua table 索引范围 [1, end_0]
        tableMove(self.buffer, 1, end_0, firstChunkSize + 1, newBuffer)
    end

    -- 更新缓冲区状态
    self.buffer = newBuffer
    self.head = 0 -- 数据已被线性化, head 重置为 0
    self.capacity = newCapacity
    self.mask = newCapacity - 1
end

---在尾部添加元素
---@param item T 要添加的元素
function RingBuffer:addLast(item)
    if self.count == self.capacity then
        self:ensureCapacity()
    end

    local index = (self.head + self.count) & self.mask
    self.buffer[index + 1] = item -- Lua 索引调整
    self.count = self.count + 1
end

---在头部添加元素
---@param item T 要添加的元素
function RingBuffer:addFirst(item)
    if self.count == self.capacity then
        self:ensureCapacity()
    end

    self.head = (self.head - 1) & self.mask
    self.buffer[self.head + 1] = item -- Lua 索引调整
    self.count = self.count + 1
end

---移除头部元素
---@return T? item # 被移除的元素, 如果缓冲区为空则返回 nil
function RingBuffer:removeFirst()
    if self.count == 0 then
        return nil
    end

    local index = self.head & self.mask
    local item = self.buffer[index + 1] -- Lua 索引调整
    self.buffer[index + 1] = nil        -- 清理引用
    self.head = self.head + 1
    self.count = self.count - 1

    return item
end

---移除尾部元素
---@return T? item # 被移除的元素, 如果缓冲区为空则返回 nil
function RingBuffer:removeLast()
    if self.count == 0 then
        return nil
    end

    local index = (self.head + self.count - 1) & self.mask
    local item = self.buffer[index + 1] -- Lua 索引调整
    self.buffer[index + 1] = nil        -- 清理引用
    self.count = self.count - 1

    return item
end

---按索引访问元素
---@param index integer 索引 (从 0 开始)
---@return T? item # 指定位置的元素, 如果索引无效则返回 nil
function RingBuffer:get(index)
    if index < 0 or index >= self.count then
        return nil
    end

    local actualIndex = (self.head + index) & self.mask
    return self.buffer[actualIndex + 1] -- Lua 索引调整
end

---设置指定索引的元素值
---@param index integer 索引 (从 0 开始)
---@param value any 新值
function RingBuffer:set(index, value)
    if index < 0 or index >= self.count then
        error("索引超出范围: " .. index, 2)
    end

    local actualIndex = (self.head + index) & self.mask
    self.buffer[actualIndex + 1] = value -- Lua 索引调整
end

---获取当前元素数量
---@return integer
function RingBuffer:getSize()
    return self.count
end

---获取缓冲区容量
---@return integer
function RingBuffer:getCapacity()
    return self.capacity
end

---检查缓冲区是否为空
---@return boolean
function RingBuffer:isEmpty()
    return self.count == 0
end

---获取头部元素(最旧元素)
---@return T? first # 头部元素, 如果缓冲区为空则返回 nil
function RingBuffer:getFirst()
    if self.count == 0 then
        return nil
    end
    return self:get(0)
end

---获取尾部元素(最新元素)
---@return T? last # 尾部元素.如果缓冲区为空则返回 nil
function RingBuffer:getLast()
    if self.count == 0 then
        return nil
    end
    return self:get(self.count - 1)
end

---清空缓冲区
function RingBuffer:clear()
    self.buffer = {}
    self.head = 0
    self.count = 0
    self.capacity = calculateCapacity(8)
    self.mask = self.capacity - 1
end

---@class RingBufferSpan<T>
---@field package first BufferView<T>
---@field package second? BufferView<T>
---@field count integer 总元素数量
local RingBufferSpan = {}
RingBufferSpan.__index = RingBufferSpan

---@param first BufferView<T>
---@param second? BufferView<T>
---@param count integer
---@return RingBufferSpan<T>
function RingBufferSpan:new(first, second, count)
    return setmetatable({ first = first, second = second, count = count }, RingBufferSpan)
end

---为 RingBufferSpan 实现迭代器
---@generic T
---@param span RingBufferSpan<T>
---@return fun(): integer, T
local function spanIterator(span)
    local i = 0
    local first = span.first
    local second = span.second
    local firstLen = #first
    local secondLen = second and #second or 0

    return function()
        i = i + 1
        if i <= firstLen then
            return i, first.buffer[first.start + i - 1]
        elseif i <= firstLen + secondLen then
            if not second then
                return nil
            end
            local j = i - firstLen
            return i, second.buffer[second.start + j - 1]
        else
            return nil
        end
    end
end

---@return fun(): integer, T
function RingBufferSpan:__pairs()
    return spanIterator(self)
end

local emptyView = BufferView:new({}, 1, 0)

---获取环形缓冲区所有元素的视图
---@return RingBufferSpan<T> span # 包含两个连续片段视图的结构
function RingBuffer:getSpan()
    if self.count == 0 then
        return RingBufferSpan:new(emptyView, nil, 0)
    end

    local start = self.head & self.mask
    local endPos = (self.head + self.count) & self.mask

    local first, second
    if endPos > start then
        -- 情况1: 数据在一个连续段内
        first = BufferView:new(self.buffer, start + 1, self.count)
    else
        -- 情况2: 数据环绕了数组边界, 分为两段
        first = BufferView:new(self.buffer, start + 1, self.capacity - start)
        second = BufferView:new(self.buffer, 1, endPos)
    end

    return RingBufferSpan:new(first, second, self.count)
end

---获取所有元素的副本
---@return T[] # 包含所有元素的数组
function RingBuffer:toArray()
    local result = {}
    local span = self:getSpan()

    -- 使用 pairs 遍历 RingBufferSpan
    for _, item in pairs(span) do
        tableInsert(result, item)
    end

    return result
end

---查找元素的索引位置
---@param item any 要查找的元素
---@return integer index # 元素索引 (0-based), 未找到则返回 -1
function RingBuffer:indexOf(item)
    local span = self:getSpan()
    local logicalIndex = 0

    -- 使用 pairs 遍历 RingBufferSpan
    for _, value in pairs(span) do
        if value == item then
            return logicalIndex
        end
        logicalIndex = logicalIndex + 1
    end

    -- 未找到
    return -1
end

---检查是否包含指定元素 (无需修改, 自动受益)
---@param item any 要查找的元素
---@return boolean
function RingBuffer:contains(item)
    return self:indexOf(item) ~= -1
end

---创建指定容量的环形缓冲区
---@generic T
---@param capacity? integer 初始容量
---@return RingBuffer<T>
local function createRingBuffer(capacity)
    return new("Rxlua.RingBuffer")(capacity)
end

return {
    RingBuffer = RingBuffer,
    createRingBuffer = createRingBuffer
}
