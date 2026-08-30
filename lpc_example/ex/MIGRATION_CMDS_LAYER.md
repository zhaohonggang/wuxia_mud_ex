# 指令迁移计划：`mud/cmds` → `lib/kantele`

> 分支: `kalevala` ｜ 更新: 2026-08-30 ｜ 总命令数: ~295

---

## 0. 现状

- **已移植**: 67 个命令（见附录 A）
- **未移植**: ~228 个命令
- **测试基线**: 872 tests / 0 failures

---

## 1. 分类与优先级

### P0 — 核心战斗/移动/物品（直接影响可玩性）

#### 1.1 std/ 核心命令

| 命令 | 文件 | 说明 | 依赖 |
|------|------|------|------|
| `ansuan` | std/ansuan.c | 暗算 | feature/attack, move |
| `drop` | std/drop.c | 丢弃物品 | inventory, money |
| `drug` | std/drug.c | 吸毒 | Item.Drug / condition |
| `buy` | usr/buy.c | 向玩家购物 | Economy.Money, Vendor |
| `sell` | usr/sell.c | 卖给玩家 | (已有，接线) |
| `wear` | std/wear.c | 穿装备 | Item.Equip |
| `remove` | std/remove.c | 脱装备 | Item.Equip |
| `unwield` | std/unwield.c | 放下武器 | Item.Equip |
| `get` | std/get.c | 捡东西 | move, inventory |
| `put` | std/put.c | 放东西 | inventory, container |
| `fill` | std/fill.c | 装填液体 | Item.Liquid |
| `pour` | std/pour.c | 倒液体 | Item.Liquid |
| `cook` | std/cook.c | 烹饪 | Item.Food, skill |
| `hide` | std/hide.c | 躲藏 | skill, move |
| `steal` | std/steal.c | 偷窃 | skill, move |
| `guard` | std/guard.c | 守卫 | Npc.Guarder |
| `push` | std/push.c | 推 | move |
| `drive` | std/drive.c | 驱赶 | transport |

#### 1.2 usr/ 核心命令

| 命令 | 文件 | 说明 | 依赖 |
|------|------|------|------|
| `assist` | usr/assist.c | 协助战斗 | combat |
| `auction` | usr/auction.c | 拍卖 | Economy |
| `baitan` | usr/baitan.c | 拜托（任务） | Quest |
| `buy` | usr/buy.c | 向玩家买 | Economy.Money |
| `sell` | usr/sell.c | 卖给玩家 | (已有，接线) |
| `list` | usr/list.c | 商店列表 | Npc.Dealer |
| `purchase` | std/purchase.c | 向商店买 | Npc.Vendor |
| `divorce` | usr/divorce.c | 离婚 | Family |
| `engage` | usr/engage.c | 求婚 | Family |
| `passwd` | usr/passwd.c | 修改密码 | Auth |
| `score2` | usr/score2.c | 详细分数 | Stats |
| `rideto` | usr/rideto.c | 骑乘传送 | Transport |
| `summon` | usr/summon.c | 召唤 | (已有，接线) |

---

### P1 — 日常功能（社交/信息）

#### 1.3 skill/ 技能命令

| 命令 | 文件 | 说明 | 依赖 |
|------|------|------|------|
| `abandon` | skill/abandon.c | 放弃技能 | Skills |
| `berserk` | skill/berserk.c | 狂战士 | skill |
| `breakup` | skill/breakup.c | 拆解 | skill |
| `burning` | skill/burning.c | 燃烧 | skill |
| `combine` | skill/combine.c | 组合技能 | skill |
| `derive` | skill/derive.c | 派生 | skill |
| `fuse` | skill/fuse.c | 融合 | skill |
| `imbue` | skill/imbue.c | 注入 | Item.Craft |
| `jingxiu` | skill/jingxiu.c | 静修 | vitals |
| `persuade` | skill/persuade.c | 说服 | NPC |
| `pique` | skill/pique.c | 激怒 | NPC |
| `recruit` | skill/recruit.c | 招募 | Family |
| `research` | skill/research.c | 研修 | skill |
| `spattack` | skill/spattack.c | 特攻 | skill |
| `san` | skill/san.c | 祝融 | Item.Craft |
| `syn` | skill/syn.c | 同步 | skill |
| `yanlian` | skill/yanlian.c | 炎炼 | skill |
| `animaout` | skill/animaout.c | 元神出窍 | skill |
| `crattack` | skill/crattack.c | 反击 | combat |
| `enchase` | skill/enchase.c | 镶嵌 | Item.Craft |

