// 白盒测试：参数解析、选项组装与 BOM 剥离。
//
// 真的去跑 CLI 需要起进程、还要看退出码，不适合放进单元测试，
// 所以这里测的是「把命令行翻译成 Options」这一层。
// 输入读取（--file / 位置参数 / 互斥）用真命令行手工验证。

///|
test "parse_align 认得三种对齐方式" {
  assert_true(parse_align("left") == Some(@my_hackathon.Left))
  assert_true(parse_align("center") == Some(@my_hackathon.Center))
  assert_true(parse_align("right") == Some(@my_hackathon.Right))
}

///|
test "parse_align 大小写敏感，认不出来就返回 None" {
  assert_true(parse_align("middle") is None)
  assert_true(parse_align("Left") is None)
  assert_true(parse_align("") is None)
}

///|
test "build_options 的默认值：展平、左对齐、按出现顺序" {
  match build_options(no_flatten=false, sort=false, align="left") {
    Ok(options) => {
      assert_true(options.flatten_objects)
      assert_true(options.alignment == @my_hackathon.Left)
      assert_false(options.sort_columns)
    }
    Err(msg) => fail("默认选项不该失败：\{msg}")
  }
}

///|
test "build_options 把 --no-flatten 翻成 flatten_objects=false" {
  match build_options(no_flatten=true, sort=false, align="left") {
    Ok(options) => assert_false(options.flatten_objects)
    Err(msg) => fail("不该失败：\{msg}")
  }
}

///|
test "build_options 打开 --sort" {
  match build_options(no_flatten=false, sort=true, align="left") {
    Ok(options) => assert_true(options.sort_columns)
    Err(msg) => fail("不该失败：\{msg}")
  }
}

///|
test "build_options 三种对齐都接得上" {
  let aligns : Array[(String, @my_hackathon.Alignment)] = [
    ("left", @my_hackathon.Left),
    ("center", @my_hackathon.Center),
    ("right", @my_hackathon.Right),
  ]
  for pair in aligns {
    let (name, expected) = pair
    match build_options(no_flatten=false, sort=false, align=name) {
      Ok(options) => assert_true(options.alignment == expected)
      Err(msg) => fail("\{name} 不该失败：\{msg}")
    }
  }
}

///|
test "build_options 对非法对齐给出中文错误" {
  match build_options(no_flatten=false, sort=false, align="middle") {
    Ok(_) => fail("非法对齐不该成功")
    Err(msg) => {
      assert_true(msg.contains("--align"))
      assert_true(msg.contains("middle"))
    }
  }
}

///|
test "strip_bom 去掉开头的 BOM" {
  assert_eq(strip_bom("\u{FEFF}[{\"a\":1}]"), "[{\"a\":1}]")
}

///|
test "strip_bom 对没有 BOM 的文本原样返回" {
  assert_eq(strip_bom("[{\"a\":1}]"), "[{\"a\":1}]")
  assert_eq(strip_bom(""), "")
}

///|
test "strip_bom 只吃开头那一个，后面的 BOM 保留" {
  // 中间的 U+FEFF 是数据的一部分，不该动
  assert_eq(strip_bom("\u{FEFF}a\u{FEFF}"), "a\u{FEFF}")
}

///|
test "strip_bom 不碰中文开头的文本" {
  assert_eq(strip_bom("张三"), "张三")
}

///|
test "parse 把位置参数取成 json" {
  let matches = command().parse(argv=["[{\"a\":1}]"])
  assert_eq(first_value(matches, "json", ""), "[{\"a\":1}]")
  // 没给 --file 时取到的是兜底值
  assert_eq(first_value(matches, "file", ""), "")
}

///|
test "parse 让 --align 有默认值 left" {
  let matches = command().parse(argv=[])
  assert_eq(first_value(matches, "align", ""), "left")
}

///|
test "parse 认得出 --no-flatten、--sort 与 -f" {
  let matches = command().parse(argv=[
    "--no-flatten", "--sort", "-f", "data.json",
  ])
  assert_true(matches.flags.get("no-flatten") == Some(true))
  assert_true(matches.flags.get("sort") == Some(true))
  assert_eq(first_value(matches, "file", ""), "data.json")
  // -f 是 --file 的短写，不应该顺带把位置参数也填上
  assert_eq(first_value(matches, "json", ""), "")
}

///|
test "parse 没给开关时两个 flag 都是假" {
  let matches = command().parse(argv=["[{\"a\":1}]"])
  assert_false(matches.flags.get("no-flatten") == Some(true))
  assert_false(matches.flags.get("sort") == Some(true))
  assert_false(matches.flags.get("help") == Some(true))
}

///|
test "帮助文本列出了全部参数" {
  let help = help_text(command())
  for name in ["--no-flatten", "--sort", "--file", "--align", "-h"] {
    assert_true(help.contains(name))
  }
}
