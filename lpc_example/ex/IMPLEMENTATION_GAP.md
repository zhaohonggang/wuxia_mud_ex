# 命令实现差异报告

> 生成时间: 2026-08-31
> 检查范围: 已标记为"完全实现"的命令 + 完整命令对照分析（66组命令）
> 测试基线: 877 tests / 0 failures

---

## 1. time 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 440 | ~25 |
| **文件** | `cmds/usr/time.c` | `lib/kantele/character/commands/time_command.ex` |

### LPC完整功能
- 农历/公历转换算法（含LunarCal 1936-2031年数据）
- 节日系统（lunarfete 8个农历节日 + solarfete 71个公历节日）
- 未来7天节日预览（prepare函数）
- 游戏运行时间显示
- 日期换算支持（`time 1999-12-31`）

### Elixir简化版
```elixir
def run(conn, _params) do
  {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
  time_str = "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}:#{pad(second)}"
  conn |> render(CommandView, "text", %{text: "现在北京时间是：#{time_str}\n"})
end
```

### 缺失功能
- [ ] 农历计算
- [ ] 节日显示（农历+公历）
- [ ] 游戏运行时间
- [ ] 未来7天节日预览
- [ ] 日期换算参数

---

## 2. score 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 440 | ~51 |
| **文件** | `cmds/usr/score.c` | `lib/kantele/character/commands/score_command.ex` |

### LPC完整功能
- 年龄/性别/种族显示
- 师门/出生信息
- 存款显示（MONEY_D->money_str）
- 伴侣/婚姻状态
- 战斗统计（MKS/ PKS/ WPK 击杀数）
- 死亡记录（dietimes/ last_die）
- 修炼状态（任督二脉/元婴/生死玄关/转世）
- 武学评价（oprank拳脚/兵器/内功/轻功）
- RMB注入资金

### Elixir简化版
```elixir
# 仅显示：name, vitals, str/dex/con/int, combat_exp, potential,
# coins, score, weiwang, gongxian, skills, performs
```

### 缺失功能
- [ ] 年龄/性别/种族
- [ ] 师门/师父信息
- [ ] 存款（银行）
- [ ] 伴侣/婚姻
- [ ] 战斗击杀统计
- [ ] 死亡记录
- [ ] 修炼状态（breakup/animaout/death/reborn）
- [ ] 武学评价等级
- [ ] rmb资金

---

## 3. hp 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 285 | ~28 |
| **文件** | `cmds/usr/hp.c` | `lib/kantele/character/commands/hp_command.ex` |

### LPC完整功能
- `hp` - 精气/气血/内力/精力/食物/饮水/潜能/体会
- `hp -m` - 属性上限（精力/内力/潜能/体会/等级/加怒/加力）
- `hp -g` - 天赋属性（初始/先天/成功/失败/故事/转世）
- 愤怒状态（craze/jinu）
- 颜色状态（status_color根据百分比变色）
- 死亡/杀戮保护状态

### Elixir简化版
```elixir
info = """
【 气血 】 #{vitals.qi}/#{vitals.max_qi}
【 精气 】 #{vitals.jing}/#{vitals.max_jing}
【 内力 】 #{vitals.neili}/#{vitals.max_neili}
【 精力 】 #{vitals.jingli}/#{vitals.max_jingli}
"""
```

### 缺失功能
- [ ] `-m` 参数（属性上限）
- [ ] `-g` 参数（天赋属性详情）
- [ ] 食物/饮水显示
- [ ] 愤怒状态
- [ ] 潜能/体会
- [ ] 颜色状态（根据百分比变色）
- [ ] 死亡/杀戮保护

---

## 4. who 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 404 | ~12 |
| **文件** | `cmds/usr/who.c` | `lib/kantele/character/commands/who_command.ex` |

### LPC完整功能
- `-h` 帮助
- `-l` 详细模式（显示描述/状态）
- `-w` 巫师列表
- `-p` 门派列表
- `-i` 空闲时间排序
- `-m` 门派排序
- `-n` 名字排序
- `-s` 简短模式
- `--wizlord` 特殊过滤
- 玩家头衔显示
- 空闲状态标记（>120秒显示*）
- DNS远程查询

### Elixir简化版
```elixir
def run(conn, _params) do
  conn
  |> assign(:characters, Presence.characters())
  |> render(WhoView, "list")
end
```

### 缺失功能
- [ ] 所有参数支持（-l/-w/-p/-i/-m/-n/-s等）
- [ ] 详细模式
- [ ] 巫师过滤
- [ ] 门派过滤
- [ ] 空闲时间显示
- [ ] 玩家状态（doing）

---

## 5. inventory 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 97 | ~17 |
| **文件** | `cmds/usr/inventory.c` | `lib/kantele/character/commands/inventory_command.ex` |

### LPC完整功能
- 负重百分比显示
- 装备物品标记（HIC "□ "）
- 手持物品标记（HIM "□ "）
- 物品数量显示（chinese_number）
- 巫师查看他人（`inventory <玩家名>`）

### Elixir简化版
```elixir
item_instances = Enum.map(conn.character.inventory, fn item_instance ->
  %{item_instance | item: Items.get!(item_instance.item_id)}
end)
conn |> assign(:item_instances, item_instances) |> render(InventoryView, "list")
```

### 缺失功能
- [ ] 负重百分比
- [ ] 装备标记（□）
- [ ] 手持物品标记
- [ ] 物品数量中文
- [ ] 巫师查看他人

---

## 6. finger 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | ~150+ | ~42 |
| **文件** | `cmds/usr/finger.c` | `lib/kantele/character/commands/finger_command.ex` |

### LPC完整功能
- 玩家连线IP
- 最后连线时间
- Email信息
- 注册时间
- 等级/门派
- 连续在线时间

### Elixir简化版
```elixir
# 仅显示：name, id, "状态暂未开放"
```

### 缺失功能
- [ ] 连线IP
- [ ] 最后连线时间
- [ ] Email
- [ ] 注册时间
- [ ] 门派信息

---

## 7. alias 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 81 | ~86 |
| **文件** | `cmds/usr/alias.c` | `lib/kantele/character/commands/alias_command.ex` |

### 关键差异

| 功能 | LPC | Elixir |
|------|-----|--------|
| 系统命令检查 | `COMMAND_D->find_command(verb, PLR_PATH)` | `Commands.parse(verb)` |

### LPC代码
```c
else if (stringp(COMMAND_D->find_command(verb, PLR_PATH)))
    return notify_fail("动词 " + verb + " 是一个常用命令，你不能替代它。\n");
```

### Elixir代码
```elixir
defp system_verb?(verb) do
  case Commands.parse(verb) do
    {:ok, _command} -> true
    _ -> false
  end
end
```

### 状态
- [x] 核心功能一致
- [ ] Commands.parse可能在Elixir中不可用

---

## 8. fill 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 54 | ~55 |
| **文件** | `cmds/std/fill.c` | `lib/kantele/character/commands/fill_command.ex` |

### LPC检查项
```c
if (!environment(me)->query("resource/water"))
    return notify_fail("这里没有地方可以装水。\n");

if (me->is_busy())
    return notify_fail("你上一个动作还没有完成。\n");

if (me->is_fighting())
    return notify_fail("你正忙着打架，没工夫装水！\n");
```

### 缺失功能
- [ ] 环境有水检查
- [ ] busy检查
- [ ] 战斗检查
- [ ] 旧液体倒掉消息

---

## 9. quit 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | ~100+ | ~12 |
| **文件** | `cmds/usr/quit.c` | `lib/kantele/character/commands/quit_command.ex` |

### LPC检查项
```c
if (LOGIN_D->get_madlock())
    return notify_fail("时空已经封闭，没有人能够退出这个时空了。\n");

if (me->is_busy() && !me->query("doing"))
    return notify_fail("你现在正忙着做其他事，不能退出游戏！\n");

if (me->is_fighting())
    return notify_fail("你现在正在打架，怎么能说走就走？\n");

if (me->query_competitor())
    return notify_fail("好家伙，你正在和人比武，怎么能开溜？\n");

if (me->dps_count() > 0)
    return notify_fail("好家伙，你打晕了别人就想开溜？\n");

if (me->over_encumbranced())
    return notify_fail("你身上背的东西太多了，无法离开这个世界。\n");
```

### 缺失功能
- [ ] madlock检查
- [ ] busy检查
- [ ] 战斗检查
- [ ] 比武检查
- [ ] 打晕别人检查
- [ ] 超重检查

---

## 10. option 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 74 | ~87 |
| **文件** | `cmds/usr/option.c` | `lib/kantele/character/commands/option_command.ex` |

### 状态
- [x] 核心功能基本一致
- [ ] LPC使用`option/`路径存储，我们使用`option`字段

---

## 11. quest 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 113 | ~80 |
| **文件** | `cmds/usr/quest.c` | `lib/kantele/character/commands/quest_command.ex` |

### LPC完整功能
- `quest` - 查看任务列表
- `quest <NPC>` - 向NPC领任务
- `quest cancel` - 取消任务
- 节日任务（festival）

### Elixir简化版
```elixir
# 仅显示：todo列表、solved列表
```

### 缺失功能
- [ ] 向NPC领任务
- [ ] 取消任务
- [ ] 节日任务

---

## 12. save 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | ~50 | ~30 |
| **文件** | `cmds/usr/save.c` | `lib/kantele/character/commands/save_command.ex` |

### 状态
- [x] 核心功能一致
- [ ] LPC有30秒冷却限制（已注释）
- [ ] LPC检查link_ob

---

## 优先级建议

### P0 - 严重影响可玩性
1. **hp -m / -g** - 属性上限和天赋详情
2. **score** - 战斗统计、师门信息
3. **who** - 过滤参数

### P1 - 日常功能
4. **inventory** - 负重/装备标记
5. **quit** - 各种检查
6. **fill** - 环境检查

### P2 - 低优先级
7. **time** - 农历/节日（复杂算法）
8. **finger** - 连线资料
9. **quest** - 领任务

---

## 13. fight 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 82 | ~19 |
| **文件** | `cmds/std/fight.c` | `lib/kantele/character/commands/fight_command.ex` |

### LPC完整功能
- `no_fight`区域检查
- 目标存在检查
- `is_character`检查
- 已经在战斗检查
- `living`检查
- 体力检查（<30%不能战斗）
- 不能攻击自己
- NPC `accept_fight`回调
- `fight_ob`/`kill_ob`启动战斗

### Elixir简化版
```elixir
def run(conn, params) do
  conn
  |> event("combat/attack", %{name: params["name"], type: params["type"] || "fight"})
  |> assign(:prompt, false)
end
```

### 缺失功能
- [ ] no_fight区域检查
- [ ] 体力检查（<30%）
- [ ] accept_fight NPC回调
- [ ] 战斗启动完整逻辑

---

## 14. drink 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 197 | ~93 |
| **文件** | `cmds/std/drink.c` | `lib/kantele/character/commands/drink_command.ex` |

### LPC完整功能
- `drink <物品> in [all] <容器>` 容器语法
- 容具存在/安全性检查
- `guarded`物品检查
- `only_do_effect`处理
- `liquid/remaining`检查
- 水上限检查（max_water_capacity）
- 液体减少（remaining - 1）
- 醉酒状态（drunk condition）
- `auto_drinkout`环境行为

### Elixir简化版
- 仅支持直接喝物品
- 无容器语法
- 无液体容量概念

### 缺失功能
- [ ] 容器语法（in [all] <容器>）
- [ ] guarded检查
- [ ] liquid/remaining容量
- [ ] 水上限检查
- [ ] 醉酒状态
- [ ] auto_drinkout

