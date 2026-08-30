# inherit 移植计划

> 创建: 2026-08-30 ｜ 分支: `kalevala` ｜ 目标: 将 `C:\files\git\mud\inherit` 移植到 Elixir 框架

## 背景

`mud/inherit` 是 LPC mudlib 的**基础对象继承层**，由组合 feature 模块构成具体对象。世界文件（房间、NPC、物品）通过 `inherit` 这些基类获得行为。

框架已有 Kalevala 基础行为 + 49 feature 纯逻辑层，本计划补全缺失的继承层逻辑。

---

## 0. 现状分析

### 继承文件清单（按目录）

```
inherit/
├── char/           # 角色基类
│   ├── char.c       # 玩家/NPC 通用基类（heart_beat/setup）
│   ├── npc.c        # NPC 特化
│   ├── fighter.c    # 战斗 NPC
│   ├── smith.c      # 工匠 NPC
│   ├── challenger.c # 挑战者
│   ├── punisher.c   # 惩罚者
│   ├── quarry.c     # 猎物
│   ├── waiter.c     # 服务员
│   ├── insect.c     # 昆虫
│   ├── worm.c       # 蠕虫
│   ├── snake.c      # 蛇
│   └── knower.c     # 知情者
├── item/           # 物品基类
│   ├── item.c       # 物品基础（setup/type）
│   ├── money.c      # 货币
│   ├── book.c       # 书籍
│   ├── container.c  # 容器
│   ├── combined.c   # 组合物品
│   ├── inlaid.c     # 镶嵌物品
│   ├── medical-book.c # 医书
│   └── task.c       # 任务物品
├── room/           # 房间基类
│   ├── room.c       # 房间基础（reset/优化）
│   ├── bank.c       # 银行房间
│   ├── shop.c       # 商店房间
│   ├── chatroom.c   # 聊天室
│   ├── privateroom.c # 私人房间
│   ├── buildroom.c  # 建房
│   ├── pigroom.c    # 猪笼
│   ├── river.c      # 河流
│   ├── create.c     # 创建
│   ├── producing.c   # 生产
│   └── trans.c      # 传送
├── weapon/         # 武器类型
│   ├── sword.c      # 剑
│   ├── blade.c     # 刀
│   ├── axe.c       # 斧
│   ├── club.c      # 棍
│   ├── dagger.c    # 匕首
│   ├── fork.c      # 叉
│   ├── hammer.c    # 锤
│   ├── pin.c       # 针
│   ├── staff.c     # 杖
│   ├── whip.c      # 鞭
│   ├── bow.c       # 弓
│   ├── throwing.c  # 暗器
│   ├── xsword.c    # 玄铁剑
│   └── _*.c        # 空文件占位符
├── armor/         # 护甲类型
│   ├── armor.c     # 护甲基础
│   ├── cloth.c     # 布甲
│   ├── boots.c     # 靴子
│   ├── head.c      # 头盔
│   ├── neck.c      # 项链
│   ├── finger.c    # 戒指
│   ├── waist.c     # 腰带
│   ├── wrist.c     # 护腕
│   ├── hands.c     # 手套
│   ├── shield.c    # 盾牌
│   ├── surcoat.c   # 外袍
│   └── charm.c     # 护身符
├── condition/     # 状态系统
│   ├── poison.c    # 毒
│   ├── damo.c      # 大魔
│   └── illness.c   # 疾病
├── medicine/      # 药品
│   ├── pill.c      # 药丸
│   └── powder.c    # 药粉
├── skill/         # 技能系统
│   ├── force.c     # 内功
│   ├── skill.c     # 技能基础
│   └── shaolin.c   # 少林
├── misc/          # 杂项
│   ├── bboard.c   # 公告板
│   ├── fboard.c   # 论坛
│   ├── jboard.c   # 江湖榜
│   ├── quest.c    # 任务
│   ├── equip.c    # 装备
│   └── _*.c       # 乐器
├── Socket.c       # 网络 Socket
├── insect.c       # 昆虫（根级）
└── worm.c         # 蠕虫（根级）
```

### 框架已有覆盖

| 类别 | 框架状态 | 说明 |
|------|----------|------|
| char/ | ✅ 完整 | `Kalevala.Character` + `Kantele.Character` + `Kantele.NPC` |
| item/ | ✅ 完整 | `Kalevala.Item` + 具体 Item 类型 + `Kantele.Item.ExtraLong` + `Kantele.Item.type/1` |
| room/ | ✅ 完整 | `Kalevala.Room` + `Kantele.World.Room` + `Kantele.World.Room.Const` |
| weapon/ | ✅ 完整 | `Kantele.Item.ExtraLong.weapon/2` |
| armor/ | ✅ 完整 | `Kantele.Item.ExtraLong.armor/2` |
| condition/ | ✅ 完整 | `Kantele.Character.Conditions` |
| skill/ | ✅ 完整 | `Kantele.Combat.Skills` |
| misc/ | 🟡 部分 | bboard/fboard/jboard 需实现（P2） |

