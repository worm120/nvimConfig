#!/usr/bin/env python3
"""clangd 工程索引"热了没"探针：冷启动一个 clangd，按间隔数工程索引目录里 .idx 的新增数量。

用途：判断 <A-r> 引用为空到底是"后台索引还没建完"（这里会看到 .idx 持续新增）还是"索引早就好了、
      是那个长跑进程的问题"（这里 0 新增）。

用法：
  ROOT=<编译库根> python3 clangd_index_warm.py            # 间隔 20s、共 5 次
  ROOT=... INTERVAL=10 SAMPLES=10 python3 clangd_index_warm.py
  CLANGD=<二进制> ROOT=... python3 clangd_index_warm.py

注意：索引目录是**工程本地**的（当祖先目录里存在 <project>/.cache/clangd 时），
      否则是 ~/.cache/clangd/index，脚本会自动选。
"""
import glob
import json
import os
import subprocess
import threading
import time

ROOT = os.environ.get("ROOT") or os.getcwd()
CLANGD = os.environ.get("CLANGD") or "clangd"
INTERVAL = float(os.environ.get("INTERVAL", "20"))
SAMPLES = int(os.environ.get("SAMPLES", "5"))

project_idx = os.path.join(ROOT, ".cache/clangd/index")
user_idx = os.path.join(os.path.expanduser("~"), ".cache/clangd/index")
IDX = project_idx if os.path.isdir(project_idx) else user_idx
print(f"索引目录 = {IDX}" + ("（工程本地）" if IDX == project_idx else "（用户级）"))
if not os.path.isdir(IDX):
    print("索引目录还不存在 —— clangd 会在首次索引后才创建它")


def snap():
    return {os.path.basename(p): os.path.getmtime(p) for p in glob.glob(IDX + "/*.idx")}


before = snap()
print(f"启动前 .idx 数量 = {len(before)}")
print(f"启动 clangd（{CLANGD}），每 {INTERVAL:.0f}s 采样一次，共 {SAMPLES} 次 ...")

proc = subprocess.Popen([CLANGD], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=open("/tmp/clangd_index_warm.err", "wb"), cwd=ROOT)
assert proc.stdin is not None and proc.stdout is not None
stdin, stdout = proc.stdin, proc.stdout
replies, cv = {}, threading.Condition()


def send(o):
    b = json.dumps(o).encode()
    with cv:
        stdin.write(b"Content-Length: %d\r\n\r\n" % len(b) + b)
        stdin.flush()


def read_one():
    h = {}
    while True:
        ln = stdout.readline()
        if not ln:
            return None
        ln = ln.strip()
        if not ln:
            break
        k, _, v = ln.partition(b":")
        h[k.strip().lower()] = v.strip()
    return json.loads(stdout.read(int(h[b"content-length"])))


def reader():
    while True:
        m = read_one()
        if m is None:
            return
        if not isinstance(m, dict):
            continue
        if "method" in m and "id" in m:
            send({"jsonrpc": "2.0", "id": m["id"], "result": None})   # 回掉 server request
        elif "id" in m:
            with cv:
                replies[m["id"]] = m
                cv.notify_all()


threading.Thread(target=reader, daemon=True).start()
send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
      "params": {"processId": os.getpid(), "rootUri": "file://" + os.path.abspath(ROOT),
                 "capabilities": {}, "rootPath": os.path.abspath(ROOT),
                 "workspaceFolders": [{"uri": "file://" + os.path.abspath(ROOT), "name": "root"}]}})
with cv:
    end = time.time() + 30
    while 1 not in replies and time.time() < end:
        cv.wait(0.5)
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

total_new = 0
for i in range(1, SAMPLES + 1):
    time.sleep(INTERVAL)
    now = snap()
    new = [k for k in now if k not in before]
    total_new += len(new)
    before = now
    print(f"  +{i * INTERVAL:5.0f}s: .idx 总数 {len(now):5d}, 本次新增 {len(new):3d}"
          + ("   " + ", ".join(new[:6]) if new else ""), flush=True)

print(f"\n合计新增 {total_new} 个 .idx")
print("新增为 0 → 索引是热的（clangd 认为磁盘 shard 都是最新的，会跳过重索引）；"
      "此时 <A-r> 仍为空就别再等索引了，去查那个长跑进程（tools/probe_nvim_lsp.lua）")
print("持续新增 → 索引还在建，等写盘结束再按 <A-r>（每次按都由 clangd 立刻用当前索引作答，不等后台索引）")
proc.terminate()