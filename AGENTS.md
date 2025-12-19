# gtex62-clean-suite — Codex instructions

## Working style (must follow)
- One step at a time.
- Prefer minimal diffs. Do not refactor unless explicitly requested.
- Before editing, briefly state what you plan to change and why.
- Default to editing ONLY the selected text in VS Code.
  - If nothing is selected, edit ONLY the currently open file unless I name other files.
- Preserve existing indentation/alignment and comment style.
- After editing, show the exact before/after for each changed line or block.

## Safety rules
- Never run git commit, git push, tag, release, or open PRs unless I explicitly ask.
- You may suggest commit messages and summarize diffs.

## Repo layout
- Widgets live in: `widgets/`
- Shared lua modules live in: `lua/`
- Scripts live in: `scripts/`
- Icons: `icons/`
- Screenshots: `screenshots/`

## Theme + color conventions
- theme.lua uses two color formats:
  1) RGBA tables `{ r, g, b, a }` where r/g/b/a are 0.00–1.00 floats
  2) Hex strings `"RRGGBB"` (no leading `#`)
- When converting `rgb(R,G,B)`:
  - RGBA floats: use `R/255`, `G/255`, `B/255` rounded to 2 decimals unless I specify otherwise
  - Hex strings: convert to 2-digit hex per channel (e.g. rgb(36,36,36) -> "242424")
- When changing a color, update the comment to match the new color name (and rgb/hex when helpful).

## Documentation (README.md)
- If a widget changes behavior, config, dependencies, or file paths, update README.md in the same set of edits.
- README widget sections should include: purpose, dependencies, config snippet, and usage notes.
- If screenshots exist, reference them under `screenshots/`.