#### 1.4 usr/ 社交/信息命令

| 命令 | 文件 | 说明 | 依赖 |
|------|------|------|------|
| `area` | usr/area.c | 地区信息 | World |
| `beep` | usr/beep.c | 呼叫 | tell |
| `brothers` | usr/brothers.c | 结拜 | Family |
| `describe` | usr/describe.c | 描述 | Character |
| `feed` | usr/feed.c | 喂养 | NPC |
| `finger` | usr/finger.c | 查看玩家信息 | (已有，接线) |
| `hatred` | usr/hatred.c | 仇恨 | Quest |
| `idle` | usr/idle.c | 闲置时间 | (info) |
| `jifen` | usr/jifen.c | 积分 | Quest |
| `league` | usr/league.c | 结社 | Social |
| `miss` | usr/miss.c | 约会 | Social |
| `mobile` | usr/mobile.c | 移动信息 | World |
| `mudinfo` | usr/mudinfo.c | 游戏信息 | System |
| `mudlist` | usr/mudlist.c | 游戏列表 | System |
| `mudlist2` | usr/mudlist2.c | 游戏列表2 | System |
| `news` | usr/news.c | 新闻 | Board |
| `pkd` | usr/pkd.c | PK开关 | Pvp |
| `qrcode` | usr/qrcode.c | 二维码 | System |
| `quest2` | usr/quest2.c | 任务2 | Quest |
| `recall` | usr/recall.c | 召回 | (已有，接线) |
| `record` | usr/record.c | 录像 | System |
| `scheme` | usr/scheme.c | 计划 | Quest |
| `score` | usr/score.c | 分数 | (已有，接线) |
| `set` | usr/set.c | 设置 | Option |
| `shop` | usr/shop.c | 商店 | (已有，接线) |
| `skip` | usr/skip.c | 跳过 | System |
| `suicide` | usr/suicide.c | 自杀 | (已有，接线) |
| `system` | usr/system.c | 系统 | System |
| `tianshu` | usr/tianshu.c | 天书 | Quest |
| `time` | usr/time.c | 时间 | System |
| `title` | usr/title.c | 称号 | (已有，接线) |
| `top` | usr/top.c | 排行榜 | System |
| `top2` | usr/top2.c | 排行榜2 | System |
| `topp` | usr/topp.c | 排行榜p | System |
| `unset` | usr/unset.c | 取消设置 | Option |
| `wizlist` | usr/wizlist.c | 巫师列表 | System |

---

### P2 — 管理员/巫师命令（低优先级）

#### 1.5 adm/ 管理命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `auth` | adm/auth.c | 认证 |
| `cache` | adm/cache.c | 缓存 |
| `checkuser` | adm/checkuser.c | 检查用户 |
| `chklog` | adm/chklog.c | 日志检查 |
| `clear` | adm/clear.c | 清除 |
| `dump` | adm/dump.c | 转储 |
| `eval` | adm/eval.c | 求值 |
| `f` | adm/f.c | F命令 |
| `fcrypt` | adm/fcrypt.c | 加密 |
| `giftall` | adm/giftall.c | 全体赠送 |
| `giveall` | adm/giveall.c | 全体给予 |
| `grant` | adm/grant.c | 授权 |
| `guilei` | adm/guilei.c | 归类 |
| `linux` | adm/linux.c | Linux命令 |
| `loadall` | adm/loadall.c | 加载全部 |
| `msg` | adm/msg.c | 消息 |
| `profile` | adm/profile.c | 配置 |
| `query` | adm/query.c | 查询 |
| `reclaim` | adm/reclaim.c | 回收 |
| `rinemote` | adm/rinemote.c | 远程 |
| `shutdown` | adm/shutdown.c | 关闭 |
| `sp` | adm/sp.c | SP |
| `telnet` | adm/telnet.c | Telnet |
| `tongji` | adm/tongji.c | 统计 |
| `updateall` | adm/updateall.c | 更新全部 |
| `updatei` | adm/updatei.c | 更新 |

