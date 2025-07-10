---@namespace Luakit

local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local type = type
local next = next
local rawset = rawset
local _errorHandler = error
local tableInsert = table.insert
local debugGetInfo = debug.getinfo

---@export
---@class Class
local Class = {}

---记录了所有已声明的类
---@type table<string, Class.Base>
local _classMap = {}

---为已有构造函数创建的类型别名
---@type table<string, function>
local _aliasMap = {}

---@type table<string, Class.Config>
local _classConfigMap = {}

local NOOP = function() end -- 空函数

---@class Class.Base<T>
---@field public  __init?     fun(self: any, ...) 构造函数
---@field public  __del?      fun(self: any) 析构函数
---@field public  __alloc?    fun(self: any) 直接`class(...)`会调用该函数, 但并没有为其分配实例.
---@field package __call      fun(self: any, ...): any 调用函数
---@field package __name      string 类名
---@field package __getter    table<string, fun(self: any): any> 所有获取器
---@field package __setter    table<string, fun(self: any, value: any): any> 所有设置器
---@field package __index     any
---@field package __newindex  any

---@alias Class.Config.ExtendsCallData { name: string, init?: fun(self: any, super: (fun(...): Class.Base), ...) }

---@class Class.Config
---@field private name         string
---@field package extendsMap   table<string, boolean> 记录了该类扩展的类(包含父类)
---@field package extendsCalls Class.Config.ExtendsCallData[] 记录了所有扩展的类的初始化信息
---@field package extendsKeys  table<string, boolean> 记录该类已继承的所有字段
---@field package superClass?  Class.Base 记录了父类, 需要注意的是 父类是唯一的, 但可以存在多个扩展类(这里包含了父类)
---@field package initCalls?   false|fun(...)[] 初始化函数调用链, 如果为 false 则表示无需初始化, 为`nil`则表示还未计算
---@field package circularCheckDone? boolean 是否已完成循环继承检查
local ClassConfigMeta = {}

---获取指定类的配置, 如果未配置, 则创建一个配置.
---@param name string
---@return Class.Config
local function getConfig(name)
    local config = _classConfigMap[name]
    if not config then
        config = setmetatable({ name = name }, { __index = ClassConfigMeta })
        _classConfigMap[name] = config
    end
    ---@diagnostic disable-next-line: return-type-mismatch
    return config
end

---检查循环继承（仅检查一次并缓存结果）
---@package
---@param visited? table<string, boolean> 已访问的类名
function ClassConfigMeta:_checkCircularInheritance(visited)
    if self.circularCheckDone then
        return
    end

    visited = visited or {}
    if visited[self.name] then
        error(('class %q has circular inheritance'):format(self.name))
    end

    visited[self.name] = true

    -- 递归检查所有扩展的类
    if self.extendsCalls then
        for _, callData in ipairs(self.extendsCalls) do
            local parentConfig = getConfig(callData.name)
            parentConfig:_checkCircularInheritance(visited)
        end
    end

    visited[self.name] = nil
    self.circularCheckDone = true
end

---延迟创建扩展相关的表
---@param self Class.Config
local function ensureExtendsTables(self)
    if not self.extendsMap then
        self.extendsMap = {}
        self.extendsCalls = {}
        self.extendsKeys = {}
    end
end

---清除当前类的缓存（在扩展关系变化时调用）
---@private
function ClassConfigMeta:clearCache()
    self.circularCheckDone = false
    self.initCalls = nil
    ClassConfigMeta.clearInheritanceCache()
end

---启用 getter 和 setter 方法.
---@param class Class.Base 类
local function enableGetterAndSetter(class)
    if class.__getter then
        return
    end
    local __getter = {}
    local __setter = {}
    class.__getter = __getter
    class.__setter = __setter

    ---@package
    class.__index = function(self, key)
        local getter = __getter[key]
        if getter then
            return getter(self)
        end
        return class[key]
    end

    ---@package
    class.__newindex = function(self, key, value)
        local setter = __setter[key]
        if setter then
            setter(self, value)
        else
            rawset(self, key, value)
        end
    end
end