---

## 15. eat 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 181 | ~93 |
| **文件** | `cmds/std/eat.c` | `lib/kantele/character/commands/eat_command.ex` |

### LPC完整功能
- `eat <物品> in [all] <容器>` 容器语法
- 容具检查
- 数量检查（amount < 1）
- busy检查
- guarded检查
- 食物检查（edible）
- fighting检查
- 完成效果（do_effect）

### 缺失功能
- [ ] 容器语法
- [ ] 数量检查
- [ ] guarded检查
- [ ] fighting检查
- [ ] 完成效果回调

---

## 16. give 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 224 | ~60（待确认） |
| **文件** | `cmds/std/give.c` | `lib/kantele/character/commands/give_command.ex` |

### LPC完整功能
- `give <物品> to <人>` / `give <人> <物品>`
- 数量支持（`give 10 gold to oldman`）
- `no_drop`检查
- `no_accept` / `can_accept`检查
- 负重检查
- `is_riding`检查
- 分割物品（set_amount）

### 缺失功能
- [ ] 数量+物品语法
- [ ] no_drop检查
- [ ] no_accept检查
- [ ] 负重检查

---

## 17. wear/wield 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | wear 121 / wield 49 | ~283（合并） |
| **文件** | `cmds/std/wear.c` + `wield.c` | `lib/kantele/character/commands/wield_command.ex` |

### LPC完整功能
- `wear all` 支持
- `female_only`性别检查
- 装备位置自动选择
- 武器双手/副手判断
- 卸下再装备逻辑

### Elixir实现
- wield/unwield/wear/remove 四个命令
- 包含 Equip 决策层
- 基本覆盖LPC功能

### 状态
- [x] 核心功能基本完整
- [ ] female_only未实现
- [ ] `wear all`未测试

---

## 18. study 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 189 | ~60（待确认） |
| **文件** | `cmds/skill/study.c` | `lib/kantele/character/commands/study_command.ex` |

### LPC完整功能
- `pigging`检查
- busy检查
- 冷却时间检查（同一秒不能连续读）
- fighting检查
- 读书次数参数（study book 10）
- literate技能检查
- `no_fight`区域+scheme检查
- 实战经验检查（exp_required）
- 读书消耗计算（jing_cost * 20 + difficulty - int）
- skill提升（study_skill）

### 缺失功能
- [ ] pigging检查
- [ ] 冷却时间
- [ ] 次数参数
- [ ] literate检查
- [ ] exp_required检查
- [ ] 读书消耗jing计算

---

## 19. follow 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 54 | ~30 |
| **文件** | `cmds/std/follow.c` | `lib/kantele/character/commands/follow_command.ex` |

### LPC完整功能
- `follow <人>` / `follow none`
- 目标存在检查
- `is_character`检查
- 不能跟随自己
- `set_leader`设置
- 消息显示

### 缺失功能
- [ ] 基本功能可能已有，简单命令

---

## 20. emote 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 67 | ~30 |
| **文件** | `cmds/std/emote.c` | `lib/kantele/character/commands/emote_command.ex` |

### LPC完整功能
- `ban_say`检查
- `no_say`区域检查
- doing=scheme时精神检查
- 无参数时默认消息
- `env/no_prefix`控制前缀

### 缺失功能
- [ ] ban_say检查
- [ ] no_say区域
- [ ] scheme精神消耗

---

## 21. reply 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 85 | ~40 |
| **文件** | `cmds/std/reply.c` | `lib/kantele/character/commands/reply_command.ex` |

### LPC完整功能
- `reply`回复上次tell的人
- 跨MUD回复（target@mud）
- DNS远程（GTELL）
- `no_tell`/`can_tell`检查
- `net_dead`检查
- `jam_talk`阻塞模式

### 缺失功能
- [ ] 跨MUD回复
- [ ] GTELL DNS
- [ ] no_tell检查
- [ ] jam_talk

---

## 22. drop 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 171 | ~50（item_command.ex，drop/get/put合并315行） |
| **文件** | `cmds/std/drop.c` | `lib/kantele/character/commands/item_command.ex` |

### LPC完整功能
- 数量语法 `drop N 物品`（拆堆+克隆+失败回滚obj2->move(me)）
- `drop all` 批量丢弃 + 无价值物品立即销毁（"因为这样东西并不值钱..." + destruct）
- 骑乘坐骑时 drop → 成功下马（is_riding/is_rided_by清理+跳下消息）
- 藏宝库物品（is_depot_ob）→ "你也舍得丢弃？"
- 房间级 no_drop 检查
- equipped 区分"worn"/"wielded"两种文案
- 房间物品上限 MAX_ITEM_IN_ROOM(999) + can_combine_to
- is_area/area_move_side/tell_area 区域逻辑
- 重物分支（>20000重量）"将$n从背上放了下来，躺在地上。"
- `unit` 量词定制文案

### Elixir实现
- drop_single：装备中→"必须脱下来才能丢掉"、骑乘中→拒绝、no_drop→拒绝、否则 request_item_drop
- drop_all：过滤（非装备/非骑乘/无no_drop）→"你丢下了一堆东西"
- 房间广播只在框架层 Room.item_request_drop

### 缺失功能
- [ ] 数量语法 `drop N 物品`
- [ ] 骑乘坐骑 drop（LPC 是下马，Elixir 直接拒绝）
- [ ] 藏宝库物品检查
- [ ] 房间级 no_drop 检查
- [ ] worn/wielded 双文案
- [ ] MAX_ITEM_IN_ROOM 上限（常量@max_item_in_room 999已定义但未引用）
- [ ] area 区域逻辑
- [ ] 重物分支
- [ ] 无价值物品立即销毁
- [ ] drop all 的房间 vision 广播（LPC 向全房广播，Elixir 只发给自己）
- [ ] **数据层缺口：no_drop 不在 Item.Meta defstruct 与 loader 解析中 → 对世界物品恒为 nil，分支是死代码**

---

## 23. get 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 234 | ~73（get_single/get_from_container/get_all/get_item） |
| **文件** | `cmds/std/get.c` | `lib/kantele/character/commands/item_command.ex` |

### LPC完整功能
- `get X from 容器` 容器语法 + 搜身权限链（wizardp/wiz_level比较/SECURITY_D site privilege）
- 数量语法 `get N 物品`（战斗中 start_busy(3)/整堆 start_busy(1)）
- `get all`：战斗中拒绝开抢、query_max_encumbrance容器判定、living中断
- 随身守卫（guarded temp）→ "X 正守在...一旁，防止任何人拿走。"
- 尸体搬运（>20000重量"扶了起来背在背上"+ DAUB_CMD->check_poison 敷毒检查）
- $N主语、unit量词、来源区分（捡起/除下/搜出/摘下/拿出）
- `get all` 三态 message_vision 房间广播
- present 递归语义（可命中容器里的物品）

### Elixir实现
- get_single：在 room.items 查物品 → get_item
- get_from_container：读 container.meta[:items]（**但 Item.Meta 无 :items 键** → 恒失败）
- get_all：只取 room.items → "你把地上的东西都拣了起来"
- get_item：库存≥80检查、no_get检查、request_item_pickup

### 缺失功能
- [ ] 数量语法 + 拆堆/回滚
- [ ] 容器取物的**核心数据缺失**（meta无:items键，标准容器取物恒失败）
- [ ] present 递归语义（房间容器内物品）
- [ ] 搜身权限链
- [ ] 战斗限制（get all 拒绝、start_busy）
- [ ] 守卫拦截取物
- [ ] 尸体敷毒检查（check_poison）
- [ ] 来源区分消息与房间广播
- [ ] **路由错误：item_name=="all" 优先于 " from " 判断 → `get all from corpse` 退化成捡地板**
- [ ] 数据层：no_get/no_get_from 不在 Meta/loader 解析中
- [ ] 框架层约束差异：LPC get 不查动词表，Elixir room.item_request_pickup 要求 get 动词

---

## 24. put 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 146 | ~38（put/put_single） |
| **文件** | `cmds/std/put.c` | `lib/kantele/character/commands/item_command.ex` |

### LPC完整功能
- `put X in Y` / `put N X in Y` / `put all in Y`
- no_get_from 先于参数解析检查
- 容器判定（!is_container && !is_character）→ "X 不是容器"
- 容器容量上限 MAX_ITEM_CARRIED(80)
- no_put / 尸体 / 玩家(userp) / 自己套自己 检查
- 移动成功 message_vision 房间广播 + 失败回滚 obj->move(me,1)

### Elixir实现
- put_single：no_put → 拒绝、dest.meta.no_get_from → 拒绝、is_depot → 提示、**否则 request_item_drop（把物品丢到房间地上！）**

### 缺失功能
- [ ] **核心缺陷：put 不放入容器**。put_single 最终走 request_item_drop，物品落在房间地板上，容器既不接收也不渲染
- [ ] living 目标判定
- [ ] 数量拆堆 + 回滚
- [ ] put all（parser会把"all"当物品名恒报"你身上没有这样东西"）
- [ ] 非容器目标判定
- [ ] 容器容量上限
- [ ] 尸体/玩家/自己套自己检查
- [ ] message_vision 房间广播
- [ ] 数据层：no_put/is_depot 不在 Meta 解析中 → 死代码

---

## 25. remove 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 98 | 24（+wield_command.ex remove ~27行） |
| **文件** | `cmds/std/remove.c` | `lib/kantele/character/commands/remove_command.ex` + `wield_command.ex` |

### LPC完整功能
- `remove all` 批量脱装（"你脱完了"/"你什么都没有脱下来"）
- present 存在性检查 + 按id回退遍历
- unequip() 可失败
- 自定义 remove_msg 优先级
- 按 armor_type 派生文案（cloth/armor/surcoat/boots脱下、bandage拆伤口、默认卸除）
- no_wear → "脱下以后你觉得舒服多了"
- message_vision 全房广播

### Elixir实现
- **RemoveCommand 是占位 stub（返回"脱卸系统暂未开放"）**
- 实际生效路径：WieldCommand.remove 在 combat.equipped 快照中按名匹配 → Combat.unequip + subtract_armor_prop → 只发本人"你卸下了X"

### 缺失功能
- [ ] remove_command.ex 纯占位，与 wield_command 双实现语义分裂
- [ ] remove all
- [ ] present 存在性检查
- [ ] unequip 失败语义（Combat.unequip 恒成功）
- [ ] remove_msg / armor_type 文案 / no_wear 附加消息
- [ ] message_vision 房间广播
- [ ] handing 槽被静默排除无提示
- [ ] 中文别名"脱"与 remove 无参路径文案不一致

---

## 26. exercise 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 141 | 105（+ExerciseEvent.ex 151行） |
| **文件** | `cmds/skill/exercise.c` | `lib/kantele/character/commands/exercise_command.ex` |

### LPC完整功能
- pigging/busy/fighting 检查
- 无 force 映射 → 必须先 enable
- exercise_cost 计算、qi/jing比例(<70)检查
- no_fight+can_dazuo+doing=="scheme" 三态豁免
- SKILL_D(force)->do_effect 前置检查
- busy循环：neili_gain随机、钳制、突破（max_neili+1、"内力增加了！！"）
- room->exercise_improve 加成
- halt：tell_room广播"深吸一口气站了起来"、内力钳回2×max

### Elixir实现
- exercise_command：valid_cost?、qi不足、jing比例<70、no_fight房间
- ExerciseEvent.tick/step/finish/interrupt：gain计算（忽略room加成）、瓶颈/上限提升、落盘

