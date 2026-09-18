// 黑盒测试：只使用包的公开 API。运行 `moon test` 执行。

///|
test "parse_json 能解析对象数组" {
  match @my_hackathon.parse_json("[{\"name\":\"张三\",\"age\":20}]") {
    Ok(json) => assert_true(json is Array(_))
    Err(msg) => fail("解析不该失败：\{msg}")
  }
}

///|
test "parse_json 能解析单个对象" {
  match @my_hackathon.parse_json("{\"name\":\"张三\"}") {
    Ok(json) => assert_true(json is Object(_))
    Err(msg) => fail("解析不该失败：\{msg}")
  }
}

///|
test "parse_json 对非法 JSON 返回错误" {
  match @my_hackathon.parse_json("{\"name\":}") {
    Ok(_) => fail("非法 JSON 不该解析成功")
    Err(msg) => assert_true(msg.length() > 0)
  }
}

///|
/// 测试辅助：转换成功时返回表格，失败直接让测试失败。
fn table_of(input : String) -> String raise {
  match @my_hackathon.json_to_markdown_table(input) {
    Ok(md) => md
    Err(msg) => fail("转换不该失败：\{msg}")
  }
}

///|
test "json_to_markdown_table 转换对象数组" {
  let input = "[{\"name\":\"张三\",\"age\":20,\"city\":\"北京\"},{\"name\":\"李四\",\"age\":22,\"city\":\"上海\"}]"
  assert_eq(
    table_of(input),
    "| name | age | city |\n| --- | --- | --- |\n| 张三 | 20 | 北京 |\n| 李四 | 22 | 上海 |\n",
  )
}

///|
test "json_to_markdown_table 三行数据" {
  let input = "[{\"name\":\"张三\",\"age\":20,\"city\":\"北京\"},{\"name\":\"李四\",\"age\":22,\"city\":\"上海\"},{\"name\":\"王五\",\"age\":21,\"city\":\"广州\"}]"
  assert_eq(
    table_of(input),
    "| name | age | city |\n| --- | --- | --- |\n| 张三 | 20 | 北京 |\n| 李四 | 22 | 上海 |\n| 王五 | 21 | 广州 |\n",
  )
}

///|
test "json_to_markdown_table 缺失的键留空" {
  let input = "[{\"name\":\"张三\",\"age\":20},{\"name\":\"李四\"}]"
  assert_eq(
    table_of(input),
    "| name | age |\n| --- | --- |\n| 张三 | 20 |\n| 李四 |  |\n",
  )
}

///|
test "json_to_markdown_table 端到端转义竖线与换行" {
  assert_eq(
    table_of("[{\"note\":\"a|b\"},{\"note\":\"第一行\\n第二行\"}]"),
    "| note |\n| --- |\n| a\\|b |\n| 第一行<br>第二行 |\n",
  )
}

///|
test "json_to_markdown_table 空数组得到空表格" {
  assert_eq(table_of("[]"), "")
}

///|
test "json_to_markdown_table 数组含非对象时报出具体类型" {
  match @my_hackathon.json_to_markdown_table("[{\"a\":1},2]") {
    Ok(md) => fail("数组里混入非对象不该成功：\{md}")
    Err(msg) => assert_true(msg.contains("数字"))
  }
}

///|
test "json_to_markdown_table 单个对象转成一行表格" {
  assert_eq(
    table_of("{\"name\":\"张三\",\"age\":20}"),
    "| name | age |\n| --- | --- |\n| 张三 | 20 |\n",
  )
}

///|
test "json_to_markdown_table 顶层是字符串时报出具体类型" {
  match @my_hackathon.json_to_markdown_table("\"just a string\"") {
    Ok(md) => fail("字符串不该转成表格：\{md}")
    Err(msg) => assert_true(msg.contains("字符串"))
  }
}

///|
test "非法 JSON 会得到中文错误信息" {
  match @my_hackathon.parse_json("[{\"a\":") {
    Ok(_) => fail("非法 JSON 不该解析成功")
    Err(msg) => assert_true(msg.contains("不完整"))
  }
}

///|
test "非法字符会带上行列位置" {
  match @my_hackathon.parse_json("[1, @]") {
    Ok(_) => fail("非法 JSON 不该解析成功")
    Err(msg) => assert_true(msg.contains("行") && msg.contains("列"))
  }
}

///|
test "json_to_markdown_table 中文键与中文值" {
  assert_eq(
    table_of("[{\"姓名\":\"张三\",\"年龄\":20}]"),
    "| 姓名 | 年龄 |\n| --- | --- |\n| 张三 | 20 |\n",
  )
}

///|
/// 测试辅助：用指定选项转换，失败直接让测试失败。
fn table_of_with(
  input : String,
  options : @my_hackathon.Options,
) -> String raise {
  match @my_hackathon.json_to_markdown_table_with(input, options) {
    Ok(md) => md
    Err(msg) => fail("转换不该失败：\{msg}")
  }
}

