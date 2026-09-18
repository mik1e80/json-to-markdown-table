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

///|
/// 转义 Markdown 表格单元格的内容。
///
/// - `|` 会把表格截断，转义为 `\|`
/// - 换行会破坏表格结构（一行一行的 Markdown 表格），转成 `<br>`
/// - `\r` 直接丢弃，CRLF 的换行交给 `\n` 处理
fn escape_cell(s : String) -> String {
  let parts : Array[String] = []
  for c in s {
    match c {
      '|' => parts.push("\\|")
      '\n' => parts.push("<br>")
      '\r' => ()
      _ => parts.push(c.to_string())
    }
  }
  parts.join("")
}

///|
/// 渲染一行表格（不含结尾换行），每个单元格先转义。
fn render_row(cells : Array[String]) -> String {
  "| " + cells.map(escape_cell).join(" | ") + " |"
}

///|
/// 收集所有行出现过的键，去重后按字典序排序。
///
/// 表头取「并集」而不是只看第一行，这样后面才出现的键不会丢；
/// 排序则保证同样的数据每次得到完全一样的表格。
fn collect_keys(rows : Array[Map[String, Json]]) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let keys : Array[String] = []
  for row in rows {
    for k, _ in row {
      if !seen.contains(k) {
        seen.set(k, ())
        keys.push(k)
      }
    }
  }
  keys.sort()
  keys
}
