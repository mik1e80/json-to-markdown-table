# JSON → Markdown 表格

把 JSON 对象数组转换成 Markdown 表格的 MoonBit 库，附带一个命令行工具。
JSON 解析使用官方库 `moonbitlang/core/json`，没有手写解析器。

## 特性

- **不丢列**：表头取所有对象键的并集，某一行缺少的键留空单元格，
  不会因为第一行字段少就把后面的列丢掉
- **输出稳定**：表头按字典序排序，同一份数据每次得到完全一样的表格
- **自动转义**：竖线转义成 `\|`、换行转成 `<br>`，值里带竖线也撑不破表格
- **中文错误**：解析失败时说明原因，并给出出错的行列位置

## 命令行用法

```bash
# 转换命令行参数里的 JSON
moon run cmd/main '[{"name":"张三","age":20,"city":"北京"},{"name":"李四","age":22,"city":"上海"}]'

# 不带参数时，打印用法和内置示例
moon run cmd/main
```

输出：

```text
| age | city | name |
| --- | --- | --- |
| 20 | 北京 | 张三 |
| 22 | 上海 | 李四 |
```

## 库用法

对外只有两个函数：

| 函数 | 说明 |
| --- | --- |
| `json_to_markdown_table(input)` | 解析 + 转换，一步到位 |
| `parse_json(input)` | 只做解析，需要自己处理 JSON 时用 |

两个函数都返回 `Result`：成功是 `Ok`，失败是 `Err(错误信息)`。

```mbt check
///|
test {
  let input = "[{\"name\":\"张三\",\"age\":20}]"
  match json_to_markdown_table(input) {
    Ok(md) =>
      assert_true(md == "| age | name |\n| --- | --- |\n| 20 | 张三 |\n")
    Err(_) => @test.fail("示例不该失败")
  }
}
```

## 转换规则

顶层输入：

| 输入 | 结果 |
| --- | --- |
| 对象数组 `[{...}, {...}]` | 每个对象一行 |
| 单个对象 `{...}` | 一行 |
| 空数组 `[]` | 空字符串 |
| 其他类型 | `Err`，错误信息里说明当前是什么类型 |

单元格取值：

| JSON 值 | 单元格内容 |
| --- | --- |
| `null` | 空 |
| `true` / `false` | `true` / `false` |
| 数字 | 优先用原始写法（超出双精度时），否则用 Double 的文本，`1.50` 会规范化成 `1.5` |
| 字符串 | 原样输出，竖线和换行会被转义 |
| 数组 / 对象 | 压成一行 JSON |

## 开发

```bash
moon check   # 编译检查
moon test    # 跑测试
moon fmt     # 格式化
moon info    # 更新 .mbti 接口文件
```

## 项目结构

- `my_hackathon.mbt` — 库实现
- `cmd/main/` — 命令行工具
- `my_hackathon_test.mbt` — 公开 API 的黑盒测试
- `my_hackathon_wbtest.mbt` — 内部函数的白盒测试