#### 1.6 arch/ 建筑师命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `ban` | arch/ban.c | 封禁 |
| `blockade` | arch/blockade.c | 封锁 |
| `board` | arch/board.c | 公告板 |
| `build` | arch/build.c | 建筑 |
| `call` | arch/call.c | 调用 |
| `callouts` | arch/callouts.c | 定时器 |
| `changename` | arch/changename.c | 改名 |
| `child` | arch/child.c | 子进程 |
| `chinese` | arch/chinese.c | 中文 |
| `cleanup` | arch/cleanup.c | 清理 |
| `cleartemp` | arch/cleartemp.c | 清除临时 |
| `cmd` | arch/cmd.c | 命令 |
| `config` | arch/config.c | 配置 |
| `data` | arch/data.c | 数据 |
| `dual` | arch/dual.c | 双人 |
| `endlog` | arch/endlog.c | 结束日志 |
| `examine` | arch/examine.c | 检查 |
| `find` | arch/find.c | 查找 |
| `findusr` | arch/findusr.c | 查找用户 |
| `free` | arch/free.c | 空闲 |
| `getid` | arch/getid.c | 获取ID |
| `kickout` | arch/kickout.c | 踢出 |
| `log` | arch/log.c | 日志 |
| `mv` | arch/mv.c | 移动 |
| `overview` | arch/overview.c | 概览 |
| `p2` | arch/p2.c | P2 |
| `possess` | arch/possess.c | 附身 |
| `promote` | arch/promote.c | 晋升 |
| `purge` | arch/purge.c | 清除 |
| `qdel` | arch/qdel.c | 快速删除 |
| `qinfo` | arch/qinfo.c | 快速信息 |
| `reboot` | arch/reboot.c | 重启 |
| `recovermud` | arch/recovermud.c | 恢复 |
| `register` | arch/register.c | 注册 |
| `rehash` | arch/rehash.c | 重新加载 |
| `restore` | arch/restore.c | 恢复 |
| `sa` | arch/sa.c | SA |
| `sameip` | arch/sameip.c | 同IP |
| `setsk` | arch/setsk.c | 设置技能 |
| `smash` | arch/smash.c | 破坏 |
| `spy` | arch/spy.c | 间谍 |
| `status1` | arch/status1.c | 状态1 |
| `throw` | arch/throw.c | 投掷 |
| `var` | arch/var.c | 变量 |
| `version` | arch/version.c | 版本 |
| `which` | arch/which.c | 哪个 |
| `wizlock` | arch/wizlock.c | 巫师锁 |

#### 1.7 wiz/ 巫师命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `cat` | wiz/cat.c | 查看 |
| `cd` | wiz/cd.c | 切换目录 |
| `chblk` | wiz/chblk.c | 禁言 |
| `clone` | wiz/clone.c | 克隆 |
| `color` | wiz/color.c | 颜色 |
| `copyskill` | wiz/copyskill.c | 复制技能 |
| `cost` | wiz/cost.c | 花费 |
| `cp` | wiz/cp.c | 复制 |
| `dest` | wiz/dest.c | 销毁 |
| `edit` | wiz/edit.c | 编辑 |
| `ff` | wiz/ff.c | FF |
| `goto` | wiz/goto.c | 跳转 |
| `home` | wiz/home.c | 回家 |
| `ilist` | wiz/ilist.c | 实例列表 |
| `info` | wiz/info.c | 信息 |
| `ip` | wiz/ip.c | IP |
| `ipname` | wiz/ipname.c | IP名 |
| `localcmds` | wiz/localcmds.c | 本地命令 |
| `ls` | wiz/ls.c | 列表 |
| `mem` | wiz/mem.c | 内存 |
| `mkdir` | wiz/mkdir.c | 建目录 |
| `more` | wiz/more.c | 更多 |
| `mv` | wiz/mv.c | 移动 |
| `nodie` | wiz/nodie.c | 不死 |
| `pwd` | wiz/pwd.c | 当前目录 |
| `qload` | wiz/qload.c | 快速加载 |
| `rm` | wiz/rm.c | 删除 |
| `status` | wiz/status.c | 状态 |
| `summon` | wiz/summon.c | 召唤 |
| `ulist` | wiz/ulist.c | 用户列表 |
| `unchblk` | wiz/unchblk.c | 解除禁言 |
| `update` | wiz/update.c | 更新 |
| `weight` | wiz/weight.c | 重量 |
| `where` | wiz/where.c | 位置 |
| `who1` | wiz/who1.c | 谁1 |
| `who2` | wiz/who2.c | 谁2 |
| `who3` | wiz/who3.c | 谁3 |
| `whoami` | wiz/whoami.c | 我是谁 |
| `whohave` | wiz/whohave.c | 谁有 |
| `whoride` | wiz/whoride.c | 谁骑 |
| `wizard` | wiz/wizard.c | 巫师 |