### 缺失功能
- [ ] do_effect 前置检查
- [ ] room->exercise_improve 加成
- [ ] can_dazuo/doing=="scheme" 豁免分支
- [ ] halt 的 tell_room 广播

---

## 27. exert 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 62 | 32 |
| **文件** | `cmds/skill/exert.c` | `lib/kantele/character/commands/exert_command.ex` |

### LPC完整功能
- busy检查
- no_exert temp / exert_drug 状态检查（内息紊乱）
- do_effect 前置
- 分派优先级：映射内功 → 基础 force 退路
- 运功成功后 random(120)<force_level 概率 improve_skill
- `<功能> <施用对象>` 参数含对象（由内功 exert_function 二次解析）

### Elixir实现
- 只取 params["function"] → exert_module.exert_list()[function] → run(conn)；无 → "你不会这种运功方法"

### 缺失功能
- [ ] busy检查
- [ ] no_exert/exert_drug 状态检查
- [ ] do_effect 前置
- [ ] 基础 force 退路
- [ ] improve_skill 概率提升
- [ ] 施用对象参数解析与传递
- [ ] 未enable force时 Elixir 静默走 nil → "你不会这种运功方法"，而非 LPC "先 enable 内功"

---

## 28. jingzuo 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 94 | 86 |
| **文件** | `cmds/skill/jingzuo.c` | `lib/kantele/character/commands/jingzuo_command.ex` |

### LPC完整功能
- 峨嵋派限定 + mahayana技能≥40 + eff_jing<50检查
- 120秒冷却 (jingzuo_time)
- 静坐期间 block_msg/all=1、no_get、disable_player("<静坐中>")、start_call_out(random(45)+1)
- wakeup结算：addp=random(skillslvl)/5+intpot(悟性/10)、addc=random(skillslvl)/3+exppot、receive_damage("jing",15)、no_fight房额外receive_wound("jing",5)、improve_potential + add combat_exp、enable_player、清状态

### Elixir实现
- run：busy/fighting、family.name!="峨嵋派"、jing<50、no_fight_room?、120秒冷却、Stats.effective(force)<40（替代mahayana）、start_jingzuo（duration=45-90s）+ send_after 自投递
- **wakeup 结算完全没有实现**——无 wakeup 事件处理器、无奖励结算

### 缺失功能
- [ ] wakeup 结算流程整体缺失（potential/exp奖励、jing消耗）
- [ ] mahayana 门槛用 force 等效40替代（占位）
- [ ] eff_jing vs jing
- [ ] block_msg / no_get / disable_player 静坐状态
- [ ] intpot/exppot/skillslvl压缩逻辑
- [ ] receive_damage/receive_wound
- [ ] 时长不一致：LPC 1-45s vs Elixir 45-90s

---

## 29. learn 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 272 | 189（含PracticeCommand） |
| **文件** | `cmds/skill/learn.c` | `lib/kantele/character/commands/learn_command.ex` |

### LPC完整功能
- 参数 `learn <某人> [about] <技能> <次数>`（同秒防刷 time/learn、次数1-100）
- pigging/busy/fighting检查
- 师父资格：is_apprentice_of / recognize_apprentice（reject_msg随机）
- no_teach(skill) 拒授、嫡传martial valid_learn_level 不再教、my_skill>=master_skill 不输师父、betrayer/times*2 叛师门禁
- can_learn：main_skill、env/no_learn、force系valid_force冲突检查
- 消耗：jing_cost=(100+my_skill*2)/int、my_skill==0时×2、潜能检查
- 教学循环：师父耗精(jing/5+1)、auto_regenerate回精、武星wuxing特技+20%、improve_skill(4+random(rand))
- tell_object 通知师父、query_skill_name 招式心得

### Elixir实现
- LearnCommand：parse_times(xN) → 发 skills/learn 事件到房间
- SkillsEvent.teach/do_teach：内功互斥门、exp门、潜能池、teachable、valid_learn、Master.prevent_learn
- learn_result：learn_levels逐级、apply_skill_improved、perform解锁、partial
- PracticeCommand：practice_cost/valid_learn/conflict_gate/exp_gate/check_jing(70%)/check_vitals、Stats.improve_skill、spend_potential

### 缺失功能
- [ ] pigging、time/learn同秒防刷
- [ ] 参数顺序不同：LPC `learn <某人> about <技能> <次数>` vs Elixir `learn <技能> <师父> [x次数]`
- [ ] recognize_apprentice 拒绝消息 + -1条件不够分支
- [ ] no_teach(skill) 拒授、valid_learn_level 不再教、betrayer 叛师门禁
- [ ] env/no_learn、valid_force 冲突
- [ ] 师父为玩家的场景（playerp 师父耗精）
- [ ] my_skill==0 首次学习 jing_cost*2
- [ ] auto_regenerate 回精继续学习
- [ ] wuxing 特技 +20%
- [ ] 招名心得、tell_object 通知师父

---

## 30. skills 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 333 | 106 |
| **文件** | `cmds/skill/skills.c` | `lib/kantele/character/commands/skills_command.ex` |

### LPC完整功能
- MAP类型参数 `<技能> of <某人>`、多词对象解析、非巫师学徒校验
- 查看他人（师徒/夫妻/结拜/同盟权限）、ob->skills(me,skill1) 重载回调
- 三类过滤：filter_for_enable / filter_for_main / filter_for_combine
- 子技能(main_skill)分组合并、按basic排序+others归类
- 学习进度 percent=learned*100/((lvl+1)^2+1)、学满大师HIM标记
- □ 已映射前缀、技能名对齐、CYN/WHT颜色、Error(No such skill)
- start_more 分页

### Elixir实现
- 固定查自己，format_skills：base_skills硬编码5类、特殊技能标题/等级、★表示有绝招

### 缺失功能
- [ ] MAP类型参数整体缺失（只能查自己）
- [ ] 查看他人技能权限
- [ ] 三类过滤逻辑
- [ ] 子技能分组
- [ ] 学习进度percent、大师标记
- [ ] □前缀、对齐、颜色、Error提示
- [ ] start_more分页

---

## 31. enable 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 147 | 56 |
| **文件** | `cmds/skill/enable.c` | `lib/kantele/character/commands/enable_command.ex` |

### LPC完整功能
- valid_types 23类 mapping（unarmed/sword/blade/.../tanqin-jifa）
- 无参数展示当前映射、`?` 列出种类、none 取消映射、种类==名称基础判断
- 正在激发防重复、不会该技能/不会半点该类型检查、valid_enable检查
- **magic类切换 → 精力重置（jingli=0）**
- **force类切换 → 内力重置（neili=0）+ receive_damage qi**（重要内功转移约束）
- reset_action()

### Elixir实现
- usage/skill_id/module、module==nil→没有该武功、!valid_enable→不能enable、否则写stats.mapped[usage]+save

### 缺失功能
- [ ] MAP类型参数（无参展示/`?`/none/基础判断）整体缺失
- [ ] valid_types 23类中文映射表（Elixir仅4个usage_title硬编码）
- [ ] magic/force 切换时的资源重置（**内功转移约束缺失**）
- [ ] 防重复、技能检查、reset_action

---

## 32. prepare 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 185 | 126 |
| **文件** | `cmds/skill/prepare.c` | `lib/kantele/character/commands/prepare_command.ex` |

### LPC完整功能
- valid_types 6类拳术（finger/hand/cuff/claw/strike/unarmed）
- 无参数展示组合、`?`列出种类、none取消全部
- 双技能组合：valid_combine检查、逆查smap找basic、prepare_skill + reset_action
- 单技能补第二拳术、已准备1种拦截

### Elixir实现
- **占位实现**（moduledoc明示）：show_current固定"没有组合任何特殊拳术"、clear固定"取消全部准备"、try_prepare固定报"暂未实装组合逻辑"

### 缺失功能
- [ ] **整体功能未实装（占位）**：无 prepare_skill 状态模型
- [ ] valid_combine 逻辑完全缺失
- [ ] 逆查映射、错误分支、落盘

---

## 33. checkskill 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 425 | 178 |
| **文件** | `cmds/skill/checkskill.c` | `lib/kantele/character/commands/checkskill_command.ex` |

