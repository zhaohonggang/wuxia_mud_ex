# LPC Example 迁移现状与差距记录

> 更新时间: 2026-08-28
> 共 22 个样本目录，**18 个真实行为迁移 + 4 个纯 UCL 数据物品**，均已覆盖。
>
> ⚠️ **重要约束**: 所有迁移仅限 `C:\files\git\wuxia_mud_ex\lpc_example\ex` 目录内修改，**不实际接入游戏**。产物为纯数据 UCL + 纯函数 Elixir 模块，供开发参考与框架能力设计使用。所有 `.ex` 均通过容器 `elixirc` 编译（Elixir 1.11），仅剩框架缺口的 undefined-function 警告属预期。

---

## 真实行为迁移 (18/22) —— `.ex` 纯函数 + `.ucl` + `FRAMEWORK_REQUIREMENTS.md`

| 目录 | .ex 模块 / 产物 | 要点 |
|------|----------------|------|
| `class_generate_chinese` | `class_generate_chinese.ex` + `name_generator.ex` + `sects.ex` | 完整姓名生成算法 + 39 门派原型 |
| `class_wudang_zhang` | `class_wudang_zhang.ex` + `zhang_sanfeng.ucl` + `zhenwu_jian.ucl` | 13 问询、5 关收徒、真武剑、九阳、战斗 AI |
| `condition_poison` | `condition_poison.ex` | 混合毒引擎、do_effect、dispel、jing/qi 伤害 |
| `daemon_combatd` | `daemon_combatd.ex` + `smoke_test.exs` | valid_power/skill_power/hit-parry-dodge 公式、伤害封顶 |
| `feature_attack` | `feature_attack.ex` | enemy/killer/want_kill、fight/kill、competitor、action 系统、init 自动战斗 |
| `feature_damage` | `feature_damage.ex` | 伤害核心 receive_damage/wound/unconcious/死亡、食物水分 |
| `inherit_char_npc` | `inherit_char_npc.ex` + `smoke_test.exs` | accept_fight/hit/kill 决策、heal_self 治疗决策树、chat、check_family |
| `inherit_room_pigroom` | `inherit_room_pigroom.ex` + `smoke_test.exs` | 拱猪牌局状态机、do_play/valid_play、叫牌去重、table/scoreboard |
| `item_wudu_qianzhumiji` | `qianzhumiji.ex` + `.ucl` | 千蛛万毒手 3 绝技解锁流程 |
| `item_yinzhen` | `yinzhen.ex` + `.ucl` | 银针 do_heal 完整判定链、治伤/刺伤、冷却 |
| `npc_horseboss` | `horseboss.ex` + `.ucl` | 多阶段坐骑向导状态机 + 生成器 |
| `npc_xiaoer` | `xiaoer.ex` + `.ucl` | 收金/收尸、积分兑换、满座清场 |
| `room_qianting` | `qianting.ex` + `.ucl` | 大门 push/close/auto_close、valid_leave 权限、动态 exit（中文用 `\u{...}` 码点存储） |
| `room_qiyuan2` | `qiyuan.ex` + `.ucl` + `smoke_test.exs` | 完整围棋/五子棋引擎（提子/劫/禁入/悔棋），已提交 |
| `room_wudu_liandu` | `poison_workshop.ex` + `.ucl` | 五毒炼毒房 6 配方、成功率、经验 |
| `skill_dugu-jiujian` | `skill_dugu-jiujian.ex` | 独孤九剑 24 招 + 3 无招、valid_damage/parry |
| `skill_taiji-quan` | `skill_taiji-quan.ex` | 太极拳 25 招、极意动态属性、蓄力 hit_ob |
| `system_npc_luban` | `system_npc_luban.ex` + `smoke_test.exs` | 鲁班建房系统（户型表/房名代号校验/描述净化/路径映射） |

> 说明：`inherit_room_pigroom`、`inherit_char_npc`、`daemon_combatd`、
> `system_npc_luban`、`feature_attack`、`feature_damage`、`condition_poison`
> 属**框架核心 mixin/引擎**（C 级），正确姿势是把其纯函数与数值公式并入
> 框架层 `Kantele.Xxx`；`.ex` 已提炼可测落地，`FRAMEWORK_REQUIREMENTS.md`
> 列明所需框架能力。
>
> 本会话修复：`feature_attack.ex` 的 **`elsif`（Elixir 非法）→ 嵌套 if/else**、
> `room_qianting.ex` 的 **tuple 解构 `new_state,msgs=`→`{new_state,msgs}=`**，二者现均可编译。

---

## 纯 UCL 数据物品 (4/22) —— 无需行为模块，UCL 即完整

| 目录 | LPC 大小 | 说明 |
|------|---------|------|
| `weapon_changjian` | 678B / 20 行 | 标准长剑，无特殊行为，`.ucl` 完整 |
| `mount_ziliuma` | 849B / 25 行 | 紫驴马坐骑，`.ucl` 含 ridable 数据 |
| `item_shaolin_map` | 8217B | 少林地图，纯 ASCII 长文本，`.ucl` 存储 |
| `quest_song-yupai` | 4647B | 宋玉佩任务物品，复用框架 turn_in，`.ucl` 完整 |

---

## 迁移标准 (Definition of Done)

每个目录完成需满足：
1. ✅ 原 `.c` 完整读取并理解
2. ✅ `.ucl` 数据完整对应原文件字段
3. ✅ `.ex` 含原 LPC 函数对应的纯函数实现（框架核心类提炼公式/决策树）
4. ✅ `elixirc *.ex` 在容器 (Elixir 1.11) 通过编译（仅余框架缺口警告）
5. ✅ `FRAMEWORK_REQUIREMENTS.md` 列出所需框架能力扩展
6. ✅ 关键算法有 smoke_test.exs（可选但推荐，本次 4 个新迁移均含）

---

## 文件命名约定

```
<sample_dir>/
├── <sample>.c          # 原 LPC (只读对照)
├── <sample>.ucl        # 数据模板 (必有)
├── <sample>.ex         # 行为模块 (纯函数，必有)
├── <related>.ucl       # 关联物品/NPC/房间数据
├── smoke_test.exs      # 纯函数冒烟测试 (可选)
└── FRAMEWORK_REQUIREMENTS.md  # 框架需求文档
```

---

## 已知差距 / 后续方向

- **中文乱码风险**：`write` 工具在 Windows 部分情况下会破坏中文。已成功保留
  中文的：taiji-quan / dugu-jiujian / qiyuan / inherit_char_npc 等；
  `room_qianting` 采用 `\u{码点}` 转义规避。若新增含中文文件需在容器 `cat`
  复核。
- **框架接入（未做）**：`daemon_combatd` 公式、`feature_attack`/`feature_damage`
  状态机等应并入 `lib/kantele/` 引擎层 —— 属框架开发阶段，超出本迁移范围。
- **smoke 测试**：本次为 4 个新迁移补了 `smoke_test.exs`（char_npc 18、
  pigroom 36、combatd 27、luban 28，全部 PASS）。旧迁移（taiji-quan 等）尚未
  附测试，需要时可按相同模式补。

---

## 下一步建议

1. 复核新增 4 个迁移（`inherit_char_npc`、`inherit_room_pigroom`、
   `daemon_combatd`、`system_npc_luban`）与 2 个修复（`feature_attack`、
   `room_qianting`）后，可提交/推送（等用户指示）。
2. 若继续：为旧迁移补 `smoke_test.exs`，或开始将 C 级公式并入 `lib/kantele`。
