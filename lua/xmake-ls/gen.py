#!/usr/bin/env python3
"""重新生成 lua_ls 认 xmake 脚本所需的两个文件：

  globals.lua            -- lua_ls 的 diagnostics.globals 名单（xmake 的 DSL 全局 API）
  defs/xmake-defs.lua    -- xmake 对 os/path/table/string 等内建模块的扩展（---@meta 定义）

数据来源（不手抄）：
  1) `xmake show -l apis` —— xmake 自己的 API 注册表（core/project/project.lua 的 project.apis()）
  2) 一个临时 xmake 项目，逐个"字面引用"探测候选名，确认它在本版本里真是脚本作用域的全局
     （xmake 沙箱里 _G / getmetatable / io 都不可用，只能字面引用）

用法（xmake 升级后，或发现新的 undefined-global 时重跑）：
  python3 ~/.config/nvim/lua/xmake-ls/gen.py

配合的 lua_ls 设置写在哪、怎么启用，见本目录上一级 lua/plugins/lsp.lua 里的注释。
"""
import collections
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from typing import NoReturn

HERE = pathlib.Path(__file__).resolve().parent
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

# 会被注入成全局的 DSL 作用域
DSL_SCOPES = ("target", "option", "rule", "package", "toolchain", "task", "language")
# xmake 扩展过的内建模块（这些是"字段"，如 os.projectdir，不能进 globals，得写定义文件）
MODULE_SCOPES = ("os", "io", "path", "string", "table", "math", "coroutine", "debug",
                 "hash", "utils", "net", "async", "cli", "xmake", "linuxos", "macos", "winos")

# core/project/project.lua project.apis() —— 项目作用域的 API（不在 show -l apis 里）
PROJECT_APIS = (
    "set_project", "set_description", "set_allowedmodes", "set_allowedplats",
    "set_allowedarchs", "set_defaultmode", "set_defaultplat", "set_defaultarchs",
    "add_requires", "add_requireconfs", "add_repositories", "add_packagedirs",
    "set_config", "is_os", "is_kind", "is_arch", "is_mode", "is_plat", "is_cross",
    "is_config", "get_config", "has_config", "has_package", "add_moduledirs",
    "add_plugindirs", "add_platformdirs", "add_toolchaindirs",
)

# 构造器与常用脚本级全局（也要实机确认，确认不了的会被丢掉）
CURATED = (
    "namespace", "includes", "include", "set_xmakever", "target", "option", "rule",
    "package", "toolchain", "task", "template", "policy", "language", "add_projectdirs",
    "os", "io", "path", "table", "string", "math", "coroutine", "debug", "hash",
    "format", "utils", "net", "async", "cli", "xmake", "winos", "linuxos", "macos",
    "val", "import", "inherit", "try", "catch", "finally", "raise", "printf", "print",
    "cprint", "cprintf", "dprint", "vprint", "wprint", "iprint", "echo", "assert",
)


def die(msg: str) -> NoReturn:
    print("错误: " + msg, file=sys.stderr)
    sys.exit(1)


def xmake_apis():
    try:
        out = subprocess.run(["xmake", "show", "-l", "apis"],
                             capture_output=True, text=True, timeout=120).stdout
    except FileNotFoundError:
        die("找不到 xmake，请先确认它在 PATH 里")
    except subprocess.TimeoutExpired:
        die("`xmake show -l apis` 超时")
    if not out.strip():
        die("`xmake show -l apis` 没有输出")
    scoped = collections.defaultdict(set)
    for tok in ANSI.sub("", out).split():          # xmake 的输出带 ANSI 颜色码，必须先剥掉
        m = re.fullmatch(r"([a-z_]+)\.([A-Za-z_][A-Za-z_0-9]*)", tok)
        if m:
            scoped[m.group(1)].add(m.group(2))
    if not scoped:
        die("解析 `xmake show -l apis` 失败（输出格式变了？）")
    return scoped