### LPC完整功能
- 动态 SKILL_D 加载任意技能 + 中文名反查（CHINESE_D->find_skill）→ Original:<英文>
- 技能特性（type/double_attack/main_skill/query_description）
- 技能互备（skill_combines遍历valid_combine）、技能合成（query_sub_skills）
- 技能所属基本技能提前分支
- 绝招/内功目录扫描（perform/*.c、exert/*.c）→ 共N项绝招/M项内功功能
- 排版对齐（PREFIX_STR/LINE_LEN、7列换行）

### Elixir实现
- **单一硬编码技能表（仅7个技能）**、resolve_skill_id表内精确+中文包含模糊匹配
- format_checkskill输出等级/类型/mapped有效等级/可enable用法/可施展绝招/可运功

### 缺失功能
- [ ] 动态技能加载（只能查表内7个技能）
- [ ] double_attack/main_skill/description特性
- [ ] 技能互备、技能合成
- [ ] 中文名反查 Original 输出
- [ ] 基本技能提前分支
- [ ] 绝招/内功目录扫描计数
- [ ] 排版对齐

---

## 34. surrender 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 41 | 67 |
| **文件** | `cmds/std/surrender.c` | `lib/kantele/character/commands/surrender_command.ex` |

### LPC完整功能
- 非战斗拒绝（"投降？现在没有人在打你啊....？"）
- `last_opponent` is_killing 时**投降被拒** + 房间广播 RANK_D->query_rude 称谓
- remove_all_enemy + score减50（下限0）
- message_vision 全房广播投降说话（HIW/NOR高亮）

### Elixir实现
- Combat.fighting? 检查、do_surrender：发combat/halt事件、扣score 50、Combat.new()、Records.save、**只给自己渲染文本**

### 缺失功能
- [ ] is_killing 拒绝分支（注释明示简化跳过）
- [ ] 房间级广播（旁观者看不到）
- [ ] ANSI高亮

---

## 35. team 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 73+子命令581（with50/dismiss25/kick25/talk19/form18/kill142/swear302） | 325（+team.ex 89/team_event.ex 200） |
| **文件** | `cmds/std/team.c` + `team/*.c` | `lib/kantele/character/commands/team_command.ex` |

### LPC完整功能
- with：12人上限、非队长禁邀、双向同意（被邀者再team with <队长>回应）
- dismiss：队长解散/队员脱离 + message广播
- form：真实调用 SKILL_D->form_array（战斗加成、阵形特效、领袖移动即解除）
- kill：no_fight检查、目标校验、accept_kill、want_kill_flag主动PK判定、逐人kill_ob/fight_ob状态同步、can_speak喊话
- swear：声望四档门槛(1000/10000/20000/50000)、中文名校验、LEAGUE_D重名校验、逐人投票right/refuse、LEAGUE_D->create_league持久化、rumor江湖传闻

### Elixir实现
- dispatch 支持 with/accept/refuse/dismiss/kick/talk/say/list/form/kill/swear
- **accept/refuse**用独立机制（LPC是被邀者再with回应，UX不同）
- kick 真实现（LPC kick是复制dismiss的bug，Elixir反而更完整）
- form：仅设置meta.formation名称标签，**无阵法战斗效果**
- kill：只发team/attack事件，无no_fight/目标校验/PK语义
- swear：weiwang<20000单档、即时结义、不做持久化（LEAGUE_D不存在）
- Team.new只设leader_pid但follow?读leader_id → 跟随判定可能失效

### 缺失功能
- [ ] 12人上限
- [ ] form 的 SKILL_D->form_array 真实阵形效果、"领袖移动解阵"
- [ ] kill 的 no_fight/目标校验/accept_kill/want_kill/PK判定/喊话/状态同步
- [ ] swear 的四档声望/中文名校验/LEAGUE_D/逐人投票/persist/rumor广播
- [ ] Team.new leader_pid vs follow? leader_id 不一致隐患
- [ ] 【正向差异】kick/accept/refuse/list 比 LPC 更完整

---

## 36. ride 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 76 | 84 |
| **文件** | `cmds/std/ride.c` | `lib/kantele/character/commands/ride_command.ex` |

### LPC完整功能
- 房间在场生物检定（present+living，骑房间里的动物）
- is_busy/is_fighting检查
- query("ridable")对象属性、守卫阻挡（guarded）
- set_weight(1) + obj->move(me) 把坐骑移进背包 + 超重失败分支
- message_vision 房间广播、is_rided_by/is_riding双端temp标记

### Elixir实现
- **在背包 inventory 中找坐骑**（meta "ridable"或type=="mount"）
- Mount.can_ride? 驾驶权限（正向差异，LPC所无）
- 仅写meta.riding，坐骑**留在背包**

### 缺失功能
- [ ] 房间在场生物检定（只能骑背包物品）
- [ ] living/ridable属性、busy/fighting检查
- [ ] 守卫阻挡
- [ ] 坐骑移入背包 + set_weight(1) + 超重分支
- [ ] message_vision 房间广播
- [ ] 【正向差异】Mount.can_ride? 驾驶权限

---

## 37. unride 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 32 | 28 |
| **文件** | `cmds/std/unride.c` | `lib/kantele/character/commands/unride_command.ex` |

### LPC完整功能
- 无坐骑拒绝、message_vision房间广播、**坐骑移回房间地面**、is_rided_by/is_riding双端清理

### Elixir实现
- 清除meta.riding + 自我回显"你从坐骑上飞身跳下"

### 缺失功能
- [ ] 坐骑移回房间地（Elixir坐骑始终留在背包）
- [ ] is_rided_by 被骑方标记清理
- [ ] 房间广播

---

## 38. stop 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 47 | 24 |
| **文件** | `cmds/std/stop.c` | `lib/kantele/character/commands/stop_command.ex` |

### LPC完整功能
- 驯兽体系：present目标/owner归属/is_busy检查、呼哨广播文案、remove_all_enemy(1)
- 整套命令：come（跟随）/stay（停下）/attack（攻击）/stop（停止攻击）/release（放离）

### Elixir实现
- **两个run/2子句均渲染"驯兽系统暂未开放。"** —— 纯占位桩

### 缺失功能
- [ ] 全部功能缺失（驯兽/宠物机制整体未实现）

---

## 39. move 命令（移动机制）

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | go.c 555（命令）+ feature/move.c 323（机制） | 39（+MoveEvent.ex 121） |
| **文件** | `cmds/std/go.c` + `feature/move.c` | `lib/kantele/character/commands/move_command.ex` |

> **LPC 无 "move" 命令文件**，移动由 go.c（go/方向）承载，底层走 feature/move.c 的 move()。Elixir move_command.ex 即 go 的等价物（转发6方位给request_movement）。

### LPC完整功能（go.c + move.c）
- 20个方向中文映射（n/s/e/w/up/down/northup...out/in）
- 超重(over_encumbranced)/busy/doing前置
- 战斗移动完整机制：clean_up_enemy、守路口guarded阻挡、**逃跑判定**（dodge+dex*15 vs gp*3/4概率、force_power 4/3/2倍撞晕/撞伤/撞开）、success_flee担保放行
- valid_leave房间级离开钩子、出口T_OBJECT/T_STRING/T_MAPPING（区坐标）
- 隐身巫师不广播、进出消息风格化（武器/防具/骑马/野兽种族描述）
- area区域移动（area_move/tell_area/坐标init）、escape随机出口、按等级差50-(lv差*2)被挡
- do_flee（随机出口）、move()机制：装备先卸、载重体系（encumb/weight/add_encumbrance）、area move_in/out、magic_move、handing清理、GMCP Room.Info
- remove()：destruct钩子、存档回退

### Elixir实现
- 6个方位函数（north/south/east/west/up/down）→ request_movement
- MoveEvent.commit：更新room_id → notify_enemies_left → notify_followers → notify_team → 注册表更新 + move渲染 → 老房退订/新房间订阅 + room/look
- abort渲染失败、notice渲染提示

### 缺失功能
- [ ] 20方位（仅6个，缺northeast/southeast/northwest/southwest/out/in等）
- [ ] 超重/忙/doing前置（**载重体系整体缺失**）
- [ ] valid_leave 房间级离开钩子
- [ ] 出口类型多样性（区域出口）
- [ ] 战斗逃跑判定/守卫阻挡/force_power撞人全套
- [ ] success_flee 担保机制
- [ ] 进出消息风格化
- [ ] area 区域移动体系
- [ ] 竞技lost/win、state/go计数
- [ ] GMCP Room.Info
- [ ] 架构差异：Elixir 房间推送 vs LPC 环境树+全环境message

---

## 40. flee 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **LPC来源** | go.c do_flee(494-507)+do_room_move逃跑挡路(97-173)+do_area_move escape(399-445)；char.c心跳wimpy自动逃跑；killer.c NPC追捕 | 37（+flee_event 10/flee_action 16/combat_event.check_wimpy 330-348） |
| **文件** | 无独立flee命令，合并在go.c/char.c | `lib/kantele/character/commands/flee_command.ex` |

> **LPC 不存在 flee 玩家命令**：逃跑 = ①心跳自动触发(env/wimpy阈值) ②技能/道具担保(success_flee→do_flee) ③战斗移动被动挡路。Elixir 提供显式flee命令+wimpy自动触发，功能上超集。

### LPC完整功能
- 逃跑成功率判定（dodge+dex*15 vs 目标gp*3/4概率被拦 start_busy(1)）
- 敌方玩家 force_power 撞人分档
- 守卫（guarded/<dir>）参与阻挡
- area逃跑（"無路可逃"文案、chance挡路、随机出口）
- success_flee 担保必逃
- killer NPC call_out 60s追捕

### Elixir实现
- flee_command：非战斗拒绝、"正忙着呢"拒绝、room/flee事件 → FleeEvent随机出口 + request_movement
- wimpy自动逃跑（combat_event.check_wimpy：meta.wimpy>0且气血比<=wimpy → 广播"看来该找机会逃跑了"+room/flee）
- flee_action：Action封装room/flee（供绝招/道具复用）

### 缺失功能
- [ ] 逃跑成功率判定（LPC概率对抗+start_busy，Elixir直接移动）
- [ ] force_power撞人
- [ ] 守卫阻挡
- [ ] area环境逃跑
- [ ] success_flee担保机制
- [ ] killer NPC追捕AI
- [ ] 【正向差异】Elixir 显式flee命令是LPC所无

---

## 41. bank 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 无独立命令文件：feature/banker.c 238（NPC动作）+ inherit/room/bank.c 59 | 235（+npc/banker.ex 99/economy/money.ex 129） |
| **文件** | `feature/banker.c` | `lib/kantele/character/commands/bank_command.ex` |

> **LPC 无全局 bank 命令**：钱庄是"房间+NPC动作"（银行家add_action注册 check/convert/deposit/withdraw），玩家必须站在钱庄房间内才能存取。

### LPC完整功能（feature/banker.c）
- do_check查账、负余额强制归零
- do_deposit：busy/fighting检查、数量单位解析、present钱币对象、start_busy(1)、balance+=base_value*amount、实物钱币离身、message_vision
- do_withdraw：amount>=10000拒付（"本店没这么多零散现金"）、balance不足检查、MONEY_D->pay_player、message_vision
- do_convert：换汇（向下取整amount%=bv2/bv1）、散钱>10000拒、start_busy(1)
- do_transfer：**global_find_player校验对方、双方balance一减一加、双方save()、双方tell_object红字通知、global_destruct_player收尾**

### Elixir实现
- 全局命令（任何地方都能存取）：check/deposit/withdraw/convert/transfer
- Money.split扁平铜钱拆面额、Banker.deposit/withdraw、convert成功只改meta.coins、**transfer仅发起方扣减、不校验/不贷记/不通知接收方**
- friendly 错误文案映射

### 缺失功能
- [ ] 人物/房间前提（必须身在钱庄+钱庄主在场）
- [ ] **转账目标侧完全缺失**（不校验/不贷记/不通知接收方）
- [ ] busy状态机、银行家战斗态检查
- [ ] 重启保护（is_rebooting）
- [ ] 金额溢出检查（10000上限）
- [ ] 货币实物模型（*_money可叠加对象、message_vision）
- [ ] do_check负余额归零
- [ ] 注释与实现不符（bank_command.ex头部注释"暂不落盘"但Records实际已persist bank_coins）

---

## 42. shop 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | cmds/usr/shop.c 76（巫师管理）+ inherit/room/shop.c 91 + feature/dealer.c 531（采购侧） | 78（3个模块） |
| **文件** | `cmds/usr/shop.c` + `inherit/room/shop.c` + `feature/dealer.c` | `lib/kantele/character/commands/shop_commands.ex` |

> 结构错位：Elixir shop_commands.ex 移植的是 dealer/waiter/vendor 的"购物互动"（list/buy/ask），**不是** LPC cmds/usr/shop.c 的巫师店铺管理。

### LPC完整功能
- cmds/usr/shop.c：巫师店铺管理（list_shop/open_all/close_all/reset shop/change_owner，SECURITY_D valid_grant校验）
- room/shop.c：shop_type开/关、open_long描述、DATA_DIR/shop/<id> save/restore
- dealer.c do_list：现货行p*12/10加价、vendor_goods目录、count=-1大量供应、base_unit聚合
- do_buy：MAX_ITEM_CARRIED、amount>100限购、货币拒售、店东八折(value*4/5+台词)、MONEY_D->player_pay三态(0穷光蛋/2银票找不开/1成交)、message_vision

### Elixir实现
- ListCommand（list [商人]）、BuyCommand（buy xN parse_quantity、max 100）、AskCommand（ask about前缀剥离）
- NpcShopEvent.list用Dealer.build_list、buy_result直接扣扁平铜钱+生成Item.Instance+Records.save

### 缺失功能
- [ ] LPC巫师店铺管理链路整缺
- [ ] 店铺状态（shop_type/open_long/save_restore）
- [ ] 购买权限制约（MAX_ITEM_CARRIED）
- [ ] 货币支付三态（0/2/1）与银票
- [ ] 店东八折+台词
- [ ] vendor_goods标价覆盖与val_factor 12/10分支
- [ ] do_list展示口径（12/10加价、大量供应、可叠加聚合）
- [ ] 摊主忙碌态、message_vision、摊主库存扣减/补货
- [ ] `sell X to Y` / `buy X from Y` 指名摊主语法

---

## 43. sell 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | dealer.c do_sell≈142行 + do_value≈46行（合计531） | 175（+npc/dealer.ex） |
| **文件** | `feature/dealer.c`（商人NPC add_action注册） | `lib/kantele/character/commands/sell_command.ex` |

### LPC完整功能（do_value/do_sell）
- do_value：货币/活物拒绝、consistence成色折扣、value<1一文不值、no_drop/no_sell细分支
- do_sell：`<物品> to <id>`指定摊主、数量前缀、身上没有/不可拆卖/超量/货币/活物拦截
- no_drop/no_sell拒收语、自己摊上的货"我卖给你好不好？"、food_supply/shaolin/mingjiao专门拒收
- 成交：三折MONEY_D->pay_player(me, value*3/10)、整组move / 拆卖new+set_amount、ob->sold()回调、message_vision
- amount<1负数量 log_file("sell")作弊追踪

### Elixir实现
- value/估价、sell/卖 <物品> [xN]：parse_quantity→take→Dealer.do_sell→从背包剔除+coins+=total+Records.save
- item_map 只填name/id/value，**不会携带 no_sell/food_supply/shaolin/mingjiao等数据驱动拒收位**

### 缺失功能
- [ ] 房间/摊主前提与指名（任意地点对虚空商人卖出）
- [ ] 数据驱动拒收位全部缺席（food_supply/shaolin/mingjiao/no_drop/no_sell恒为falsy→分支永不触发）
- [ ] is_vendor_good自买自卖拦截
- [ ] amount<1日志追踪
- [ ] 可叠加物/半成品拆分（set_amount/add_amount）
- [ ] consistence成色折扣
- [ ] value<2兜底、ob->sold()回调
- [ ] 摊主收货动作（move(this_object())进商人库存）
- [ ] message_vision第三人称

---

## 44. channel 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | channeld.c 627（+feature/command.c频道入口 + tune.c 55） | 11（+channel_event.ex/tune_command.ex） |
| **文件** | `adm/daemons/channeld.c` + `feature/command.c` | `lib/kantele/character/commands/channel_command.ex` |

> LPC 频道入口：**任何未识别动词只要命中频道名就当频道发言**（chat/rumor/shout/party/family/inter/bill/ultra/wiz/sys/debug/sing/waidi/rultra/ic）。

### LPC完整功能（channeld.c）
- 多频道定义表（权限only：wiz/arch/party/family/league、age门槛ic18/rumor30）
- 超长自动chat转ultra、rumor扣jing -random(36)、shout扣内力random(200)+300
- ban_say禁言、chblk_on、4秒重复检测、scheme扣jing 50
- 自动订阅（没听过就set channels+提示）、for_listen只许听
- 频道emote（EMOTE_D、匿名rumor"某人"、intermud远程REMOTE_Q）
- 匿名谣言+sys播报+SPECIAL_NPC/ROBOT_NPC上报
- 投递filter_listener过滤、message("channel:<verb>")
- channel_log（omit_log跳/30条/10秒刷）、QQ群同步(qq_d)、intermud频道

### Elixir实现
- 仅 fixed `general <text>` 语法、publish_message("general")
- ChannelEvent：interested? = announcement || channel_name=="general"、system_character虚拟角色
- 登录订阅 general/rumor（无条件）、tune只能在已订阅列表内开关
- tune：打开要"用频道说话"（闭式）

### 缺失功能
- [ ] 频道命令入口（任意未识别动词即发言）
- [ ] 多频道定义表缺（只有general）
- [ ] 订阅即限制（从不读meta.channels）
- [ ] 发言权限门禁（wiz等级/party/family/league归属）
- [ ] 年龄/资源门槛、rumor扣精、shout扣内力
- [ ] 反滥用（重复检测/禁言/chblk_on）
- [ ] 频道emote/匿名谣言/intermud
- [ ] channel_log、QQ同步
- [ ] filter_listener、tune开/关两态

---

## 45. tell 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 237 | 14+50（tell_event）+24（tell_view） |
| **文件** | `cmds/std/tell.c` | `lib/kantele/character/commands/tell_command.ex` |

### LPC完整功能
- `target@mud` GTELL跨服、MESSAGE_D离线回落
- no_tell/can_tell白黑名单（巫师豁免）
- interactive/is_net_dead/living在线校验、ban_say禁言
- obj==me → message_vision"$N喃喃自语"
- **jam_talk阻塞交谈队列**（tell_list合并、32K上限、单人12条上限、write_prompt打断）
- set_temp("reply")供reply命令、idle>120秒"在猪圈中发呆N分钟"
- remote_tell/7 intermud反向入口

### Elixir实现
- TellCommand → tell/send事件 → Room.TellEvent：find_local/find_player → TellEvent.broadcast：置meta.reply_to + publish_message("characters:<id>")
- 接收方TellView "listen"（英文"X tells you"）

### 缺失功能
- [ ] no_tell/can_tell骚扰过滤
- [ ] 在线状态校验（目标不在订阅就打给空气）
- [ ] ban_say禁言、自我tell
- [ ] jam_talk阻塞队列
- [ ] reply/skip联动确认
- [ ] idle提示、intermud@mud跨服
- [ ] MESSAGE_D离线回落
- [ ] 文案中文化（Elixir英文）

---

## 46. whisper 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 67 | 14+68（whisper_event）+33（whisper_view） |
| **文件** | `cmds/std/whisper.c` | `lib/kantele/character/commands/whisper_command.ex` |

### LPC完整功能
- 同房查找(present+is_character)、ob==me自我拦截、ban_say禁言
- 房间no_say约束（字符串/通用）
- doing==scheme扣精（jing<100拦截、jing-=50）
- 回显"你在X的耳边悄声说道：msg"
- tell_room旁观者只见"X在Y耳边小声地说了些话"看不见内容
- NPC→relay_whisper（NPC可接应耳语）

### Elixir实现
- WhisperCommand → whisper/send事件 → Room.WhisperEvent：find_local → **整房广播** rooms:<id>，靠interested?（type=="whisper"）过滤
- WhisperView三模板：echo/listen/obscured（英文）

### 缺失功能
- [ ] ban_say禁言、no_say约束
- [ ] scheme扣精
- [ ] 自我耳语拦截
- [ ] NPC relay_whisper
- [ ] 消息过滤是整房广播靠interested?（LPC是tell_room排除指定者）
- [ ] 文案中文化（旁观obscured模板文案不同）

---

## 47. note 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | feature/edit.c 29（行编辑器）+ 挂接方bboard/newsd/jboard | 98（+editor/line.ex 33） |
| **文件** | `feature/edit.c`（非命令） | `lib/kantele/character/commands/note_command.ex` |

> **LPC 无独立 note 命令**：note/便笺编辑由可继承编辑器 feature/edit.c 提供（me->edit(callback)），挂接在公告板/新闻系统（done_post → 写注记表notes：标题/作者/时间排序）。

### LPC完整功能（edit.c）
- `me->edit(callback)` 行编辑器：.结束、~q取消、~e内建vi（空实现）
- input_to逐行捕获（牺牲命令解析）
- 挂接方是note的关键：bboard.c/newsd.c done_post 把标题+作者+时间构造成note mapping写入注记表，**便笺有投稿/发贴目标**

### Elixir实现
- note/便笺/笔记 <rest>，Line.accumulate状态机（. / ~q / ~e）
- finish：清会话渲染"便笺完成：\n---\ntext---\n"+save()；**无任何落板/存档载体**

### 缺失功能
- [ ] **回调目标缺失**：LPC完结文本进done_post写注记表（发板/发新闻/写存档）；Elixir只回显
- [ ] 输入方式差异（每行都要note前缀驱动 vs LPC裸行input_to）
- [ ] **裸note被north的"n"吞掉不可达**（moduledoc明示）
- [ ] ~q文案差异、与news整合（newsd.c）

---

## 48. look 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 1087（37KB） | 9（+Room.LookEvent ~34行） |
| **文件** | `cmds/std/look.c` | `lib/kantele/character/commands/look_command.ex` |

### LPC完整功能
- look 房间：出口描述、房间物品/生物列表、动态环境（下雨/打雷/傍晚等天气）、额外描述
- look <物品>：物品详细描述
- look <人物>：人物外貌/装备/受伤状态/称号
- look <方向>：出口方向查看
- look at/help 分支
- 大量辅助函数（look_room/look_item/look_char/look_dir等）

### Elixir实现
- 9行 stub → room/look事件 → Room.LookEvent：assign room/characters(排除死者)/item_instances/mini_map → 渲染LookView "look" + "mini_map" + "look.extra"

### 缺失功能
- [ ] look 物品/人物/方向详细查看
- [ ] 动态天气/环境描述
- [ ] 出口查看、文字布局细节
- [ ] 人物装备/状态查看

---

## 49. describe 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 40 | 46 |
| **文件** | `cmds/usr/describe.c` | `lib/kantele/character/commands/describe_command.ex` |

### 状态
- [x] 功能基本对齐（设置/删除个人描述）
- [ ] 需确认描述存储与展示链路是否走通

---

## 50. nick 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 68 | 65 |
| **文件** | `cmds/usr/nick.c` | `lib/kantele/character/commands/nick_command.ex` |

### 缺失功能
- [ ] ANSI颜色代码支持
- [ ] 80字符长度检查

---

## 51. title 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 430 | 78 |
| **文件** | `cmds/usr/title.c` | `lib/kantele/character/commands/title_command.ex` |

### LPC完整功能
- 玩家自设称号 + **巫师称号管理池**（管理型称号的授权/分配/回收）
- 称号分类（管理/门派/自设）、等级校验、保存

### Elixir实现
- 仅玩家侧自设称号

### 缺失功能
- [ ] 巫师管理池整缺（LPC 430行大多在此）

---

## 52. color 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 31 | 36 |
| **文件** | `cmds/usr/color.c` | `lib/kantele/character/commands/color_command.ex` |

### 缺失功能
- [ ] 实际色块演示（颜色预览）
- [ ] 亮色/背景色处理

---

## 53. tune 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 55 | 55 |
| **文件** | `cmds/std/tune.c` | `lib/kantele/character/commands/tune_command.ex` |

### 状态
- [x] 功能基本对齐
- [ ] 频道列表交互细节（见 channel 分析）

---

## 54. help 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 205 | 53 |
| **文件** | `cmds/usr/help.c` | `lib/kantele/character/commands/help_command.ex` |

### LPC完整功能
- `help` 无参：HELP_DIR/topics静态索引（分页）
- `help here`：按所在房间domain+short在here_map（≈50区域）/here_map2（多图区域）查地图帮助，房间名$BLINK$高亮
- `help <主题>`：/help/路径顺序查找
- 主题没文件：按命令名 me->find_command(arg) 调用该命令的 help() 回调
- `efun()` 语法支持（剥离括号后走efun_search四路径）

### Elixir实现
- Help.Cache.keys()枚举索引、Help.KeywordCache关键词/中文别名、未命中unknown页

### 缺失功能
- [ ] help here 房间/区域定位（50+区域映射）
- [ ] 命令名兜底（help()回调机制）—— 无此机制
- [ ] efun/lfun 函数语法与文档路径
- [ ] topics静态文件索引
- [ ] 长文档分页

---

## 55. version 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 101 | 11 |
| **权限** | **arch/admin 管理命令** | 全玩家 |
| **文件** | `cmds/arch/version.c` | `lib/kantele/character/commands/version_command.ex` |

### LPC完整功能
- version 无参：VERSION_D->is_version_ok同步检查、版本号、ctime生成时间、本地MUD名
- version stop/cancel（admin）：清除VERSION_D同步信息
- version sync（arch）：强制同步最新版本（一天内免同步）
- version get <file>（admin）：读服务器/version/下文件

### Elixir实现
- 仅渲染"Powered by Kalevala v<版本号>"一行

### 缺失功能
- [ ] arch/admin权限校验
- [ ] version sync/stop/get 管理功能
- [ ] 版本同步状态检查、本地MUD名/生成时间

---

## 56. map 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 321 | 7 |
| **文件** | `cmds/std/map.c` | `lib/kantele/character/commands/map_command.ex` |

### LPC完整功能
- `map here`：绘制当前户外地图（out_family地图册/outdoors/非克隆/busy/jing>=50校验、消耗jing 20+rand30、drawing技能≥30、广播vision、start_busy、按技能等级给经验/潜能/江湖阅历奖励）
- `map view` 本地地图、`map list` 已绘制地点（分页）、`map all` 地区列表
- `map <地点>`：中文名→ID转换、MAP_D->mark_map、@R/@N颜色替换、分页
- `map rumor`：奇闻趣事记录/查阅

### Elixir实现
- 7行：无条件触发 zone-map/look 事件（显示当前区域地图），无参数解析

### 缺失功能
- [ ] map here 绘制流程+奖励
- [ ] view/list/all 参数
- [ ] <地点> 中文名转换、mark_map、颜色替换
- [ ] rumor 奇闻
- [ ] MAP_D 地图存储与标记系统

---

## 57. world_status 命令

| 项目 | LPC对应 | Elixir版本 |
|------|---------|------------|
| **行数** | loadall.c 70（admin）+ mudinfo.c 115（总览） | 16 |
| **文件** | `cmds/adm/loadall.c` / `cmds/usr/mudinfo.c` | `lib/kantele/character/commands/world_status_command.ex` |

> **LPC 不存在 world_status 独立文件**。最接近等价物：loadall（admin递归加载校验.c文件）/mudinfo（世界运行状态总览：MUD名/驱动版本/CPU/负载/内存/在线人数/载入对象/uptime）。

### Elixir实现
- 调用 Kantele.World.Kickoff.status()（GenServer查**上次世界热更/加载**结果）
- 输出：从未加载过/成功+时间（ISO8601 UTC）/失败+时间+出错文件+原因摘要截断300字符
- 定位是管理员热更排查工具，回应reload命令

### 缺失/错位
- [ ] 无 loadall 主动遍历加载校验命令
- [ ] 无世界总览（mudinfo的MUD名/驱动/CPU/内存/在线数/uptime/状态）
- [ ] 无玩家在线/注册人数、载入对象数
- [ ] 仅"上次热更结果"单点，无实时运行状态面板
- [ ] 权限未显式admin校验

---

## 58. recall 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 157 | 67 |
| **文件** | `cmds/usr/recall.c` | `lib/kantele/character/commands/recall_command.ex` |

### LPC完整功能
- 前置守卫：outdoors为空或∈gaochang / is_area() / maze → 拒绝
- 30个区域名→大地图坐标表（如changan/huashan→(59,63)、shaolin/songshan→(66,66)），default随机random(100)落点
- area_move(load_object("/world/area/world"), me, x, y) 定点传送

### Elixir实现
- 取character.room_id → start_room_id：找"startroom"flag房间回退Enum.at(rooms,0) → Teleport.teleport(dest)
- 语义改为"区域起始房间startroom"而非世界坐标

### 缺失功能
- [ ] outdoors/gaochang黑名单/is_area/maze 守卫
- [ ] 30区→坐标表与随机落点

---

## 59. suicide 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 137 | 38 |
| **文件** | `cmds/usr/suicide.c` | `lib/kantele/character/commands/suicide_command.ex` |

### LPC完整功能
- is_busy、身上携带活人(deep_inventory+userp/playerp)拦截
- 要求完整`suicide -f` → input_to 管理密码二次校验（crypt(passwd, old)==old）
- 15秒倒计时（slow_suicide/halt_suicide busy回调、每5秒提示剩余）
- combat_exp>=1000 → CHANNEL_D rumor广播 + log_file("static/suicide")记录IP
- tell_room"化作轻烟，渐渐消失了……"
- **UPDATE_D->remove_user(id)级联删除角色档案**
- halt：打消寻死的念头

### Elixir实现
- rest=="-f" → farewell：告别语+halt()；否则输出提示+**注记"当前为占位实现，实际不会删除档案"**
- 不删档、不断线、不加busy

### 缺失功能
- [ ] UPDATE_D->remove_user 级联删档（核心行为，明示不实现）
- [ ] 管理密码二次校验
- [ ] 15秒倒计时+halt后悔期
- [ ] is_busy/带活人拦截
- [ ] rumor广播、log_file档案
- [ ] tell_room场景广播、来源IP

---

## 60. backpack 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | feature/user_storage.c 404（bag/store/take三命令add_action） | 447（+item/backpack.ex 103） |
| **文件** | `feature/user_storage.c`（非命令文件） | `lib/kantele/character/commands/backpack_command.ex` |

> **LPC 无 cmds/**/backpack.c**：Elixir BackpackCommand 是 LPC bag/store/take 三命令的统一移植。

