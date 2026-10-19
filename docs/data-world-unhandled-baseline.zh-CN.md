# 未解析清单基线（P0.1）

> 本文件由 `scripts/tier_unhandled_manifest.py` 生成，请勿手改。
> 数字**只能降不能升**；回归断言见 `scripts/assert_unhandled_baseline.py`（P6）。

## 1. 基线数字

| 指标 | 值 |
|------|----|
| 记录总数 | 11095 |
| 函数记录 | 2136 |
| 条件分支记录 | 8525 |
| 函数名（distinct） | 643 |
| `UNHANDLED FUNCTION` 条数 / 名数 | 2136 / 643 |
| 分支归属函数数 | 442 |
| 函数 body 未回源 | 32 |
| 抑制清单条目 | 188 |

可排期清单：`tmp/unhandled_manifest_tiered.json`（在 manifest 每条记录上加了 `tier` / `subsystem` / `tier_reason`）。

### 按 kind

| kind | 条数 |
|------|-----:|
| `complex_if` | 135 |
| `complex_map` | 34 |
| `cond_branch` | 8525 |
| `function` | 2136 |
| `generic` | 63 |
| `raw` | 38 |
| `switch_pool` | 132 |
| `switch_stmt` | 27 |
| `switch_table` | 5 |

## 2. 分诊（Tier）

| Tier | 含义 | 条数 |
|:----:|------|-----:|
| 0 | 免除：lifecycle/query 回调、已实现的全局命令、或源无 body | 188 |
| 1 | 引擎已有全局命令，只缺逐对象 `add_action` 覆盖 | 1041 |
| 2 | 需新子系统 / 手工实现 | 9866 |

### 动作记录按动词分布（top 20）

`object_action:*` = Tier 1（可走逐对象通道）；`action_impl:*` = Tier 2（需新实现）。

| 动词 | 记录数 |
|------|-------:|
| `object_action:move` | 217 |
| `action_impl:think` | 163 |
| `object_action:jump` | 95 |
| `object_action:eat` | 84 |
| `object_action:du` | 73 |
| `object_action:open` | 71 |
| `object_action:canwu` | 65 |
| `object_action:push` | 64 |
| `object_action:tiao` | 55 |
| `action_impl:get` | 54 |
| `action_impl:bet` | 51 |
| `action_impl:order` | 51 |
| `action_impl:pick` | 47 |
| `object_action:enter` | 47 |
| `action_impl:undo` | 39 |
| `action_impl:jida` | 36 |
| `action_impl:mianbi` | 36 |
| `action_impl:new` | 36 |
| `action_impl:broadcast` | 33 |
| `action_impl:zou` | 33 |

### 按子系统（聚合）

| 子系统 | 条数 |
|--------|-----:|
| `other` | 2962 |
| `p1_p2_data_create` | 2690 |
| `action_impl` | 1551 |
| `object_action` | 1041 |
| `npc_actions` | 565 |
| `look_inquiry` | 512 |
| `veto_channel` | 481 |
| `combat` | 263 |
| `one_off_scene` | 189 |
| `item_food` | 164 |
| `door_container` | 162 |
| `lifecycle` | 156 |
| `movement` | 146 |
| `apprentice` | 121 |
| `no_body` | 32 |
| `dynamic_long_name` | 29 |
| `data_lifecycle` | 21 |
| `p1_p2_data_room` | 10 |

## 3. 未回源函数（32 条 → 全部抑制，0 条可归属）

命名变体（`ask_me1` ↔ `ask_me_1` 等）已在**本文件 + 继承链**内匹配；语料中仅有的同名定义属于**其它对象**，不可归属。

