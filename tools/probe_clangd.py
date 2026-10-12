#!/usr/bin/env python3
"""独立 clangd 探针：用新起的 clangd 查某个符号的 references / definition / workspace-symbol。

用途：判断"磁盘上的工程索引到底有没有这些引用"——如果这里能拿到 N 处，而 nvim 里按 <A-r> 是空的，
      说明问题在那个长跑 clangd 进程的状态（重启用 restart_nvim_lsp.lua），不是代码/配置。

用法：
  python3 probe_clangd.py [文件] [符号名]            # 符号名给了就自动定位它在文件里的第一处
  python3 probe_clangd.py --file <f> --symbol <s> --line <0基行> --col <0基列>
  ROOT/CLANGD 用环境变量覆盖：ROOT=<编译库根> CLANGD=/path/to/clangd python3 probe_clangd.py ...

要点（踩过的坑都写在这）：
  * 只能有**一个**线程读 stdout：主线程与 drain 线程同时 read 会把回复吃掉 → 永久挂住。
  * server→client 的 request（window/workDoneProgress/create 等）必须回结果，否则 clangd 会一直等。
  * clangd 启动即触发对 compile_commands.json 里所有 TU 的后台索引；大 preamble 工程要等几十秒到几分钟，
    本脚本默认只等 20s（够查"索引里已有什么"），要等它自己建完索引就加大 WAIT。
"""
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time

ROOT = os.environ.get("ROOT") or os.getcwd()
CLANGD = os.environ.get("CLANGD") or "clangd"
WAIT = float(os.environ.get("WAIT", "20"))          # didOpen 后等多久再发请求

argv = sys.argv[1:]
file_rel, symbol, line, col = None, None, None, None
while argv:
    a = argv.pop(0)
    if a == "--file":
        file_rel = argv.pop(0)
    elif a == "--symbol":
        symbol = argv.pop(0)
    elif a == "--line":
        line = int(argv.pop(0))
    elif a == "--col":
        col = int(argv.pop(0))
    elif file_rel is None:
        file_rel = a
    elif symbol is None:
        symbol = a
    else:
        sys.exit(f"多余的参数: {a}")

if not file_rel:
    sys.exit(__doc__)
path = file_rel if os.path.isabs(file_rel) else os.path.join(ROOT, file_rel)
if not os.path.exists(path):
    sys.exit(f"文件不存在: {path}")

text = open(path, encoding="utf-8").read()
if line is None:
    if symbol is None:
        sys.exit("需要 --line/--col，或者给一个符号名让我自己定位")
    for i, ln in enumerate(text.split("\n")):
        j = ln.find(symbol)
        if j >= 0:
            line, col = i, j
            break
    if line is None:
        sys.exit(f"在 {path} 里找不到符号 {symbol!r}（给 --line/--col 手动指定）")
assert line is not None and col is not None
print(f"ROOT   = {ROOT}\nCLANGD = {shutil.which(CLANGD) or CLANGD}")
print(f"file   = {path}\npos    = line {line + 1} col {col + 1}"
      + (f"  ({symbol})" if symbol else ""))
print(f"该行  = {text.split(chr(10))[line].strip()[:110]}")

uri = "file://" + os.path.abspath(path)
proc = subprocess.Popen([CLANGD, "--background-index"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=open("/tmp/probe_clangd.err", "wb"), cwd=ROOT)
assert proc.stdin is not None and proc.stdout is not None
stdin, stdout = proc.stdin, proc.stdout
replies, responses, cv = {}, queue.Queue(), threading.Condition()


def send(obj):
    b = json.dumps(obj).encode()
    with cv:
        stdin.write(b"Content-Length: %d\r\n\r\n" % len(b) + b)
        stdin.flush()


def read_one():
    headers = {}
    while True:
        ln = stdout.readline()
        if not ln:
            return None
        ln = ln.strip()
        if not ln:
            break
        k, _, v = ln.partition(b":")
        headers[k.strip().lower()] = v.strip()
    return json.loads(stdout.read(int(headers[b"content-length"])))


def reader():
    while True:
        m = read_one()
        if m is None:
            with cv:
                cv.notify_all()
            return
        if not isinstance(m, dict):
            continue
        if "method" in m and "id" in m:
            responses.put(m)                     # server -> client request
        elif "id" in m:
            with cv:
                replies[m["id"]] = m
                cv.notify_all()


threading.Thread(target=reader, daemon=True).start()


def serve():
    while True:
        m = responses.get()
        send({"jsonrpc": "2.0", "id": m["id"], "result": None})


threading.Thread(target=serve, daemon=True).start()

rid = [0]


def request(method, params, timeout=180):
    rid[0] += 1
    i = rid[0]
    send({"jsonrpc": "2.0", "id": i, "method": method, "params": params})
    end = time.time() + timeout
    with cv:
        while i not in replies and time.time() < end:
            cv.wait(0.5)
        return replies.pop(i, None)


r = request("initialize", {"processId": os.getpid(), "rootUri": "file://" + os.path.abspath(ROOT),
                           "capabilities": {}, "rootPath": os.path.abspath(ROOT),
                           "workspaceFolders": [{"uri": "file://" + os.path.abspath(ROOT), "name": "root"}]}, 60)
print("initialize     :", "ok" if r and "result" in r else r)
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
send({"jsonrpc": "2.0", "method": "textDocument/didOpen",
      "params": {"textDocument": {"uri": uri, "languageId": "cpp", "version": 1, "text": text}}})
print(f"等待 {WAIT:.0f}s（后台索引/诊断）...")
time.sleep(WAIT)


def loc(it):
    l = it.get("location", it)
    return "%s:%d:%d" % (l["uri"].replace("file://", ""), l["range"]["start"]["line"] + 1,
                         l["range"]["start"]["character"] + 1)


res = request("textDocument/references", {"textDocument": {"uri": uri},
                                          "position": {"line": line, "character": col},
                                          "context": {"includeDeclaration": True}})
locs = (res or {}).get("result") or []
print(f"references     : {len(locs)}")
for l in locs[:40]:
    print("    ", loc(l))
print("                 " + ("(空 -> 索引里还没有这个符号的引用；等多一会儿或看第八行的等待时间)"
                            if not locs else "..."))

res = request("textDocument/definition", {"textDocument": {"uri": uri},
                                          "position": {"line": line, "character": col}})
d = (res or {}).get("result")
if isinstance(d, list):
    d = d[0] if d else None
print("definition     :", loc(d) if isinstance(d, dict) and "uri" in d else d)

if symbol:
    res = request("workspace/symbol", {"query": symbol})
    syms = (res or {}).get("result") or []
    print(f"workspace/sym  : {len(syms)}")
    for s in syms[:10]:
        print("    ", s.get("name"), "->", loc(s))

proc.terminate()
print("\nclangd stderr 头几行（看它加载了哪个 compile_commands.json / 有多少 TU 要索引）:")
for ln in open("/tmp/probe_clangd.err", encoding="utf-8", errors="ignore").read().split("\n")[:400]:
    if any(k in ln for k in ("Loaded compilation database", "Enqueueing", "Failed to", "version")):
        print("   ", ln[:160])