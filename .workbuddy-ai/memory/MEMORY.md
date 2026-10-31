# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. HEAD == origin/kalevala 时不要自行 push。
- 无本地 Erlang → Docker 是唯一验证路径：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- **提交前体检（用户 2026-10-30 定，替代回归）**：每次 commit 前跑 `docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`，退出码 0 即无编译错误（既有 warning 来自无关文件，可忽略）。`mix compile` 不覆盖 `.exs`，另用 `Code.string_to_quoted!`（`mix run --no-start <script>`）做纯语法解析。**不做测试回归**，全量回归等全部改完由用户最后跑一次。
- 全量回归（4 块）统一收尾跑一次（Docker 易崩）。容器内 `find test -name '*_test.exs' | split -n l/4`，逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`，`set -e` 且**不要** `| tail`，用 `grep --line-buffered "tests, "` 抓摘要。
- **改动前检查铁律**：认定「真缺口」动手前，先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`，确认没早已实现。实测 `valid_learn/1`、`practice_cost()` 在数百技能里早已存在（多为 `(_stats), do: :ok` / `nil` 占位），真缺口多为「占位→LPC 保真」而非「从零新增」。基类（`unarmed.c`/`sword.c` 仅 `inherit SKILL` + 空 `skill_improved`）是假阳性，别碰。
- UCL (Elias)：newline 分隔块、无逗号、裸 key（含中文）、`newline=""`；`"..."` 内仅 `\"`/`\'` 与 `\`+word 合法；数组逗号分隔、无尾逗号。
- clone_lib 去重：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。
- **不要升级 nimble_parsec**（用户明确要求）。`commands.ex` 冷编译 ~28s 是正常代价（452 parse → 452 defparsecp）。详见 `2026-10-28.md`。

## Test gotchas (CRITICAL — 动 skills/combat/items 前必读)
- **技能双通道**：`query_action/2`（无角色，只能空手表）vs **可选** `query_action/3(level, rng, attacker)`（`%Fighter{}`，含 `:skills`/`:weapon_name`/`:weapon_skill_type`）；`valid_enable/1` vs **可选** `valid_enable/2(usage, character)`（`%Kalevala.Character{}`）；`valid_learn/1` vs **可选** `valid_learn/2(stats, character)`（character 形如 `%{meta: %{vitals: %{max_neili: _}, env: %{gender: _}}}`）。宏有默认回落。
- `alias Kantele.Character.Stats` **不会**由 `use Kantele.Combat.Skill` 带入，每个迁移文件须自己加。
- `practice_cost()`：`nil` → 「只能用学(learn)的来增加熟练度」；`%{qi:, neili:}` → `Vitals.damage(:qi, …)` + neili 扣减（非负）。
- `Stats.effective/3` = LPC `query_skill`：`div(skills[usage],2) + skills[special] + apply`，**基本技能折半**。`self` 等级 = `Stats.skill(stats, id())`。基础属性读 `Stats.int/dex/str/con`。
- `Skill.reborn?/1` 以 `stats.reborn` 任一非零加成判定；`Skill.mark?/2` 读 `meta.marks` 顶替 LPC `can_learn`。
- `Fighter.weapon_skill_type` 存**原始** `skill_type`（不套 `pin → sword` 归一），`never-defeated` 按 `"whip"` 分表。
- condition daemon 纯函数不拿 conn → 发声/改状态走 `state.condition_messages` / `condition_unconcious`，由 ConditionEvent flush。生命周期两跳：先递减、后效果。
- `@type` 是保留属性，字符串键常量加前缀（`@key_type`）。
- 物品定义 vs 实例：`%Kalevala.World.Item{}` 全局只读，`%Item.Instance{}` 才带状态；写实例 meta，不污染定义。`Records.inventory` 只存 item_id；跨登录状态进 `serialize_inventory_item/1`（`:book` 刻意不存）。
- `Conn.put_character` 写 `conn.private.update_character`，断言读 `conn.private.update_character || conn.character`。`conn.private` 是**结构体**：`%{conn | private: %{conn.private | room: %{characters: [...]}}}`，`put_in(conn.private[:room], …)` 会炸。
- `:global` name race：setup_all 注册一次 + 每测试 `reset/1`。`put_character/2` 返回新 conn。`Item` 无 `:value/:unit`（在 `item.meta`）。Elixir `0` 为 truthy。
- Elias 三坑：①裸 `#` 行报 syntax error；②列表 `[a.id, b.id]` **逗号后不能有空格**；③块漏 `}` 会吞后续兄弟块。① ② 会让**整区加载失败**。
- `Room.message_vision/3` 是**死接口**（发 `{:vision_message, …}`，Foreman 只处理 `{:room_message, …}`）。房间 vision 用 `RoomActions.Helpers.broadcast_vision/4`。
- 房间角色 `:id` 是**带 zone 的完整 id**（`signature:ganjiang`），按裸名比对永远找不到。
- LPC 数字文案一律 `Kantele.Util.ChineseNumber.to_chinese/1`（照抄 `chinesed.c`：110→「一百十」）。`Money` 已委托它。
- 锻造：报价「两黄金」记账「文」，1 两 = 10000 文；`ForgingTimeout.schedule/4` 取消用 `:timer_token` 令牌（不是 ref）；**顺序**：先 `Forging.put(new_session)` 再 `cancel/1`。落盘不能 `Jason.encode!(%Item{})`（Meta.Trim 只剩 damage/armor）；`file_name/1` 把 `:` 换 `-`。`forge_timing_scale` 生产 1 / 测试 0。
- **事件模块命名铁律**：`use Kalevala.Event.Router` 的 `module(X)` 按 `scope` 前缀拼名；`scope(Kantele.Character)` 下写 `module(Foo)` = `Kantele.Character.Foo`，写成 `Kantele.World.Foo` 只在**运行时**炸。新事件模块一律放 `Kantele.Character.*`。

