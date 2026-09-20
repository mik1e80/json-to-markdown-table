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
const sourceEl = document.getElementById("source");
const copyBtn = document.getElementById("copy");
const downloadBtn = document.getElementById("download");

/// 当前生成的 Markdown，复制和下载都从这里取。
let currentMarkdown = "";

/// 把生成的 Markdown 放进源码区。
///
/// 没有内容时（解析失败、空表格）连同复制/下载按钮一起禁用——
/// 让人一眼看出「现在没东西可拿」，而不是点了没反应。
function setOutput(markdown) {
  currentMarkdown = markdown;
  sourceEl.textContent = markdown;
  const hasOutput = markdown !== "";
  copyBtn.disabled = !hasOutput;
  downloadBtn.disabled = !hasOutput;
}

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
    setOutput("");
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
    setOutput("");
    return;
  }

  previewEl.appendChild(renderTable(table));
  statusEl.textContent = `${table.rows.length} 行 × ${table.headers.length} 列`;
  statusEl.className = "status status-ok";
  setOutput(md);
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

// ── 复制与下载 ──────────────────────────────────────────────────────────

/// 复制文本到剪贴板，成功返回 true。
///
/// 先用 navigator.clipboard，它需要「安全上下文」；这个页面是要能双击
/// 打开（file://）的，不能假设有 https，所以下面留了一条 execCommand 的
/// 老路兜底。execCommand 虽然已废弃，但目前所有浏览器都还支持。
async function copyText(text) {
  if (navigator.clipboard !== undefined) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // 被权限或安全上下文拦下了，走兜底
    }
  }

  const scratch = document.createElement("textarea");
  scratch.value = text;
  scratch.setAttribute("readonly", "");
  // 放在视口外，避免复制时页面跳一下
  scratch.style.position = "fixed";
  scratch.style.top = "-1000px";
  document.body.appendChild(scratch);
  // 必须先 focus 再 select：execCommand("copy") 要求文档有焦点，
  // 少了这一步在某些情况下选区建不起来，复制会静默失败
  scratch.focus();
  scratch.select();
  let ok = false;
  try {
    ok = document.execCommand("copy");
  } catch {
    ok = false;
  }
  scratch.remove();
  return ok;
}

/// 按钮上短暂显示一句反馈，然后恢复原文案。
function flash(button, text) {
  if (button.dataset.timer !== undefined) {
    clearTimeout(Number(button.dataset.timer));
  } else {
    button.dataset.label = button.textContent;
  }
  button.textContent = text;
  button.classList.add("done");
  button.dataset.timer = String(
    setTimeout(() => {
      button.textContent = button.dataset.label;
      button.classList.remove("done");
      delete button.dataset.timer;
    }, 1500)
  );
}

copyBtn.addEventListener("click", async () => {
  const ok = await copyText(currentMarkdown);
  flash(copyBtn, ok ? "已复制" : "复制失败");
});

downloadBtn.addEventListener("click", () => {
  const blob = new Blob([currentMarkdown], {
    type: "text/markdown;charset=utf-8",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "table.md";
  document.body.appendChild(link);
  link.click();
  link.remove();
  // 立刻 revoke 有些浏览器会来不及读，挪到下一轮事件循环
  setTimeout(() => URL.revokeObjectURL(url), 0);
});

inputEl.value = EXAMPLES.nested.json;
render();
