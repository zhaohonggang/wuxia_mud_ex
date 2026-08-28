# Framework Requirements — room_qiyuan2 (棋苑棋房)

Migrated from `lpc_example/room/room_qiyuan2.c` (22443B).

判定等级: **B/C** —— 完整围棋/五子棋规则引擎为纯函数已可落地；仅需 Room 交互载体。

⚠️ 修正: 原目录 signature 误标「奇缘」(随机事件)；实际为 棋苑(Go/Gomoku 棋房)。

## 已落地（B 档，纯函数，已用 smoke test 验证）

| 能力 | LPC 对应 | 说明 |
|------|----------|------|
| `translate_position/2` | translate_position | 解析 `d4` 式坐标 → `{:ok, x, y}` / `:error` |
| `no_qi/4` | no_qi/3 | 块气判定（临时标记 @aux_color + 复原，与 LPC 一致） |
| `remove_block/3` | remove_block/3 | 移除整块并返回计数（空位=删除 key） |
| `eat/4` | eat/5 | 落子后清敌子，返回被吃数与坐标 |
| `weiqi_rule/3` | weiqi_rule/2 | 围棋合法性（占地/提劫/禁入点/自杀） |
| `wuzi_rule/3` | wuzi_rule/2 | 五子棋五连判定 |
| `new_game/2` | do_new | new [-5] [-bN] [-hN] 参数解析 + 让子摆放 |
| `play/2` | do_play | 走棋流 + 胜负判定 + 轮换 |
| `undo/1` | do_undo | 悔棋（仅五子棋，一次一步） |
| `show_game/1` | show_game | 棋盘 ASCII 渲染 |

## 需框架扩展（C 档，Room 交互载体）

| 能力 | LPC 对应 | 框架缺口 |
|------|----------|----------|
| 座位数据 | `pl["black"]/pl["white"]` mapping | 无多玩家座位/房间级状态存储 |
| 临时玩家标记 | `query_temp("weiqi_seat")` | 无 query_temp 等价物 |
| 命令路由 | add_action(sit/leave/play/pass/new/undo/refresh) | 需 Room command 分发 |
| 消息广播 | message_vision / tell_room / tell_object | 需要 room 内广播 |
| 玩家对象 | `this_player()->name()` / living / present | 需玩家对象模型 |
| 定时清理 | `call_out("check_players", 3)` | 需 circular timer |

## 建议扩展项

1. Room 级别对弈状态存储（`%{black_id, white_id, game}`）。
2. `query_temp/1` / `set_temp/2` / `delete_temp/1` 玩家标记。
3. `message_vision/1`、`tell_room/1`、`tell_object/1` 广播原语。
4. `add_action/2` 命令分发（形如 `%{name => {fn, spec}}`）。
5. 房间玩家清单 `present/1`、`living/1`。

## 验证

smoke test 覆盖：坐标解析、五子棋五连胜利、占用判定、围棋围杀提子、让子摆放。全部通过。