### LPC完整功能
- 守卫：storage_bag==0"你还没有背包呢"、busy/fighting
- list_bag：编号列表[%2d]、amount==0清理
- take：`take 编号 数量`（1-10000）、new失败清格、**身上物品≥100且不可合并拒绝**、合并物品set_amount+move/非合并逐件new、random(2)start_busy(3)、msg("vision")广播
- store：**容量公式n=(∛(combat_exp*10)+1)/10 clamp 9..99 + storage_bag扩展**、逐条校验链（moneey/food/liquid/temp_dbase/SILENTDEST/UNIQUE/no_clone/no_put/no_store/装备worn-wielded双文案/容器内含物检查）、同file+id+name合并
- store all：排除装备/钱/活人/食物/液体、>100"太多了"
- save_depot/restore_depot存档（name/id/file/amount）

### Elixir实现
- store/take/list：unlock?（meta.storage_bag>0）、busy/fighting守卫
- Backpack.capacity 复刻立方根公式、store合并/追加、take越界钳制、grant_instances重建实例
- store_check校验链（money?恒false、food?/liquid?、equipped_item?、store_ok?cloneable+no_clone/no_put/no_store）

### 缺失功能
- [ ] take 身上≥100件拒绝分支
- [ ] take random(2)start_busy(3)随机忙碌
- [ ] take/store msg("vision")房间广播
- [ ] 合并物品set_amount路径
- [ ] store 校验链缺 temp_dbase/SILENTDEST/UNIQUE/is_item_make/!clonep/is_character项
- [ ] store 容器内含物检查
- [ ] store 装备worn/wielded双文案（Elixir合并一条）
- [ ] store all 过滤维度（money?泼油恒false，钱币未真正拦截）
- [ ] store_each 失败全量回滚 vs LPC 尽力而为

