// json-to-markdown-table：把 JSON 数据转换成 Markdown 表格。
//
// 对外提供三个入口：
// - parse_json：解析 JSON 文本
// - json_to_markdown_table：一步完成「解析 + 转换」
// - json_to_markdown_table_with：同上，可传入 Options 调整行为

///|
/// 解析 JSON 文本。
///
/// 成功时返回解析出的 `Json` 值；失败时返回一条可读的中文错误信息。
///
/// 注：`InvalidNumber` 与 `InvalidIdentEscape` 两个变体在当前版本的官方解析器里
/// 没有被抛出过（数字和转义写错时报的是 `InvalidChar`），但错误类型里有它们，
/// 这里一并给出提示，以防将来解析器改用这两个变体。
pub fn parse_json(input : String) -> Result[Json, String] {
  let json = @json.parse(input) catch {
    @json.ParseError::InvalidEof =>
      return Err("JSON 内容不完整，意外结束")
    @json.ParseError::InvalidChar(pos, c) =>
      return Err(format_position(pos) + "出现非法字符 '\{c}'")
    @json.ParseError::InvalidNumber(pos, text) =>
      return Err(format_position(pos) + "数字写法非法：\{text}")
    @json.ParseError::InvalidIdentEscape(pos) =>
      return Err(
        format_position(pos) +
        "转义序列非法（\\u 后面需要 4 位十六进制）",
      )
    @json.ParseError::DepthLimitExceeded =>
      return Err("嵌套层数太深，超出解析器上限")
  }
  Ok(json)
}

///|
/// 把解析器的位置信息拼成「第 X 行第 Y 列」。
///
/// 解析器的 `column` 是 0 基的，展示给用户时加 1。
fn format_position(pos : @json.Position) -> String {
  "第 \{pos.line} 行第 \{pos.column + 1} 列"
}

///|
/// 说明一个 JSON 值是什么类型，用于拼错误提示。
fn type_name(json : Json) -> String {
  match json {
    Null => "null"
    True | False => "布尔值"
    Number(_) => "数字"
    String(_) => "字符串"
    Array(_) => "数组"
    Object(_) => "对象"
  }
}

