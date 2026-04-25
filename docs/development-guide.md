# LevNas プラグイン開発ガイド

LevNas の Claude Code プラグインエコシステムに新しいプラグインを追加する、または既存プラグインを更新するための規約集です。

## エコシステム構成

LevNas はマルチリポジトリ型でプラグインを管理しています。

```
LevNas/claudecode-plugins      # マーケットプレイス (このリポジトリ)
├── .claude-plugin/marketplace.json   # プラグイン索引
├── docs/development-guide.md          # このファイル
└── scripts/lint-skills.sh             # 中央リンタ

LevNas/ccmemo       # プラグイン本体 (独立リポジトリ)
LevNas/ccevolve     # 同上
LevNas/ccorch       # 同上
LevNas/ccresmon     # 同上
```

各プラグインは独立したパブリックリポジトリで管理し、`claudecode-plugins` はそれらを `marketplace.json` で索引します。

## プラグインの種類

| 種類 | 例 | 特徴 |
|------|----|----|
| Skill型 | ccmemo / ccevolve | `skills/*/SKILL.md` を1つ以上持つ |
| Hook型 | ccresmon | SKILL.md を持たず、`hooks.json` と実行ファイルで動作 |
| 複合型 | ccorch | Skill + Hook + スクリプトの組合せ |

リンタは SKILL.md が存在しないプラグインを正常扱いにします(Hook型は frontmatter 検査をスキップ)。

## ディレクトリ構造の規約

### 標準レイアウト

```
<plugin-repo>/
├── .claude-plugin/
│   └── plugin.json              # プラグインメタデータ (必須)
├── README.md                    # ユーザー向け説明 (必須)
├── LICENSE                      # ライセンス (必須)
├── skills/                      # Skill型の場合
│   └── <skill-name>/
│       ├── SKILL.md             # スキル定義 (必須)
│       ├── references/          # 実行時参照リソース (任意)
│       └── assets/templates/    # テンプレート (任意)
├── hooks/                       # Hook型の場合
│   ├── hooks.json
│   └── <hook-impl>
├── scripts/                     # 補助スクリプト (任意)
├── docs/                        # 開発者/運用者向け内部ドキュメント (任意)
└── tests/                       # テスト (任意)
```

### ドキュメントの種類と配置場所

| 種類 | 配置場所 | 読者 |
|------|----------|------|
| プラグイン概要・導入手順 | `README.md` | プラグイン利用者 (人間) |
| スキル定義 | `skills/<name>/SKILL.md` | Claude Code |
| 実行時参照リソース | `skills/<name>/references/*.md` | Claude Code |
| テンプレート | `skills/<name>/assets/templates/` | Claude Code |
| 設計ドキュメント (任意) | `docs/` または `docs/sdd/` | 開発者 (人間) |

**禁止事項**:

- skills/<name>/ 以下に README.md を置かない (利用者向け情報は `README.md` に集約)
- スキル定義と実行時参照リソースを同一ファイルに詰め込まない (巨大化防止)
- `templates/` (assets/ 無し) のような非標準名は使わない

**LevNas独自事項**: 設計ドキュメントを持つプラグイン (ccorch / ccresmon) は `docs/sdd/` 構造 (requirements/ design/ tasks/) を採用してよい。ただし SKILL.md・references・assets は上記の標準レイアウトを守ること。

## SKILL.md 規約

### frontmatter 必須4フィールド

```yaml
---
name: my-skill-name
description: 1行で完結する具体的な説明。いつ・何のために使うかを明示する
license: MIT
allowed-tools: Read, Grep, Glob, Edit, Write
---
```

| フィールド | 要件 |
|-----------|------|
| `name` | kebab-case (`^[a-z0-9-]+$`)、64文字以下 |
| `description` | 1024文字以下。何をするスキルかが1行で判る粒度 |
| `license` | プラグインのLICENSEと整合させる (通常 `MIT`) |
| `allowed-tools` | 実際に呼び出すツール名のカンマ区切り |

### その他の制約

- SKILL.md は **500行以内** を推奨 (超過時は warn)
- `references/*.md` が100行を超える場合は `## 目次` または `<!-- TOC -->...<!-- /TOC -->` を記載
- 全 `.md` ファイルは **50KB以下** (README.md / CLAUDE.md / CHANGELOG.md と `docs/` 配下は対象外)

## plugin.json 規約

各プラグインリポジトリの `.claude-plugin/plugin.json` に最低限以下を記述します。

```json
{
  "name": "ccmemo",
  "version": "1.10.2",
  "description": "Persist knowledge and plans across Claude Code sessions",
  "author": "LevNas",
  "license": "MIT",
  "keywords": ["knowledge", "memory", "planning"]
}
```

- `name` はリポジトリ名と一致させる
- `version` は SemVer
- `keywords` は marketplace での検索性に直結するため適切に

## 新プラグインの追加手順

1. 新しいパブリックリポジトリ `LevNas/<plugin-name>` を作成
2. 標準レイアウトに沿って `plugin.json` / README / LICENSE / (skills or hooks) を配置
3. `claudecode-plugins/.claude-plugin/marketplace.json` に以下を追加:
   ```json
   {
     "name": "<plugin-name>",
     "source": { "source": "github", "repo": "LevNas/<plugin-name>" },
     "description": "..."
   }
   ```
4. `claudecode-plugins/README.md` の「Available Plugins」表に1行追加
5. このガイドのリンタで検査:
   ```bash
   bash scripts/lint-skills.sh ~/src/github.com/LevNas/<plugin-name>
   ```

## リンタの使い方

`scripts/lint-skills.sh` は `claudecode-plugins` リポジトリに置かれた中央リンタです。別リポジトリにあるプラグインを引数で指定して検査します。

```bash
# 単一プラグイン検査
bash scripts/lint-skills.sh ~/src/github.com/LevNas/ccmemo

# 複数プラグイン一括検査
bash scripts/lint-skills.sh \
  ~/src/github.com/LevNas/ccmemo \
  ~/src/github.com/LevNas/ccevolve \
  ~/src/github.com/LevNas/ccorch \
  ~/src/github.com/LevNas/ccresmon

# 警告もエラー扱い (strict)
bash scripts/lint-skills.sh --strict ~/src/github.com/LevNas/ccmemo
```

### 検査項目

1. SKILL.md の行数 (500行超で warn)
2. frontmatter 必須4フィールド (name / description / license / allowed-tools)
3. name の形式 (kebab-case) と長さ
4. description の長さ
5. `references/*.md` の TOC (100行超で必須)
6. `.md` ファイルサイズ (50KB以下)

### 終了コード

- `0`: エラー無し (警告のみは通常通り成功)
- `1`: エラー発生、または `--strict` 指定時に警告有り
- `2`: 引数不正

## CI

現在、分散CI (各プラグインリポジトリの GitHub Actions) は導入していません。リンタ仕様の安定後に段階的に展開予定。それまでは手元で `lint-skills.sh` を実行して品質を担保してください。
