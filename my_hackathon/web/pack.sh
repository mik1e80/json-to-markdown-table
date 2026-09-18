#!/usr/bin/env bash
# 把网页打包成单个 HTML 文件，方便直接发给别人。
#
# 样式表、页面逻辑、MoonBit 编译出来的转换函数全部内联进一个 .html，
# 对方收到双击就能用：不用联网、不用装环境、不用起服务器。
#
# 产物在 dist/json-to-markdown-table.html。它是生成物，不进版本库——
# 要发给谁就发那个文件，改了源码重新跑一次即可。

set -euo pipefail

web="$(cd "$(dirname "$0")" && pwd)"
cd "$web"

out="dist/json-to-markdown-table.html"

if [ ! -f dist/web.js ]; then
  echo "错误：dist/web.js 不存在，先跑 bash web/build.sh" >&2
  exit 1
fi

# 内联进 <script> 的代码里如果出现 "</script"，标签会被提前闭合；
# 出现 "<!--" 会让解析器一路吃到 "-->"。先检查，免得生成一个坏文件还发出去。
for f in dist/web.js app.js; do
  if grep -q '</script\|<!--' "$f"; then
    echo "错误：$f 里含有 </script 或 <!--，没法直接内联" >&2
    exit 1
  fi
done

awk '
BEGIN {
  print "<!--"
  print "  这个文件是生成的，请勿直接编辑。"
  print "  源码在 web/ 目录：index.html + style.css + app.js + web.mbt"
  print "  重新生成：bash web/pack.sh"
  print "-->"
}
# 匹配的是完整的标签，不是文件名。页面正文里也会出现 "dist/web.js" 这样的字眼
# （介绍那段就提到了），只按文件名匹配会把整个 262KB 的 JS 又内联进正文一次。
index($0, "href=\"style.css\"") > 0 {
  print "    <style>"
  while ((getline line < "style.css") > 0) print line
  close("style.css")
  print "    </style>"
  next
}
index($0, "src=\"dist/web.js\"") > 0 {
  print "    <script>"
  print "      // MoonBit 编译产物：username/my_hackathon/web 导出的 convert / convert_error"
  while ((getline line < "dist/web.js") > 0) print line
  close("dist/web.js")
  print "    </script>"
  next
}
index($0, "src=\"app.js\"") > 0 {
  print "    <script>"
  while ((getline line < "app.js") > 0) print line
  close("app.js")
  print "    </script>"
  next
}
{ print }
' index.html > "$out"

echo "已生成 $out（$(wc -c < "$out") 字节，可以直接发给别人）"
