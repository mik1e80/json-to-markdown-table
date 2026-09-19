// 白盒测试：导出层对 JavaScript 承诺的契约。
//
// 这一层的价值全在「两个函数各自返回什么」上，所以测试重点不是转换结果本身
// （那在库的黑盒测试里已经覆盖了），而是：
//   - 成功的输入，convert 给表格、convert_error 给空串
//   - 失败的输入，convert 给空串、convert_error 给中文错误
//   - 空数组这种「合法地得到空表格」的输入，两个函数都给空串、不误报错

///|
test "convert 成功时返回表格" {
  assert_eq(
    convert("[{\"name\":\"张三\",\"age\":20}]", "left", true, false),
    "| name | age |\n| --- | --- |\n| 张三 | 20 |\n",
  )
}

///|
test "convert_error 成功时返回空串" {
  assert_eq(convert_error("[{\"name\":\"张三\"}]", "left", true, false), "")
}

///|
test "失败时 convert 给空串、convert_error 给中文错误" {
  let input = "[{\"a\":"
  assert_eq(convert(input, "left", true, false), "")
  assert_true(convert_error(input, "left", true, false).contains("不完整"))
}

///|
test "非法对齐方式两个函数都报错" {
  assert_eq(convert("[{\"a\":1}]", "middle", true, false), "")
  let msg = convert_error("[{\"a\":1}]", "middle", true, false)
  assert_true(msg.contains("left"))
  assert_true(msg.contains("middle"))
}

///|
test "空数组是合法的空表格，不能被当成错误" {
  // 两个函数都返回空串，页面靠「convert 空串 → 再问 convert_error」来区分，
  // 这里必须保证 convert_error 在空数组时也是空串，否则页面会弹出一个假错误
  assert_eq(convert("[]", "left", true, false), "")
  assert_eq(convert_error("[]", "left", true, false), "")
}

///|
test "全是空对象同样是合法空表格" {
  assert_eq(convert("[{},{}]", "left", true, false), "")
  assert_eq(convert_error("[{},{}]", "left", true, false), "")
}

///|
test "convert 认三种对齐方式" {
  let input = "[{\"a\":1}]"
  assert_true(convert(input, "left", true, false).contains("| --- |"))
  assert_true(convert(input, "center", true, false).contains("| :---: |"))
  assert_true(convert(input, "right", true, false).contains("| ---: |"))
}

///|
test "convert 的 flatten 参数生效" {
  let input = "[{\"name\":\"张三\",\"addr\":{\"city\":\"北京\"}}]"
  assert_true(convert(input, "left", true, false).contains("addr.city"))
  assert_true(
    convert(input, "left", false, false).contains("{\"city\":\"北京\"}"),
  )
}

///|
test "convert 的 sort 参数生效" {
  let input = "[{\"name\":\"张三\",\"age\":20}]"
  assert_true(convert(input, "left", true, false).contains("| name | age |"))
  assert_true(convert(input, "left", true, true).contains("| age | name |"))
}

///|
test "非对象数组与顶层非对象都走错误通道" {
  assert_eq(convert("[{\"a\":1},2]", "left", true, false), "")
  assert_true(
    convert_error("[{\"a\":1},2]", "left", true, false).contains("数字"),
  )
  assert_eq(convert("\"just a string\"", "left", true, false), "")
  assert_true(
    convert_error("\"just a string\"", "left", true, false).contains(
      "字符串",
    ),
  )
}

///|
test "convert 与 convert_error 永远只有一个非空" {
  let inputs : Array[String] = [
    "[{\"name\":\"张三\"}]", "[{\"a\":", "[]", "[{},{}]", "2", "null", "", "[[1]]",
  ]
  for input in inputs {
    let ok = convert(input, "left", true, false) != ""
    let failed = convert_error(input, "left", true, false) != ""
    assert_false(ok && failed)
  }
}
