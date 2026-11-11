#!/usr/bin/env python3
"""Mechanical gate for the skill benchmark. Checks what a program can check; see bench/rubric.md.

Usage: python3 bench/check.py [PLUGIN_ROOT]   (exit 1 when any skill fails a check)
"""
import os
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
LEDGER_CMDS = {"append", "verify", "list", "show", "pending", "thread", "strategies"}
ENTRY_TYPES = {"open", "fill", "check", "adjust", "close", "review", "decision"}
OPTCALC_CMDS = {"screen", "value", "drawdown", "corr", "facts", "book", "income"}
MAX_LINES = 100
EM_DASH = "—"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    return dict(line.split(":", 1) for line in m.group(1).splitlines() if ":" in line)


def check_skill(name, text, skills, agents, optcalc_flags):
    fails = []
    fm = frontmatter(text)
    if fm is None:
        fails.append("no frontmatter")
    else:
        keys = {k.strip() for k in fm}
        if keys != {"name", "description"}:
            fails.append(f"frontmatter keys are {sorted(keys)}, expected name and description")
        if fm.get("name", "").strip() != name:
            fails.append(f"frontmatter name '{fm.get('name', '').strip()}' does not match folder '{name}'")
        if len(fm.get("description", "").strip()) < 40:
            fails.append("description shorter than 40 characters")
    lines = text.count("\n")
    if lines > MAX_LINES:
        fails.append(f"{lines} lines, limit {MAX_LINES}")
    if not re.search(r"^## Next\b", text, re.M):
        fails.append("no '## Next' section")
    if EM_DASH in text:
        fails.append("contains an em dash")
    if "/Users/" in text or "/home/" in text:
        fails.append("contains an absolute home path")
    for ref in sorted(set(re.findall(r"/fin-protek:([a-z0-9-]+)", text))):
        if ref not in skills:
            fails.append(f"references missing skill /fin-protek:{ref}")
    for ref in sorted(set(re.findall(r"(?<![/\w])fin-protek:([a-z0-9-]+)", text))):
        if ref not in agents and ref not in skills:
            fails.append(f"references missing agent fin-protek:{ref}")
    for cmd in sorted(set(re.findall(r"bin/ledger ([a-z]+)", text))):
        if cmd not in LEDGER_CMDS:
            fails.append(f"bin/ledger has no command '{cmd}'")
    for types in re.findall(r"--type ([a-z|]+)", text):
        for t in types.split("|"):
            if t and t not in ENTRY_TYPES:
                fails.append(f"unknown ledger entry type '{t}'")
    for cmd in sorted(set(re.findall(r"bin/optcalc ([a-z]+)", text))):
        if cmd not in OPTCALC_CMDS:
            fails.append(f"bin/optcalc has no command '{cmd}'")
    for call in re.findall(r"bin/optcalc (?:screen|value)[^`\n]*(?:\n[^`\n]*)?", text):
        for flag in re.findall(r"--[a-z-]+", call):
            if flag not in optcalc_flags:
                fails.append(f"bin/optcalc has no flag '{flag}'")
    return sorted(set(fails))


def main():
    skills_dir = os.path.join(ROOT, "skills")
    skills = sorted(d for d in os.listdir(skills_dir) if os.path.isfile(os.path.join(skills_dir, d, "SKILL.md")))
    agents = {f[:-3] for f in os.listdir(os.path.join(ROOT, "agents")) if f.endswith(".md")}
    # every flag the program accepts appears in its usage text
    optcalc_flags = set(re.findall(r"--[a-z-]+", read(os.path.join(ROOT, "optcalc", "optcalc.ml"))))
    bad = 0
    for name in skills:
        fails = check_skill(name, read(os.path.join(skills_dir, name, "SKILL.md")), set(skills), agents, optcalc_flags)
        print(f"{'PASS' if not fails else 'FAIL'}  {name}")
        for f in fails:
            print(f"      - {f}")
        bad += bool(fails)
    for name in sorted(agents):
        text = read(os.path.join(ROOT, "agents", name + ".md"))
        fails = []
        fm = frontmatter(text)
        if fm is None or fm.get("name", "").strip() != name:
            fails.append("frontmatter name missing or does not match file name")
        if EM_DASH in text:
            fails.append("contains an em dash")
        print(f"{'PASS' if not fails else 'FAIL'}  agent {name}")
        for f in fails:
            print(f"      - {f}")
        bad += bool(fails)
    print(f"\n{len(skills)} skills, {len(agents)} agents, {bad} failing")
    sys.exit(1 if bad else 0)


main()