## C 相位 F4 武功迁移（LPC `kungfu/skill/*.c` → `lib/kantele/combat/skills/*.ex`）
- **整桶收口 (2026-10-29)**：静态 `@actions`（202 空壳）+ `valid_enable`（70 空壳，69 保真）+ `performs/`（728 模块，414 条清单全实现、缺模块 0）。`kungfu-f4-migration-checklist.zh-CN.md` 已加 ⚠️ 过时声明。
- **招式表补齐 ≠ 能用**：必须一并查 `Skills.@static`（195/733 白名单）。生成器改文件时单行 `@actions []` 最易漏，改完 `grep -n "^  @actions"` 数 >1 即残留。
- 余 `TODO(migrate)` = 动态公式门槛：`valid_learn`(680)/`practice_skill`(628)/`query_skill`(1121 多为基础类)/`prepare_skill`(62)/`valid_damage`(17)/`surge`(5)。
- **契约**：`valid_learn/2(stats, character)` 已贯通 learn 事件（`learn_command` 传 `student_vitals` → `skills_event` `do_teach` → `valid_learn(student_stats, %{meta: %{vitals: student_vitals}})`）。
- 已完成批次（全部 commit+push，细节见 `docs/待办实施计划.zh-CN.md` 的 C-PVE7~18 与各日期日志）：

| 批 | commit | 技能（n） |
|---|---|---|
| 1–2 | `f0bc5536` | banruo-zhang, dagou-bang, kuangfeng-jian, cibei-dao, luohan-quan (5) |
| 3 | `45f34658` | wudang-jian, taiji-jian, yijinjing (3) |
| 4 | `c0e09d5a` | jingang-quan, emei-jian, quanzhen-jian, taiji-shengong (4) |
| 5 | `38af1aa3` | songshan-jian, henshan-jian, houquan, sanhua-zhang, liuhe-dao, luohan-gun (6) |
| 6 | `f6b3c246` | qingliang-jian, xiyang-jian, qixing-jian, suqin-beijian, hanmei-jian, yunhe-jian, mizong-houquan (7) |
| 7 | `deb1c713` | bagua-dao, baxian-jian, chuanyue-jian, guxing-jian, jueqing-jian, kuimang-dao, mingwang-jian (7) |
| 8 | `c8168b27` | pichen-jian, qiankun-jian, shangjia-dao, poguang-dao, luoying-shenjian, jiuqu-jian (6) |
| 9 | `a6c1a545` | damo-jian, jinshe-jian, longxing-jian, suxin-jian, shunv-jian (5，+`stats.ex` 基础属性 helper) |
| 10 | `0e5e7c09` | baibian-daxue, baisheng-daofa, boyun-suowu, caiyan-gong, canghong-bifa, chuangwang-dao, dali-chu, danding-dao, dongyang-dao, duanjia-sword (10) |
| 11 | `5b487daa` | bizhen-qingzhang, chuanxin-zhang, chanhun-suo, dacheng-fosuo, hanxing-bada, hexing-bifa, jinshe-zhui, kunlun-qifa, luoyun-dao, lutou-zhang (10) |
| 12 | `aee49cf8` | 暗器系 12：bagua-biao, bingpo-shenzhen, duoming-jinhua, fenglei-zifa, furong-jinzhen, hansha-sheying, heixue-shenzhen, jinbiao-jue, pidi-shenzhen, mantian-xing, mantianhuayu-zhen, pomie-jinzhen |
| 13 | `d6441b03` | hanwang-qingdao, jingyue-bifa, lingshe-zhangfa, longcheng-shendao, nianhua-zhi, ningxue-zhang, pangen-cuojiefu, panlong-suo, qianye-shou, raozhi-roujian (10) |
| 14 | `474db464` | jiandun-zhusuo, qishi-ji, ruanhong-zhusuo, riyue-bian, qiufeng-chenfa, ruyun→rouyun-steps, sougu, tangmen-throwing, tiangang-zhi, feixing-shu (10) |
| 15 | `4007fdff` | 内功 7：beiming-shengong, sanku-shengong, duanshi-xinfa, kurong-changong, lengyue-shengong, miaojia-neigong, shenlong-xinfa |
| 16 | `cf7d6b45` | 收官 9：daojian-guizhen, miaojia-jian, duanyun-fu, jinguan-yusuo, sun-finger, sanwu-shou, qiulin-shiye, shenxing-baibian, xixing-dafa |

