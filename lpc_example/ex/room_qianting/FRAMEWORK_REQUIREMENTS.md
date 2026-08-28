# room_qianting Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Room.exits` / dynamic exit rewrite | open gate adds "north", close removes it | do_push/do_close |
| `Room.sync_room/1` | Sync exit/gate state to adjacent room (`/d/room/panlong/zoudao`) | do_push/do_close |
| `Room.set_timer/3` / `cancel_timer/2` | 10s auto-close timer (qianting_auto_close) | do_push |
| `Room.broadcast/2` | Broadcast message to adjacent area (zoudao) | do_push/do_close |
| `Room.vision/2` | Room vision message | do_push/do_close |
| `Player.owner?/2` | Whether player is the house owner | valid_leave/_do_push |
| `Player.owner_permit?/2` | Whether player has owner permit | valid_leave/_do_push |
| `Player.name/1` / `Player.shen/1` | Name / 声望 for title | format_msg/respect_title |

## Core Algorithms (ported)

### 1. do_push/3 — Push open the gate
```
gate already :open        -> {:error, "大门开着呢，你还推什么？"}
else {new_state, msgs} = _do_push(state, player, laopu)
```

`_do_push` message routing by `msg_type`:
```
laopu.owner?(player)                      -> :owner        ("主人推门")
not laopu.living/present                  -> :nobody        ("大门被打开")
not owner and not owner_permit            -> :laopu_for_permit  ("拦住 {respect} 请回")
laopu.living                              -> :laopu_opens   ("老仆开门")
```
Effects:
- state: gate=:open, exits += "north"
- sync zoudao: `%{"exits/south"=>"qianting.ex", "gate"=>:open}`
- emit cancel_timer + set_timer(qianting_auto_close, 10000, auto_close_timer)

### 2. do_close/4 — Close the gate (auto_close flag)
```
gate already :close -> {:error, "大门关着呢，你还再再关一过？"}
else _do_close(state, player, laopu, auto_close)
```
`msg_type`: auto_close -> :nobody; owner -> :owner_self; not_living -> :nobody;
owner -> :laopu_for_owner; living -> :laopu_closes.
Effects: gate=:close, exits -= "north"; sync zoudao `%{"exits/south"=>:delete, "gate"=>:close}`.

### 3. auto_close_timer/2
If gate == :open → do_close(state, nil, laopu, true) else {:noop, state}.

### 4. check_valid_leave/4 — 权限拦截 (leaving north = entering house)
```
dir != "north" or laopu not living -> {:passthrough}
laopu.is_owner?(player)         -> {:allow, "请进"}
laopu.is_owner_permit?(player)  -> {:allow, "朋友请进"}
true                            -> {:deny,  "非请莫入"}
```

### 5. generate_long/3 — Dynamic room description
Appends door status ("大门敞开"/"大门紧闭") + laopu sweeping line to room long,
wrapped by sort_string (60-char pad + 句号 newline).

### 6. respect_title/1 — title by 声望 (shen)
```
shen >  10000 : 大传
shen >   5000 : 传士
shen >    500 : 良善
shen >   -500 : 少传
shen >  -5000 : 恶徒
else           : 魔头
```

## Integration Notes

- C-tier 房间交互 mixin。中文原文全部用 `\u{....}` 码点转义存放，规避 Windows
  写盘乱码问题。
- 关键框架缺口：**动态 exits**（房间状态机改写 exit 表）、**跨房间 sync**
  （改相邻 zoudao 的 exits/south）、**每房间定时器**（10s 自动关门）、
  **valid_leave 钩子**（移动到特定方向前的权限拦截）。
- 需在 Kantele.World.Room 增加 `dynamic_exits` + `sync_room` + 定时器原语，
  并让所有 UCL 房间能声明 owner/permit 身份。
