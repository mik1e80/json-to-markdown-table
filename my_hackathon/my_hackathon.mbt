// json-to-markdown-table：把 JSON 数据转换成 Markdown 表格。
//
// 对外提供两个入口：
// - parse_json：解析 JSON 文本
// - json_to_markdown_table：一步完成「解析 + 转换」

///|
/// 解析 JSON 文本。
///
/// 成功时返回解析出的 `Json` 值；失败时返回一条可读的错误信息。
pub fn parse_json(input : String) -> Result[Json, String] {
  let json = @json.parse(input) catch { err => return Err(err.to_string()) }
  Ok(json)
}
