---@namespace Luakit

local tableSort    = table.sort
local stringRep    = string.rep
local tableConcat  = table.concat
local tostring     = tostring
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local next         = next
local rawset       = rawset
local move         = table.move
local tableRemove  = table.remove
local setmetatable = debug.setmetatable
local mathType     = math.type
local mathCeil     = math.ceil
local getmetatable = getmetatable
local mathAbs      = math.abs
local mathRandom   = math.random
local ioOpen       = io.open
local utf8Len      = utf8.len
local getenv       = os.getenv
local getupvalue   = debug.getupvalue
local mathHuge     = math.huge
local inf          = 1 / 0
local nan          = 0 / 0
local error        = error
local assert       = assert
local mathFloor    = math.floor

_ENV               = nil


local function isInteger(n)
    return mathType(n) == 'integer'
end

local function formatNumber(n)
    if n == inf
        or n == -inf
        or n == nan
        or n ~= n then -- IEEE 标准中，NAN 不等于自己。但是某些实现中没有遵守这个规则
        return ('%q'):format(n)
    end
    if isInteger(n) then
        return tostring(n)
    end
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

local TAB = setmetatable({}, {
    __index = function(self, n)
        self[n] = stringRep('    ', n)
        return self[n]
    end
})

local RESERVED = {
    ['and']      = true,
    ['break']    = true,
    ['do']       = true,
    ['else']     = true,
    ['elseif']   = true,
    ['end']      = true,
    ['false']    = true,
    ['for']      = true,
    ['function'] = true,
    ['goto']     = true,
    ['if']       = true,
    ['in']       = true,
    ['local']    = true,
    ['nil']      = true,
    ['not']      = true,
    ['or']       = true,
    ['repeat']   = true,
    ['return']   = true,
    ['then']     = true,
    ['true']     = true,
    ['until']    = true,
    ['while']    = true,
}

---@export global
local export = {}

--- 打印表的结构
---@param tbl any
---@param option? table
---@return string
function export.dump(tbl, option)
    if not option then
        option = {}
    end
    if type(tbl) ~= 'table' then
        return ('%s'):format(tbl)
    end
    local lines = {}
    local mark = {}
    local stack = {}
    lines[#lines + 1] = '{'
    local function unpack(tbl)
        local deep = #stack
        mark[tbl] = (mark[tbl] or 0) + 1
        local keys = {}
        local keymap = {}
        local integerFormat = '[%d]'
        local alignment = 0
        if #tbl >= 10 then
            local width = #tostring(#tbl)
            integerFormat = ('[%%0%dd]'):format(mathCeil(width))
        end
        for key in pairs(tbl) do
            if type(key) == 'string' then
                if not key:match('^[%a_][%w_]*$')
                    or RESERVED[key]
                    or option['longStringKey']
                then
                    keymap[key] = ('[%q]'):format(key)
                else
                    keymap[key] = ('%s'):format(key)
                end
            elseif isInteger(key) then
                keymap[key] = integerFormat:format(key)
            else
                keymap[key] = ('["<%s>"]'):format(tostring(key))
            end
            keys[#keys + 1] = key
            if option['alignment'] then
                if #keymap[key] > alignment then
                    alignment = #keymap[key]
                end
            end
        end
        local mt = getmetatable(tbl)
        if not mt or not mt.__pairs then
            if option['sorter'] then
                option['sorter'](keys, keymap)
            else
                tableSort(keys, function(a, b)
                    return keymap[a] < keymap[b]
                end)
            end
        end
        for _, key in ipairs(keys) do
            local keyWord = keymap[key]
            if option['noArrayKey']
                and isInteger(key)
                and key <= #tbl
            then
                keyWord = ''
            else
                if #keyWord < alignment then
                    keyWord = keyWord .. (' '):rep(alignment - #keyWord) .. ' = '
                else
                    keyWord = keyWord .. ' = '
                end
            end
            local value = tbl[key]
            local tp = type(value)
            local format = option['format'] and option['format'][key]
            if format then
                value = format(value, unpack, deep + 1, stack)
                tp    = type(value)
            end
            if tp == 'table' then
                if mark[value] and mark[value] > 0 then
                    lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, option['loop'] or '"<Loop>"')
                elseif deep >= (option['deep'] or mathHuge) then
                    lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, '"<Deep>"')
                else
                    lines[#lines + 1] = ('%s%s{'):format(TAB[deep + 1], keyWord)
                    stack[#stack + 1] = key
                    unpack(value)
                    stack[#stack] = nil
                    lines[#lines + 1] = ('%s},'):format(TAB[deep + 1])
                end
            elseif tp == 'string' then
                lines[#lines + 1] = ('%s%s%q,'):format(TAB[deep + 1], keyWord, value)
            elseif tp == 'number' then
                lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, (option['number'] or formatNumber)(value))
            elseif tp == 'nil' then
            else
                lines[#lines + 1] = ('%s%s%s,'):format(TAB[deep + 1], keyWord, tostring(value))
            end
        end
        mark[tbl] = mark[tbl] - 1
    end
    unpack(tbl)
    lines[#lines + 1] = '}'
    return tableConcat(lines, '\r\n')
end

---空函数
export.NOOP = function() end

---@param value any
---@return TypeGuard<table>
function export.isObject(value)
    return type(value) == 'table'
end

---@param value any
---@return TypeGuard<function>
function export.isFunction(value)
    return type(value) == 'function'
end

local function _equal(a, b, hasChecked)
    local tp1 = type(a)
    local tp2 = type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        if hasChecked[a] then
            return true
        end
        hasChecked[a] = true
        local mark = {}
        for k, v in pairs(a) do
            mark[k] = true
            local res = _equal(v, b[k])
            if not res then
                return false
            end
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    elseif tp1 == 'number' then
        if mathAbs(a - b) <= 1e-10 then
            return true
        end
        return tostring(a) == tostring(b)
    else
        return a == b
    end
end

--- 递归判断A与B是否相等
---@param valueA any
---@param valueB any
---@return boolean
function export.equal(valueA, valueB)
    local hasChecked = {}
    return _equal(valueA, valueB, hasChecked)
end

---将`source`中的元素合并到`target`中, 并返回`target`
---@param target table 目标对象
---@param source table 源对象
---@return table
function export.tableMerge(target, source)
    for k, v in pairs(source) do
        target[k] = v
    end
    return target
end

---将`b`中的数组元素合并到`a`中, 并返回`a`
---@param a any[]
---@param b any[]
---@return any[]
function export.arrayMerge(a, b)
    local len = #b
    for i = 1, len do
        a[#a + 1] = b[i]
    end
    return a
end

---创建新的绑定函数到目标对象
---@param func function 目标函数
---@param targetObj table 函数所绑定的对象
---@return function
function export.methodBind(func, targetObj)
    return function(...) return func(targetObj, ...) end
end

---判断字符串是否以指定字符串开头
---@param str string
---@param head string
---@return boolean
function export.stringStartWith(str, head)
    return str:sub(1, #head) == head
end

---判断字符串是否以指定字符串结尾
---@param str string
---@param tail string
---@return boolean
function export.stringEndWith(str, tail)
    return str:sub(- #tail) == tail
end

---裁剪字符串
---@param str string
---@param mode? '"left"'|'"right"'
---@return string
function export.trim(str, mode)
    if mode == "left" then
        return (str:gsub('^%s+', ''))
    end
    if mode == "right" then
        return (str:gsub('%s+$', ''))
    end
    return (str:match '^%s*(.-)%s*$') or ''
end

return export
