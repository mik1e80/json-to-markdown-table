// 给网页用的导出层。
//
// 这一层本身不做转换，只负责把库的 `Result[String, String]` 翻译成 JavaScript
// 能接住的形状。转换逻辑全在 mik1e80/json2md 里。
//
// `moon.pkg` 里用 link.js.exports 把下面两个 pub 函数暴露成全局变量，
// 页面里直接调 convert(...) / convert_error(...)。

///|
/// 把 `--align` 那样的字符串翻成 `Alignment`，认不出来时返回 `None`。
///
/// 和 cmd/main/main.mbt 里的同名函数重复了几行，是有意的：那边解析的是命令行
/// 参数，这边解析的是网页传来的字符串，两边报错文案也不一样。为这几行去动库的
/// 公开 API 不划算。
fn parse_align(name : String) -> @json2md.Alignment? {
  match name {
    "left" => Some(@json2md.Left)
    "center" => Some(@json2md.Center)
    "right" => Some(@json2md.Right)
    _ => None
  }
}

///|
/// 把网页传来的四个参数拼成 `Options`，对齐方式非法时给出中文错误。
fn build_options(
  align : String,
  flatten : Bool,
  sort : Bool,
) -> Result[@json2md.Options, String] {
  let alignment = match parse_align(align) {
    Some(alignment) => alignment
    None =>
      return Err(
        "对齐方式只支持 left / center / right，收到的是「\{align}」",
      )
  }
  Ok({ flatten_objects: flatten, alignment, sort_columns: sort, })
}

///|
/// 把 JSON 转成 Markdown 表格。成功返回表格，失败返回空串。
///
/// 失败原因由 `convert_error` 单独取——MoonBit 的 `Result` 过不了 JavaScript 边界，
/// 而且 `Json` 没有公开构造器、没法拿 JSON 当中间格式，所以干脆拆成两个纯函数。
/// 调用方看到空串时再问一次错误信息即可。
///
/// 四个参数对应库里的 `Options`，网页上暂时只传默认值，留着是为了以后加控件时
/// 不用再动 MoonBit 这边。
pub fn convert(
  input : String,
  align : String,
  flatten : Bool,
  sort : Bool,
) -> String {
  match build_options(align, flatten, sort) {
    Err(_) => ""
    Ok(options) =>
      match @json2md.json_to_markdown_table_with(input, options) {
        Ok(md) => md
        Err(_) => ""
      }
  }
}

///|
/// 同样的输入会产生的错误信息；转换成功时返回空串。
///
/// 注意「空数组」这种合法输入本来就会得到空表格，此时这里也返回空串，
/// 所以调用方不会把空表格误报成错误。
pub fn convert_error(
  input : String,
  align : String,
  flatten : Bool,
  sort : Bool,
) -> String {
  match build_options(align, flatten, sort) {
    Err(msg) => msg
    Ok(options) =>
      match @json2md.json_to_markdown_table_with(input, options) {
        Ok(_) => ""
        Err(msg) => msg
      }
  }
}
