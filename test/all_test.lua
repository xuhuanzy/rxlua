-- 计算加载需要的内存
local count = collectgarbage("count")
local Rxlua = require("rxlua")
local memory = collectgarbage("count") - count


local TestFramework = require("luakit.test")

require("test.behaviorSubject_test")
require('test.replaySubject_test')
require('test.subject_test')
require('test.reactiveProperty_test')


---#region factories

require('test.factories.fromEvent_test')
require('test.factories.of_test')
require('test.factories.range_test')
require('test.factories.merge_test')

---#endregion



---#region operators

require('test.operators.map_test')
require('test.operators.skip_test')
require('test.operators.take_test')
require('test.operators.where_test')
require('test.operators.distinct_test')
require('test.operators.distinctUntilChanged_test')
require('test.internal.fakeTimeProvider_test')

require('test.operators.debounce_test')
require('test.operators.throttleFirst_test')
require('test.operators.throttleFirstLast_test')
require('test.operators.throttleLast_test')
require('test.operators.timeInterval_test')
require('test.operators.timeout_test')
require('test.operators.tap_test')
require('test.operators.delay_test')
require('test.operators.index_test')
require('test.operators.scan_test')
require('test.operators.count_test')
require('test.operators.min_test')
require('test.operators.max_test')





---#endregion


TestFramework.testPrintStats()
print("加载 Rxlua 需要 " .. memory .. " KB 内存")
