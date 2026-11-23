#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 shawnliu1979
#
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 shawnliu1979
#
# Copilot Reviewer 套件安装脚本
#
#   默认安装到用户级 ~/.copilot/；用 --project 安装到项目级 <repo>/.github/
#   只复制本脚本所在目录内的模板文件：不联网、不装依赖、不改 VS Code 设置。
#
#   安全护栏：--dry-run 只打印不写入；同名文件默认跳过，需 --force 才覆盖。

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
用法: ./install.sh [选项]

作用域（默认 --user）:
  -u, --user                 用户级：~/.copilot/，跨所有工作区生效
  -p, --project [DIR]        项目级：<DIR>/.github/，仅在该仓库生效
                             DIR 省略时取当前工作目录；也支持 --project=DIR
  -n, --dry-run              只打印将执行的操作，不创建目录、不写任何文件
  -f, --force                覆盖目标中已存在的同名文件（默认跳过并提示）
  -h, --help                 显示本帮助

环境变量:
  COPILOT_HOME               覆盖用户级根目录（默认 $HOME/.copilot）

示例:
  ./install.sh                            # 用户级（默认）
  ./install.sh --dry-run                  # 先预演，不写入
  ./install.sh --project                  # 项目级，目标为当前目录/.github
  ./install.sh --project ../myrepo         # 项目级，指定仓库根（相对路径示例）
  ./install.sh -p ../myrepo --force       # 项目级并覆盖同名文件
EOF
}

SCOPE="user"
PROJECT_DIR=""
DRY_RUN=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)      SCOPE="user"; shift ;;
    -p|--project)
      SCOPE="project"
      shift
      if [[ $# -gt 0 && "$1" != -* ]]; then
        PROJECT_DIR="$1"
        shift
      fi
      ;;
    --project=*)
      SCOPE="project"
      PROJECT_DIR="${1#--project=}"
      shift
      ;;
    -n|--dry-run)   DRY_RUN=1; shift ;;
    -f|--force)     FORCE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)
      printf '错误：未知参数 %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# --- 解析目标路径 ---
if [[ "$SCOPE" == "user" ]]; then
  ROOT="${COPILOT_HOME:-$HOME/.copilot}"
  AGENTS_DIR="$ROOT/agents"
  SKILLS_DIR="$ROOT/skills"
  SCOPE_DESC="用户级 (user) —— 跨所有工作区生效"
else
  PROJECT_DIR="${PROJECT_DIR:-$PWD}"

  # 展开引号里可能残留的 ~ 前缀
  case "$PROJECT_DIR" in
    "~"|"~/"*) PROJECT_DIR="$HOME${PROJECT_DIR#\~}" ;;
  esac
  # 相对路径转绝对路径
  if [[ "$PROJECT_DIR" != /* ]]; then
    PROJECT_DIR="$PWD/$PROJECT_DIR"
  fi
  PROJECT_DIR="${PROJECT_DIR%/}"
  [[ -n "$PROJECT_DIR" ]] || PROJECT_DIR="/"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    printf '错误：项目目录不存在: %s\n' "$PROJECT_DIR" >&2
    exit 1
  fi
  if [[ "$PROJECT_DIR" == "/" || "$PROJECT_DIR" == "$HOME" ]]; then
    printf '错误：拒绝把项目级配置写入 %s（会在根目录/家目录创建 .github）。\n请指定具体的仓库路径。\n' "$PROJECT_DIR" >&2
    exit 1
  fi
  if [[ ! -e "$PROJECT_DIR/.git" ]]; then
    printf '提示：%s 不是 git 仓库根（无 .git），仍会安装到其 .github/ 下。\n' "$PROJECT_DIR" >&2
  fi

  ROOT="$PROJECT_DIR/.github"
  AGENTS_DIR="$ROOT/agents"
  SKILLS_DIR="$ROOT/skills"
  SCOPE_DESC="项目级 (project) —— 仅在 $PROJECT_DIR 生效"
fi

# --- 模板完整性 ---
for required in \
  "$KIT_DIR/agents/shawnliu1979-reviewer.agent.md" \
  "$KIT_DIR/agents/shawnliu1979-implementer.agent.md" \
  "$KIT_DIR/skills/shawnliu1979-review-loop/SKILL.md"
do
  if [[ ! -f "$required" ]]; then
    printf '错误：缺少模板文件 %s\n' "$required" >&2
    exit 1
  fi
done

if [[ $DRY_RUN -eq 1 ]]; then
  MODE_DESC="DRY-RUN（只打印，不写入）"
else
  MODE_DESC="实际写入"
fi
if [[ $FORCE -eq 1 ]]; then
  FORCE_DESC="--force：覆盖同名文件"
else
  FORCE_DESC="同名文件默认跳过"
fi

printf '=== Copilot Reviewer 套件安装 ===\n'
printf '模板源  : %s\n' "$KIT_DIR"
printf '作用域  : %s\n' "$SCOPE_DESC"
printf '目标根  : %s\n' "$ROOT"
printf '模式    : %s\n' "$MODE_DESC"
printf '覆盖策略: %s\n\n' "$FORCE_DESC"

COUNT_COPY=0
COUNT_SKIP=0

make_dir() {
  printf '  MKDIR   %s\n' "$1"
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$1"
  fi
}

install_file() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      printf '  OVERWRITE  %s\n' "$dst"
      if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
      fi
      COUNT_COPY=$((COUNT_COPY + 1))
    else
      printf '  SKIP (exists)  %s   [用 --force 覆盖]\n' "$dst"
      COUNT_SKIP=$((COUNT_SKIP + 1))
    fi
  else
    printf '  COPY    %s\n' "$dst"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
    COUNT_COPY=$((COUNT_COPY + 1))
  fi
}

make_dir "$AGENTS_DIR"
make_dir "$SKILLS_DIR"

for src in "$KIT_DIR/agents/"*.agent.md; do
  [[ -f "$src" ]] || continue
  install_file "$src" "$AGENTS_DIR/$(basename "$src")"
done

SKILL_PREFIX="$KIT_DIR/skills/"
SKILL_PREFIX_LEN=${#SKILL_PREFIX}
while IFS= read -r -d '' src; do
  rel="${src:SKILL_PREFIX_LEN}"
  install_file "$src" "$SKILLS_DIR/$rel"
done < <(find "$KIT_DIR/skills" -type f -print0)

printf '\n汇总: 复制 %d, 跳过 %d\n' "$COUNT_COPY" "$COUNT_SKIP"
if [[ $DRY_RUN -eq 1 ]]; then
  printf '（DRY-RUN：以上均未实际执行；去掉 --dry-run 才会写入。）\n'
else
  printf '下一步：在 VS Code 中按 README 第 3 节验证加载情况。\n'
fi