def _probe_block(tag, names, indent):
    """生成一段"逐个字面引用"的探测代码"""
    lines = [indent + "local out_" + tag + " = {}"]
    for n in names:
        lines.append(indent + "if " + n + " ~= nil then out_" + tag +
                     "[#out_" + tag + " + 1] = \"" + n + "\" end")
    lines.append(indent + 'print("PROBE_' + tag + '=" .. table.concat(out_' + tag + ', " "))')
    return lines


def runtime_probe(names):
    """在临时 xmake 项目里确认哪些名字真是脚本作用域的全局"""
    script = ["-- 自动生成：xmake 作用域全局名探测"]
    script += _probe_block("PROJECT", names, "")
    script += ["", 'target("probe")']
    script += _probe_block("TARGET", names, "    ")

    tmp = tempfile.mkdtemp(prefix="xmake-ls-probe-")
    try:
        (pathlib.Path(tmp) / "xmake.lua").write_text("\n".join(script) + "\n")
        try:
            r = subprocess.run(["xmake", "f", "-y"], cwd=tmp, capture_output=True,
                               text=True, timeout=300)
        except subprocess.TimeoutExpired:
            die("探测用的 `xmake f` 超时")
        out = ANSI.sub("", r.stdout + r.stderr)
        if r.returncode != 0 and "PROBE_" not in out:
            die("探测用的 `xmake f` 失败:\n" + out.strip()[:800])
        found = set()
        for tag in ("PROJECT", "TARGET"):
            for line in out.splitlines():
                if line.startswith("PROBE_" + tag + "="):
                    found |= set(line.split("=", 1)[1].split())
        if not found:
            die("探测没有拿到结果，无法确认全局名单")
        return found
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    scoped = xmake_apis()
    print("show -l apis 作用域: " +
          " ".join(f"{k}={len(v)}" for k, v in sorted(scoped.items())))

    dsl = set()
    for s in DSL_SCOPES:
        dsl |= scoped.get(s, set())
    candidates = sorted(dsl | set(PROJECT_APIS) | set(CURATED))
    print(f"候选全局名 {len(candidates)} 个，正在用真 xmake 探测…")
    verified = runtime_probe(candidates)
    dropped = sorted(set(CURATED) - verified)
    if dropped:
        print("探测后丢弃（本版本不存在）: " + " ".join(dropped))

    globals_final = sorted(dsl | set(PROJECT_APIS) | (verified & set(CURATED)))
    _write(HERE / "globals.lua",
           "-- 自动生成，请勿手改：由 lua/xmake-ls/gen.py 从 `xmake show -l apis` + 实机探测导出\n"
           "-- 内容 = xmake 脚本作用域里可用的全局 API（lua_ls 的 Lua.diagnostics.globals）\n"
           "return {\n" + "".join(f'  "{n}",\n' for n in globals_final) + "}\n")

    defs = ["---@meta",
            "--- 自动生成，请勿手改：由 lua/xmake-ls/gen.py 导出",
            "--- xmake 对内建模块与标准库的扩展（os.projectdir / path.join 之类）", ""]
    for scope in MODULE_SCOPES:
        names = sorted(scoped.get(scope, set()))
        if not names:
            continue
        defs.append(f"-- ===== {scope} =====")
        defs.extend(f"function {scope}.{n}(...) end" for n in names)
        defs.append("")
    _write(HERE / "defs" / "xmake-defs.lua", "\n".join(defs) + "\n")

    print(f"globals.lua: {len(globals_final)} 个名字")
    print(f"defs/xmake-defs.lua: {sum(1 for s in MODULE_SCOPES for _ in scoped.get(s, ()))} 条定义")


def _write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    old = path.read_text() if path.exists() else None
    if old == text:
        print(f"{path.name}: 内容无变化")
        return
    path.write_text(text)
    print(f"{path.name}: {'已更新' if old else '已生成'}（{len(text.splitlines())} 行）")


if __name__ == "__main__":
    main()