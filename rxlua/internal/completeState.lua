---@namespace Rxlua

local Result = require('rxlua.internal.result')

---@enum CompleteState.ResultStatus
local ResultStatus = {
    Done = "Done",                     -- 状态设置成功
    AlreadySuccess = "AlreadySuccess", -- 已经是成功状态
    AlreadyFailed = "AlreadyFailed"    -- 已经是失败状态
}

-- 状态常量定义
local NotCompleted = 0     -- 未完成
local CompletedSuccess = 1 -- 完成成功
local CompletedFailure = 2 -- 完成失败
local Disposed = 3         -- 已释放

---@class CompleteState
---@field private completeState integer 完成状态
---@field private error any 错误信息
local CompleteState = {}
CompleteState.__index = CompleteState

---构造函数
---初始化为未完成状态
---@return CompleteState
function CompleteState.new()
    return setmetatable({
        completeState = NotCompleted,
        error = nil
    }, CompleteState)
end

---尝试设置完成结果
---@param result Result 操作结果
---@return CompleteState.ResultStatus @ 设置状态结果
function CompleteState:trySetResult(result)
    -- 检查当前状态, 如果不是未完成状态则返回相应结果
    local currentState = self.completeState
    if currentState ~= NotCompleted then
        if currentState == CompletedSuccess then
            return ResultStatus.AlreadySuccess
        elseif currentState == CompletedFailure then
            return ResultStatus.AlreadyFailed
        elseif currentState == Disposed then
            self:throwObjectDisposedException()
        end
    end

    -- 设置新的完成状态
    if result:isSuccess() then
        self.completeState = CompletedSuccess
    else
        self.completeState = CompletedFailure
        self.error = result.exception
    end

    return ResultStatus.Done
end

---尝试设置为已销毁状态
---@return boolean success 是否设置成功
---@return boolean alreadyCompleted 是否已经完成
function CompleteState:trySetDisposed()
    local currentState = self.completeState

    if currentState == NotCompleted then
        self.completeState = Disposed
        return true, false
    elseif currentState == CompletedSuccess or currentState == CompletedFailure then
        self.completeState = Disposed
        return true, true
    elseif currentState == Disposed then
        return false, false
    end

    return false, false
end

---检查是否已完成
---@return boolean
function CompleteState:isCompleted()
    if self.completeState == Disposed then
        self:throwObjectDisposedException()
    end
    return self.completeState == CompletedSuccess or self.completeState == CompletedFailure
end

---检查是否已销毁
---@return boolean
function CompleteState:isDisposed()
    return self.completeState == Disposed
end

---检查是否已完成或已销毁
---@return boolean
function CompleteState:isCompletedOrDisposed()
    return self.completeState ~= NotCompleted
end

---尝试获取完成结果
---@return Result? # 完成结果, 如果未完成返回nil
function CompleteState:tryGetResult()
    local currentState = self.completeState
    if currentState == NotCompleted then
        return nil
    elseif currentState == CompletedSuccess then
        return Result.success()
    elseif currentState == CompletedFailure then
        return Result.failure(self:getException())
    elseif currentState == Disposed then
        self:throwObjectDisposedException()
    end

    return nil
end

---获取异常信息
---@return any # 异常对象
---@private
function CompleteState:getException()
    if self.error ~= nil then
        return self.error
    end
    return "未知错误"
end

---抛出对象已销毁异常
---@private
function CompleteState:throwObjectDisposedException()
    error("无法访问已释放的对象")
end

-- 导出ResultStatus常量供外部使用
CompleteState.ResultStatus = ResultStatus

return CompleteState
