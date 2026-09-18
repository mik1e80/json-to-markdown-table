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
