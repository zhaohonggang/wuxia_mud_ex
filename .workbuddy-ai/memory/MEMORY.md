# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Project conventions

- **Iron rule**: No `git commit` unless explicitly asked by the user. All work stays uncommitted.
- **No Erlang runtime**: `elixir` is not on PATH (Elixir present at `C:\Program Files\Elixir\` but `erl.exe` missing). `mix compile`/`mix test` cannot run locally. Verification relies on `validate_ucl.py`, Python algorithm ports, code review, idempotent re-runs.
- **UCL format (Elias parser)**:
  - Block members separated by newlines, NO commas between members.
  - Member keys cannot be quoted strings starting with `"` (Elias `read_bare` stops at `"`). Use bare keys, including bare Chinese keys (accepted).
  - Inline objects: multi-line `key = { subkey = value }`, NOT single-line `key = { a = 1 b = 2 }`.
  - `newline=""` when writing UCL files (avoid CRLF on Windows).
  - **String escapes (verified against `deps/elias/src/elias_lexer.xrl` + `elias_parser.yrl`)**:
    - Inside a double-quoted string the ONLY legal backslash uses are `\"` / `\'` (rule `words -> back_slash quotes words`) and `\` + word, e.g. `\n` / `\t` (rule `words -> back_slash word words`).
    - **`\\` (double backslash) is a syntax error** — no `back_slash back_slash` production.
    - **A real newline inside a string is a syntax error** — `words` has no `newline` production. So no multi-line double-quoted strings, and `\` + newline (line continuation) also fails.
    - Elias does NOT unescape: `\n` stays as the two characters `\` + `n` in the parsed value (rendering/unescaping, if any, happens elsewhere).
    - When encoding runtime text: escape backslash/quote **first**, then real newline → `\n`. Doing it in the opposite order double-escapes `\n` into `\\n` and breaks the whole zone file (root cause of the 2026-10-21 hengyang/huashan/suzhou load failure in `backfill_static_look_text.py`).
    - `validate_ucl.py` now has an `EliasStrings` check for these three failure modes; the older `read_string` was lenient and let them through.
  - **Arrays**: elements comma-separated, but **NO trailing comma** (`array_inner -> array_value comma array_inner` needs a value after every comma; `, ]` has no production). `[ {…}, {…}, ]` is a syntax error — earlier note claiming it was OK was wrong.
  - **Chars illegal inside a double-quoted string**: `[`, `]`, `;` (lexer emits `array_open`/`array_close`/`semi_colon`, none of which `words` accepts). Legal inside strings: `,` `=` `*` `#` `-` `:` `/` `'` `{` `}` digits spaces (`,` is NOT excluded by the `Word` regex, so 292 corpus occurrences are fine).
  - Inline single-line blocks like `{ key = "x" text = "y" }` ARE legal (assignments may be space-separated).
- **Backfill discipline (G1–G8)**: dry-run → backup (`tmp/backup-*-<timestamp>/`) → apply (`newline=""`) → `validate_ucl.py` green → idempotent re-run = 0 pending.
- **Backup location**: `tmp/backup-<name>-<YYYYMMDD-HHMMSS>/<zone>.ucl`.

## Inquiry system architecture (ask_* batch)

- **ask_skill → existing perform_id pipeline** (no new handler needed):
  `UCL inquiries map (no kind)` → `NpcAskEvent.handle_scripted_answer/3` → `npc/perform` event → `NpcScriptEvent.perform_result/2` → `SectMaster.inquiry_grant/3` (family + skill level + gongxian + shen + min_levels gating) → `Stats.learn_perform/2` → deduct gongxian.
- **ask_me/ask_me_1/ask_me_2 → kind="give_item"** → `InquiryHandlers.GiveItem` (family gate, unique/carry checks, inventory broadcast, `npc/inquiry_consume`).
- **Silent unhandled kinds**: `kind = "money"`, `"any"`, `"item_id"`, `"player_skill"` in UCL have no `InquiryHandlers` entry → `lookup/1` returns `nil` → silently ignored (pre-existing gap).
- **UCL inquiries config keys** (string keys, loader-normalized): `perform_id`, `skill`, `min_levels` (`%{skill => level}`), `min_gongxian`, `min_shen`, `cost_gongxian`.
- **`SectMaster.inquiry_grant/3`**: `{:ok, perform_id, cost}` | `{:error, msg}`; reads `:family` from player/npc stats for same-sect check (missing family = no block); `perform_known?` checks `MapSet.member?(performs, perform_id)`.

## Files modified in this session

- `data/world/wudang.ucl` — appended `characters "wudang_zhang" { ... }` with 11 ask_skill inquiries (perform_id scripts).
- `data/world/wudu.ucl` — appended `characters "wudu_qiyunao" { ... }` with 3 ask_skill inquiries (perform_id scripts) + 1 ask_me give_item (毒经中篇 → items.dujing2); also fixed pre-existing `$N`/`$n` → `{npc}`/`{name}` in ganggou messages block (lines 4004-4005).
- `scripts/backfill_wudang_zhang_inquiries.py` — new backfill script (G1–G8, idempotent).
- `scripts/backfill_wudu_qiyunao_inquiries.py` — new backfill script (G1–G8, idempotent).
- `test/kantele/sect_master_test.exs` — +18 tests for wudang ask_skills; +16 tests for wudu_qiyunao ask_skills; +14 tests for wudang ask_me NPCs (shan/xi/yin/yu perform_id: yitian-zhang/zheng, xuanxu-dao/huan, raozhi-roujian/chuankong, huzhua-shou/juehu) + failure branches + dedup test.
- `scripts/backfill_wudang_ask_me_inquiries.py` — NEW backfill script for all 6 wudang ask_me NPCs: guxu/qingxu (give_item daodejing_i/ii from clone_lib), shan/xi/yin/yu (perform_id teachings). Applied, validated, idempotent.
- `data/world/wudang.ucl` — appended 6 `characters` blocks: wudang_guxu, wudang_qingxu, wudang_shan, wudang_xi, wudang_yin, wudang_yu.

## Known gaps (not yet done)

- `wudang_zhang` ask_skill6「太极图」: max_jingli>=1000, potential>=learned_points+100, can_perform/taiji-quan/tu counter (>=10 cap) not in inquiry_grant pipeline — TODO noted in UCL comments.
- `wudu_qiyunao` shen gate: LPC requires shen <= -20000/-35000/-40000 (足够邪恶), but `inquiry_grant` checks `shen >= min_shen` (方向相反). `min_shen` set to sentinel -999999999 (disabled); needs `max_shen` handler for strict fidelity.
- Other sects' ask_skill (beyond wudang/wudu) not yet backfilled — batch by sect pending.
- 86 non-ask_skill `ask_*` functions not yet surveyed.
- 完整拱猪子系统接线 (deferred): Pigroom seats/server fields, sit/leave/deal/bid/play actions + phase state machine.
- P6 防回归 housekeeping: uncommitted changes need user-approved commit.
- Full `mix test`: cannot run locally (no Erlang).
