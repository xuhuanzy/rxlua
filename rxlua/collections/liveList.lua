---@namespace Rxlua

local Class = require('luakit.class')
local Observer = require('rxlua.observer')
---@class (partial) Observable<T>
local Observable = require("rxlua.observable")
local RingBuffer = require('rxlua.internal.ringBuffer').RingBuffer
local getUnhandledExceptionHandler = require('rxlua.observableSystem').getUnhandledExceptionHandler
local new = require('luakit.class').new

---LiveList的内部观察者
---@class LiveList.ListObserver<T>: Observer<T>
---@field parent LiveList<T> 父LiveList对象
local ListObserver = Class.declare('Rxlua.LiveList.ListObserver', {
    super = Observer,
    enableSuperChaining = true
})


---实时列表, 订阅Observable并将接收到的值存储在列表中
---@class LiveList<T>: IDisposable
---@field list table<integer, T> | RingBuffer<T> 存储数据的容器
---@field sourceSubscription IDisposable 源订阅的释放函数
---@field bufferSize integer 缓冲区大小(-1表示无限制)
---@field isCompleted boolean 完成状态标志
---@field completedValue Result 完成时的Result值
local LiveList = Class.declare('Rxlua.LiveList')

---@param source Observable<T> 数据源
---@param bufferSize? integer 缓冲区大小(-1表示无限制)
function LiveList:__init(source, bufferSize)
    self.bufferSize = bufferSize or -1
    if self.bufferSize == 0 then
        self.bufferSize = 1
    end

    self.isCompleted = false
    self.completedValue = nil

    if self.bufferSize == -1 then
        self.list = {}
    else
        -- 固定大小模式, 使用RingBuffer
        self.list = new(RingBuffer)(self.bufferSize)
    end

    -- 创建内部观察者并订阅源
    self.sourceSubscription = source:subscribe(new(ListObserver)(self))
end

---获取指定索引的元素(基于1的索引)
---@param index integer 索引位置(从1开始)
---@return T? value 元素值, 如果索引无效则返回nil
function LiveList:get(index)
    if self.bufferSize == -1 then
        -- 无限制模式
        return self.list[index]
    else
        -- 固定大小模式, 转换为基于0的索引
        return self.list:get(index - 1)
    end
end

---获取当前元素数量
---@return integer count 元素数量
function LiveList:getCount()
    if self.bufferSize == -1 then
        return #self.list
    else
        return self.list:getSize()
    end
end

---检查是否已完成
---@return boolean isCompleted 是否已完成
function LiveList:getIsCompleted()
    return self.isCompleted
end

---获取完成结果
---@return Result result 完成结果
function LiveList:getResult()
    if not self.isCompleted then
        error("LiveList is not completed, you should check IsCompleted.")
    end
    return self.completedValue
end

---清空所有元素
function LiveList:clear()
    if self.bufferSize == -1 then
        self.list = {}
    else
        self.list:clear()
    end
end

---释放资源
function LiveList:dispose()
    if self.sourceSubscription then
        self.sourceSubscription:dispose()
        self.sourceSubscription = nil
    end
end

---遍历所有元素
---@generic TState
---@param action fun(value: T, state?: TState) 对每个元素执行的操作
---@param state? TState 状态对象, 如果不传入则不使用状态
function LiveList:forEach(action, state)
    if self.bufferSize == -1 then
        for _, item in ipairs(self.list) do
            action(item, state)
        end
    else
        local span = self.list:getSpan()
        for _, item in pairs(span) do
            action(item, state)
        end
    end
end

---转换为数组
---@return T[] array 包含所有元素的数组
function LiveList:toArray()
    if self.bufferSize == -1 then
        ---@cast self.list table<integer, T>
        return self.list
    else
        return self.list:toArray()
    end
end

-- #region ListObserver

---@param parent LiveList<T>
function ListObserver:__init(parent)
    self.parent = parent
end

---处理下一个值
---@param message T 接收到的值
function ListObserver:onNextCore(message)
    local parent = self.parent

    if parent.bufferSize == -1 then
        -- 无限制模式, 直接添加到table
        table.insert(parent.list, message)
    else
        -- 固定大小模式, 使用 RingBuffer
        local ring = parent.list

        if ring:getSize() == parent.bufferSize then
            ring:removeFirst()
        end
        ring:addLast(message)
    end
end

---@param error Luakit.Exception 错误信息
function ListObserver:onErrorResumeCore(error)
    getUnhandledExceptionHandler()(error)
end

---@param complete Result 完成结果
function ListObserver:onCompletedCore(complete)
    self.parent.completedValue = complete
    self.parent.isCompleted = true
end

-- #endregion



---将Observable转换为LiveList
---@generic T
---@param bufferSize? integer 缓冲区大小, 默认`-1`表示无限制
---@return LiveList<T> liveList 实时列表
function Observable:toLiveList(bufferSize)
    return new(LiveList)(self, bufferSize)
end

return LiveList
