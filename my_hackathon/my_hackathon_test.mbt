// 黑盒测试：只使用包的公开 API。运行 `moon test` 执行。

///|
test "parse_json 能解析对象数组" {
  match @my_hackathon.parse_json("[{\"name\":\"张三\",\"age\":20}]") {
    Ok(json) => assert_true(json is Array(_))
    Err(msg) => @test.fail("解析不该失败：\{msg}")
  }
}

///|
test "parse_json 能解析单个对象" {
  match @my_hackathon.parse_json("{\"name\":\"张三\"}") {
    Ok(json) => assert_true(json is Object(_))
    Err(msg) => @test.fail("解析不该失败：\{msg}")
  }
}

///|
test "parse_json 对非法 JSON 返回错误" {
  match @my_hackathon.parse_json("{\"name\":}") {
    Ok(_) => @test.fail("非法 JSON 不该解析成功")
    Err(msg) => assert_true(msg.length() > 0)
  }
}
