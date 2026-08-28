# Framework Requirements — skill_dugu-jiujian (独孤九剑)

Migrated from `lpc_example/skill/skill_dugu-jiujian.c` (24971B).

判定等级: **C** —— 招式表可落，但「无招双表」与多处横向钩子需底层扩展。

## 已落地（B 档，单文件纯函数）

| 能力 | LPC 对应 | 说明 |
|------|----------|------|
| `@actions` 招式表 | `action[]` | 24 招，全部字段 force/attack/dodge/parry/damage/damage_type |
| `@actions2` 无招表 | `action2[]` | 3 招，威力为 600/300/300/300/460 |
| `valid_enable/2` | valid_enable | `parry` 恒可用；`sword` 需等级 ≥30 |
| `valid_learn/1` | valid_learn | int≥39、sword≥100、sword≥dugu 等级 |
| `query_effect_parry/1` | query_effect_parry | 按等级 0→120 阶梯 |
| `query_action/3` | query_action | 按「无招」标记切换 action/action2 双表 |

## 需框架扩展（C 档）

| 能力 | LPC 对应 | 框架缺口 |
|------|----------|----------|
| 武器对象模型 | `query_temp("weapon")` / `skill_type=="sword"` | 框架无武器对象/临时装备槽；valid_learn 与 valid_damage 均依赖 |
| `valid_learn` 需剑 | valid_learn 首行 | 无 `query_temp("weapon")` 等价物 |
| 阵营/性格判定 | `query("character")` == 心狠手辣/阴险奸诈/光明磊落 | Stats 无 character 字段；valid_learn 三行性格拦截缺 |
| valid_damage | valid_damage/4 | 需 parry/count 双攻防判定 + 无招完全反弹（-damage）；现行为无 |
| hit_ob | hit_ob/3 | 附伤/缴械/九连击；依赖 COMBAT_D->do_attack / set_bhinfo / message_vision / start_busy |
| practice_skill | practice_skill | 恒失败(只能用「总诀式」演练)；需 perform 系统有总诀式路径 |
| perform_action_file | perform_action_file | 绝招路由「dugu-jiujian/<action>」；框架 perform_list 仅短名映射 |
| skill_improved | skill_improved | 等级>120/150 时渐进解锁「破气式」「总破式」perform + improve_skill |
| difficult_level | difficult_level | 无招态 1000 / 常态 600 |

## 建议扩展项

1. `Stats` 增加 `character/1`、`con/1`、`dex/1` 属性访问。
2. 武器对象模型：`query_temp_weapon/1` 返回 `%{id, name, skill_type}`。
3. `Kantele.Combat.Skill` behaviour 增加回调：
   - `valid_damage/6`
   - `hit_ob/4`
   - `practice_skill/1`
   - `perform_action_file/1`
   - `skill_improved/1`
   - `difficult_level/0`
4. `COMBAT_D` 等价物：`do_attack/4`、`set_bhinfo/1`、`message_vision/1`、`message_combatd/1`、`message_sort/1`。
5. `start_busy/2`、`receive_wound/4`、`improve_skill/2`。
