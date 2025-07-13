---@namespace Luakit

---@class TestSuite
---@field name string
---@field tests table[]
---@field suites TestSuite[]
---@field parent TestSuite?
local TestSuite = {}
TestSuite.__index = TestSuite

---创建新的测试套件
---@param name string
---@param parent TestSuite?
---@return TestSuite
function TestSuite.new(name, parent)
    return setmetatable({
        name = name,
        tests = {},
        suites = {},
        parent = parent
    }, TestSuite)
end

---@class TestFramework
local TestFramework = {}
TestFramework.__index = TestFramework

---@class ExpectObject
---@field value any
---@field isNot boolean
local ExpectObject = {}
ExpectObject.__index = ExpectObject

-- 测试统计 (enhanced for suites)
local stats = {
    total = 0,
    passed = 0,
    failed = 0,
    tests = {},
    rootSuite = TestSuite.new("Root", nil),
    currentSuite = nil -- track current suite
}

-- 初始化当前套件为根套件
stats.currentSuite = stats.rootSuite

-- 嵌套描述调用的套件栈
local suiteStack = {}

---将值转换为可读的字符串格式
---@param value any
---@param indent? number 缩进级别
---@param visited? table 已访问的表，用于避免循环引用
---@param compact? boolean 是否使用紧凑格式
---@return string
local function valueToString(value, indent, visited, compact)
    indent = indent or 0
    visited = visited or {}
    compact = compact == nil and true or compact -- 默认使用紧凑格式

    local valueType = type(value)

    if valueType == "nil" then
        return "nil"
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return string.format('"%s"', value)
    elseif valueType == "function" then
        return "function"
    elseif valueType == "thread" then
        return "thread"
    elseif valueType == "userdata" then
        return "userdata"
    elseif valueType == "table" then
        -- 避免循环引用
        if visited[value] then
            return "[Circular Reference]"
        end
        visited[value] = true

        -- 检查是否为数组
        local isArray = true
        local arrayLen = #value
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or k > arrayLen then
                isArray = false
                break
            end
        end

        -- 判断是否应该使用紧凑格式
        local shouldUseCompact = compact and indent == 0
        if shouldUseCompact then
            -- 检查表的复杂度
            local totalItems = 0
            local totalNestedTable = 0
            local maxDepth = 10

            if isArray then
                totalItems = arrayLen
                for i = 1, arrayLen do
                    if type(value[i]) == "table" then
                        totalNestedTable = totalNestedTable + 1
                        if totalNestedTable > maxDepth then
                            break
                        end
                    end
                end
            else
                for k, v in pairs(value) do
                    totalItems = totalItems + 1
                    if type(v) == "table" then
                        totalNestedTable = totalNestedTable + 1
                        if totalNestedTable > maxDepth then
                            break
                        end
                    end
                end
            end

            -- 如果项目少且没有嵌套表，使用单行格式
            if totalItems <= 20 and totalNestedTable < 3 then
                if isArray and arrayLen > 0 then
                    local items = {}
                    for i = 1, arrayLen do
                        table.insert(items, valueToString(value[i], 0, visited, true))
                    end
                    visited[value] = nil
                    return "[" .. table.concat(items, ", ") .. "]"
                else
                    local items = {}
                    local keys = {}
                    for k, _ in pairs(value) do
                        table.insert(keys, k)
                    end
                    table.sort(keys, function(a, b)
                        return tostring(a) < tostring(b)
                    end)

                    for _, k in ipairs(keys) do
                        local keyStr = type(k) == "string" and k or string.format("[%s]", valueToString(k, 0, {}, true))
                        local valueStr = valueToString(value[k], 0, visited, true)
                        table.insert(items, keyStr .. ": " .. valueStr)
                    end
                    visited[value] = nil
                    return "{" .. table.concat(items, ", ") .. "}"
                end
            end
        end

        -- 使用多行格式
        local result = {}
        ---@diagnostic disable-next-line: param-type-not-match
        local indentStr = string.rep("  ", indent)
        ---@diagnostic disable-next-line: param-type-not-match
        local nextIndentStr = string.rep("  ", indent + 1)

        if isArray and arrayLen > 0 then
            -- 数组格式
            table.insert(result, "[")
            for i = 1, arrayLen do
                local valueStr = valueToString(value[i], indent + 1, visited, false)
                if i == arrayLen then
                    table.insert(result, nextIndentStr .. valueStr)
                else
                    table.insert(result, nextIndentStr .. valueStr .. ",")
                end
            end
            table.insert(result, indentStr .. "]")
        else
            -- 对象格式
            table.insert(result, "{")
            local keys = {}
            for k, _ in pairs(value) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)

            for i, k in ipairs(keys) do
                local keyStr = type(k) == "string" and k or string.format("[%s]", valueToString(k, 0, {}, true))
                local valueStr = valueToString(value[k], indent + 1, visited, false)
                if i == #keys then
                    table.insert(result, nextIndentStr .. keyStr .. ": " .. valueStr)
                else
                    table.insert(result, nextIndentStr .. keyStr .. ": " .. valueStr .. ",")
                end
            end
            table.insert(result, indentStr .. "}")
        end

        visited[value] = nil -- 清理访问记录
        return table.concat(result, "\n")
    else
        return tostring(value)
    end
