#!/usr/bin/env bash
# LibraCore 数据库初始化与校验（zyj）
# 用法：DB_HOST=127.0.0.1 DB_USER=root DB_PASSWORD='...' bash tests/database/verify_init.sh
# 密码只从环境变量读取，不写进脚本、不出现在命令行参数里。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"

if [[ -z "${DB_PASSWORD:-}" ]]; then
    echo "错误：请先设置 DB_PASSWORD 环境变量（不要写进脚本或命令行历史）。" >&2
    echo "示例：read -rs DB_PASSWORD && export DB_PASSWORD && bash tests/database/verify_init.sh" >&2
    exit 1
fi

export MYSQL_PWD="$DB_PASSWORD"

MYSQL_CMD=(mysql
    --host="$DB_HOST"
    --port="$DB_PORT"
    --user="$DB_USER"
    --default-character-set=utf8mb4
    --table)

for sql_file in \
    "$REPO_ROOT/database/schema.sql" \
    "$REPO_ROOT/database/procedures.sql" \
    "$REPO_ROOT/database/seed.sql"
do
    echo "==> 执行 $(basename "$sql_file")"
    "${MYSQL_CMD[@]}" < "$sql_file"
done

echo "==> 结构 / 数据一致性校验"
"${MYSQL_CMD[@]}" < "$REPO_ROOT/tests/database/verify_schema.sql"

echo "==> 完成。请把上面的 PASS/FAIL 表格保存到 tests/database/results/ 作为验收证据。"