///|
/// 转义 Markdown 表格单元格的内容。
///
/// - `\` 转义为 `\\`。必须先于 `|` 处理：值里本来就有反斜杠时（例如 `a\|b`），
///   若只转义竖线会得到 `a\\|b`，其中的 `\\` 在 Markdown 里是「一个字面反斜杠」，
///   后面的 `|` 就重新变成未转义的列分隔符，表格会被撑破
/// - `|` 会把表格截断，转义为 `\|`
/// - 换行会破坏表格结构（一行一行的 Markdown 表格），转成 `<br>`
/// - `\r` 直接丢弃，CRLF 的换行交给 `\n` 处理
fn escape_cell(s : String) -> String {
  let parts : Array[String] = []
  for c in s {
    match c {
      '\\' => parts.push("\\\\")
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
/// 收集所有行出现过的键，去重。
///
/// 表头取「并集」而不是只看第一行，这样后面才出现的键不会丢。
///
/// 默认保留键的**出现顺序**：`Map` 本身是保插入序的，而 JSON 解析器是按
/// 遇到顺序插入键的，所以这里的顺序就是原 JSON 里的书写顺序，最贴近直觉。
/// `sort` 为真时改按字典序排列，用于需要跨数据源稳定输出的场景。
///
/// 排序注意用 `lexical_compare` 而不是默认的 `sort_by`：String 的 `Compare`
/// 是 shortlex 序（先比长度再比字符），排出来不是字典序。
fn collect_keys(
  rows : Array[Map[String, Json]],
  sort? : Bool = false,
) -> Array[String] {
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
  if sort {
    keys.sort_by(fn(a, b) { a.lexical_compare(b) })
  }
  keys
}

///|
/// 统计每个「点号路径」被占用的最小树深度。
///
/// 同一个路径可能被多处占用：`{"a": {"b": 1}, "a.b": 2}` 里的 `a.b` 既被顶层
/// 直接键占用（深度 0），也被 `a` 下的展平键占用（深度 1）。这里记下最小深度，
/// 展平时只让最浅的那处写入，于是「直接键赢过展平键」与键的书写顺序无关。
fn record_depths(
  obj : Map[String, Json],
  prefix : String,
  depth : Int,
  depths : Map[String, Int],
) -> Unit {
  for k, v in obj {
    let key = if prefix == "" { k } else { prefix + "." + k }
    let shallower = match depths.get(key) {
      Some(known) => depth < known
      None => true
    }
    if shallower {
      depths.set(key, depth)
    }
    match v {
      Object(inner) =>
        if !inner.is_empty() {
          record_depths(inner, key, depth + 1, depths)
        }
      _ => ()
    }
  }
}

///|
/// 按出现顺序输出展平后的键值。
///
/// 只有最浅的那处占用才写入（深度由 `record_depths` 算出），同名更深处的
/// 展平键直接跳过。空的嵌套对象没有可展开的字段，保留键本身、值当作 `null`
/// （于是单元格显示为空），免得整列凭空消失。
fn emit_flattened(
  obj : Map[String, Json],
  prefix : String,
  depth : Int,
  depths : Map[String, Int],
  out : Map[String, Json],
) -> Unit {
  for k, v in obj {
    let key = if prefix == "" { k } else { prefix + "." + k }
    let is_shallowest = depths.get(key) == Some(depth)
    match v {
      Object(inner) =>
        if inner.is_empty() {
          if is_shallowest {
            // Json 的构造器跨包不可见，用官方提供的 Json::null()
            out.set(key, Json::null())
          }
        } else {
          emit_flattened(inner, key, depth + 1, depths, out)
        }
      _ => if is_shallowest { out.set(key, v) }
    }
  }
}

///|
/// 把一行里的嵌套对象递归展平成 `a.b.c` 形式的键，列的顺序不变。
///
/// 只展平对象；数组不展平，照旧压成一行 JSON 放在一个单元格里。
fn flatten_row(row : Map[String, Json]) -> Map[String, Json] {
  let depths : Map[String, Int] = Map([])
  record_depths(row, "", 0, depths)
  let out : Map[String, Json] = Map([])
  emit_flattened(row, "", 0, depths, out)
  out
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
/// 转换选项。
///
/// - `flatten_objects`：是否把嵌套对象展平成 `父.子` 形式的列。默认 `true`；
///   设为 `false` 时嵌套对象照旧压成一行 JSON 放进一个单元格
/// - `sort_columns`：表头是否按字典序排序。默认 `false`，即保留键在 JSON
///   里出现的顺序，跟原始数据的书写顺序一致
///
/// 想只改其中一项时用结构体更新语法，例如
/// `{ ..Options::default(), flatten_objects: false }`。
pub(all) struct Options {
  flatten_objects : Bool
  sort_columns : Bool
} derive(Eq)

///|
/// 默认选项：展平嵌套对象、表头按出现顺序。
pub fn Options::default() -> Options {
  { flatten_objects: true, sort_columns: false, }
}

///|
/// 把 JSON 文本转换成 Markdown 表格，使用默认选项。
///
/// 等价于 `json_to_markdown_table_with(input, Options::default())`。
pub fn json_to_markdown_table(input : String) -> Result[String, String] {
  json_to_markdown_table_with(input, Options::default())
}

///|
/// 把 JSON 文本转换成 Markdown 表格，可指定选项。
///
/// 输入可以是「对象数组」或「单个对象」（单个对象视为只有一行）：
/// 表头取所有对象键的并集，某一行缺少某个键时对应单元格留空。
/// 返回值结尾带一个换行。
pub fn json_to_markdown_table_with(
  input : String,
  options : Options,
) -> Result[String, String] {
  let json = match parse_json(input) {
    Ok(json) => json
    Err(msg) => return Err(msg)
  }
  let rows = match json {
    Array(items) => {
      let rows : Array[Map[String, Json]] = []
      for item in items {
        let kind = type_name(item)
        match item {
          Object(obj) => rows.push(obj)
          _ =>
            return Err(
              "数组里出现了\{kind}，只有对象才能作为表格的一行",
            )
        }
      }
      rows
    }
    Object(map) => [map] // 单个对象当成「只有一行」的表格
    _ =>
      return Err(
        "输入需要是对象数组或单个对象，当前是\{type_name(json)}",
      )
  }
  // 展平只作用于每一行的值，不影响上面「对象数组 / 单个对象」的判定
  let rows = if options.flatten_objects { rows.map(flatten_row) } else { rows }
  let headers = collect_keys(rows, sort=options.sort_columns)
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