end

---推入套件到栈中
---@param suite TestSuite
local function pushSuiteStack(suite)
    table.insert(suiteStack, suite)
    stats.currentSuite = suite
end

---从栈中弹出套件
local function popSuiteStack()
    if #suiteStack > 0 then
        stats.currentSuite = table.remove(suiteStack)
    else
        stats.currentSuite = stats.rootSuite
    end
end

---创建期望对象
---@param value any
---@return ExpectObject
function TestFramework.expect(value)
    local obj = setmetatable({
        value = value,
        isNot = false -- 添加标志量
    }, ExpectObject)
    return obj
end

---检查值是否相等
---@param expected any
---@return boolean
function ExpectObject:toBe(expected)
    local result = self.value == expected

    -- 根据 isNot 标志决定是否取反
    if self.isNot then
        result = not result
    end

    if result then
        return true
    else
        if self.isNot then
            error(
                string.format("Expected %s not to be %s", valueToString(self.value), valueToString(expected)),
                2
            )
        else
            error(string.format("Expected %s to be %s", valueToString(self.value), valueToString(expected)),
                2
            )
        end
    end
end

---检查值是否不相等
---@param expected any
---@return boolean
function ExpectObject:notToBe(expected)
    local result = self.value ~= expected

    -- 根据 isNot 标志决定是否取反
    if self.isNot then
        result = not result
    end

    if result then
        return true
    else
        if self.isNot then
            error(string.format("Expected %s to be %s", valueToString(self.value), valueToString(expected)))
        else
            error(string.format("Expected %s not to be %s", valueToString(self.value), valueToString(expected)))
        end
    end
end

---深度比较两个值
---@param a any
---@param b any
---@return boolean
local function deepEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    -- 比较数组长度
    local lenA, lenB = #a, #b
    if lenA ~= lenB then
        return false
    end

    -- 比较数组元素
    for i = 1, lenA do
        if not deepEqual(a[i], b[i]) then
            return false
        end
    end

    -- 比较表的键值对
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then
            return false
        end
    end

    for k, v in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end



---检查值是否深度相等(用于数组和对象比较)
---@param expected any
---@return boolean
function ExpectObject:toEqual(expected)
    local result = deepEqual(self.value, expected)

    -- 根据 isNot 标志决定是否取反
    if self.isNot then
        result = not result
    end

    if result then
        return true
    else
        if self.isNot then
            error(string.format("Expected %s not to equal %s", valueToString(expected), valueToString(self.value)), 2)
        else
            error(string.format("Expected %s to equal %s", valueToString(expected), valueToString(self.value)), 2)
        end
    end
end

---检查函数是否抛出错误
---@param expectedMessage? string 可选的错误消息
---@return boolean
function ExpectObject:toThrow(expectedMessage)
    if type(self.value) ~= "function" then
        error("Expected value to be a function")
    end

    local success, err = pcall(self.value)
    local didThrow = not success

    -- 根据 isNot 标志决定是否取反
    local result = self.isNot and not didThrow or not self.isNot and didThrow

    if not result then
        if self.isNot then
            error("Expected function not to throw an error, but it did")
        else
            error("Expected function to throw an error, but it didn't")
        end
    end

    -- 如果期望抛出错误且确实抛出了，检查错误消息
    if didThrow and not self.isNot and expectedMessage and not string.find(tostring(err), expectedMessage, 1, true) then
        error(string.format("Expected function to throw error containing '%s', but got '%s'", expectedMessage,
            tostring(err)))
    end

    return true
end

