#!/usr/bin/env python3
"""LibraCore 第 10 周借还业务验证（真实 MySQL 8，无需 Python 数据库驱动）。

用法：
  DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=<user> DB_PASSWORD=<pwd> \
      python tests/database/verify_loans.py

依赖：mysql 命令行客户端在 PATH（或用 MYSQL_BIN 指定），库 libra_core，
且已执行过 database/schema.sql、database/procedures.sql、database/seed.sql。
输出同时保存到 tests/database/results/verify-loans-<日期>.txt。
"""

import concurrent.futures
import datetime
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
RESULTS = ROOT / 'tests' / 'database' / 'results'
BIN = os.environ.get('MYSQL_BIN', 'mysql')
HOST = os.environ.get('DB_HOST', '127.0.0.1')
PORT = os.environ.get('DB_PORT', '3306')
USER = os.environ.get('DB_USER', 'root')
PWD = os.environ.get('DB_PASSWORD', '')
DB = 'libra_core'

LINES = []


def log(msg=''):
    print(msg)
    LINES.append(str(msg))


def mysql(sql):
    env = os.environ.copy()
    if PWD:
        env['MYSQL_PWD'] = PWD
    cmd = [BIN, '--host=' + HOST, '--port=' + PORT, '--user=' + USER,
           '--default-character-set=utf8mb4', '--batch', '--skip-column-names', DB]
    p = subprocess.run(cmd, input=sql, text=True, capture_output=True,
                       encoding='utf-8', env=env)
    return p.returncode, (p.stdout or '').strip(), (p.stderr or '').strip()


def scalar(sql):
    rc, out, err = mysql(sql)
    if rc != 0 or not out:
        return None
    return out.splitlines()[0].strip()


def reset():
    seed = (ROOT / 'database' / 'seed.sql').read_text(encoding='utf-8')
    rc, out, err = mysql(seed)
    if rc != 0:
        log('重置 seed.sql 失败: ' + err)
        sys.exit(1)


RECORDS = []


def check(name, ok, detail=''):
    RECORDS.append((name, bool(ok), detail))
    line = '%-42s %-4s %s' % (name, 'PASS' if ok else 'FAIL', detail)
    log(line.rstrip())


def expect_error(sql, keyword):
    rc, out, err = mysql(sql)
    msg = err.splitlines()[-1] if err else '(无错误信息)'
    return rc != 0 and keyword in err, msg


