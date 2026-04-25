#!/usr/bin/env bash
# lint-skills.sh - LevNas plugin SKILL.md linter
#
# Usage:
#   lint-skills.sh [--strict] <plugin-path> [<plugin-path>...]
#
# Checks SKILL.md files in the given plugin directories against the
# LevNas plugin conventions. A plugin without any SKILL.md is treated as
# valid (e.g. hook-only plugins like ccresmon).
set -euo pipefail

STRICT=false
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=true ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TARGETS+=("$arg") ;;
  esac
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "usage: $(basename "$0") [--strict] <plugin-path> [<plugin-path>...]" >&2
  exit 2
fi

MAX_SKILL_LINES=500
MAX_DESCRIPTION_CHARS=1024
MAX_NAME_CHARS=64
MAX_FILE_SIZE_KB=50
MIN_REF_LINES_FOR_TOC=100

REQUIRED_FIELDS=(name description license allowed-tools)

warnings=0
errors=0
checks=0

warn() { echo "[WARN] $1"; warnings=$((warnings + 1)); }
ok()   { echo "[OK]   $1"; }
err()  { echo "[ERR]  $1"; errors=$((errors + 1)); }
check(){ checks=$((checks + 1)); }

lint_target() {
  local root="$1"

  if [ ! -d "$root" ]; then
    err "$root: not a directory"
    return
  fi

  local plugin_name
  plugin_name="$(basename "$root")"
  echo "=== $plugin_name ($root) ==="

  local skill_files=()
  while IFS= read -r f; do
    skill_files+=("$f")
  done < <(find "$root" -name "SKILL.md" -not -path "*/node_modules/*" -not -path "*/.git/*" | sort)

  if [ "${#skill_files[@]}" -eq 0 ]; then
    ok "$plugin_name: no SKILL.md (hook-only plugin, skipping frontmatter checks)"
  else
    # --- Check 1: SKILL.md line count ---
    for skill_file in "${skill_files[@]}"; do
      check
      local rel="${skill_file#"$root"/}"
      local line_count
      line_count=$(wc -l < "$skill_file" | tr -d ' ')
      if [ "$line_count" -gt "$MAX_SKILL_LINES" ]; then
        warn "$rel: ${line_count} lines (limit: ${MAX_SKILL_LINES})"
      else
        ok "$rel: ${line_count} lines"
      fi
    done

    # --- Check 2: Frontmatter validation (LevNas: 4 required fields) ---
    for skill_file in "${skill_files[@]}"; do
      check
      local rel="${skill_file#"$root"/}"

      # Read file with CRLF normalized to LF for frontmatter parsing
      local normalized
      normalized=$(tr -d '\r' < "$skill_file")

      local first_line
      first_line=$(printf '%s\n' "$normalized" | head -1)
      if [ "$first_line" != "---" ]; then
        err "$rel: missing YAML frontmatter"
        continue
      fi

      local closing
      closing=$(printf '%s\n' "$normalized" | awk 'NR>1 && /^---$/{print NR; exit}')
      if [ -z "$closing" ]; then
        err "$rel: frontmatter missing closing '---'"
        continue
      fi

      local frontmatter
      frontmatter=$(printf '%s\n' "$normalized" | awk 'NR==1{next} /^---$/{exit} {print}')

      # Required field presence
      local missing=()
      for field in "${REQUIRED_FIELDS[@]}"; do
        if ! echo "$frontmatter" | grep -qE "^${field}:" ; then
          missing+=("$field")
        fi
      done
      if [ "${#missing[@]}" -gt 0 ]; then
        err "$rel: missing required field(s): ${missing[*]}"
        continue
      fi

      # name format + length
      local name_value
      name_value=$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//' || true)
      if [ -z "$name_value" ]; then
        err "$rel: 'name' field is empty"
      else
        if ! echo "$name_value" | grep -qE '^[a-z0-9-]+$'; then
          err "$rel: name '$name_value' must match ^[a-z0-9-]+$"
        fi
        if [ "${#name_value}" -gt "$MAX_NAME_CHARS" ]; then
          warn "$rel: name is ${#name_value} chars (limit: ${MAX_NAME_CHARS})"
        fi
      fi

      # description length (supports block scalar)
      local desc_value
      desc_value=$(echo "$frontmatter" | grep -E '^description:' | head -1 | sed 's/^description:[[:space:]]*//' || true)
      if [ -z "$desc_value" ] || echo "$desc_value" | grep -qE '^\|[-]?$|^>[-]?$'; then
        desc_value=$(echo "$frontmatter" | awk '
          /^description:/ { found=1; next }
          found && /^[a-zA-Z0-9_-]+:/ { exit }
          found { gsub(/^[[:space:]]+/, ""); printf "%s ", $0 }
        ')
        desc_value=$(echo "$desc_value" | sed 's/[[:space:]]*$//')
      fi
      if [ -z "$desc_value" ]; then
        err "$rel: 'description' field is empty"
      elif [ "${#desc_value}" -gt "$MAX_DESCRIPTION_CHARS" ]; then
        warn "$rel: description is ${#desc_value} chars (limit: ${MAX_DESCRIPTION_CHARS})"
      fi

      # license non-empty
      local license_value
      license_value=$(echo "$frontmatter" | grep -E '^license:' | head -1 | sed 's/^license:[[:space:]]*//' || true)
      if [ -z "$license_value" ]; then
        err "$rel: 'license' field is empty"
      fi

      # allowed-tools non-empty
      local tools_value
      tools_value=$(echo "$frontmatter" | grep -E '^allowed-tools:' | head -1 | sed 's/^allowed-tools:[[:space:]]*//' || true)
      if [ -z "$tools_value" ]; then
        err "$rel: 'allowed-tools' field is empty"
      fi

      ok "$rel: frontmatter OK (name=$name_value)"
    done
  fi

  # --- Check 3: Reference files TOC check ---
  while IFS= read -r ref_file; do
    check
    local rel="${ref_file#"$root"/}"
    local line_count
    line_count=$(wc -l < "$ref_file" | tr -d ' ')
    if [ "$line_count" -ge "$MIN_REF_LINES_FOR_TOC" ]; then
      local has_toc_heading has_toc_open has_toc_close
      has_toc_heading=$(grep -ciE '(## 目次|## Contents|## Table of Contents)' "$ref_file" || true)
      has_toc_open=$(grep -c '<!-- TOC -->' "$ref_file" || true)
      has_toc_close=$(grep -c '<!-- /TOC -->' "$ref_file" || true)
      if [ "$has_toc_open" -gt 0 ] && [ "$has_toc_close" -eq 0 ]; then
        warn "$rel: found <!-- TOC --> but missing <!-- /TOC --> (${line_count} lines)"
      elif [ "$has_toc_open" -eq 0 ] && [ "$has_toc_close" -gt 0 ]; then
        warn "$rel: found <!-- /TOC --> but missing <!-- TOC --> (${line_count} lines)"
      elif [ "$has_toc_open" -gt 0 ] || [ "$has_toc_heading" -gt 0 ]; then
        ok "$rel: TOC found (${line_count} lines)"
      else
        warn "$rel: no TOC found (${line_count} lines)"
      fi
    fi
  done < <(find "$root" -path "*/references/*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" | sort)

  # --- Check 4: File size ---
  while IFS= read -r md_file; do
    check
    local rel="${md_file#"$root"/}"
    local size
    size=$(wc -c < "$md_file" | tr -d ' ')
    local limit=$((MAX_FILE_SIZE_KB * 1024))
    if [ "$size" -gt "$limit" ]; then
      local kb=$(( (size + 1023) / 1024 ))
      warn "$rel: ${kb}KB (limit: ${MAX_FILE_SIZE_KB}KB)"
    fi
  done < <(find "$root" -name "*.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/docs/*" \
    -not -name "CLAUDE.md" \
    -not -name "MEMORY.md" \
    -not -name "README.md" \
    -not -name "CHANGELOG.md" | sort)

  echo ""
}

echo "=== LevNas SKILL.md lint ==="
echo ""
for target in "${TARGETS[@]}"; do
  target_abs="$(cd "$target" 2>/dev/null && pwd || echo "$target")"
  lint_target "$target_abs"
done

echo "=== Summary ==="
echo "Checks:   ${checks}"
echo "Warnings: ${warnings}"
echo "Errors:   ${errors}"

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "Lint FAILED with ${errors} error(s) and ${warnings} warning(s)"
  exit 1
elif [ "$warnings" -gt 0 ] && $STRICT; then
  echo ""
  echo "Lint FAILED (strict mode) with ${warnings} warning(s)"
  exit 1
else
  echo ""
  echo "Lint PASSED"
  exit 0
fi
