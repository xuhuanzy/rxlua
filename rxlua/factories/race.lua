---@namespace Rxlua

local Observable = require("rxlua.observable")
local Observer = require("rxlua.observer")
local Class = require("luakit.class")
local new = require("luakit.class").new

-- #region _RaceObserver

---@class Race.RaceObserver<T>: Observer<T>
---@field private parent Race._Race<T>
---@field private index int
---@field private won boolean 是否获胜
local RaceObserver = Class.declare("Rxlua.Race.RaceObserver", Observer)

---@param parent Race._Race<T>
---@param index int
function RaceObserver:__init(parent, index)
    self.parent = parent
    self.index = index
    self.won = false
end

function RaceObserver:onNextCore(value)
    if self.won then
        self.parent.observer:onNext(value)
        return
    end

    local oldWinner = self.parent.winner
    if oldWinner == nil then
        self.parent.winner = self
    end
    if not oldWinner then
        -- 首先移除掉其他
        self.won = true
        for _, obs in ipairs(self.parent.subscriptions) do
            if obs ~= self and obs ~= nil then
                obs:dispose()
            end
        end
        self.parent.subscriptions = {
            [self.index] = self
        }
        self.parent.observer:onNext(value)
    elseif oldWinner == self then
        self.parent.observer:onNext(value)
    else
        self:dispose()
    end
end

function RaceObserver:onErrorResumeCore(error)
    if self.won then
        self.parent.observer:onErrorResume(error)
        return
    end

    local oldWinner = self.parent.winner
    if oldWinner == nil then
        self.parent.winner = self
    end
    if not oldWinner then
        self.won = true
        for _, obs in ipairs(self.parent.subscriptions) do
            if obs ~= self and obs ~= nil then
                obs:dispose()
            end
        end
        self.parent.subscriptions = {
            [self.index] = self
        }
        self.parent.observer:onErrorResume(error)
    elseif oldWinner == self then
        self.parent.observer:onErrorResume(error)
    else
        self:dispose()
    end
end

function RaceObserver:onCompletedCore(result)
    if self.won then
        self.parent.observer:onCompleted(result)
        return
    end

    local oldWinner = self.parent.winner
    if oldWinner == nil then
        self.parent.winner = self
    end
    if not oldWinner then
        self.won = true
        for _, obs in ipairs(self.parent.subscriptions) do
            if obs ~= self and obs ~= nil then
                obs:dispose()
            end
        end
        self.parent.subscriptions = {
            [self.index] = self
        }
        self.parent.observer:onCompleted(result)
    elseif oldWinner == self then
        self.parent.observer:onCompleted(result)
    else
        self:dispose()
    end
end

function RaceObserver:disposeCore()
    self.parent.subscriptions[self.index] = nil
end

-- #endregion

-- #region _Race

---@class Race._Race<T>: IDisposable
---@field public observer Observer<T>
---@field package subscriptions table<int, IDisposable>
---@field public winner? Race.RaceObserver
local _Race = Class.declare("Rxlua.Race._Race")

---@param observer Observer<T>
function _Race:__init(observer)
    self.observer = observer
    self.subscriptions = {}
end

function _Race:dispose()
    for _, subscription in ipairs(self.subscriptions) do
        subscription:dispose()
    end
end

-- #endregion

-- #region RaceObservable

---@class Race<T>: Observable<T>
---@field private sources Observable<T>[]
local RaceObservable = Class.declare("Rxlua.Race", Observable)

---@param sources Observable<T>[]
function RaceObservable:__init(sources)
    self.sources = sources
end

function RaceObservable:subscribeCore(observer)
    local raceState = new(_Race)(observer)

    for i, source in ipairs(self.sources) do
        local raceObserver = new(RaceObserver)(raceState, i)
        raceState.subscriptions[i] = source:subscribe(raceObserver)
    end

    return raceState
end

-- #endregion


---race 返回一个 observable, 当订阅它时, 会立即订阅所有源 observable. 一旦某个源 observable 发出值, 结果 observable 就会取消订阅其他源. <br>
---结果 observable 将转发来自"获胜"源 observable 的所有通知, 包括错误和完成.
---@generic T
---@param ... Observable<T>
---@return Observable<T>
local function race(...)
    local sources = { ... }
    if #sources == 0 then
        return require("rxlua.factories.empty")()
    end
    return new(RaceObservable)(sources)
end

return race