- 累计 **90 个技能**已迁移（`valid_learn/2` + `practice_cost`），每批均含专用测试文件 + docs 块（C-PVE7~20）+ 记忆同步。
- **F4 `valid_learn`/`practice_skill` 长尾已收口（2026-10-30）**。余下 `TODO(migrate)` 属别的类别：`query_skill`(1121，多为基础技能基础类)、`prepare_skill`(62)、`surge`(5)，以及「引擎未建模层」（alignment 性格门 / `ultrap` 大宗师 / `can_learn` 父类检查 / practice 专属门 / 须持械空手）。
- **`valid_damage/5`（Option 2，防守方 invocation）已全部落地（2026-10-30，未 commit）**：
  - 引擎：`skill.ex` `@callback valid_damage` 5 元 + `@optional_callbacks valid_damage: 5` + fallback `{damage, nil}`；`Fighter` 新增 `:max_neili`；`Round` 新增 `:counter_damage`；`engine.ex` `damage_calc` 调用 `apply_valid_damage`（攻击方映射技能）+ `apply_defender_valid_damage`（防守方 parry/dodge 映射技能），折叠 2/3 元返回、合并 `counter_damage`、拼接 `segments`；`Engine.rand` 已 0-indexed（`rng.(n)-1`，与 LPC `random` 对齐）。
  - 27 技能 `valid_damage/5` 全按 LPC 保真迁移（`me`=防守方→`victim`，`ob`=攻击方→`attacker.skills`，`query_temp("weapon")`→`weapon_name`，`random(n)`→`rng.(n)-1`，`damage=-damage` 反弹→`{0, msg}`，剥 LPC 色码保留 `$N/$n/$l`）：pilot `kongming-quan`/`tianluo-diwang` + 更新 `dugu-jiujian`/`taiji-quan` 为 5 元+rng，新增 `beiming-shengong`/`dafumo-quan`/`dagou-bang`/`douzhuan-xingyi`/`huagong-dafa`/`jingang-buhuaiti`/`jinguan-yusuo`/`jinzhong-zhao`/`jiuyang-shengong`/`jiuyin-shengong`/`kuihua-mogong`/`lingbo-weibu`/`pixie-jian`/`qiankun-danuoyi`/`qingfu-shenfa`/`shexing-lifan`/`taiji-jian`/`taixuan-gong`/`tanzhi-shentong`/`wai-bagua`/`xixing-dafa`/`xixing-xiaofa`/`zhuangzi-wu`。
  - 验证：`mix compile` 退出码 **0**（零新增告警；仅 `feature_attack.ex`/`drive_command.ex` 既有无关警告）。`test/kantele/combat/skills_valid_damage_test.exs` 已扩展覆盖 **全部 27 技能**（`zero_rng()` 恒 1 让化解胜出、`two_rng()` 恒 2 过 `random(2)==1` 门），**73 tests, 0 failures**（Docker + db）。helper 用 keyword-opts（`victim(skills: ..., weapon: ..., neili: ...)`），attacker/victim 均含 `:mapped`。
  - 遗留：`counter_damage` 跨进程作用到攻击方（`combat_event.ex` `apply_hit` 仅本地）尚未接入；`mp>=100` 失败分支因 `count` 技能未普遍落入 `stats.skills` 而休眠（与 alignment/ultrap 同属引擎未建模层，待基础设施补齐）。
  - 文档/记忆：`待办实施计划.zh-CN.md` 待新增 C-PVE 块；本条即为 MEMORY 同步。

## 待办（开放中）
- **第十六批已 push `cf7d6b45`**（2026-10-30，9 lib + 9 test + C-PVE20 + 记忆）。
- **假阳性结论（勿再当缺口）**：`force.c` `valid_learn` = `{return 1;}`；`force_lifeheal/power/roar/shot` 是 **Perform 模块**（`kungfu/skill/force/*.c` 为 exert 函数文件），不是技能。`xuehai-mogong` LPC 仅 `return ::valid_learn(me)`。
- **引擎未建模层（要动需先补基础设施）**：alignment（`query("character")`，本仓无字段/设定入口；`meta.character` 只在 performs 里被读、实际恒 nil）、`ultrap`（大宗师）、`valid_practice` 回调（practice 专属门）、`valid_learn` 里的须持械/空手（`character` 快照不含持械）。
- 打工闭环 / 注内力 / 锻造 等 S0-S4 任务见各日期日志。

## 已交付（历史，均已 push，详见 git log / 各日期日志）
condition/drunk、Force.Dispel+sleep、房间 water/liquid、P5 乞讨/fuse/战斗闲聊/打造(S1b+S1c)、R21 clone_lib、注内力(S2#156)、乾坤袋(S4)、币值勘误、LPC 全面对齐(ChineseNumber/Stats.effective)、打工闭环+yelvqi 覆命奖励。