---

## 61. respirate 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 132 | 104（+respirate_event.ex） |
| **文件** | `cmds/skill/respirate.c` | `lib/kantele/character/commands/respirate_command.ex` |

### LPC完整功能
- 守卫链：age<18、pigging、busy、fighting、cost<=0、jing不足、qi*100/max<70、no_fight+doing!="scheme"
- start_busy(respirating, halt_respirate)、set_short_desc("正坐在地下吐纳炼精")、message_vision盘膝坐下
- respirating每tick：jingli_gain=1+force/10/2+random(jingli_gain)、钳制、add jingli/add -jing
- 收尾：瓶颈(jingli>query_current_jingli_limit)/突破(add max_jingli "你的精力增加了！！")
- halt：分压回丹田 + tell_room、jingli钳回2×max

### Elixir实现
- 守卫链：session respirate存在、busy、fighting、**Stats.mapped force为空→先enable（LPC无此，属新增）**、valid_cost、**cost<@min_cost 10（LPC无最小值，属新增限制）**、jing不足、qi_ratio<70、no_fight_room?
- start_respirate：send_after发respirate/tick + put_session
- tick循环在 RespirateEvent

### 缺失功能
- [ ] age<18、pigging拦截
- [ ] no_fight+doing=="scheme"豁免（LPC允许scheme在安全区吐纳）
- [ ] set_short_desc显示状态
- [ ] message_vision盘膝坐下/吐纳完毕广播
- [ ] halt停止回调
- [ ] jingli_gain随机波动与瓶颈判定需与事件层对账
- [ ] 新增限制：@min_cost 10、显式enable检查

---

## 62. closed 命令（闭关）

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 203 | 72 |
| **文件** | `cmds/skill/closed.c` | `lib/kantele/character/commands/closed_command.ex` |

### LPC完整功能
- 守卫链：pigging、ultrap大宗师、wizardp巫师拦截、no_fight房间、sleep_room休息房、busy、潜能≥10000、qi/jing各90%、max_neili≥4000、neili 90%
- 开始：message_vision盘膝、set("startroom")、set("doing","closed")、CLOSE_D->user_closed、rumor广播"大宗师X开始闭关修行"
- closing周期回调（PERIOD=864秒一轮）：潜能耗尽/时间守卫/每轮learned_points+50+random(100)、exp_inc=(50+random(100))*(100+martial-cognize)/500*(100+int)/100、improve_neili/jingli随机、improve_skill("martial-cognize",1000+random(500))、随机martial技能improve(5000+random(1000))
- **非交互→force_me("chat* haha")+call_out user_quit 强制quit（离线修行）**
- halt：**回补一半潜能(learned_points-potential)/2**、rumor"闭关中途突然复出"

### Elixir实现
- 守卫（顺序不同）：busy、**fighting（LPC无此，属新增）**、**family==nil→先拜师（LPC无此，属新增）**、潜能<10000、qi/jing 90%、no_fight_room?
- 通过后**恒返回占位**："闭关修行功能尚未完全开放。大宗师闭关需要离线修行系统支持..."

### 缺失功能
- [ ] 闭关循环主体（CLOSE_D/PERIOD=864节拍）未实现
- [ ] ultrap大宗师/wizardp/pigging/sleep_room边界判定
- [ ] max_neili≥4000与neili 90%检查
- [ ] 离线闭关（user_quit强制quit、chat* haha）
- [ ] rumor广播（开始/圆满/复出）
- [ ] per-round产出（潜能/exp/neili/jingli/martial-cognize/技能感悟）
- [ ] halt潜能回补(learned-potential)/2
- [ ] 新增：family拜师检查、fighting检查

---

## 63. close 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 52 | 48 |
| **文件** | `cmds/std/close.c` | `lib/kantele/character/commands/close_command.ex` |

### LPC完整功能
- 门表解析：方向key精确命中或遍历doors[i]["name"]/id数组**别名模糊匹配**（否则"你要关闭什么？"）
- environment(me)->close_door(dir) 驱动房间状态 + message_vision全房广播"$N将...关上"

### Elixir实现
- Map.get(doors,target)、door.open为真→:ok（开着才可关）、否则"X已经关上了"
- 成功只提示本人

### 缺失功能
- [ ] name/id别名匹配（只能按方向key）
- [ ] message_vision房间广播
- [ ] **无真实状态落库**（只检查door.open不写入闭合状态）
- [ ] "已关上门"提示为Elixir新增（LPC整体失败无专门文案）
- [ ] 无help

---

## 64. open 命令

与 close 完全对称（`cmds/std/open.c` 52行 vs `open_command.ex` 48行）。

### 缺失功能
- [ ] name/id别名匹配
- [ ] message_vision房间广播
- [ ] 无真实门状态写入（只读door.open不置开）
- [ ] "已经打开"提示为Elixir新增
- [ ] 无help

---

## 65. detach 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 105（+feature/master.c attempt_detach 53 + feature/skill.c skill_expell_penalty） | 86（+DetachEvent） |
| **文件** | `cmds/skill/detach.c` | `lib/kantele/character/commands/detach_command.ex` |

