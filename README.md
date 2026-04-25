# claudecode-plugins

Claude Code plugin marketplace by LevNas.

## Usage

```bash
# Add this marketplace
/plugin marketplace add LevNas/claudecode-plugins
```

## Available Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| [ccmemo](https://github.com/LevNas/ccmemo) | Persist knowledge and plans across Claude Code sessions | `/plugin install ccmemo@levnas-plugins` |
| [ccresmon](https://github.com/LevNas/ccresmon) | Resource monitor hook (memory/CPU/disk I/O checks) | `/plugin install ccresmon@levnas-plugins` |
| [ccevolve](https://github.com/LevNas/ccevolve) | Self-improving workflow for Claude Code | `/plugin install ccevolve@levnas-plugins` |
| [ccorch](https://github.com/LevNas/ccorch) | tmux-based orchestration for multi-level task delegation | `/plugin install ccorch@levnas-plugins` |
| [ccaudit](https://github.com/LevNas/ccaudit) | Audit-trail capture for AI-assisted work (Stop-hook flush + /audit-flush) | `/plugin install ccaudit@levnas-plugins` |

## For Plugin Developers

- [Development Guide](docs/development-guide.md) — directory layout, SKILL.md frontmatter rules, plugin.json conventions, new plugin checklist
- [SKILL.md Linter](scripts/lint-skills.sh) — central linter enforcing the 4 required frontmatter fields (`name` / `description` / `license` / `allowed-tools`) and file-size/TOC conventions

```bash
# Lint a plugin
bash scripts/lint-skills.sh ~/src/github.com/LevNas/ccmemo

# Lint all LevNas plugins at once
bash scripts/lint-skills.sh \
  ~/src/github.com/LevNas/ccmemo \
  ~/src/github.com/LevNas/ccevolve \
  ~/src/github.com/LevNas/ccorch \
  ~/src/github.com/LevNas/ccresmon
```