def main():
    log('LibraCore 第 10 周借还验证 | MySQL %s | %s' %
        (scalar('SELECT VERSION()'), datetime.datetime.now().isoformat(timespec='seconds')))
    log('=' * 78)

    # ---------- 正常借 → 查 → 还 ----------
    reset()
    copy_id = scalar("SELECT id FROM book_copies WHERE status='available' ORDER BY id LIMIT 1")
    book_id = scalar(f"SELECT book_id FROM book_copies WHERE id={copy_id}")
    avail_before = int(scalar(f"SELECT available_copies FROM v_book_inventory WHERE book_id={book_id}"))

    rc, out, err = mysql(f"CALL sp_borrow_book({copy_id}, 1, 30)")
    loan_id = out.splitlines()[0].strip() if (rc == 0 and out) else None
    ok = rc == 0 and loan_id is not None and loan_id.isdigit()
    check('T10-1 正常借书', ok, f'copy_id={copy_id} loan_id={loan_id} {err[:60]}')
    if not ok:
        log('借书失败，后续用例无法继续')
        return

    check('T10-1a 副本变为 borrowed',
          scalar(f"SELECT status FROM book_copies WHERE id={copy_id}") == 'borrowed')
    check('T10-1b 借阅记录为 active',
          scalar(f"SELECT status FROM borrow_records WHERE id={loan_id}") == 'active')
    check('T10-1c 可借数减少 1',
          int(scalar(f"SELECT available_copies FROM v_book_inventory WHERE book_id={book_id}")) == avail_before - 1)
    check('T10-1d 当前借阅视图可见',
          scalar(f"SELECT COUNT(*) FROM v_active_loans WHERE loan_id={loan_id}") == '1')

    ok, msg = expect_error(f"CALL sp_borrow_book({copy_id}, 1, 30)", 'COPY_UNAVAILABLE')
    check('T10-2 重复借同一副本被拒', ok, msg)
    check('T10-2a 未产生第二条 active',
          scalar(f"SELECT COUNT(*) FROM borrow_records WHERE copy_id={copy_id} AND status='active'") == '1')

    rc, out, err = mysql(f"CALL sp_return_book({loan_id})")
    check('T10-3 正常还书', rc == 0, err[:60])
    check('T10-3a 副本回到 available',
          scalar(f"SELECT status FROM book_copies WHERE id={copy_id}") == 'available')
    check('T10-3b returned_at 已写入',
          scalar(f"SELECT returned_at IS NOT NULL FROM borrow_records WHERE id={loan_id}") == '1')
    check('T10-3c 可借数恢复',
          int(scalar(f"SELECT available_copies FROM v_book_inventory WHERE book_id={book_id}")) == avail_before)
    ok, msg = expect_error(f"CALL sp_return_book({loan_id})", 'ALREADY_RETURNED')
    check('T10-4 重复还书被拒', ok, msg)

    # ---------- 异常输入 ----------
    reset()
    copy2 = scalar("SELECT id FROM book_copies WHERE status='available' ORDER BY id LIMIT 1")
    ok, msg = expect_error(f"CALL sp_borrow_book({copy2}, 999999, 30)", 'READER_NOT_FOUND')
    check('T10-5 无效读者被拒', ok, msg)
    ok, msg = expect_error(f"CALL sp_borrow_book({copy2}, 3, 30)", 'READER_SUSPENDED')
    check('T10-6 停用读者被拒', ok, msg)
    ok, msg = expect_error("CALL sp_borrow_book(999999, 1, 30)", 'COPY_NOT_FOUND')
    check('T10-7 无效副本被拒', ok, msg)
    ok, msg = expect_error("CALL sp_return_book(999999)", 'LOAN_NOT_FOUND')
    check('T10-7a 无效借阅记录被拒', ok, msg)

    # ---------- 并发争抢同一副本 ----------
    reset()
    c3 = scalar("SELECT id FROM book_copies WHERE status='available' ORDER BY id LIMIT 1")

    def borrow(reader_id):
        return mysql(f"CALL sp_borrow_book({c3}, {reader_id}, 30)")

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(borrow, r) for r in (1, 2)]
        results = [f.result() for f in futures]
    succeeded = sum(1 for rc, out, err in results if rc == 0)
    failures = [err.splitlines()[-1] if err else '' for rc, out, err in results if rc != 0]
    check('T10-8 并发争抢仅一次成功', succeeded == 1,
          f'成功={succeeded} 失败={failures}')
    check('T10-8a 副本最终为 borrowed',
          scalar(f"SELECT status FROM book_copies WHERE id={c3}") == 'borrowed')
    check('T10-8b 该副本仅一条 active 借阅',
          scalar(f"SELECT COUNT(*) FROM borrow_records WHERE copy_id={c3} AND status='active'") == '1')
    check('T10-8c 无半更新（借阅记录与副本一致）',
          scalar("SELECT COUNT(*) FROM borrow_records br JOIN book_copies c ON c.id=br.copy_id "
                 "WHERE br.status='active' AND c.status<>'borrowed'") == '0')

    # ---------- 恢复初始数据 ----------
    reset()
    counts = scalar("SELECT CONCAT((SELECT COUNT(*) FROM books),'/',"
                    "(SELECT COUNT(*) FROM book_copies),'/',"
                    "(SELECT COUNT(*) FROM borrow_records))")
    check('T10-9 验证后恢复初始数据', counts == '16/44/3', f'books/copies/loans={counts}')

    passed = sum(1 for _, ok, _ in RECORDS if ok)
    log('=' * 78)
    log(f'合计 {len(RECORDS)} 项，通过 {passed}，失败 {len(RECORDS) - passed}')
    RESULTS.mkdir(parents=True, exist_ok=True)
    out_path = RESULTS / ('verify-loans-' + datetime.date.today().isoformat() + '.txt')
    out_path.write_text('\n'.join(LINES) + '\n', encoding='utf-8')
    log('证据文件: ' + str(out_path))
    sys.exit(0 if passed == len(RECORDS) else 1)


if __name__ == '__main__':
    main()
