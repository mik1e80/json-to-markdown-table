// 命令行入口：读取 JSON，输出 Markdown 表格。
//
// 参数解析交给官方库 moonbitlang/core/argparse，文件读取交给 moonbitlang/x/fs，
// 退出码用 moonbitlang/x/sys。输入来源有三个：位置参数、--file、以及两者都不给
// 时的内置示例。

///|
/// 内置示例，无参数运行时展示效果。
let sample : String = "[{\"name\":\"张三\",\"age\":20,\"city\":\"北京\"},{\"name\":\"李四\",\"age\":22,\"city\":\"上海\"}]"

///|
/// 命令行定义。
///
/// 特意关掉 argparse 自带的 `--help`：它内部直接调 wasi 的 `proc_exit` 结束进程，
/// 退出码和输出都不受我们控制。这里换成普通 flag，由 `run` 自己打印帮助。
fn command() -> @argparse.Command {
  @argparse.Command(
    "json-to-markdown-table",
    about="把 JSON 对象数组转换成 Markdown 表格",
    flags=[
      @argparse.FlagArg(
        "no-flatten",
        about="嵌套对象不展平，压成一行 JSON 放进单元格",
      ),
      @argparse.FlagArg(
        "sort",
        about="表头按字典序排列（默认按键在 JSON 里出现的顺序）",
      ),
      @argparse.FlagArg("help", short='h', about="显示这份帮助"),
    ],
    options=[
      @argparse.OptionArg("file", short='f', about="从文件读取 JSON"),
      @argparse.OptionArg(
        "align",
        about="整张表的对齐方式：left / center / right",
        default_values=["left"],
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "json",
        about="直接写在命令行上的 JSON 文本；省略且没给 --file 时展示示例",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
    disable_help_flag=true,
  )
}

///|
/// 帮助文本：argparse 渲染的参数表，加上中文的示例。
fn help_text(cmd : @argparse.Command) -> String {
  cmd.render_help() +
  "\n示例：\n" +
  "  moon run cmd/main '[{\"name\":\"张三\",\"age\":20}]'\n" +
  "  moon run cmd/main --file data.json --align center\n" +
  "  moon run cmd/main --no-flatten --sort '[{\"a\":{\"b\":1}}]'\n" +
  "\n没有位置参数也没有 --file 时，打印这份帮助和一个内置示例。\n"
}

///|
/// 把 `--align` 的取值翻成 `Alignment`，认不出来时返回 `None`。
fn parse_align(name : String) -> @my_hackathon.Alignment? {
  match name {
    "left" => Some(@my_hackathon.Left)
    "center" => Some(@my_hackathon.Center)
    "right" => Some(@my_hackathon.Right)
    _ => None
  }
}

///|
/// 组装转换选项。`--no-flatten` 是「关闭展平」，所以这里取反。
///
/// 对齐方式取值非法时返回中文错误，而不是让 argparse 报英文。
fn build_options(
  no_flatten~ : Bool,
  sort~ : Bool,
  align~ : String,
) -> Result[@my_hackathon.Options, String] {
  let alignment = match parse_align(align) {
    Some(alignment) => alignment
    None =>
      return Err(
        "--align 只支持 left / center / right，收到的是「\{align}」",
      )
  }
  Ok({ flatten_objects: !no_flatten, alignment, sort_columns: sort, })
}

///|
/// 去掉文本开头的 BOM。
///
/// 用 UTF-8 保存的 JSON 文件常常带 BOM（字节 `EF BB BF`），解码出来是
/// U+FEFF 一个字符。JSON 解析器不认它，会报非法字符，所以读文件后先剥掉。
/// `substring` 和 `code_unit_at` 用的是同一套下标（UTF-16 码元），BOM 正好占 1 个。
fn strip_bom(text : String) -> String {
  if text.length() > 0 && text.code_unit_at(0) == 0xFEFF {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
/// 取某个选项的第一个值，没有就用 `fallback`。
fn first_value(
  matches : @argparse.Matches,
  name : String,
  fallback : String,
) -> String {
  match matches.values.get(name) {
    Some([first, ..]) => first
    _ => fallback
  }
}

///|
/// 决定 JSON 从哪来：`--file` 或命令行上的 JSON，两者只能给一个。
///
/// 都没给时返回 `None`，由调用方决定去展示示例。
fn read_input(file : String, inline : String) -> Result[String?, String] {
  if file != "" && inline != "" {
    return Err("--file 和命令行上的 JSON 只能给一个")
  }
  if file != "" {
    let text = @fs.read_file_to_string(file) catch {
      @fs.IOError(msg) => return Err("读取文件失败：\{file}（\{msg}）")
    }
    return Ok(Some(strip_bom(text)))
  }
  if inline != "" {
    return Ok(Some(inline))
  }
  Ok(None)
}

///|
/// 打印帮助和一段示例转换结果。
fn show_demo() -> Unit {
  println(help_text(command()))
  println("示例输入：")
  println(sample)
  println("")
  println("示例输出：")
  match @my_hackathon.json_to_markdown_table(sample) {
    Ok(md) => println(md.trim_end())
    Err(msg) => println("转换失败：\{msg}")
  }
}

///|
/// 解析参数、取输入、转换并打印。错误以 `Err` 返回，由 `main` 统一打印并定退出码。
fn run() -> Result[Unit, String] raise {
  let cmd = command()
  let matches = cmd.parse()
  if matches.flags.get("help") == Some(true) {
    println(help_text(cmd))
    return Ok(())
  }
  let options = match
    build_options(
      no_flatten=matches.flags.get("no-flatten") == Some(true),
      sort=matches.flags.get("sort") == Some(true),
      align=first_value(matches, "align", "left"),
    ) {
    Ok(options) => options
    Err(msg) => return Err(msg)
  }
  let input = match
    read_input(
      first_value(matches, "file", ""),
      first_value(matches, "json", ""),
    ) {
    Ok(input) => input
    Err(msg) => return Err(msg)
  }
  let text = match input {
    Some(text) => text
    None => {
      show_demo()
      return Ok(())
    }
  }
  match @my_hackathon.json_to_markdown_table_with(text, options) {
    Ok(md) => {
      println(md.trim_end())
      Ok(())
    }
    Err(msg) => Err(msg)
  }
}

///|
/// 命令行入口。转换失败、参数非法、文件读不到都以退出码 1 结束，
/// 好让脚本能靠退出码判断成功与否。
fn main {
  let result = run() catch { err => Err(err.to_string()) }
  match result {
    Ok(_) => ()
    Err(msg) => {
      println("错误：\{msg}")
      @sys.exit(1)
    }
  }
}