### LPC完整功能
- busy检查、cancel分支（pending/detach清空）、**二次确认**（pending/want，红字警告"将被废除所有特殊武功"）
- 目标解析：present/is_character/"你想和谁断绝师徒关系？"/ob==me/!living弄醒
- 磕头广播message_vision"师父！我…我想脱离师门"
- 同家族/异家族两种拒绝文案
- attempt_detach：非嫡传拒、skill_expell_penalty()惩罚 + unconcious（一指废武功场景广播）
- **skill_expell_penalty：删除可enable parry/dodge/throwing/force的martial技能 + 其余martial降到100级上限**、清skill_map/skill_prepare
- 清family/gongxian/quest/title="普通百姓"、detach/家族计数、转世豁免(old_family_name)

### Elixir实现
- run直接发family/detach事件 **无本地校验**
- DetachEvent.detach_result：penalty?时 Stats.all 每技能 level>1则-1（封底1）、gongxian置0、清family、Records.save
- 文案"你毅然决然地叛离了师门！武功尽失一重，门派贡献归零。"（非penalty"武功未受影响"）

### 缺失功能
- [ ] cancel分支、is_busy、**二次确认流程**
- [ ] 目标解析与ob==me/living拦截
- [ ] 磕头/请求message_vision与tell_object
- [ ] 同家族/异家族拒绝文案
- [ ] **惩罚语义差异大**：LPC"删可enable技能+其余砍100级" vs Elixir"全技能-1"
- [ ] unconcious眩晕、detach/家族计数、title="普通百姓"、quest清除、转世豁免
- [ ] 无help

---

## 66. cut 命令

| 项目 | LPC版本 | Elixir版本 |
|------|---------|------------|
| **行数** | 51（+feature/cutable.c） | 68（守卫迁到world/room.ex room/cut事件+cut_event.ex） |
| **文件** | `cmds/std/cut.c` | `lib/kantele/character/commands/cut_command.ex` |

### LPC完整功能
- `cut <部位> from <尸体>` / 无from列可割部位
- 守卫：present失败"你附近没有这样东西"、ob==me"割自己？你有毛病啊？"、can_speak活人"活人你也敢割，找打么"、defeated_by归属"这具尸体已被别人盯上了"
- 兜底notify_fail("你没有地方下手。") → ob->do_cut(me, part)（裁决交给尸体对象）

### Elixir实现
- parse_arg（" from "parts:2）、组装room/cut事件（带weapon_skill_type/weapon_name/skills/force快照）
- 守卫迁往 room.ex room/cut（:call）按名字解析尸体转发给尸体进程
- cut_event.ex（尸体侧do_cut）执行部位校验与产物、Cutable.validate_cut武器/修为校验（已割/no_cut/针锤杖棍鞭部位类型）、产物玩家侧入包落盘

### 缺失功能
- [ ] 四个目标守卫迁出命令层（"你附近没有"/"割自己"/"活人你也敢割"/"尸体已被盯上"）需确认房间/尸体侧等价回灌
- [ ] "你没有地方下手。"兜底由validate_cut替代，文案与触发条件需逐条对照feature/cutable.c
- [ ] 命令层不直接获得do_cut同步返回值（改事件异步，需确认产物入包与失败回显完整）

---

## 总结：39个命令覆盖情况

### 已完全对齐（缺口小）
- describe、tune、remove(实为wield_command承载)、nick（缺ANSI/长度）、color（缺色块预览）

### 已有真实实现但细节缺失
- item命令较多：item系列(drop/get/put)、exercise、learn、team、bank、backpack、respirate、flee、tell、whisper、detach、cut

### 占位/极简（严重缺）
- prepare（"暂未实装组合逻辑"）、stop（"驯兽系统暂未开放"）、suicide（不删档占位）、closed（"闭关尚未开放"）、jingzuo wakeup结算缺失、look（仅房间视图）、map（仅区域地图）、channel（仅general）、world_status（仅热更结果）、version（仅版本号）

### 正向差异（Elixir 更完整）
- team kick/accept/refuse/list（LPC kick是复制dismiss的bug）
- move/flee 显式命令入口（LPC 无独立命令文件）
- respirate 的 enable 检查、closed 的 family/fighting 检查

### 跨命令共性缺口模式
1. **message_vision 房间广播普遍缺失**——Elixir 多为玩家本人单显文本
2. **help() 函数基本未移植**
3. **数据层缺口**：no_drop/no_get/no_get_from/no_put/is_depot 等不再 Item.Meta defstruct 与 loader 解析中 → 命令层分支是死代码
4. **数量/堆叠语义缺失**：Elixir 用"实例一一对应"模型，无 query_amount/叠加
5. **busy/fighting 前置检查普遍缺失**（item/经济/通讯类）
6. **载重(encumbrance)体系整体缺失**（move/quit/get 依赖它）
7. **有状态/离线玩法被降级为占位**（suicide倒计时、closed离线闭关、CLOSE_D）
8. **异步事件化使守卫外移**（detach/cut），需逐条核对文案与触发顺序

---

## 附：全部命令索引表

| # | 命令 | LPC行数 | Elixir行数 | 状态 |
|---|------|---------|------------|------|
| 1 | time | 440 | ~25 | 农历/节日缺失 |
| 2 | score | 440 | ~51 | 战斗/师门缺失 |
| 3 | hp | 285 | ~28 | -m/-g参数缺失 |
| 4 | who | 404 | ~12 | 过滤参数缺失 |
| 5 | inventory | 97 | ~17 | 负重/装备标记缺失 |
| 6 | finger | ~150 | ~42 | 连线资料缺失 |
| 7 | alias | 81 | ~86 | 基本一致 |
| 8 | fill | 54 | ~55 | 环境检查缺失 |
| 9 | quit | ~100 | ~12 | 安全检查缺失 |
| 10 | option | 74 | ~87 | 基本一致 |
| 11 | quest | 113 | ~80 | 领任务缺失 |
| 12 | save | ~50 | ~30 | 基本一致 |
| 13 | fight | 82 | ~19 | 校验缺失 |
| 14 | drink | 197 | ~93 | 容器/液体缺失 |
| 15 | eat | 181 | ~93 | 容器/数量缺失 |
| 16 | give | 224 | ~60 | 数量语法缺失 |
| 17 | wear/wield | 170 | ~283 | **基本完整** |
| 18 | study | 189 | ~60 | 次数/消耗缺失 |
| 19 | follow | 54 | ~30 | 基本涵盖 |
| 20 | emote | 67 | ~30 | 禁言/区域缺失 |
| 21 | reply | 85 | ~40 | 跨MUD缺失 |
| 22 | drop | 171 | ~50 | 数量/区域缺失 |
| 23 | get | 234 | ~73 | 容器/搜身缺失 |
| 24 | put | 146 | ~38 | **无法入容器** |
| 25 | remove | 98 | 24stub | 占位+双实现 |
| 26 | exercise | 141 | 105+151 | 结局检查/加成缺失 |
| 27 | exert | 62 | 32 | 退路/提升缺失 |
| 28 | jingzuo | 94 | 86 | **wakeup结算缺失** |
| 29 | learn | 272 | 189 | 防刷/师资格缺失 |
| 30 | skills | 333 | 106 | 参数/过滤缺失 |
| 31 | enable | 147 | 56 | 资源重置缺失 |
| 32 | prepare | 185 | 126 | **占位未实装** |
| 33 | checkskill | 425 | 178 | 动态加载缺失 |
| 34 | surrender | 41 | 67 | is_killing/广播缺失 |
| 35 | team | 654 | 325 | 阵法/PK/结义缺失 |
| 36 | ride | 76 | 84 | 房间生物/守卫缺失 |
| 37 | unride | 32 | 28 | 移回地面/广播缺失 |
| 38 | stop | 47 | 24 | **驯兽占位** |
| 39 | move | 555 | 39 | 载重/逃跑体系缺失 |
| 40 | flee | 合入go.c | 37 | 成功率判定缺失 |
| 41 | bank | banker.c238 | 235 | **转账目标侧缺失** |
| 42 | shop | 698 | 78 | 巫师管理缺失 |
| 43 | sell | ~188 | 175 | 拒收位/前置缺失 |
| 44 | channel | 627 | 11 | **多频道缺失** |
| 45 | tell | 237 | 14+74 | 过滤/队列缺失 |
| 46 | whisper | 67 | 14+101 | 禁言/scheme缺失 |
| 47 | note | edit.c29 | 98 | **无落板载体** |
| 48 | look | 1087 | 9 | 仅房间视图 |
| 49 | describe | 40 | 46 | **基本对齐** |
| 50 | nick | 68 | 65 | ANSI/长度缺失 |
| 51 | title | 430 | 78 | 巫师管理池缺失 |
| 52 | color | 31 | 36 | 色块预览缺失 |
| 53 | tune | 55 | 55 | **基本对齐** |
| 54 | help | 205 | 53 | here/回调缺失 |
| 55 | version | 101 | 11 | 管理功能缺失 |
| 56 | map | 321 | 7 | **绘制/奖励缺失** |
| 57 | world_status | loadall70/mudinfo115 | 16 | 错位（仅热更） |
| 58 | recall | 157 | 67 | 坐标表/守卫缺失 |
| 59 | suicide | 137 | 38 | **不删档占位** |
| 60 | backpack | user_storage.c404 | 447 | **基本完整** |
| 61 | respirate | 132 | 104 | 年龄/广播缺失 |
| 62 | closed | 203 | 72 | **闭关占位** |
| 63 | close | 52 | 48 | 别名/广播/落库缺失 |
| 64 | open | 52 | 48 | 同上 |
| 65 | detach | 105+ | 86 | 惩罚语义简化 |
| 66 | cut | 51+ | 68 | 守卫外移需核对 |

### P0 新增（严重影响可玩性）
1. **put 无法入容器**（物品丢到地上）——核心操作错误
2. **get from 容器恒失败**（Item.Meta无:items键）
3. **channel 只有 general**——玩家无法用频道说话
4. **look 只有房间视图**——无法查看物品/人物
5. **data层死代码**：no_drop/no_get/no_put 等不被解析

### P1 新增（日常功能）
6. **jingzuo wakeup 结算缺失**（打坐无收益）
7. **enable force 切换不重置内力**（内功约束缺失）
8. **prepare 未实装**（组合拳术）
9. **bank 转账目标侧缺失**（无法给玩家转账）
10. **team 阵法/PK/结义简化**
11. **map 绘制/奖励缺失**

### P2 新增（低优先级）
12. closed（离线闭关）、suicide（删档）、stop（驯兽）、world_status（世界总览）

---

## 第二批命令对照（逐一核验）

> 本批逐行核对了 LPC `cmds/*` 与 Elixir `commands/*_command.ex` 双端实现，
> **不假设任一侧缺失**。绝大多数 Elixir 命令为"暂未开放"占位桩。

### A. Elixir 为占位桩（仅回显"×××系统暂未开放"，无任何逻辑）的命令