#### 1.8 chat/ 聊天命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `command` | chat/command.c | 聊天命令 |
| `enterworld` | chat/enterworld.c | 进入世界 |
| `finger` | chat/finger.c | 指尖 |
| `getenv` | chat/getenv.c | 获取环境 |
| `go` | chat/go.c | 移动 |
| `input` | chat/input.c | 输入 |
| `look` | chat/look.c | 看 |
| `say` | chat/say.c | 说 |
| `setenv` | chat/setenv.c | 设置环境 |
| `tell` | chat/tell.c | 告诉 |
| `who` | chat/who.c | 谁 |

#### 1.9 imm/  IMM 命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `cpemote` | imm/cpemote.c | 复制表情 |
| `edemote` | imm/edemote.c | 编辑表情 |
| `flyto` | imm/flyto.c | 飞往 |
| `recover` | imm/recover.c | 恢复 |
| `rnemote` | imm/rnemote.c | 远程表情 |

---

### P3 — 测试文件（不迁移）

| 文件 | 说明 |
|------|------|
| `test/efun.c` | LPC 内部函数 |
| `test/test.c` | 测试 |
| `test/test.h` | 测试头 |

---

## 2. 分批推进计划

> 每批：实现 → 测试通过 → 提交推送 → 更新本文档

### Batch CM1 — 核心物品命令（P0）
**source**: `std/drop`, `std/get`, `std/put`, `std/wear`, `std/remove`, `std/unwield`
**target**: `lib/kantele/character/commands/{drop,get,put,wear,remove,unwield}_command.ex`
**依赖**: Item.Equip, Backpack
**测试**: 6+ new tests

### Batch CM2 — 液体/容器命令（P0）
**source**: `std/fill`, `std/pour`, `usr/buy`
**target**: `lib/kantele/character/commands/{fill,pour,buy}_command.ex`
**依赖**: Item.Liquid, Economy.Money
**测试**: 3+ new tests

### Batch CM3 — 战斗增强命令（P0）
**source**: `std/ansuan`, `std/hide`, `std/steal`, `std/guard`
**target**: `lib/kantele/character/commands/{ansuan,hide,steal,guard}_command.ex`
**依赖**: Combat, move, skill
**测试**: 4+ new tests

### Batch CM4 — 生活技能命令（P1）
**source**: `std/cook`, `std/drive`, `std/push`
**target**: `lib/kantele/character/commands/{cook,drive,push}_command.ex`
**依赖**: Item.Food, Transport
**测试**: 3+ new tests

### Batch CM5 — 技能系统扩展（P1）
**source**: `skill/abandon`, `skill/berserk`, `skill/breakup`, `skill/fuse`, `skill/derive`
**target**: `lib/kantele/character/commands/{abandon,berserk,breakup,fuse,derive}_command.ex`
**依赖**: Combat.Skills
**测试**: 5+ new tests

### Batch CM6 — 社交/任务扩展（P1）
**source**: `usr/assist`, `usr/auction`, `usr/baitan`, `usr/divorce`, `usr/engage`
**target**: `lib/kantele/character/commands/{assist,auction,baitan,divorce,engage}_command.ex`
**依赖**: Quest, Family, Economy
**测试**: 5+ new tests

### Batch CM7 — 信息/系统命令（P1）
**source**: `usr/area`, `usr/mobile`, `usr/mudinfo`, `usr/mudlist`, `usr/news`
**target**: `lib/kantele/character/commands/{area,mobile,mudinfo,mudlist,news}_command.ex`
**依赖**: World, Board
**测试**: 5+ new tests

### Batch CM8 — 排行/统计命令（P1）
**source**: `usr/top`, `usr/top2`, `usr/topp`, `usr/score2`
**target**: `lib/kantele/character/commands/{top,score2}_command.ex`
**依赖**: Stats
**测试**: 2+ new tests

