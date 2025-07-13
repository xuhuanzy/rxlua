-- 用于将可观察对象中的值收集到列表中
---@param observable Rxlua.Observable<any>
---@return table
local function toLiveList(observable)
    local list = { values = {}, completed = false, error = nil }
    observable:subscribe({
        next = function(v) table.insert(list.values, v) end,
        completed = function() list.completed = true end,
        errorResume = function(e) list.error = e end
    })
    return list
end


return {
    toLiveList = toLiveList
}