///|
test "json_to_markdown_table 嵌套对象默认展平成点号列" {
  assert_eq(
    table_of("[{\"name\":\"张三\",\"addr\":{\"city\":\"北京\"}}]"),
    "| name | addr.city |\n| --- | --- |\n| 张三 | 北京 |\n",
  )
}

///|
test "json_to_markdown_table 关闭展平后压成一行 JSON" {
  let no_flatten : @my_hackathon.Options = {
    ..@my_hackathon.Options::default(),
    flatten_objects: false,
  }
  assert_eq(
    table_of_with(
      "[{\"name\":\"张三\",\"addr\":{\"city\":\"北京\"}}]", no_flatten,
    ),
    "| name | addr |\n| --- | --- |\n| 张三 | {\"city\":\"北京\"} |\n",
  )
}

///|
test "展平支持多层嵌套" {
  assert_eq(
    table_of("[{\"a\":{\"b\":{\"c\":1}}}]"),
    "| a.b.c |\n| --- |\n| 1 |\n",
  )
}

///|
test "空的嵌套对象保留列但单元格为空" {
  assert_eq(table_of("[{\"addr\":{}}]"), "| addr |\n| --- |\n|  |\n")
}

///|
test "展平键与直接键冲突时直接键赢" {
  // 顶层直接写出的 a.b 优先于从 a 里展平出来的 a.b
  assert_eq(
    table_of("[{\"a\":{\"b\":1},\"a.b\":2}]"),
    "| a.b |\n| --- |\n| 2 |\n",
  )
  // 换个书写顺序，结果必须一样
  assert_eq(
    table_of("[{\"a.b\":2,\"a\":{\"b\":1}}]"),
    "| a.b |\n| --- |\n| 2 |\n",
  )
}

///|
test "数组不展平" {
  assert_eq(table_of("[{\"tags\":[1,2]}]"), "| tags |\n| --- |\n| [1,2] |\n")
}

///|
test "展平后的列同样参与表头并集与缺省留空" {
  assert_eq(
    table_of("[{\"a\":{\"x\":1}},{\"a\":{\"y\":2}}]"),
    "| a.x | a.y |\n| --- | --- |\n| 1 |  |\n|  | 2 |\n",
  )
}

///|
test "json_to_markdown_table 值里同时有竖线和换行" {
  assert_eq(
    table_of("[{\"note\":\"a|b\\nc\"}]"),
    "| note |\n| --- |\n| a\\|b<br>c |\n",
  )
}

///|
test "json_to_markdown_table 布尔与 null" {
  assert_eq(
    table_of("[{\"ok\":true,\"extra\":null}]"),
    "| ok | extra |\n| --- | --- |\n| true |  |\n",
  )
}

///|
test "json_to_markdown_table 值里的反斜杠与竖线组合" {
  // JSON 里的 \\ 解析成一个反斜杠，所以值是 a\|b；
  // 输出必须把反斜杠也转义，否则 \\ 之后的 | 会重新变成列分隔符
  assert_eq(
    table_of("[{\"note\":\"a\\\\|b\"}]"),
    "| note |\n| --- |\n| a\\\\\\|b |\n",
  )
}

///|
test "json_to_markdown_table 表头里的竖线也会被转义" {
  assert_eq(table_of("[{\"a|b\":1}]"), "| a\\|b |\n| --- |\n| 1 |\n")
}

///|
test "json_to_markdown_table 数组里含 null 时报出类型" {
  match @my_hackathon.json_to_markdown_table("[{\"a\":1},null]") {
    Ok(md) => fail("不该成功：\{md}")
    Err(msg) => assert_true(msg.contains("null"))
  }
}

///|
test "json_to_markdown_table 全是空对象时返回空串" {
  assert_eq(table_of("[{},{}]"), "")
}

///|
test "json_to_markdown_table 单个空对象返回空串" {
  assert_eq(table_of("{}"), "")
}

///|
test "json_to_markdown_table_with 可以按字典序排列表头" {
  let options : @my_hackathon.Options = {
    ..@my_hackathon.Options::default(),
    sort_columns: true,
  }
  match
    @my_hackathon.json_to_markdown_table_with(
      "[{\"name\":\"张三\",\"age\":20,\"city\":\"北京\"}]", options,
    ) {
    Ok(md) =>
      assert_eq(
        md, "| age | city | name |\n| --- | --- | --- |\n| 20 | 北京 | 张三 |\n",
      )
    Err(msg) => fail("转换不该失败：\{msg}")
  }
}

///|
test "嵌套过深会给出提示" {
  let mut input = ""
  let mut i = 0
  while i < 1030 {
    input = input + "["
    i = i + 1
  }
  let mut j = 0
  while j < 1030 {
    input = input + "]"
    j = j + 1
  }
  match @my_hackathon.parse_json(input) {
    Ok(_) => fail("这么深的嵌套不该解析成功")
    Err(msg) => assert_true(msg.contains("嵌套"))
  }
}
