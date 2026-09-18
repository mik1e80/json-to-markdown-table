// 命令行入口：读取 JSON，输出 Markdown 表格。

///|
/// 用法说明。
fn usage() -> String {
  "json-to-markdown-table：把 JSON 对象数组转成 Markdown 表格\n" +
  "\n" +
  "用法：\n" +
  "  moon run cmd/main '<JSON>'\n" +
  "\n" +
  "示例：\n" +
  "  moon run cmd/main '[{\"name\":\"张三\",\"age\":20}]'\n"
}

///|
/// 内置示例，无参数运行时展示效果。
let sample : String = "[{\"name\":\"张三\",\"age\":20,\"city\":\"北京\"},{\"name\":\"李四\",\"age\":22,\"city\":\"上海\"}]"

///|
/// 打印用法和一段示例转换结果。
fn show_demo() -> Unit {
  println(usage())
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
/// 命令行入口：带参数时转换参数里的 JSON，不带参数时展示用法与示例。
fn main {
  let args = @env.args()
  // args[0] 是程序名，真正的入参从下标 1 开始
  if args.length() <= 1 {
    show_demo()
    return
  }
  match @my_hackathon.json_to_markdown_table(args[1]) {
    Ok(md) => println(md.trim_end())
    Err(msg) => println("错误：\{msg}")
  }
}
