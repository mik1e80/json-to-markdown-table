#!/usr/bin/env bash
# 重新生成 dist/web.js。
#
# 改了 web/web.mbt 或库代码之后跑一次，页面才会看到新逻辑。
# 产物是提交进仓库的，所以别人 clone 下来直接双击 index.html 就能用，不必先构建。

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

moon build --target js --release

mkdir -p web/dist
cp _build/js/release/build/web/web.js web/dist/web.js

echo "已生成 web/dist/web.js（$(wc -c < web/dist/web.js) 字节）"
