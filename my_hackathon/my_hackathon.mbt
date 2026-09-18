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

///|
/// 把一个 JSON 值渲染成单元格里的文本（不含 Markdown 转义，转义交给 render_row）。
///
/// - `null` → 空串，表格里看起来就是「没填」
/// - 布尔 → `true` / `false`
/// - 数字 → 优先用 `repr`。官方解析器只在 Double 无法精确表示该字面量时才填它
///   （例如超出双精度整数范围的 `12345678901234567890`），此时保留原文可避免精度丢失；
///   其余情况用 Double 的文本表示，`1.50` 会被规范化成 `1.5`（值本身没有变化）
/// - 字符串 → 原样
/// - 数组 / 对象 → 压成一行 JSON
fn json_to_cell(json : Json) -> String {
  match json {
    Null => ""
    True => "true"
    False => "false"
    Number(d, repr~) =>
      match repr {
        Some(r) => r
        None => d.to_string()
      }
    String(s) => s
    Array(_) | Object(_) => json.stringify()
  }
}

///|
/// 把 JSON 文本转换成 Markdown 表格。
///
/// 输入应当是「对象数组」：表头取所有对象键的并集并按字典序排序，
/// 某一行缺少某个键时对应单元格留空。返回值结尾带一个换行。
pub fn json_to_markdown_table(input : String) -> Result[String, String] {
  let json = match parse_json(input) {
    Ok(json) => json
    Err(msg) => return Err(msg)
  }
  let rows = match json {
    Array(items) => {
      let rows : Array[Map[String, Json]] = []
      for item in items {
        match item {
          Object(obj) => rows.push(obj)
          _ =>
            return Err("数组里出现了非对象元素，无法转成表格")
        }
      }
      rows
    }
    _ => return Err("输入需要是对象数组")
  }
  let headers = collect_keys(rows)
  if headers.length() == 0 {
    // 空数组，或数组里全是空对象：没有列可展示
    return Ok("")
  }
  Ok(render_table(headers, rows))
}

///|
/// 渲染整张表：表头行 + 分隔行 + 数据行，以换行结尾。
fn render_table(
  headers : Array[String],
  rows : Array[Map[String, Json]],
) -> String {
  let lines : Array[String] = [
    render_row(headers),
    render_row(headers.map(fn(_) { "---" })),
  ]
  for row in rows {
    let cells : Array[String] = []
    for h in headers {
      cells.push(
        match row.get(h) {
          Some(value) => json_to_cell(value)
          None => ""
        },
      )
    }
    lines.push(render_row(cells))
  }
  lines.join("\n") + "\n"
}