-- 复制父类字段到子类
---@param childClass Class.Base 子类
---@param childConfig Class.Config 子类配置
---@param parentClass Class.Base 父类
---@param parentName string 父类名称
local function copyInheritedMembers(childClass, childConfig, parentClass, parentName)
    -- 复制普通字段（跳过双下划线开头的元方法）
    for key, value in pairs(parentClass) do
        local canCopy = (not childClass[key] or childConfig.extendsKeys[key])
            and not key:match('^__')
        if canCopy then
            childConfig.extendsKeys[key] = true
            childClass[key] = value
        end
    end

    -- 如果父类有 getter 和 setter，且子类没有，则为子类启用 getter 和 setter
    if parentClass.__getter then
        if not childClass.__getter then
            enableGetterAndSetter(childClass)
        end

        -- 复制 getter 方法
        for key, getter in pairs(parentClass.__getter) do
            if not childClass.__getter[key] or childConfig.extendsKeys[key] then
                childConfig.extendsKeys[key] = true
                childClass.__getter[key] = getter
            end
        end

        -- 复制 setter 方法
        for key, setter in pairs(parentClass.__setter) do
            if not childClass.__setter[key] or childConfig.extendsKeys[key] then
                childConfig.extendsKeys[key] = true
                childClass.__setter[key] = setter
            end
        end
    end
end

---@generic Extends
---@param parentName `Extends` 父类名称
---@param initFunc? fun(self: self, super: Extends) 初始化函数. 第二个参数是父类初始化包装函数, 调用后将执行父类的初始化函数, 然后返回父类的配置.
function ClassConfigMeta:extends(parentName, initFunc)
    local currentClass = _classMap[self.name]
    local parentClass = _classMap[parentName]

    -- 验证父类存在性
    if not parentClass then
        _errorHandler(('class %q not found'):format(parentName))
    end

    -- 验证初始化函数类型
    if type(initFunc) ~= 'nil' and type(initFunc) ~= 'function' then
        _errorHandler('init must be nil or function')
    end

    -- 延迟创建扩展相关的表
    ensureExtendsTables(self)

    -- 清除缓存（因为扩展关系将发生变化）
    self:clearCache()

    -- 标记扩展关系
    self.extendsMap[parentName] = true

    -- 复制父类的字段与 getter 和 setter
    copyInheritedMembers(currentClass, self, parentClass, parentName)

    -- 记录父类的初始化方法
    do
        local isRewrite

        -- 检查是否已记录该父类, 如果是则更新
        for i = 1, #self.extendsCalls do
            local callData = self.extendsCalls[i]
            if callData.name == parentName then
                callData.init = initFunc
                isRewrite = true
                break
            end
        end

        if not isRewrite then
            tableInsert(self.extendsCalls, {
                init = initFunc,
                name = parentName,
            })
        end
    end

    -- 检查是否需要显式初始化
    if not initFunc then
        -- 如果父类没有构造函数, 则无需处理
        if not parentClass.__init then
            return
        end

        -- 获取父类构造函数的参数数量
        local funcInfo = debugGetInfo(parentClass.__init, 'u')
        if funcInfo.nparams <= 1 then -- 1 是 self 参数
            return
        end

        -- 如果没有传入初始化函数且父类有显式参数的构造函数，则需要显式初始化
        _errorHandler(('must call super for extends "%s"'):format(parentName))
    end
end

