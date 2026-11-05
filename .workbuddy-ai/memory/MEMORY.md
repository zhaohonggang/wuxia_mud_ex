# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略）。
  - 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 改动前 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`，确认真缺口。
- 不要升级 nimble_parsec。

## 已结案（已 commit）
- R5 动态招式表迁移：92 个真缺口全部迁移，`test/kantele/combat` 回归绿，commit b490fbb2。
- F4 @static 白名单补全 batch6：109 个未注册特技全部注册，@static 唯一 id 733（与 .ex 模块数一致），commit b1702540（分支 kalevala，未 push）。
- valid_learn 全量迁移：已注册技能里带 non-trivial valid_learn 的全部 LPC 保真迁移，review_messages.py 全部通过，commit 10068b35 + 03a0e120。
- F4 valid_learn 长尾补全批次1：linji-zhuang/longxiang-gong（arity-2 character/vitals 门），commit 7a609e9c，11/0。
- F4 valid_learn 长尾补全批次2+3：12 arity-1 + 4 arity-2 共 16 技能补 valid_learn，测试 54/0；commit 4534d108（已 push origin kalevala）。

## 人格（personality）建模——已定案
- **规范字段 = `meta.character`**（`Kantele.Character.PlayerMeta` moduledoc 第 12 行；参考实现 `skills/poison.ex` 读 `character.meta.character`；`LearnCommand` 已把 `meta.character` 作为 `student_character` 下发）。
- LPC 里 `set("character", ...)` 只有 2 处：`d/register/npc/{hua,li,lu,wei}.c`（NPC 注册）与 `adm/daemons/updated.c:515`（**转世**设「国士无双」）。故玩家侧未设 = nil ≡ LPC 0：
  - **排除门**（`== X` 则拒）→ nil 不拦；
  - **包含门**（`!= X && != Y` 则拒）→ nil **拦**（xiantian-gong / daojian-guizhen / sanwu-shou / wudoumi-shengong 因此实为转世专属）。
- 批前 30 个技能文件误读 `Map.get(meta, :personality)`（键名不存在 → 恒 nil）已全部改 `:character`（共 32 文件，含 2 个 performs/）。
- `Combat.@applies_keys` 里的 `:personality` 是**另一个概念**（人格魅力/镶嵌属性），不要动。
- `marks` 已随 `skills/learn` 事件下发（`student_marks`），`Skill.mark?/2` 的 `can_learn/...`、`can_perform/...` 门才真正生效（此前 6 个技能的 mark 门是死代码）。

## @static 白名单当前：733 唯一 id（与 733 `.ex` 模块一致，0 缺失 0 extra）。

## 进行中
- valid_learn 长尾补全过程：批次1（7a609e9c）+ 批次2+3（4534d108，已 push）+ 批次4（12 技能，22/0）+ 批次5（16 技能，90/0）+ 批次6（2 技能：dugu-jiujian/jiuyang-shengong，5/0）+ **批次7（personality 建模后回填 19 个性格门，batch7 测试 76/0）** 已做，均未 commit。真实缺口从 21 → **2**：仅 hunyuan-yiqi（`guilty` 未建模）、qiankun-danuoyi（`query_condition` 未建模）。
- 遗留（非 valid_learn 缺口）：① 全量套件 105 个既有失败（ForceRegenerate 模块缺失 / 测试传裸 map 而 impl 要 Stats 结构体 / chongling-jian 空手期望），与批次7 无关；② `meta.character` 运行态不落盘，且无玩家侧赋値入口（转世未实现），故 4 个包含门技能当前不可学——与 LPC 一致。
- 详见 2026-11-01.md / 2026-11-02.md / 2026-11-05.md。铁律：未经用户明确要求不 commit/push。
- **C-PVE27 完整进度文档**：`docs/C-PVE27-valid_learn-长尾补全进度.zh-CN.md`（7 批次总表 + personality 建模决策 + 测试回归 + 剩余缺口），两份待办文档已加链。

## 本次会话完成（2026-11-05）
- **Task #302** `Yanluo.ask_specs/0 「锁阳丹」`：`lib/kantele/npc/yanluo.ex` 新增 spec，`execute` 透过 `Quest.set_todo/3` 登记任务。
- **Task #303** `SuoyangdanAccept` + `give_event` 药引交付：新建 `lib/kantele/world/suoyangdan_accept.ex`；`give_event.ex` 新增 `:suoyangdan` 分发、`rule_hit/2`、`suoyangdan_give_ingredient/2`；`events.ex` 注册 `suoyangdan/give-ingredient`；`death.ucl` 四味药引规则改 `kind = "suoyangdan"`。
- **Task #304** 测试：`test/kantele/world/hell_zhen_test.exs` 新增 gate_error 锁阳丹硬门 3 例、Yanluo ask_specs 2 例、SuoyangdanAccept 1 例、Quest 级药引追踪 3 例；修正既有 `grant_animaout` 断言（第九门生效）。
- **Task #305** 验证：Docker `mix compile` exit 0；`hell_zhen_test.exs` 27/0；quest_test+hell_zhen+reborn 82/0；give/accept 相关 38/0。

## @static 白名单当前：733 唯一 id（与 733 `.ex` 模块一致，0 缺失 0 extra）。