### Batch CM9 — 剩余 skill 命令（P1）
**source**: `skill/jingxiu`, `skill/persuade`, `skill/pique`, `skill/recruit`, `skill/research`
**target**: `lib/kantele/character/commands/{jingxiu,persuade,pique,recruit,research}_command.ex`
**依赖**: Skills, Family
**测试**: 5+ new tests

### Batch CM10 — 剩余 usr 命令（P1）
**source**: `usr/beep`, `usr/brothers`, `usr/describe`, `usr/feed`, `usr/hatred`
**target**: `lib/kantele/character/commands/{beep,brothers,describe,feed,hatred}_command.ex`
**依赖**: Social, Family
**测试**: 5+ new tests

### Batch CM11+ — adm/wiz/arch 命令（P2/P3）
**source**: 管理/巫师命令
**target**: `lib/kantele/admin/` 或 `lib/kantele/wiz/`
**说明**: 低优先级，可后续批量处理

---

## 3. 依赖图

```
Batch CM1(核心物品)
       ↓
Batch CM2(液体/容器)
       ↓
Batch CM3(战斗增强)     Batch CM4(生活技能)
       ↓                      ↓
Batch CM5(技能扩展)     Batch CM6(社交/任务)
       ↓                      ↓
Batch CM7(信息/系统)    Batch CM8(排行)
       ↓                      ↓
       └──────────┬──────────┘
                  ↓
           Batch CM9-10 (剩余命令)
                  ↓
           Batch CM11+ (管理命令)
```

---

## 4. 验收标准

1. 每批实现后运行 `mix test`，保持 **0 failures**
2. 每批完成后提交推送，标注 `Batch CM<N>: <commands>`
3. 命令命名遵循 Elixir 惯例：`command_name_command.ex`

---

## 附录 A：已移植命令（72个）

```
abandon, alias, backpack, bank, channel, checkskill, closed, color,
cut, detach, drink, eat, emote, enable, exercise, exert, fight,
finger, fill, flee, follow, get, give, help, hp, inventory, jiali,
jingzuo, learn, look, map, move, nick, note, option, perform,
prepare, put, quest, quest_ask, quit, recall, reply, respirate,
ride, save, say, score, sell, shop, skills, study, suicide,
surrender, team, tell, title, unride, version, whistle, who,
wield, wimpy, world_status
```

---

## 附录 B：未移植命令清单（按目录）

### std/ (约 74 个，~17 已移植)
```
ansuan, attack, beg, close, cook, daub, drive, drug,
guard, hide, kill, liuxi, make, open, pour, purchase,
push, search, secularize, sleep, steal, stun,
swear, train, tune, vote, wash, wear, wenxuan, ...
```

### usr/ (约 65 个，~35 已移植)
```
area, assist, auction, baitan, beep, brothers, buy, describe,
divorce, engage, feed, finger, hatred, idle, jifen, league,
miss, mobile, mudinfo, mudlist, news, passwd, pkd, quest2,
record, rideto, scheme, score2, set, shop, skip, summon,
suicide, system, tianshu, time, title, top, top2, topp, ...
```

### skill/ (约 39 个，~21 已移植)
```
berserk, breakup, burning, combine, derive, fuse,
imbue, jingxiu, persaude, pique, recruit, research, san,
spattack, syn, yanlian, animaout, crattack, enchase, ...
```

### adm/arch/wiz/ (约 107 个)
（低优先级，P2/P3）

### chat/imm/ (约 15 个)
（部分已移植，部分需框架支持）

---

## 附录 C：已实现命令详细

| 命令 | 模块 | 状态 | 说明 |
|------|------|------|------|
| drop | ItemCommand | ✅ | 丢弃物品（含 all，数量支持） |
| get | ItemCommand | ✅ | 捡东西（含 all，从容器获取） |
| put | ItemCommand | ✅ | 放东西到容器 |
| fill | FillCommand | ✅ | 装填液体 |
| abandon | AbandonCommand | ✅ | 放弃技能/经验 |
| wear/remove/unwield | WieldCommand | ✅ | 装备/脱装备命令 |
| wield | WieldCommand | ✅ | 装备武器 |
| ride/unride | RideCommand | ✅ | 骑乘/下骑 |