---@private
---@param obj table 要初始化的对象
---@param className string 类名
---@param ... any 构造函数参数
local function runInit(obj, className, ...)
    local classConfig = getConfig(className)
    local initCalls = classConfig.initCalls

    -- 如果已确定无需初始化，直接返回
    if initCalls == false then
        return
    end

    -- 如果还没有缓存初始化调用链，则构建它
    if not initCalls then
        -- 预先检查循环继承（仅检查一次）
        classConfig:_checkCircularInheritance()

        -- 收集所有需要的初始化函数
        initCalls = {}

        local function collectInitCalls(currentClassName)
            ---@cast initCalls - nil
            local currentClass = _classMap[currentClassName]
            local currentConfig = getConfig(currentClassName)

            -- 先收集扩展类的初始化函数
            if currentConfig.extendsCalls then
                for _, callData in ipairs(currentConfig.extendsCalls) do
                    if callData.init then
                        -- 创建包装函数来处理父类初始化
                        initCalls[#initCalls + 1] = function(instance, ...)
                            local firstCall = true -- 避免重复调用父类初始化函数
                            ---@cast callData.init - nil
                            callData.init(instance, function(...)
                                if firstCall then
                                    firstCall = false
                                    runInit(instance, callData.name, ...)
                                end
                                return _classMap[callData.name]
                            end, ...)
                        end
                    else
                        -- 该父类没有自定义初始化函数，递归收集其依赖
                        collectInitCalls(callData.name)
                    end
                end
            end

            -- 最后收集当前类自己的初始化函数
            if currentClass.__init then
                initCalls[#initCalls + 1] = currentClass.__init
            end
        end

        collectInitCalls(className)

        -- 缓存结果
        if #initCalls == 0 then
            classConfig.initCalls = false
            --无需初始化, 直接返回
            return
        else
            classConfig.initCalls = initCalls
            initCalls = classConfig.initCalls
        end
    end

    -- 执行所有初始化函数
    for i = 1, #initCalls do
        initCalls[i](obj, ...)
    end
end

---@private
---@param obj table 要析构的对象
---@param className string 类名
local function runDel(obj, className)
    local currentClass = _classMap[className]
    if not currentClass then
        return
    end

    local classConfig = getConfig(className)

    -- 先析构所有扩展的类
    if classConfig.extendsCalls then
        for _, callData in ipairs(classConfig.extendsCalls) do
            runDel(obj, callData.name)
        end
    end

    -- 最后析构当前类
    if currentClass.__del then
        currentClass.__del(obj)
    end
end


---实例化一个类, 但并没有调用构造函数.
---@generic T
---@param name `T`|T 类名
---@param tbl? table
---@return T
local function new(name, tbl)
    name = name.__name or name ---@cast name -table
    local class = _classMap[name]
    if not class then
        local aliasCreator = _aliasMap[name]
        if aliasCreator then
            return function(...)
                local instance = aliasCreator(...)
                instance.__class__ = name
                return instance
            end
        end
        _errorHandler(('class %q not found'):format(name))
    end

    if not tbl then
        tbl = { __class__ = name }
    else
        tbl.__class__ = name
    end

    return setmetatable(tbl, class)
end



-- 返回的`class`调用`class(...)`可以执行`__alloc`方法, 但并没有做预初始化.
local allocMeta = {
    __call = function(self, ...)
        if not self.__alloc then
            error(('class %q can not be instantiated'):format(self.__name))
            return self
        end
        return self:__alloc(...)
    end,
}


---@class Class.DeclareOptions
---@field enableGetterAndSetter? boolean 启用 get 和 set 方法.
---@field super? string|table 父类的名称或定义表. 需要在初始化时显式调用父类初始化方法进行初始化.
---@field enableAlloc? boolean 开启时, 调用`class(...)`会执行`__alloc`方法, 但并没有做预初始化. 默认 false.
---@field extends? {[integer]: string|table} 扩展的类名或定义表集合. 仅能设置无参构造函数的类. 例如: `extends = { 'A', B }`


-- 定义一个类
---@generic T, Super
---@param name `T` 类名
---@param superOrOptions? `Super`| Class.DeclareOptions | table 类的声明选项, 当提供字符串或定义表时默认为`super`
---@return T
---@return Class.Config
function Class.declare(name, superOrOptions)
    local config = getConfig(name)
    if _classMap[name] then -- 如果已声明, 则返回已声明的类和配置
        return _classMap[name], config
    end

    local options = superOrOptions or {}
    if type(superOrOptions) == 'string' then
        -- 如果是字符串, 当作父类名处理 (快捷方式)
        options = { super = superOrOptions }
        ---@diagnostic disable-next-line: undefined-field
    elseif type(superOrOptions) == 'table' and superOrOptions.__name then
        ---@diagnostic disable-next-line: undefined-field
        options = { super = superOrOptions.__name }
    end
    ---@cast options Class.DeclareOptions

    ---@class (constructor) Class.Base<T>
    local class = {
        __name = name,
        ---@package
        __call = function(self, ...)
            runInit(self, name, ...)
            return self
        end,
    }

    if options.enableGetterAndSetter then
        enableGetterAndSetter(class)
    else
        class.__index = class
    end

    if options.enableAlloc then
        -- 使返回的`class`直接`class(...)`可以实例化
        setmetatable(class, allocMeta)
    end

    _classMap[name] = class

    -- 设置父类
    if options.super then
        local superClass = _classMap[options.super]
        if superClass then
            if class == superClass then
                _errorHandler(('class %q can not inherit itself'):format(name))
            end
            config.superClass = superClass
            config:extends(superClass.__name)
        else
            _errorHandler(('super class %q not found'):format(options.super))
        end
    end
    -- 设置扩展类
    if options.extends then
        for _, extendsName in ipairs(options.extends) do
            config:extends(extendsName.__name or extendsName)
        end
    end

    return class, config
end

---获取一个类
---@generic T: string
---@param name `T`
---@return Class.Base<T>
function Class.get(name)
    return _classMap[name]
end

---为非`Class.declare`声明的类创建类型别名, 使其可以被`Class.new`实例化.
---@param name string 类型别名
---@param creator function 构造函数, 该函数没有`self`参数, 且必须返回一个实例.
function Class.alias(name, creator)
    _aliasMap[name] = creator
end

---析构一个实例
---@param obj table
function Class.delete(obj)
    if obj.__deleted__ then
        return
    end
    obj.__deleted__ = true
    local name = obj.__class__
    if not name then
        _errorHandler('can not delete undeclared class : ' .. tostring(obj))
    end

    runDel(obj, name)
end

---获取类的名称
---@param obj any
---@return string?
local function getClassType(obj)
    if type(obj) ~= 'table' then
        return nil
    end
    return obj.__class__
end

---判断一个实例是否有效
---@param obj table
---@return boolean
function Class.isValid(obj)
    if not obj.__class__ then
        return false
    end
    return not obj.__deleted__
end

---扩展一个类. <br>
---如果传入`init`参数, 则会由该函数控制父类的初始化. 并且你必须调用第二个参数`super()`才能触发父类的初始化流程. <br>
---如果未传入`init`参数, 则会递归寻找父类链上的具有显式`init`函数的类尝试初始化.
---@generic Class
---@generic Extends
---@param name `Class`|table 类名
---@param extendsName `Extends`|table 扩展类名
---@param init? fun(self: Class, super: Extends, ...) 初始化函数. 第二个参数是父类初始化包装函数, 调用后将执行父类的初始化函数, 然后返回父类的配置.
function Class.extends(name, extendsName, init)
    name = name.__name or name ---@cast name -table
    extendsName = extendsName.__name or extendsName ---@cast extendsName -table
    getConfig(name):extends(extendsName, init)
end

---@param errorHandler fun(msg: string)
function Class.setErrorHandler(errorHandler)
    _errorHandler = errorHandler
end

do
    ---@type table<string, table<string, boolean>>
    local inheritanceChains = {}

    ---@param className string
    ---@return table<string, boolean>
    local function buildInheritanceChain(className)
        local chain = inheritanceChains[className]
        if chain then
            return chain
        end

        chain = { [className] = true }
        local config = _classConfigMap[className]

        if config then
            if config.extendsMap then
                for extendName in pairs(config.extendsMap) do
                    local extendChain = buildInheritanceChain(extendName)
                    for parentName in pairs(extendChain) do
                        chain[parentName] = true
                    end
                end
            end
        end

        inheritanceChains[className] = chain
        return chain
    end

    ---@param obj table
    ---@param targetName string|table
    ---@return boolean
    function Class.instanceof(obj, targetName)
        if type(obj) ~= 'table' or (not obj.__class__) then
            return false
        end

        if type(targetName) == 'table' then
            if targetName.__name then
                targetName = targetName.__name
            else
                error(('class %q not found'):format(targetName))
            end
        end

        local chain = buildInheritanceChain(obj.__class__)
        return chain[targetName] == true
    end

    ---@private
    function ClassConfigMeta.clearInheritanceCache()
        if next(inheritanceChains) then
            inheritanceChains = {}
        end
    end
end

-- 刷新指定父类的所有子类继承关系, 该刷新只会对第一层子类生效.
---@param parentClass string|table 父类名称或父类对象
function Class.refreshInheritance(parentClass)
    local parentName = parentClass.__name or parentClass
    if type(parentName) ~= 'string' then
        _errorHandler('`parentClass` must be a class or class name')
        return
    end

    local parent = _classMap[parentName]
    if not parent then
        _errorHandler(('parent class %q not found'):format(parentName))
        return
    end

    -- 动态查找第一层子类（遍历 _classConfigMap）
    for childName, childConfig in pairs(_classConfigMap) do
        if childConfig.extendsMap and childConfig.extendsMap[parentName] then
            local childClass = _classMap[childName]
            if childClass then
                -- 复制父类的新方法到子类
                copyInheritedMembers(childClass, childConfig, parent, parentName, true)
            end
        end
    end
end

---获取一个类的父类
---@param class table
---@return Class.Base?
function Class.super(class)
    if not class.__name then
        return nil
    end
    local config = getConfig(class.__name)
    return config and config.superClass
end

Class.getConfig = getConfig
Class.new       = new
Class.type      = getClassType
return Class