---

## 1. 优先级与依赖

### P0 — 核心阻塞（缺失则世界文件无法加载）

| 优先级 | 文件 | 原因 | 目标模块 | 状态 |
|--------|------|------|----------|------|
| P0 | `weapon/*.c` | 所有武器继承，无 extra_long 则描述不完整 | `Kantele.Item.ExtraLong` | ✅ 已完成 |
| P0 | `armor/*.c` | 所有护甲继承，无 extra_long 则描述不完整 | `Kantele.Item.ExtraLong` | ✅ 已完成 |
| P0 | `item/item.c` | 所有物品基础，type() 影响分类 | `Kantele.Item.type/1` | ✅ 已完成 |
| P0 | `room/room.c` | 所有房间继承，MAX_ITEM_IN_ROOM 等 | `Kantele.World.Room.Const` | ✅ 已完成 |
| P0 | `char/char.c` | 玩家/NPC 基础，心跳/is_character | `Kalevala.Character` | ✅ 已有 |

### P1 — 重要系统（缺失影响游戏体验）

| 优先级 | 文件 | 原因 | 目标模块 | 状态 |
|--------|------|------|----------|------|
| P1 | `condition/*.c` | 毒/病系统，世界文件大量使用 | `Kantele.Character.Conditions` | ✅ 已有 |
| P1 | `item/money.c` | 货币系统，经济基础 | `Kantele.Economy.Money` | ✅ 已有 |
| P1 | `char/npc.c` | NPC 基础行为 | `Kantele.NPC` | ✅ 已完成 |
| P1 | `item/book.c` | 书籍系统，技能学习相关 | `Kantele.Item.Book` | 🟡 待补 |
| P1 | `room/shop.c` | 商店房间 | `Kantele.Npc.Dealer` | ✅ 已有 |

### P2 — 锦上添花

| 优先级 | 文件 | 原因 | 目标模块 |
|--------|------|------|----------|
| P2 | `room/chatroom.c` | 聊天室（625 行） | `Kantele.Chatroom` |
| P2 | `misc/bboard.c` | 公告板（214 行） | `Kantele.Bboard` |
| P2 | `room/privateroom.c` | 私人房间 | `Kantele.PrivateRoom` |
| P2 | `skill/force.c` | 内功系统 | `Kantele.Combat.Force` |
| P2 | `misc/fboard.c`, `jboard.c` | 论坛/江湖榜 | `Kantele.Board` |

---

## 2. 实施计划

### Phase 1 — 武器防具 extra_long（P0）

**目标**: 补全武器防具的 `extra_long()` 描述

```
weapon/extra_long + armor/extra_long
├── lib/kantele/item/weapon.ex       # 武器 extra_long 描述
├── lib/kantele/item/armor.ex        # 护甲 extra_long 描述
├── lib/kantele/item/weapon_data.ex  # 武器类型数据（sword/blade/...）
└── test/kantele/item/weapon_armor_test.exs
```

**迁移文件**:
- `inherit/weapon/sword.c` → `weapon/extra_long()`
- `inherit/weapon/blade.c` → 同上
- `inherit/weapon/*.c` → 同上模式
- `inherit/armor/*.c` → `armor/extra_long()`

### Phase 2 — 物品基础 type()（P0）

**目标**: 补全物品 type() 分类

```
item/type
├── lib/kantele/item.ex              # type() 方法
└── test/kantele/item/type_test.exs
```

### Phase 3 — 房间基础 reset/优化（P0）

**目标**: 补全房间 reset() 逻辑和优化

```
room/reset
├── lib/kantele/world/room_reset.ex  # reset 逻辑
└── test/kantele/world/room_reset_test.exs
```

### Phase 4 — NPC 基类（P1）

**目标**: NPC 基础行为

```
char/npc
├── lib/kantele/npc.ex               # NPC 基类行为
└── test/kantele/npc/npc_test.exs
```

### Phase 5 — 条件系统增强（P1）

**目标**: 毒/病系统

```
condition/poison
├── lib/kantele/character/conditions/poison.ex
├── lib/kantele/character/conditions/illness.ex
└── test/kantele/character/conditions_test.exs
```

### Phase 6 — 聊天室/公告板（P2）

```
chatroom + bboard
├── lib/kantele/chatroom.ex
├── lib/kantele/bboard.ex
└── test/kantele/chatroom_test.exs
```

---

## 3. 验收标准

1. 每 Phase 新增测试，**全量 785+ tests, 0 failures**
2. 编译无 warnings
3. 文档更新本文档勾选状态
4. 每 Phase commit + push

---

## 4. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-08-30 | 创建文档，分类 inherit 文件并制定优先级计划 |
| 2026-08-30 | Phase 1-4 完成：weapon/armor extra_long、item type()、room Const、NPC carry_object |
| 2026-08-30 | 全量 812 tests / 0 failures |