| id | 函数 | 对象 | 判定 | 定位 |
|----|------|------|------|------|
| `baituo:mangshe_dan#function#delete_benefit` | `delete_benefit` | `mangshe_dan` | 本文件内仅有被注释掉的实现 | L82 |
| `beijing:chenglaoban#function#ask_me1` | `ask_me1` | `chenglaoban` | 同名实现在其它对象中，无法归属 | `C:\files\git\mud\d\xiangyang\npc\wuxiuwen.c` |
| `beijing:chenglaoban#function#ask_me2` | `ask_me2` | `chenglaoban` | 同名实现在其它对象中，无法归属 | `C:\files\git\mud\d\xiangyang\npc\wuxiuwen.c` |
| `beijing:dubi#function#do_skills` | `do_skills` | `dubi` | 仅有前置声明，语料中无实现 | L6 |
| `beijing:shuanger#function#ask_kiss` | `ask_kiss` | `shuanger` | 仅有前置声明，语料中无实现 | L7 |
| `changan:qunyulou#function#check_container` | `check_container` | `qunyulou` | 仅有前置声明，语料中无实现 | L7 |
| `changan:yayi#function#drool` | `drool` | `yayi` | 同名实现在其它对象中，无法归属 | `C:\files\git\mud\d\city\npc\tao1.c` |
| `chengdu:tanghuai#function#redeem` | `redeem` | `tanghuai` | 仅有前置声明，语料中无实现 | L8 |
| `city:cch#function#do_display` | `do_display` | `cch` | 仅有前置声明，语料中无实现 | L398 |
| `city:eproom#function#look_rules` | `look_rules` | `eproom` | 仅有前置声明，语料中无实现 | L7 |
| `city:horseboss#function#confirm_dispose` | `confirm_dispose` | `horseboss` | 仅有前置声明，语料中无实现 | L23 |
| `city:horseboss#function#get_type` | `get_type` | `horseboss` | 仅有前置声明，语料中无实现 | L14 |
| `city:nproom#function#look_rules` | `look_rules` | `nproom` | 仅有前置声明，语料中无实现 | L7 |
| `city:sproom#function#look_rules` | `look_rules` | `sproom` | 仅有前置声明，语料中无实现 | L7 |
| `city:tang#function#redeem` | `redeem` | `tang` | 仅有前置声明，语料中无实现 | L6 |
| `city:wproom#function#look_rules` | `look_rules` | `wproom` | 仅有前置声明，语料中无实现 | L7 |
| `foshan:chaofeng#function#redeem` | `redeem` | `chaofeng` | 仅有前置声明，语料中无实现 | L8 |
| `guanwai:famu#function#coagent` | `coagent` | `famu` | 本文件内仅有被注释掉的实现 | L403 |
| `guanwai:famu#function#end_working` | `end_working` | `famu` | 本文件内仅有被注释掉的实现 | L207 |
| `guanwai:famu#function#start_work` | `start_work` | `famu` | 本文件内仅有被注释掉的实现 | L153 |
| `kunming:liu#function#redeem` | `redeem` | `liu` | 仅有前置声明，语料中无实现 | L6 |
| `lingxiao:laoban#function#redeem` | `redeem` | `laoban` | 仅有前置声明，语料中无实现 | L6 |
| `luoyang:qi#function#redeem` | `redeem` | `qi` | 仅有前置声明，语料中无实现 | L6 |
| `motianya:dingdang#function#inquiry_yu` | `inquiry_yu` | `dingdang` | 仅有前置声明，语料中无实现 | L4 |
| `shaolin:miao#function#ask_hujia_book` | `ask_hujia_book` | `miao` | 仅有前置声明，语料中无实现 | L9 |
| `shenlong:chuanfu#function#goto_dao` | `goto_dao` | `chuanfu` | 仅有前置声明，语料中无实现 | L5 |
| `shenlong:zhang3#function#do_skills` | `do_skills` | `zhang3` | 仅有前置声明，语料中无实现 | L8 |
| `taohua:chuanfu#function#goto_dao` | `goto_dao` | `chuanfu` | 仅有前置声明，语料中无实现 | L7 |
| `test:capture#function#ask_3_for_2` | `ask_3_for_2` | `capture` | 仅有前置声明，语料中无实现 | L23 |
| `xiakedao:renter#function#hire` | `hire` | `renter` | 仅有前置声明，语料中无实现 | L12 |
| `xiangyang:laoxiansheng#function#ask_degree` | `ask_degree` | `laoxiansheng` | 仅有前置声明，语料中无实现 | L7 |
| `zhongzhou:zhousongtian#function#redeem` | `redeem` | `zhousongtian` | 仅有前置声明，语料中无实现 | L6 |

## 4. 抑制清单

文件：`scripts/unhandled_suppressions.json`（schema：`{id, tier:"noop", reason, ...}`）。

| 判定 | 条数 |
|------|-----:|
| `noop_commented_out` | 4 |
| `noop_other_object` | 3 |
| `noop_prototype_only` | 25 |

## 5. 复现

```bash
python scripts/build_unhandled_manifest.py
python scripts/resolve_unhandled_variants.py
python scripts/tier_unhandled_manifest.py
```

两条 P0.1 脚本均只写 `tmp/` / `docs/` / `scripts/unhandled_suppressions.json`，不触碰 `data/world`，可重复运行且结果字节一致。
