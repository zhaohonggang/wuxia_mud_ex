# 游戏内容修改指南（Kantele / ExVenture）

本指南说明如何修改这个 MUD 引擎的游戏世界内容：房间、NPC、物品、AI 对话、帮助主题等。

## 目录

- [内容的两条修改路径](#内容的两条修改路径)
- [前置知识：UCL 文件格式](#前置知识ucl-文件格式)
- [修改区域与房间](#修改区域与房间)
- [修改 NPC（角色）](#修改-npc角色)
- [修改 NPC 的 AI 行为（大脑）](#修改-npc-的-ai-行为大脑)
- [修改物品](#修改物品)
- [修改交互动词（Web 客户端按钮）](#修改交互动词web-客户端按钮)
- [修改表情动作](#修改表情动作)
- [修改帮助主题](#修改帮助主题)
- [修改新玩家出生点](#修改新玩家出生点)
- [通过管理后台在线修改](#通过管理后台在线修改)
- [生效方式速查与常见坑](#生效方式速查与常见坑)

---

## 内容的两条修改路径

| 路径 | 改哪里 | 生效方式 | 适用场景 |
|---|---|---|---|
| **A. 世界源文件** | `data/` 目录下的 `.ucl` / `.help` 文件 | `dev_start.bat reset` 重新播种 | 正式内容，版本可控，reset 不丢 |
| **B. 管理后台** | http://localhost:4000/admin | 编辑后点 Publish 即时生效 | 快速调试文案；但 reset 后会丢 |

**原则：正式内容写进 `data/` 源文件；后台只用来临时调试。两边都改过时，以源文件为准。**

---

## 前置知识：UCL 文件格式

`data/` 下的 `.ucl` 文件使用 ELIAS/UCL 格式（类似 JSON 的 Erlang 术语语法）。基本规则：

```ucl
rooms "town_square" {
  name = "Town Square"
  description = "You are in the town square."
}
```

- `#` 开头是注释
- 字符串用双引号；列表用 `[ ]`；对象用 `{ }`
- **必须保存为 LF 换行**（仓库已有 `.gitattributes` 兜底，VS Code 右下角可确认）
- 引用其他对象用点路径：`rooms.town_square.id`（同文件）、`sammatti.rooms.gates.id`（跨文件/跨区域）

改完源文件后执行重播种：

```bat
dev_start.bat reset
```

⚠️ reset 会清空整个数据库并重新播种，管理后台手工做过的修改会全部丢失。

---

## 修改区域与房间

世界地图定义在 `data/world/*.ucl`（现有三个区域文件：`kissa-jarvi.ucl`、`lepakko-luola.ucl`、`sammatti.ucl`）。

### 房间三要素

```ucl
rooms "inn" {
  name = "Lohikäärme"                    # 房间名
  description = "The interior of..."     # 进入房间看到的描述
  map_icon = "stein"                     # 小地图图标（可选）
  map_color = "yellow"                   # 小地图颜色（可选）

  x = 1                                  # 地图坐标（小地图布局用）
  y = 0
  z = 0                                  # z 是楼层：0=地面，1=楼上，-1=地下
}
```

### 出口

每个房间配一个 `room_exits` 块：

```ucl
room_exits "inn" {
  room_id = rooms.inn.id        # 指向哪个房间的出口配置

  west = rooms.town_square.id   # 方向 = 目标房间
  up = rooms.inn_upstairs.id    # 支持 north/south/east/west/up/down
}
```

### 房间细节（features）

玩家在房间里 `look 关键词` 可以看到细节描述：

```ucl
features = [
  {
    keyword = "well"                # 玩家输入 look well 触发
    short = "A well with a bucket"  # 短描述
    long = "A well with a bucket dangling is off to the side..."
  }
]
```

### 新建一个房间的完整步骤

1. 在区域文件里加 `rooms "my_room" { ... }` 块（key 全区域唯一）
2. 加对应的 `room_exits "my_room"`，并在相邻房间的 exits 里加回程出口
3. `dev_start.bat reset`

### 新建一个区域

复制任一现有区域文件（如 `sammatti.ucl`）作模板，顶部改为：

```ucl
zones "myzone" {
  name = "我的区域名"
}
```

注意：seeds 会自动把区域内所有房间发布上线；`seed = false` 标记的文件（如 `global.ucl`）只作为资源库，不生成实际房间。

---

## 修改 NPC（角色）

NPC 定义在各区域文件的 `characters` 块中：

```ucl
characters "villager" {
  name = "Villager"
  description = "A villager of Sammatti."   # look 时看到

  brain = brains.villager                   # 绑定 AI 大脑（见下一节）

  initial_events = [                        # 出生后自动触发的事件（可选）
    {
      topic = "characters/move"
      delay = 5000                          # 毫秒
      data = { id = "wander" }              # wander=游荡, emote=做动作
    }
  ]
}
```

把 NPC 放进房间：

```ucl
room_characters "blacksmith" {
  room_id = rooms.blacksmith.id

  characters = [
    {
      id = characters.villager.id
      name = "Anni"          # 可选：给这个实例起专名（同一 NPC 可多处放置）
    }
  ]
}
```

---

## 修改 NPC 的 AI 行为（大脑）

大脑定义在 `data/brains/*.ucl`，是一棵「条件 → 动作」节点树。核心节点类型：

| 类型 | 名称 | 作用 |
|---|---|---|
| 条件 | `conditions/message-match` | 监听房间聊天，正则匹配 `text` |
| 条件 | `conditions/tell-match` | 监听对 NPC 私聊（tell） |
| 条件 | `conditions/state-match` | 匹配 NPC 记忆状态（配合 state-set 做多轮对话） |
| 条件 | `conditions/room-enter` | 有人进入房间时触发 |
| 动作 | `actions/say` | 说话（`channel_name = "${channel_name}"` 回到当前频道） |
| 动作 | `actions/emote` | 做动作 |
| 动作 | `actions/state-set` | 写入记忆（`ttl` 秒后过期） |
| 组合 | `sequence` / `first` / `conditional` | 顺序执行 / 取第一个命中的分支 |

一个典型的多轮对话骨架（节选自 `data/brains/town_crier.ucl`）：

```ucl
brains "my_conversation" {
  type = "conditional"
  nodes = [
    {
      type = "conditions/tell-match"
      data = { self_trigger = false, text = ".*" }
    },
    {
      type = "first"
      nodes = [
        # 分支1：没聊过 → 打招呼 + 记住"已开始"
        { type = "conditional", nodes = [
            { type = "conditions/state-match",
              data = { match = "nil", key = "conversation-${character.id}" } },
            { type = "actions/say",
              data = { channel_name = "characters:${character.id}",
                       text = "你好，冒险者！" } },
            { type = "actions/state-set",
              data = { key = "conversation-${character.id}",
                       value = "started", ttl = 60 } }
        ]},
        # 分支2：聊过且回答 yes → 推进剧情
        # 分支3：聊过但说了别的 → 兜底回复
      ]
    }
  ]
}
```

常用变量插值：`${character.name}`（玩家名）、`${channel_name}`、`${room_id}`。
文字支持颜色标记：`{color foreground="white"}文字{/color}`。

大脑通过文件里的 key 被区域引用：`brain = brains.town_crier`。同一个文件里可以定义多个 brain 互相 `ref` 复用。

---

## 修改物品

全局物品库在 `data/world/global.ucl`（`seed = false`，仅作为资源被各区域引用）：

```ucl
items "longsword" {
  name = "Longsword"
  description = "A dual edged sword, with a silver hilt."

  verbs = ["drop", "get"]   # Web 客户端上该物品可用的操作按钮
}
```

把物品放进房间：

```ucl
room_items "town_square" {
  room_id = rooms.town_square.id

  items = [
    { id = global.items.longsword.id },
    { id = global.items.potion.id }
  ]
}
```

---

## 修改交互动词（Web 客户端按钮）

`data/verbs.ucl` 定义网页客户端里物品/角色旁的操作按钮：

```ucl
verbs "drop" {
  icon = "drop"              # 按钮图标
  text = "Drop"              # 按钮文字
  send = "drop ${id}"       # 点击后实际发送给服务器的命令

  conditions = {             # 何时显示该按钮
    location = ["inventory/self"]   # 仅当物品在自己背包
  }
}
```

`location` 常用值：`room`（在地上）、`inventory/self`（自己背包）、`inventory/mine`（别人背包？按需组合）。新增动词后记得把它加进对应物品的 `verbs` 列表才会出现。

---

## 修改表情动作

`data/emotes.ucl`——玩家输入的自定义社交命令：

```ucl
emotes "bow" {
  command = "bow"                    # 玩家输入 bow
  text = "bows solemnly to everyone."   # 房间内其他人看到 "XXX bows solemnly..."
}
```

---

## 修改帮助主题

`data/help/*.help` 文件，上半段是 UCL 元信息，`---` 之后是正文：

```
key = "welcome"
title = "Welcome to Kantele"
see_also = ["newbie"]
---
Welcome to {color foreground="256:39"}Kantele{/color}.
正文支持 {color foreground="cyan"}颜色标记{/color}。
```

玩家在游戏里输入 `help welcome` 查看。新建主题 = 新建一个 `.help` 文件。

---

## 修改新玩家出生点

`data/config.ucl`：

```ucl
player {
  starting_room_id = sammatti.rooms.town_square.id
}
```

改成任意 `区域名.rooms.房间key.id` 即可，reset 后生效。

---

## 通过管理后台在线修改

适合快速试文案，不用 reset：

1. 登录 http://localhost:4000 （种子账号 `admin` / `password`）
2. Admin → Zones → 选区域 → Rooms → Edit
3. 本项目有**暂存机制**：编辑只是产生 staged change，进入 Staged Changes 页面或房间详情页点 **Publish** 才真正进入游戏
4. 不想要了可在 staged changes 列表里删除

局限：只能改数据库里的房间/区域，**不能**编辑 NPC 大脑、动词、表情等（这些只在 `data/` 源文件里）；且 reset 后全部丢失。

---

## 生效方式速查与常见坑

| 改了什么 | 怎么生效 |
|---|---|
| `data/world/*.ucl`、`data/config.ucl`、`data/brains/*.ucl` 等 | `dev_start.bat reset`（重新播种） |
| 管理后台的房间/区域编辑 | 点 Publish 即时生效 |
| 游戏命令逻辑（新指令、战斗系统等） | 那是 Elixir 代码（`lib/kantele/`），保存后刷新浏览器即热重载 |

常见坑：

1. **CRLF 换行**：`.ucl`/`.help` 必须是 LF，否则 ELIAS 解析器报 `syntax error before: '\r'`，播种失败（`.gitattributes` 已兜底，手工创建的新文件仍需留意编辑器右下角）
2. **忘记回程出口**：出口是单向的，A→B 加了 B→A 才能走回来
3. **坐标冲突**：同区域同 `(x,y,z)` 的两个房间会让小地图渲染错乱
4. **reset 是毁灭性的**：会清掉所有玩家、后台改动，重新播种；正式服慎用
5. **引用路径写错**：`global.items.xxx.id` 只对 `seed = false` 的资源文件成立；同区域内部直接 `rooms.xxx.id`
