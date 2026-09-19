# json-to-markdown-table

MoonBit 实现 JSON 数组转换为 Markdown 表格的纯前端网页工具。

**在线试用：<https://mik1e80.github.io/json-to-markdown-table/>**

![网页界面](json2md/web/screenshot.png)

---

## 这是个什么项目

黑客松作品。核心是一份用 MoonBit 写的 JSON → Markdown 表格转换逻辑，加上
命令行工具、网页界面和 99 个测试。JSON 解析用的是官方库 `moonbitlang/core/json`，
没有手写解析器；网页上跑的也不是 JavaScript 重写的版本，而是同一份 MoonBit
代码编译成 JS（`moon build --target js`）的产物。

## 这是什么

把一个 JSON 对象数组转成 Markdown 表格。转换逻辑用 MoonBit 写的，
在三个地方跑同一份代码：

| 形态 | 位置 | 怎么用 |
| --- | --- | --- |
| **网页** | `json2md/web/` | 打开上面的在线链接，或在浏览器里打开 `web/index.html` |
| **命令行** | `json2md/cmd/main/` | `moon run cmd/main --file data.json` |
| **库** | `json2md/json2md.mbt` | `@json2md.json_to_markdown_table(input)` |

## 能力

- 嵌套对象自动展平成 `addr.city` 这样的列
- 表头取所有对象的键的并集，缺字段的行留空，不会丢列
- 表头按键在 JSON 里出现的顺序排列，可选字典序
- 竖线、反斜杠、换行自动转义，撑不破表格
- 整张表可左对齐 / 居中 / 右对齐
- 解析失败给出中文错误和行列位置
- 输入支持命令行参数、文件（自动剥 UTF-8 BOM）、标准输入管道

## 文档

详细的用法、API、转换规则和开发说明都在
[`json2md/README.mbt.md`](json2md/README.mbt.md)。

## 开发

```bash
cd json2md
moon test                  # 跑测试（99 个）
bash web/build.sh          # 重新编译网页用的 JS
bash web/pack.sh           # 打包成单个 HTML，方便发给别人
```

网页部分由 GitHub Actions 自动发布，见 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)。
