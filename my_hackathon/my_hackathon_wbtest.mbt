// 白盒测试：可以访问包内的私有函数。

///|
test "escape_cell 转义竖线" {
  assert_eq(escape_cell("a|b"), "a\\|b")
}

///|
test "escape_cell 把换行转成 br 标签" {
  assert_eq(escape_cell("第一行\n第二行"), "第一行<br>第二行")
}

///|
test "escape_cell 丢弃回车符" {
  assert_eq(escape_cell("a\r\nb"), "a<br>b")
}

///|
test "escape_cell 普通文本原样返回" {
  assert_eq(escape_cell("张三"), "张三")
}

///|
test "escape_cell 空串返回空串" {
  assert_eq(escape_cell(""), "")
}

///|
test "escape_cell 转义反斜杠" {
  // 输入 a\b（3 个字符）→ 输出 a\\b（4 个字符）
  assert_eq(escape_cell("a\\b"), "a\\\\b")
}

///|
test "escape_cell 反斜杠紧跟竖线" {
  // 输入 a\|b → 反斜杠和竖线都要转义，输出 a\\\|b
  assert_eq(escape_cell("a\\|b"), "a\\\\\\|b")
}

///|
test "render_row 拼接并转义单元格" {
  assert_eq(render_row(["姓名", "a|b"]), "| 姓名 | a\\|b |")
}

///|
test "render_row 单列" {
  assert_eq(render_row(["仅一列"]), "| 仅一列 |")
}

///|
/// 测试辅助：渲染一张两列的表，用来检查分隔行。
fn one_row_table(alignment : Alignment) -> String {
  let headers : Array[String] = ["a", "b"]
  let rows : Array[Map[String, Json]] = [
    Map([("a", Json::null()), ("b", Json::null())]),
  ]
  render_table(headers, rows, alignment)
}

///|
test "render_table 左对齐的分隔行是 ---" {
  assert_true(one_row_table(Left).contains("| --- | --- |"))
}

///|
test "render_table 居中对齐的分隔行是 :---:" {
  assert_true(one_row_table(Center).contains("| :---: | :---: |"))
}

///|
test "render_table 右对齐的分隔行是 ---:" {
  assert_true(one_row_table(Right).contains("| ---: | ---: |"))
}

///|
test "Options::default 的三项默认值" {
  let options = Options::default()
  assert_true(options.flatten_objects)
  assert_true(options.alignment == Left)
  assert_false(options.sort_columns)
}

///|
/// 测试辅助：把 JSON 文本解析成「对象数组」，模拟 collect_keys 的真实输入。
fn rows_of(input : String) -> Array[Map[String, Json]] raise {
  match parse_json(input) {
    Ok(Array(arr)) => {
      let rows : Array[Map[String, Json]] = []
      for item in arr {
        match item {
          Object(obj) => rows.push(obj)
          _ => fail("测试数据里出现了非对象元素")
        }
      }
      rows
    }
    Ok(_) => fail("测试数据应当是数组")
    Err(msg) => fail("测试数据解析失败：\{msg}")
  }
}

///|
test "collect_keys 合并多个对象的键并保留出现顺序" {
  let keys = collect_keys(
    rows_of("[{\"name\":\"张三\"},{\"age\":20,\"name\":\"李四\"}]"),
  )
  assert_eq(keys, ["name", "age"])
}

///|
test "collect_keys 排序开关打开时按字典序" {
  let keys = collect_keys(
    rows_of("[{\"name\":\"张三\"},{\"age\":20,\"name\":\"李四\"}]"),
    sort=true,
  )
  assert_eq(keys, ["age", "name"])
}

///|
test "collect_keys 保留只在后面出现的键" {
  let keys = collect_keys(
    rows_of("[{\"name\":\"张三\"},{\"city\":\"北京\"}]"),
  )
  assert_eq(keys, ["name", "city"])
}

///|
test "collect_keys 对空数组返回空表头" {
  let empty : Array[String] = []
  assert_eq(collect_keys(rows_of("[]")), empty)
}

