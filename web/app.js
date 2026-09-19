// 页面逻辑：读输入框 → 调 MoonBit 编译出来的 convert() → 渲染表格。
//
// 这里不含任何转换规则，只做两件事：
//   1. 把 convert() 吐出来的 Markdown 表格还原成表格结构（下面那套迷你解析器）
//   2. 把结果画到页面上
//
// 转换本身全在 dist/web.js 里（MoonBit 的 mik1e80/json2md/web 包编译产物）。

// ── 迷你 Markdown 表格解析器 ────────────────────────────────────────────
//
// 不引 marked.js 之类的库，因为：（1）离线也能用，不必联网拉 CDN；
// （2）我们自己的输出格式是固定的三行式表格，而且转义规则（\ 和 | 怎么转、
// 换行写成 <br>）是自己定的，自己解最准。
//
// 输入长这样（注意单元格里的 | 会写成 \|、换行会写成 <br>）：
//   | name | note |
//   | --- | --- |
//   | 张三 | a\|b |

/// 按未被转义的 `|` 切开一行，保留转义序列原样（交给 unescapeCell 处理）。
function splitRow(line) {
  const cells = [];
  let cur = "";
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === "\\" && i + 1 < line.length) {
      cur += c + line[i + 1]; // 反斜杠和它转义的字符一起留着
      i++;
      continue;
    }
    if (c === "|") {
      cells.push(cur);
      cur = "";
      continue;
    }
    cur += c;
  }
  cells.push(cur);
  return cells;
}

/// 行以 `|` 开头和结尾，切开后首尾各多出一个空串；单元格两侧各有一个空格。
///
/// 两侧各只去一个空格，不能用 trim()：值本身可能就带空格，`"  x"` 渲染出来是
/// `|   x |`，多去一个空格就把数据改了。
function trimRow(cells) {
  return cells
    .slice(1, cells.length - 1)
    .map((c) => unescapeCell(c.replace(/^ /, "").replace(/ $/, "")));
}

/// `\\` → `\`，`\|` → `|`。必须扫一遍而不是两次 replace：
/// 先替换 `\|` 会把 `\\|` 里的竖线也吃掉，顺序反了又会漏。
function unescapeCell(s) {
  let out = "";
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === "\\" && i + 1 < s.length) {
      const next = s[i + 1];
      if (next === "\\" || next === "|") {
        out += next;
        i++;
        continue;
      }
    }
    out += c;
  }
  return out;
}

/// 把 Markdown 表格文本解析成 { headers, rows }；空字符串返回 null。
function parseTable(md) {
  const lines = md.split("\n").filter((l) => l !== "");
  if (lines.length === 0) return null;
  const rows = lines.map((l) => trimRow(splitRow(l)));
  return { headers: rows[0], rows: rows.slice(2) };
}

// ── 渲染 ────────────────────────────────────────────────────────────────

/// 单元格里的 `<br>` 还原成真正的换行。
///
/// 全部用 createTextNode 拼，不走 innerHTML——JSON 里的内容是不可信的，
/// 直接当 HTML 插进去就等于开了个注入口子。
function appendCell(td, text) {
  const parts = text.split("<br>");
  parts.forEach((part, i) => {
    if (i > 0) td.appendChild(document.createElement("br"));
    td.appendChild(document.createTextNode(part));
  });
}

function renderTable(table) {
  const el = document.createElement("table");

  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");
  for (const h of table.headers) {
    const th = document.createElement("th");
    appendCell(th, h);
    headRow.appendChild(th);
  }
  thead.appendChild(headRow);
  el.appendChild(thead);

  const tbody = document.createElement("tbody");
  for (const row of table.rows) {
    const tr = document.createElement("tr");
    for (const c of row) {
      const td = document.createElement("td");
      appendCell(td, c);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  el.appendChild(tbody);

  return el;
}

// ── 示例 ────────────────────────────────────────────────────────────────

const EXAMPLES = {
  simple: {
    label: "普通数据",
    json: '[{"name":"张三","age":20,"city":"北京"},{"name":"李四","age":22,"city":"上海"}]',
  },
  nested: {
    label: "嵌套对象",
    json: '[{"name":"张三","addr":{"city":"北京","zip":"100000"}},{"name":"李四","addr":{"city":"上海","zip":"200000"}}]',
  },
  missing: {
    label: "字段不齐",
    json: '[{"name":"张三","age":20},{"name":"李四"},{"name":"王五","age":21,"city":"广州"}]',
  },
  tricky: {
    label: "含竖线与换行",
    json: '[{"name":"张三","note":"a|b"},{"name":"李四","note":"第一行\\n第二行","extra":null}]',
  },
  broken: {
    label: "非法 JSON",
    json: '[{"name":"张三",}]',
  },
};

// ── 页面接线 ────────────────────────────────────────────────────────────

const inputEl = document.getElementById("input");
const previewEl = document.getElementById("preview");
const errorEl = document.getElementById("error");
const statusEl = document.getElementById("status");
const examplesEl = document.getElementById("examples");

function render() {
  const json = inputEl.value;

  // convert 失败时返回空串，这时再去问一次错误信息。空数组这种合法的空表格
  // 两个函数都返回空串，所以不会误报成错误。
  const md = convert(json, "left", true, false);
  const error = md === "" ? convert_error(json, "left", true, false) : "";

  previewEl.replaceChildren();
  errorEl.textContent = "";
  errorEl.hidden = true;

  if (error !== "") {
    errorEl.textContent = error;
    errorEl.hidden = false;
    statusEl.textContent = "解析失败";
    statusEl.className = "status status-error";
    return;
  }

  const table = parseTable(md);
  if (table === null) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = "没有可展示的列（空数组，或数组里都是空对象）。";
    previewEl.appendChild(p);
    statusEl.textContent = "空表格";
    statusEl.className = "status";
    return;
  }

  previewEl.appendChild(renderTable(table));
  statusEl.textContent = `${table.rows.length} 行 × ${table.headers.length} 列`;
  statusEl.className = "status status-ok";
}

/// 输入时不要每敲一个键就重算，稍微等一下。
let timer = null;
function scheduleRender() {
  if (timer !== null) clearTimeout(timer);
  timer = setTimeout(render, 120);
}

for (const [key, example] of Object.entries(EXAMPLES)) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = example.label;
  button.addEventListener("click", () => {
    inputEl.value = example.json;
    render();
  });
  examplesEl.appendChild(button);
}

inputEl.addEventListener("input", scheduleRender);

inputEl.value = EXAMPLES.nested.json;
render();