| 命令 | LPC文件/行数 | Elixir文件 | Elixir实现 |
|------|--------------|------------|-----------|
| ansuan | cmds/std/ansuan.c 249 | ansuan_command.ex 24 | 占位桩（"暗算系统暂未开放"） |
| assist | cmds/usr/assist.c 207 | assist_command.ex 24 | 占位桩 |
| beg | cmds/std/beg.c 167 | beg_command.ex 24 | 占位桩（丐帮乞讨） |
| check | cmds/std/check.c 141 | check_command.ex 24 | 占位桩（丐帮打探） |
| come | cmds/std/come.c 87 | come_command.ex 24 | 占位桩（驯兽让跟随） |
| daub | cmds/std/daub.c 184 | daub_command.ex 24 | 占位桩（涂毒） |
| drug | cmds/std/drug.c 101 | drug_command.ex 24 | 占位桩（食物下毒） |
| hand | cmds/std/hand.c 71 | hand_command.ex 24 | 占位桩（手持物品） |
| liuxi | cmds/std/liuxi.c 58 | liuxi_command.ex 18 | 占位桩（往返柳溪镇） |
| miss | cmds/usr/miss.c 43 | miss_command.ex 24 | 占位桩（追寻炼制物品） |
| news | cmds/usr/news.c 94 | news_command.ex 30 | 占位桩（新闻阅读） |
| pkd | cmds/usr/pkd.c 60 | pkd_command.ex 18 | 占位桩（屠人场） |
| pour | cmds/std/pour.c 99 | pour_command.ex 24 | 占位桩（容器下毒） |
| purchase | cmds/std/purchase.c 344 | purchase_command.ex 24 | 占位桩（购买） |
| push | cmds/std/push.c 223 | push_command.ex 24 | 占位桩（推人） |
| remove | cmds/std/remove.c 98 | remove_command.ex 24 | 占位桩（脱装备） |
| search | cmds/std/search.c 317 | search_command.ex 18 | 占位桩（搜寻） |
| secularize | cmds/std/secularize.c 48 | secularize_command.ex 18 | 占位桩（还俗） |
| semote | cmds/std/semote.c 84 | semote_command.ex 18 | 占位桩（列表情） |
| special | cmds/std/special.c 110 | special_command.ex 24 | 占位桩（特技） |
| stab | cmds/std/stab.c 30 | stab_command.ex 24 | 占位桩（插旗） |
| stay | cmds/std/stay.c 64 | stay_command.ex 18 | 占位桩（停跟随） |
| steal | cmds/std/steal.c 219 | steal_command.ex 24 | 占位桩（偷窃） |
| stop | cmds/std/stop.c 47 | stop_command.ex 24 | 占位桩（驯兽"暂未开放"） |
| system | cmds/usr/system.c 60 | system_command.ex 18 | 占位桩（CPU占用） |
| talk | cmds/std/talk.c 63 | talk_command.ex 24 | 占位桩（与NPC对话） |
| top | cmds/usr/top.c 113 | top_command.ex 34 | 占位桩（全服排行"暂未开放"） |
| top2 | cmds/usr/top2.c 94 | top2_command.ex 18 | 占位桩（门派/同盟声望榜） |
| topp | cmds/usr/topp.c 94 | topp_command.ex 18 | 占位桩（个人榜） |
| touch | cmds/std/touch.c 34 | touch_command.ex 24 | 占位桩（触摸） |
| train | cmds/std/train.c 117 | train_command.ex 24 | 占位桩（驯兽） |
| vote | cmds/std/vote.c 119 | vote_command.ex 24 | 占位桩（投票） |
| wash | cmds/std/wash.c 108 | wash_command.ex 24 | 占位桩（清洗） |
| wenxuan | cmds/std/wenxuan.c 292 | wenxuan_command.ex 18 | 占位桩（文选） |

### B. Elixir 有真实实现（非占位），但与 LPC 有差异

#### set 命令（set_command.ex 102）

| 项目 | LPC (cmds/usr/set.c 284) | Elixir |
|------|------|--------|
| 查询 | 列出所有 env 变数 | 列出 meta.env（对齐） |
| 语法 | `set term [值]`、`-a`/`-d` 增删列表、unset | `set key=value` 或 `set key value`；**无 -a/-d，无 unset** |
| 校验 | term_map 白名单（40+项）、字符串/数字/列表类型、非零/非负、WIZ_ONLY | **无任何校验**，任意 key/value 直接写入 |
| 特例 | env_domains(combatd/jam_talk)、ENABLE_COLOR、MAX_ENV_VARS 40 上限 | 无 |

- 缺失：白名单校验、-a/-d 列表增删、类型/NON_ZERO/NON_NEG、巫师专属项、env_domains、颜色过滤、40 上限。

#### passwd 命令（passwd_command.ex 54）

| 项目 | LPC (cmds/usr/passwd.c 347) | Elixir |
|------|------|--------|
| 体系 | **双密码**：管理密码(ad_password) + 普通密码(password) | **单密码** meta.password |
| 校验 | 先验证旧管理密码 → 选改管理/普通 → 二次确认 | 仅长度>=5 |
| 巫师 | 可改他人密码（valid_grant/admin 权限校验） | 无 |
| 日志 | log_file("static/passwd") 记录变更 | 无 |
| 其它 | 管理/普通不能相同、他人改后清普通密码、发mail通知 | 无 |

- 缺失：双密码体系、旧密码验证、二次确认、巫师改他人、日志、密码一致性、通知。

#### jifen 命令（jifen_command.ex 27）

- LPC (cmds/usr/jifen.c 122)：查询自己的积分 + **巫师 +|- 增减他人积分**（find_player/global_find_player）+ 查他人 & 日志。
- Elixir：**仅能查自己** meta.jifen，无巫师增删/查他人分支。

#### league 命令（league_command.ex 27）

- LPC (cmds/usr/league.c 811)：完整子命令 info/member/dismiss/add/join/grant/kick/top/hatred/kill/set/title/out + LEAGUE_D 持久化 + rumor 广播。
- Elixir：**仅显示自己的 league_name/未加入**，无任何子命令、无 LEAGUE_D 交互。

#### whisper 命令（whisper_command.ex 14 + WhisperEvent 68 + WhisperView）

- LPC (cmds/std/whisper.c 67)：同房查找、自我拦截、ban_say/no_say、scheme 扣精、回显 + 旁观只见"小声说了些话"。
- Elixir：**功能实现**——whisper_command → whisper/send 事件 → Room.WhisperEvent.broadcast 整房发布，WhisperView 三模板（echo/listen/obscured）。
- 差异：守卫（自我拦截/禁言/no_say/scheme扣精）、NPC relay_whisper 缺失；广播整房靠 interested? 过滤而非 LPC tell_room 排除指定者；文案英文。
- **注意**：之前 GAP 仅第 46 节记录 whisper，此处确认其**已实现**（非占位）。

### C. 失败定位说明（command_module 与 commands.ex 路由）

`commands.ex` 的 module 块若引用了不存在的命令文件会导致 `UndefinedFunctionError`。
本批所有命令在 `lib/kantele/character/commands/` 下均有同名 `*_command.ex`，故**路由都能成功匹配**，
但大部分只回显占位文案 —— 属"命令可输入但功能未落地"，而非"命令不可用"。

### D. 本批最关键阻塞（占位桩密集区）

1. **驯兽/驱兽闭环**（train/come/stay/stop）全为占位 —— 无法驯兽、让野兽跟随、停下、停止攻击。
2. **下毒/涂毒/清洗闭环**（drug/pour/daub/wash）全占位 —— 毒药体系整体未实现。
3. **打探/追寻体系**（check/miss/??/answer）占位 —— 丐帮打探、追寻炼制物品不可用。
4. **社会互动**（assist/steal/vote/purchase/push/pkd/secularize）全占位。
5. **信息类**（top/top2/topp/news/wenxuan/semote/system/listen）全占位。
6. **表情/频道**（semote）占位，与 channel 只有 general 呼应。

### E. 修订累积（本批之前报告的疏漏更正）

- whisper 实际**已实现**（事件化），并非 LPC 缺失 —— 更正早期可能的误判。
- league/jifen/set/passwd 有部分实现，非完全占位。

---

## 全命令盘点：LPC cmds/ 完备性审计

> 对 `C:\files\git\mud\cmds\{std,usr,skill,chat,arch,adm,wiz}` 全部 **312 个命令**
> 逐一核对 `commands.ex` 路由与 `commands/*_command.ex` 文件是否存在。

### 审计口径

- **有 Elixir 路由**：commands.ex 中存在对应 verb 的 `parse(...)` 即可输入。
  是否"已实现"另见本文件逐节对照（多数落 `*_command.ex` 占位桩）。
- **无 Elixir 文件/路由**：既无指令文件，commands.ex 也无对应 `parse`，完全不存在。

### 结论：184 / 312 完全缺失（约 59%）

缺失部分按类别拆解：

#### A. 玩家可用的 std/（缺 19/80）
`apply attack cook drive femote go guard hit invasion look2 make makelove refuse right skill sleep swear touxi watch`
（注：`go`=LPC方向移动，Elixir用 `north/south/east/west` 等替代；
`attack/hit`=战斗，Elixir用 `kill/fight`；`watch` LPC有但Elixir完全未接。）

#### B. 玩家可用的 usr/（缺 26/55）
`accede area auction baitan divorce engage feed findwp hatred hide idle mobile mudinfo mudlist mudlist2 qrcode quest2 record rideto shop skip snoop summon unset uptime wizlist`
（`accede/divorce/engage`=婚约，`brothers/hatred`=结义/仇人，`shop/auction/baitan`=摆摊、`hide/snoop/summon/skip/idle/feed/area/mobile/qrcode/record/quest2/findwp/rideto` 均无。）

#### C. 玩家可用的 skill/（缺 23/40）
`animaout berserk breakup burning combine crattack death derive enchase enforce expell fuse imbue jingxiu persuade pique recruit research san spattack syn yanlian`
（已实现的 skill/ 仅：abandon apprentice checkskill closed detach enable exercise exert jingzuo learn myskill perform practice prepare respirate skills study。→ **combine/enchase/enforce/imbue/san/syn/spattack 等战斗/修真向技能系统整族缺失**。）

#### D. chat/（缺 6/6）
`command enterworld getenv go input setenv`
（LPC内嵌聊天客户端，Elixir环境无需单文件，聊天走 channel/general/tell 已覆盖。）

#### E. 巫师/管理员工具（arch 缺 31/31、adm 缺 25/25、wiz 缺 43/43 = 缺 99）
adm/auth cache checkuser chklog dump eval f fcrypt giftall giveall grant guilei linux loadall msg profile query reclaim rinemote shutdown sp telnet tongji updateall updatei
arch/ban blockade board build call callouts changename child chinese cleanup cleartemp cmd config data dual endlog examine find findusr free getid kickout log mv overview p2 possess promote purge qdel qinfo reboot recovermud register rehash restore sa sameip setsk smash spy status1 throw var which wizlock
wiz/cat cd chblk clone copyskill cost cp dest edit ff goto home ilist ip ipname localcmds ls mem mkdir more mv nodie pwd qload rm status summon ulist unchblk update weight where who1 who2 who3 whoami whohave whoride wizard
（Elixir侧无 WIZ/ARCH/ADM 权限体系与对应管理命令框架，故全缺。）

### 结论要点

1. 玩家核心指令已路由约 128 个；其中**大量为占位桩**（见第二批 A 表）。
2. 完全缺失的 184 个里，约 **68 个是玩家可用功能**（std19+usr26+skill23），
   其余 99 个 wiz/arch/adm 管理端 + 6 个 chat 客户端在 Elixir 架构下本就无对应物。
3. 最值得补的玩家缺失族：
   - **战斗/技能族**：combine、enforce、enchase、imbue、san、syn、spattack、research、persuade、recruit、pique、jingxiu、breakup、berserk、animaout、crattack、yanlian
   - **婚约/结义族**：accede、divorce、engage、brothers、hatred、refuse
   - **摆摊/交易族**：shop、auction、baitan、hide、record、feed
   - **社会跳转族**：area、mobile、rideto、findwp、summon、snoop、idle、skip、qrcode、quest2、uptime、mudinfo/mudlist/mudlist2、wizlist、unset、skill、sleep、cook、make、drive、guard、hit、touxi、apply、right、invasion、look2、swear、femote、makelove
   - **watch**：LPC探测房间，Elixir完全未接