///|
test "collect_keys 默认按各键首次出现的先后排列" {
  let keys = collect_keys(rows_of("[{\"b\":1,\"a\":2},{\"c\":3}]"))
  assert_eq(keys, ["b", "a", "c"])
}

///|
test "collect_keys 打开排序后结果与键出现顺序无关" {
  let a = collect_keys(rows_of("[{\"b\":1,\"a\":2},{\"c\":3}]"), sort=true)
  let b = collect_keys(rows_of("[{\"c\":3},{\"a\":2,\"b\":1}]"), sort=true)
  assert_eq(a, b)
}

///|
test "collect_keys 处理中文键时结果稳定" {
  let a = collect_keys(rows_of("[{\"姓名\":\"张三\",\"年龄\":20}]"))
  let b = collect_keys(rows_of("[{\"姓名\":\"张三\",\"年龄\":20}]"))
  assert_eq(a, b)
  assert_eq(a.length(), 2)
}

///|
/// 测试辅助：解析出单个 JSON 值。
fn json_of(input : String) -> Json raise {
  match parse_json(input) {
    Ok(json) => json
    Err(msg) => fail("测试数据解析失败：\{msg}")
  }
}

///|
test "json_to_cell 把 null 渲染成空串" {
  assert_eq(json_to_cell(json_of("null")), "")
}

///|
test "json_to_cell 渲染布尔值" {
  assert_eq(json_to_cell(json_of("true")), "true")
  assert_eq(json_to_cell(json_of("false")), "false")
}

///|
test "json_to_cell 渲染整数" {
  assert_eq(json_to_cell(json_of("20")), "20")
}

///|
test "json_to_cell 普通数字按 Double 文本输出" {
  assert_eq(json_to_cell(json_of("1.50")), "1.5")
}

///|
test "json_to_cell 超出双精度时保留数字的原始写法" {
  assert_eq(
    json_to_cell(json_of("12345678901234567890")),
    "12345678901234567890",
  )
}

///|
test "json_to_cell 字符串原样返回" {
  assert_eq(json_to_cell(json_of("\"张三\"")), "张三")
}

///|
test "json_to_cell 把嵌套对象压成一行 JSON" {
  assert_eq(
    json_to_cell(json_of("{\"city\":\"北京\"}")),
    "{\"city\":\"北京\"}",
  )
}

///|
test "json_to_cell 把数组压成一行 JSON" {
  assert_eq(json_to_cell(json_of("[1,2,3]")), "[1,2,3]")
}

///|
/// 测试辅助：把一行的第一个对象展平，拼成「键=值」的文本方便断言。
fn flattened_of(input : String) -> String raise {
  let row = flatten_row(rows_of(input)[0])
  let parts : Array[String] = []
  for k, v in row {
    parts.push(k + "=" + json_to_cell(v))
  }
  parts.join(", ")
}

///|
test "flatten_row 展平单层嵌套" {
  assert_eq(
    flattened_of("[{\"name\":\"张三\",\"addr\":{\"city\":\"北京\"}}]"),
    "name=张三, addr.city=北京",
  )
}

///|
test "flatten_row 展平多层嵌套" {
  assert_eq(flattened_of("[{\"a\":{\"b\":{\"c\":1}}}]"), "a.b.c=1")
}

///|
test "flatten_row 没有嵌套时原样返回" {
  assert_eq(flattened_of("[{\"a\":1,\"b\":\"x\"}]"), "a=1, b=x")
}

///|
test "flatten_row 保留空的嵌套对象的键" {
  assert_eq(flattened_of("[{\"addr\":{}}]"), "addr=")
}

///|
test "flatten_row 数组不展平" {
  assert_eq(flattened_of("[{\"tags\":[1,2]}]"), "tags=[1,2]")
}

///|
test "flatten_row 直接键赢过展平键" {
  assert_eq(flattened_of("[{\"a\":{\"b\":1},\"a.b\":2}]"), "a.b=2")
}

///|
test "flatten_row 嵌套层内的直接键也赢" {
  assert_eq(flattened_of("[{\"a\":{\"b\":{\"c\":1},\"b.c\":2}}]"), "a.b.c=2")
}