---检查函数是否被调用过
---@return boolean
function ExpectObject:toHaveBeenCalled()
    -- 检查 value 是否有 calls 属性来判断调用次数
    local calls = 0
    if type(self.value) == "table" and self.value.calls then
        calls = self.value.calls
    elseif type(self.value) == "function" then
        calls = self.value()
    else
        -- 如果没有 calls 属性，则认为未被调用
        calls = 0
    end

    local wasCalled = calls > 0

    -- 根据 isNot 标志决定是否取反
    local result = self.isNot and not wasCalled or not self.isNot and wasCalled

    if result then
        return true
    else
        if self.isNot then
            error(string.format("Expected function not to have been called, but it was called %d times", calls))
        else
            error("Expected function to have been called, but it was not called")
        end
    end
end

---反转期望
---@return ExpectObject
function ExpectObject:not_()
    self.isNot = true
    return self
end

---运行测试用例
---@param name string 测试名称
---@param testFn function 测试函数
function TestFramework.test(name, testFn)
    stats.total = stats.total + 1

    local success, err = pcall(testFn)

    -- 计算当前套件的嵌套深度来确定缩进
    local indent = ""
    local current = stats.currentSuite
    while current and current.name ~= "Root" do
        indent = "  " .. indent
        ---@cast current.parent -?
        current = current.parent
    end

    if success then
        stats.passed = stats.passed + 1
        local output = string.format("%s✓ %s", indent, name)
        print(output)
        io.flush()
    else
        stats.failed = stats.failed + 1
        local output = string.format("%s✗ %s", indent, name)
        print(output)
        print(string.format("%s  Error: %s", indent, tostring(err)))
        io.flush()
    end

    -- Store test result in both global stats and current suite
    local testResult = {
        name = name,
        success = success,
        error = err
    }

    table.insert(stats.tests, testResult)
    table.insert(stats.currentSuite.tests, testResult)
end

---创建测试套件
---@param name string 套件名称
---@param suiteFn function 套件函数
function TestFramework.describe(name, suiteFn)
    -- 创建新的套件作为当前套件的子套件
    local newSuite = TestSuite.new(name, stats.currentSuite)
    table.insert(stats.currentSuite.suites, newSuite)

    -- 计算当前的嵌套深度来确定缩进
    local indent = ""
    local current = stats.currentSuite
    while current and current.name ~= "Root" do
        indent = "  " .. indent
        ---@cast current.parent -?
        current = current.parent
    end

    print(string.format("%s%s", indent, name))
    io.flush() -- 确保输出立即显示

    -- 保存当前suite，然后切换到新suite
    table.insert(suiteStack, stats.currentSuite)
    stats.currentSuite = newSuite

    -- 执行套件
    suiteFn()

    -- 恢复到父级suite
    popSuiteStack()
end

-- 打印套件层级结构
---@param suite TestSuite
---@param indent string
local function printSuiteHierarchy(suite, indent)
    if suite.name ~= "Root" then
        print(string.format("%s%s", indent, suite.name))
        indent = indent .. "  "
    end

    -- 打印此套件中的测试
    for _, test in ipairs(suite.tests) do
        local status = test.success and "✓" or "✗"
        print(string.format("%s%s %s", indent, status, test.name))
        if not test.success then
            print(string.format("%s  Error: %s", indent, test.error))
        end
    end

    -- 打印子套件
    for _, childSuite in ipairs(suite.suites) do
        printSuiteHierarchy(childSuite, indent)
    end
end

---显示测试结果
function TestFramework.testPrintStats()
    print("\n" .. string.rep("=", 50))
    print("测试结果统计:")
    print(string.format("总计: %d", stats.total))
    print(string.format("通过: %d", stats.passed))
    print(string.format("失败: %d", stats.failed))

    -- 只有当存在describe块时才显示层级结构
    local hasDescribeBlocks = #stats.rootSuite.suites > 0
    if hasDescribeBlocks then
        print("\n测试层级结构:")
        printSuiteHierarchy(stats.rootSuite, "")
    end

    if stats.failed > 0 then
        print("\n失败的测试:")
        for _, test in ipairs(stats.tests) do
            if not test.success then
                print(string.format("  - %s: %s", test.name, test.error))
            end
        end
    end

    print(string.rep("=", 50))

    -- 重置统计
    stats.total = 0
    stats.passed = 0
    stats.failed = 0
    stats.tests = {}
    stats.rootSuite = TestSuite.new("Root", nil)
    stats.currentSuite = stats.rootSuite
    -- Clear suite stack
    suiteStack = {}
end

return TestFramework
