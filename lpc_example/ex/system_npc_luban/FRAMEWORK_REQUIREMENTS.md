# system_npc_luban Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Npc.House.create_room/4` | Instantiate prototype room files to player dir | 建房流程 |
| `Npc.House.create_new_key/2` | Generate door key for built house | 建房流程 |
| `Npc.House.demolish/2` / `rebuild` | Tear down / rebuild house | 管理 |
| `Player.contract(?)` | `contract/luban` temp form storage | form/建房 |
| `Wizard.form/1` | `form/<player_id>` rejected by wiz panel | 批核 |
| `Player.add_money/2` / pay | Cash payment for house | 缴款建房 |
| `Room.query_room_name/1` / `query_room_id/1` | Uniqueness check against built rooms | check_legal_* |
| `DATA_DIR` | Data root for `file_dir`/`to_player` | path gen |
| `Persona.check_legal/2` | Chinese name/id validation | naming |

## Portable Pure Data & Logic (ported to .ex with smoke tests)

### room_example — 户型表 (3 种)
| type | name | value(造价) | files 数 |
|------|------|-------------|----------|
| dule | 独乐居 | 20,000,000 | 2 |
| caihong | 彩虹居 | 70,000,000 | 4 |
| panlong | 盘龙居 | 800,000,000 | 22 |

### ban_room_id — 保留房间代号/出口名
```
north south east west northup southup eastup westup
northdown southdown eastdown westdown northeast northwest
southeast southwest up down enter out in
```

### check_room_name/1 — 房名校验
```
strwidth 4..12（即 2-6 个中文字）且全为中文 -> :ok
否则 {:error, msg}
```

### check_room_id/1 — 代号校验
```
长度 3..10；全为英文字母；不在 ban_room_id -> :ok
否则 {:error, msg}
```

### check_house_type/1
按 `type`(英文) 或 `name`(中文) 查 `room_example`，返回户型 map 或 nil。

### obey_description/1 — 描述净化
```
strwidth > 420 -> :error
"->' 、\n 转义还原、去 Tab、去空格
$BLK$..$NOR$ ANSI 色码 token -> \e[...m
末尾补 \e[0m (NOR)
```

### file_dir / to_player — 路径映射
```
file_dir(data, player) = data/room/<player>/
to_player(data, player, "/d/room/panlong/xiaoyuan.c")
    = data/room/<player>/xiaoyuan.c
```

### str_width / cjk? — 中文字符宽度
CJK 字符按 2 计（LPC `strwidth` 语义），供房名/描述长度判断。

### processable?/1
巫师等级 >= 4 (WIZLEVEL) 才能批核表单。

## Integration Notes

- C-tier 系统型 NPC。正确做法：底层新增 Kantele.House 服务层
  （户型表 + 合同/表单 + 建房/拆房 + 门匙 + 巫师批核），而不是把交互
  逻辑塞进单个 NPC 文件。
- 唯一性校验依赖已建房屋索引（`query_room_name` / `query_room_id`）。
- 此迁移**修正了原 stub 的错误定性**（原误标为"打造/机关/镶嵌 crafting"；
  实为 鲁班建房/营造 系统）。
- Smoke tests: `smoke_test.exs` (28 cases, all PASS) 覆盖户型表、三查校验、
  describe 净化（含 ANSI 替换与长度上限）、str_width、路径映射、wizlevel。
