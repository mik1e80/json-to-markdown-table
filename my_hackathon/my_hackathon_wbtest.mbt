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
