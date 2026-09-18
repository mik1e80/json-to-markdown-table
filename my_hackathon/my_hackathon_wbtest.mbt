// 白盒测试：可以访问包内的私有函数。

///|
test "escape_cell 转义竖线" {
  @test.assert_eq(escape_cell("a|b"), "a\\|b")
}

///|
test "escape_cell 把换行转成 br 标签" {
  @test.assert_eq(escape_cell("第一行\n第二行"), "第一行<br>第二行")
}

///|
test "escape_cell 丢弃回车符" {
  @test.assert_eq(escape_cell("a\r\nb"), "a<br>b")
}

///|
test "escape_cell 普通文本原样返回" {
  @test.assert_eq(escape_cell("张三"), "张三")
}

///|
test "escape_cell 空串返回空串" {
  @test.assert_eq(escape_cell(""), "")
}

///|
test "render_row 拼接并转义单元格" {
  @test.assert_eq(render_row(["姓名", "a|b"]), "| 姓名 | a\\|b |")
}

///|
test "render_row 单列" {
  @test.assert_eq(render_row(["仅一列"]), "| 仅一列 |")
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
          _ => @test.fail("测试数据里出现了非对象元素")
        }
      }
      rows
    }
    Ok(_) => @test.fail("测试数据应当是数组")
    Err(msg) => @test.fail("测试数据解析失败：\{msg}")
  }
}

///|
test "collect_keys 合并多个对象的键并按字典序排序" {
  let keys = collect_keys(
    rows_of("[{\"name\":\"张三\"},{\"age\":20,\"name\":\"李四\"}]"),
  )
  @test.assert_eq(keys, ["age", "name"])
}

///|
test "collect_keys 保留只在后面出现的键" {
  let keys = collect_keys(
    rows_of("[{\"name\":\"张三\"},{\"city\":\"北京\"}]"),
  )
  @test.assert_eq(keys, ["city", "name"])
}

///|
test "collect_keys 对空数组返回空表头" {
  let empty : Array[String] = []
  @test.assert_eq(collect_keys(rows_of("[]")), empty)
}

///|
test "collect_keys 的结果与键出现顺序无关" {
  let a = collect_keys(rows_of("[{\"b\":1,\"a\":2},{\"c\":3}]"))
  let b = collect_keys(rows_of("[{\"c\":3},{\"a\":2,\"b\":1}]"))
  @test.assert_eq(a, b)
}

///|
test "collect_keys 处理中文键时结果稳定" {
  let a = collect_keys(rows_of("[{\"姓名\":\"张三\",\"年龄\":20}]"))
  let b = collect_keys(rows_of("[{\"姓名\":\"张三\",\"年龄\":20}]"))
  @test.assert_eq(a, b)
  @test.assert_eq(a.length(), 2)
}
