# F4 招式迁移 · A 组（按目录字母顺序，283 个文件）

> 本文件由 `scripts/perf_acceptance.py` 的基线报告生成，供一个独立 session 执行。
> 另一半见另一份 .md；两半按完整路径字母顺序对半切分，互不重叠。

## 目标

把本组每个 `performs/<skill>/<move>.ex` 的**代码部分（不含注释）**改到与对应 LPC 源
`C:/files/git/mud/kungfu/skill/<lpc-rel>.c` 的**代码部分（不含注释）**中的中文文案**逐条字面一致**。

> **判据不模糊（2026-10-12 决策）**：不做「语义等价/同义改写」的宽松判定。
> `.c` 里怎么写，`.ex` 就怎么写：`难以施展`≠`无法施展`、`修为不够`≠`不够娴熟`、`真气不够`≠`真气不足`。
> 名字插在字符串中间时（如 `"…手中" + weapon->name() + "，发出…"`），
> `.ex` 必须**同样拆段**（`"…手中" <> weapon_name <> "，发出…"`），不得合并成单字面量；
> 中文弯引号 `“”‘’` 按 `.c` 原样保留。

具体包括（LPC → Elixir）：

1. **门槛文案**逐条对齐（notify_fail 的中文串；含 LPC 宏如 `#define GUA "「劈卦八卦拳」"` 内联后的完整文案）。
2. **战斗/命中/伤害/影响**分支的中文文案逐条对齐（message_combatd / do_damage 的 msg）。
3. 缺失的 `resolve_incoming/4` 分支、`Performs.feedback(...)` 消耗/忙乱、`Combat.start_busy`、
   `Vitals.damage` 等按 LPC 逻辑补齐（详见每文件末尾「原始 LPC 源码」注释块）。
4. **保留**文件末尾 `# ===== 原始 LPC 源码 =====` 注释块（禁止删改）。
5. 通过后把该文件**追加**到 `scripts/protected_performs.txt`；每完成一个**顶层目录**提交一次。

## 验收方式（硬性）

```
cd C:/files/git/wuxia_mud_ex
python scripts/perf_acceptance.py bagua_quan/gua.ex              # 单个
python scripts/perf_acceptance.py --json scripts/f4-plan-A-rel.json   # 批量
```
工具打印 `PASS` 或 `FAIL` + 每条 `- MISSING:`（.c 有而 .ex 缺的中文文案）
与 `+ EXTRA:`（.ex 多出来的，仅提示不判失败）。**本组每个文件必须 PASS 才算完成。**

## 编译校验（不需连游戏）

```
docker exec wuxia_mud_dev-app-1 sh -c "cd /app && mix compile"
```
**注意**：app 容器是 `mix phx.server`，跑测试须用
`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test app mix test ...`。
全部改完后统一在游戏里测试（本 job 内不做）。

## 清单

> `miss` = 基线缺失中文文案条数（0 = 已通过，确认后登记保护即可）。

### `bagua_quan/` （1 个，基线缺失 5 条）

- [x] ✅ `bagua_quan/gua.ex` ← `bagua-quan/gua.c`  (miss=5→0，PASS)

### `bagua_zhang/` （2 个，基线缺失 18 条）

- [x] ✅ `bagua_zhang/ding.ex` ← `bagua-zhang/ding.c`  (miss=7→0，PASS)
- [x] ✅ `bagua_zhang/jia.ex` ← `bagua-zhang/jia.c`  (miss=11→0，PASS)

### `bahuang_gong/` （2 个，基线缺失 8 条）

- [x] ✅ `bahuang_gong/powerup.ex` ← `bahuang-gong/powerup.c`  (miss=4→0，PASS)
- [x] ✅ `bahuang_gong/shield.ex` ← `bahuang-gong/shield.c`  (miss=4→0，PASS)

### `baihua_cuoquan/` （3 个，基线缺失 20 条）

- [x] ✅ `baihua_cuoquan/hong.ex` ← `baihua-cuoquan/hong.c`  (miss=9→0，PASS；ap improve + 即死分支)
- [x] ✅ `baihua_cuoquan/luan.ex` ← `baihua-cuoquan/luan.c`  (miss→0，PASS)
- [x] ✅ `baihua_cuoquan/yi.ex` ← `baihua-cuoquan/yi.c`  (miss→0，PASS)

### `baihua_quan/` （1 个，基线缺失 4 条）

- [x] ✅ `baihua_quan/cuo.ex` ← `baihua-quan/cuo.c`  (miss→0，PASS)

### `baisheng_quan/` （1 个，基线缺失 10 条）

- [x] ✅ `baisheng_quan/kai.ex` ← `baisheng-quan/kai.c`  (miss→0，PASS)

### `bazhen_zhang/` （1 个，基线缺失 7 条）

- [x] ✅ `bazhen_zhang/yin.ex` ← `bazhen-zhang/yin.c`  (miss→0，PASS)

### `beiming_shengong/` （3 个，基线缺失 23 条）

- [x] ✅ `beiming_shengong/powerup.ex` ← `beiming-shengong/powerup.c`  (miss→0，PASS)
- [x] ✅ `beiming_shengong/shield.ex` ← `beiming-shengong/shield.c`  (miss→0，PASS)
- [x] ✅ `beiming_shengong/suck.ex` ← `beiming-shengong/suck.c`  (miss→0，PASS；1 条 .c 乱码字节例外)

### `benlei_zhang/` （1 个，基线缺失 6 条）

- [x] ✅ `benlei_zhang/lei.ex` ← `benlei-zhang/lei.c`  (miss→0，PASS)

### `bibo_shengong/` （1 个，基线缺失 4 条）

- [x] ✅ `bibo_shengong/powerup.ex` ← `bibo-shengong/powerup.c`  (miss→0，PASS)

### `biluo_zhang/` （1 个，基线缺失 8 条）

- [x] ✅ `biluo_zhang/lian.ex` ← `biluo-zhang/lian.c`  (miss→0，PASS)

### `bingxin_jue/` （2 个，基线缺失 8 条）

- [x] ✅ `bingxin_jue/freeze.ex` ← `bingxin-jue/freeze.c`  (miss→0，PASS)
- [x] ✅ `bingxin_jue/powerup.ex` ← `bingxin-jue/powerup.c`  (miss→0，PASS)

### `biyan_dao/` （1 个，基线缺失 7 条）

- [x] ✅ `biyan_dao/luo.ex` ← `biyan-dao/luo.c`  (miss→0，PASS)

### `biyun_xinfa/` （1 个，基线缺失 5 条）

- [x] ✅ `biyun_xinfa/powerup.ex` ← `biyun-xinfa/powerup.c`  (miss→0，PASS)

### `bluesea_force/` （9 个，基线缺失 14 条）

- [ ] ❌ `bluesea_force/bo.ex` ← `bluesea-force/bo.c`  (miss=1)
- [x] ✅ `bluesea_force/jue.ex` ← `bluesea-force/jue.c`  (miss=0)
- [x] ✅ `bluesea_force/lu.ex` ← `bluesea-force/lu.c`  (miss=0)
- [ ] ❌ `bluesea_force/mie.ex` ← `bluesea-force/mie.c`  (miss=2)
- [ ] ❌ `bluesea_force/powerup.ex` ← `bluesea-force/powerup.c`  (miss=4)
- [ ] ❌ `bluesea_force/shield.ex` ← `bluesea-force/shield.c`  (miss=4)
- [ ] ❌ `bluesea_force/xuan.ex` ← `bluesea-force/xuan.c`  (miss=3)
- [x] ✅ `bluesea_force/zhan.ex` ← `bluesea-force/zhan.c`  (miss=0)
- [x] ✅ `bluesea_force/zhu.ex` ← `bluesea-force/zhu.c`  (miss=0)

### `canglang_zhi/` （1 个，基线缺失 7 条）

- [ ] ❌ `canglang_zhi/tao.ex` ← `canglang-zhi/tao.c`  (miss=7)

### `canhe_zhi/` （4 个，基线缺失 32 条）

- [ ] ❌ `canhe_zhi/canhe.ex` ← `canhe-zhi/canhe.c`  (miss=14)
- [ ] ❌ `canhe_zhi/jin.ex` ← `canhe-zhi/jin.c`  (miss=7)
- [ ] ❌ `canhe_zhi/you.ex` ← `canhe-zhi/you.c`  (miss=6)
- [ ] ❌ `canhe_zhi/zhi.ex` ← `canhe-zhi/zhi.c`  (miss=5)

### `changsheng_jue/` （2 个，基线缺失 8 条）

- [ ] ❌ `changsheng_jue/powerup.ex` ← `changsheng-jue/powerup.c`  (miss=4)
- [ ] ❌ `changsheng_jue/shield.ex` ← `changsheng-jue/shield.c`  (miss=4)

### `chansi_shou/` （1 个，基线缺失 7 条）

- [ ] ❌ `chansi_shou/qin.ex` ← `chansi-shou/qin.c`  (miss=7)

### `chilian_shenzhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `chilian_shenzhang/lian.ex` ← `chilian-shenzhang/lian.c`  (miss=7)

### `chongtian_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `chongtian_zhang/zhan.ex` ← `chongtian-zhang/zhan.c`  (miss=6)

### `chongyang_shenzhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `chongyang_shenzhang/lian.ex` ← `chongyang-shenzhang/lian.c`  (miss=6)

### `chousui_zhang/` （2 个，基线缺失 22 条）

- [ ] ❌ `chousui_zhang/shi.ex` ← `chousui-zhang/shi.c`  (miss=14)
- [ ] ❌ `chousui_zhang/tao.ex` ← `chousui-zhang/tao.c`  (miss=8)

### `chuncan_zhang/` （1 个，基线缺失 8 条）

- [ ] ❌ `chuncan_zhang/jian.ex` ← `chuncan-zhang/jian.c`  (miss=8)

### `cuixin_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `cuixin_zhang/cui.ex` ← `cuixin-zhang/cui.c`  (miss=7)

### `dabei_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `dabei_zhang/bei.ex` ← `dabei-zhang/bei.c`  (miss=7)

### `dacidabei_shou/` （1 个，基线缺失 5 条）

- [ ] ❌ `dacidabei_shou/yin.ex` ← `dacidabei-shou/yin.c`  (miss=5)

### `dahai_wuliang/` （1 个，基线缺失 4 条）

- [ ] ❌ `dahai_wuliang/powerup.ex` ← `dahai-wuliang/powerup.c`  (miss=4)

### `damo_jian/` （3 个，基线缺失 24 条）

- [ ] ❌ `damo_jian/luan.ex` ← `damo-jian/luan.c`  (miss=8)
- [ ] ❌ `damo_jian/shang.ex` ← `damo-jian/shang.c`  (miss=8)
- [ ] ❌ `damo_jian/zhe.ex` ← `damo-jian/zhe.c`  (miss=8)

### `daojian_guizhen/` （1 个，基线缺失 11 条）

- [ ] ❌ `daojian_guizhen/xue.ex` ← `daojian-guizhen/xue.c`  (miss=11)

### `dashou_yin/` （1 个，基线缺失 5 条）

- [ ] ❌ `dashou_yin/yin.ex` ← `dashou-yin/yin.c`  (miss=5)

### `dongyang_dao/` （1 个，基线缺失 3 条）

- [ ] ❌ `dongyang_dao/luan.ex` ← `dongyang-dao/luan.c`  (miss=3)

### `douzhuan_xingyi/` （1 个，基线缺失 7 条）

- [ ] ❌ `douzhuan_xingyi/yi.ex` ← `douzhuan-xingyi/yi.c`  (miss=7)

### `dragon_strike/` （4 个，基线缺失 41 条）

- [ ] ❌ `dragon_strike/hui.ex` ← `dragon-strike/hui.c`  (miss=17)
- [ ] ❌ `dragon_strike/lei.ex` ← `dragon-strike/lei.c`  (miss=9)
- [ ] ❌ `dragon_strike/qin.ex` ← `dragon-strike/qin.c`  (miss=14)
- [ ] ❌ `dragon_strike/xiang.ex` ← `dragon-strike/xiang.c`  (miss=1)

### `duanjia_sword/` （1 个，基线缺失 3 条）

- [ ] ❌ `duanjia_sword/jue.ex` ← `duanjia-sword/jue.c`  (miss=3)

### `duanshi_xinfa/` （1 个，基线缺失 4 条）

- [ ] ❌ `duanshi_xinfa/powerup.ex` ← `duanshi-xinfa/powerup.c`  (miss=4)

### `dugu_jiujian/` （2 个，基线缺失 24 条）

- [ ] ❌ `dugu_jiujian/jue.ex` ← `dugu-jiujian/jue.c`  (miss=11)
- [ ] ❌ `dugu_jiujian/po.ex` ← `dugu-jiujian/po.c`  (miss=13)

### `dulong_shenzhua/` （2 个，基线缺失 13 条）

- [ ] ❌ `dulong_shenzhua/bao.ex` ← `dulong-shenzhua/bao.c`  (miss=7)
- [ ] ❌ `dulong_shenzhua/ju.ex` ← `dulong-shenzhua/ju.c`  (miss=6)

### `feifeng_bian/` （1 个，基线缺失 7 条）

- [ ] ❌ `feifeng_bian/xi.ex` ← `feifeng-bian/xi.c`  (miss=7)

### `feihua_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `feihua_zhang/fei.ex` ← `feihua-zhang/fei.c`  (miss=7)

### `fengmo_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `fengmo_zhang/luan.ex` ← `fengmo-zhang/luan.c`  (miss=7)

### `fenxin_jue/` （1 个，基线缺失 4 条）

- [ ] ❌ `fenxin_jue/powerup.ex` ← `fenxin-jue/powerup.c`  (miss=4)

### `five_avoid/` （1 个，基线缺失 4 条）

- [ ] ❌ `five_avoid/break.ex` ← `five-avoid/break.c`  (miss=4)

### `force/` （10 个，基线缺失 126 条）

- [ ] ❌ `force/dispel.ex` ← `force/dispel.c`  (miss=30)
- [ ] ❌ `force/heal.ex` ← `force/heal.c`  (miss=19)
- [ ] ❌ `force/inspire.ex` ← `force/inspire.c`  (miss=19)
- [ ] ❌ `force/lifeheal.ex` ← `force/lifeheal.c`  (miss=10)
- [ ] ❌ `force/recover.ex` ← `force/recover.c`  (miss=3)
- [ ] ❌ `force/regenerate.ex` ← `force/regenerate.c`  (miss=4)
- [ ] ❌ `force/roar.ex` ← `force/roar.c`  (miss=14)
- [ ] ❌ `force/shot.ex` ← `force/shot.c`  (miss=14)
- [ ] ❌ `force/tianmo.ex` ← `force/tianmo.c`  (miss=6)
- [ ] ❌ `force/xun.ex` ← `force/xun.c`  (miss=7)

### `freezing_force/` （1 个，基线缺失 4 条）

- [ ] ❌ `freezing_force/powerup.ex` ← `freezing-force/powerup.c`  (miss=4)

### `fushang_neigong/` （1 个，基线缺失 4 条）

- [ ] ❌ `fushang_neigong/powerup.ex` ← `fushang-neigong/powerup.c`  (miss=4)

### `guanri_jian/` （2 个，基线缺失 20 条）

- [ ] ❌ `guanri_jian/fen.ex` ← `guanri-jian/fen.c`  (miss=9)
- [ ] ❌ `guanri_jian/guan.ex` ← `guanri-jian/guan.c`  (miss=11)

### `guhong_zhang/` （1 个，基线缺失 8 条）

- [ ] ❌ `guhong_zhang/qian.ex` ← `guhong-zhang/qian.c`  (miss=8)

### `gun/` （1 个，基线缺失 5 条）

- [ ] ❌ `gun/she.ex` ← `gun/she.c`  (miss=5)

### `guzhuo_zhang/` （3 个，基线缺失 23 条）

- [ ] ❌ `guzhuo_zhang/yu.ex` ← `guzhuo-zhang/yu.c`  (miss=7)
- [ ] ❌ `guzhuo_zhang/zhen.ex` ← `guzhuo-zhang/zhen.c`  (miss=8)
- [ ] ❌ `guzhuo_zhang/zhuo.ex` ← `guzhuo-zhang/zhuo.c`  (miss=8)

### `hamagong/` （6 个，基线缺失 32 条）

- [ ] ❌ `hamagong/hui.ex` ← `hamagong/hui.c`  (miss=1)
- [ ] ❌ `hamagong/powerup.ex` ← `hamagong/powerup.c`  (miss=4)
- [ ] ❌ `hamagong/reserve.ex` ← `hamagong/reserve.c`  (miss=1)
- [ ] ❌ `hamagong/tan.ex` ← `hamagong/tan.c`  (miss=12)
- [ ] ❌ `hamagong/tui.ex` ← `hamagong/tui.c`  (miss=5)
- [ ] ❌ `hamagong/zhen.ex` ← `hamagong/zhen.c`  (miss=9)

### `hanbing_mianzhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `hanbing_mianzhang/jue.ex` ← `hanbing-mianzhang/jue.c`  (miss=6)

### `hanbing_zhang/` （2 个，基线缺失 11 条）

- [ ] ❌ `hanbing_zhang/han.ex` ← `hanbing-zhang/han.c`  (miss=5)
- [ ] ❌ `hanbing_zhang/hen.ex` ← `hanbing-zhang/hen.c`  (miss=6)

### `hanbing_zhenqi/` （2 个，基线缺失 14 条）

- [ ] ❌ `hanbing_zhenqi/freezing.ex` ← `hanbing-zhenqi/freezing.c`  (miss=10)
- [ ] ❌ `hanbing_zhenqi/powerup.ex` ← `hanbing-zhenqi/powerup.c`  (miss=4)

### `haotian_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `haotian_zhang/ju.ex` ← `haotian-zhang/ju.c`  (miss=7)

### `heisha_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `heisha_zhang/cui.ex` ← `heisha-zhang/cui.c`  (miss=6)

### `henshan_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `henshan_quan/lan.ex` ← `henshan-quan/lan.c`  (miss=6)

### `honglian_dao/` （1 个，基线缺失 8 条）

- [ ] ❌ `honglian_dao/huo.ex` ← `honglian-dao/huo.c`  (miss=8)

### `hongye_daofa/` （1 个，基线缺失 4 条）

- [ ] ❌ `hongye_daofa/kuang.ex` ← `hongye-daofa/kuang.c`  (miss=4)

### `hua_quan/` （1 个，基线缺失 7 条）

- [ ] ❌ `hua_quan/juan.ex` ← `hua-quan/juan.c`  (miss=7)

### `huagong_dafa/` （2 个，基线缺失 12 条）

- [ ] ❌ `huagong_dafa/hua.ex` ← `huagong-dafa/hua.c`  (miss=8)
- [ ] ❌ `huagong_dafa/powerup.ex` ← `huagong-dafa/powerup.c`  (miss=4)

### `huagu_mianzhang/` （1 个，基线缺失 1 条）

- [ ] ❌ `huagu_mianzhang/hua.ex` ← `huagu-mianzhang/hua.c`  (miss=1)

### `huanyin_zhi/` （1 个，基线缺失 3 条）

- [ ] ❌ `huanyin_zhi/huanyin.ex` ← `huanyin-zhi/huanyin.c`  (miss=3)

### `huashan_quan/` （1 个，基线缺失 3 条）

- [ ] ❌ `huashan_quan/song.ex` ← `huashan-quan/song.c`  (miss=3)

### `huashan_zhang/` （1 个，基线缺失 4 条）

- [ ] ❌ `huashan_zhang/piao.ex` ← `huashan-zhang/piao.c`  (miss=4)

### `huilong_zhang/` （1 个，基线缺失 1 条）

- [ ] ❌ `huilong_zhang/baiwei.ex` ← `huilong-zhang/baiwei.c`  (miss=1)

### `hujia_daofa/` （1 个，基线缺失 9 条）

- [ ] ❌ `hujia_daofa/cang.ex` ← `hujia-daofa/cang.c`  (miss=9)

### `hujia_quan/` （1 个，基线缺失 7 条）

- [ ] ❌ `hujia_quan/kuai.ex` ← `hujia-quan/kuai.c`  (miss=7)

### `huntian_baojian/` （2 个，基线缺失 13 条）

- [ ] ❌ `huntian_baojian/powerup.ex` ← `huntian-baojian/powerup.c`  (miss=9)
- [ ] ❌ `huntian_baojian/sword.ex` ← `huntian-baojian/sword.c`  (miss=4)

### `huntian_qigong/` （2 个，基线缺失 8 条）

- [ ] ❌ `huntian_qigong/powerup.ex` ← `huntian-qigong/powerup.c`  (miss=4)
- [ ] ❌ `huntian_qigong/shield.ex` ← `huntian-qigong/shield.c`  (miss=4)

### `hunyuan_yiqi/` （1 个，基线缺失 4 条）

- [ ] ❌ `hunyuan_yiqi/powerup.ex` ← `hunyuan-yiqi/powerup.c`  (miss=4)

### `hunyuan_zhang/` （1 个，基线缺失 5 条）

- [ ] ❌ `hunyuan_zhang/wuji.ex` ← `hunyuan-zhang/wuji.c`  (miss=5)

### `huoyan_dao/` （1 个，基线缺失 7 条）

- [ ] ❌ `huoyan_dao/yan.ex` ← `huoyan-dao/yan.c`  (miss=7)

### `huzhua_shou/` （1 个，基线缺失 7 条）

- [ ] ❌ `huzhua_shou/juehu.ex` ← `huzhua-shou/juehu.c`  (miss=7)

### `jiasha_fumogong/` （1 个，基线缺失 6 条）

- [ ] ❌ `jiasha_fumogong/zhe.ex` ← `jiasha-fumogong/zhe.c`  (miss=6)

### `jiechen_dao/` （1 个，基线缺失 3 条）

- [ ] ❌ `jiechen_dao/xiuluo.ex` ← `jiechen-dao/xiuluo.c`  (miss=3)

### `jieshou_jiushi/` （1 个，基线缺失 6 条）

- [ ] ❌ `jieshou_jiushi/jie.ex` ← `jieshou-jiushi/jie.c`  (miss=6)

### `jifeng_cixuefa/` （1 个，基线缺失 8 条）

- [ ] ❌ `jifeng_cixuefa/cang.ex` ← `jifeng-cixuefa/cang.c`  (miss=8)

### `jinding_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `jinding_zhang/bashi.ex` ← `jinding-zhang/bashi.c`  (miss=7)

### `jingang_zhi/` （1 个，基线缺失 30 条）

- [ ] ❌ `jingang_zhi/san.ex` ← `jingang-zhi/san.c`  (miss=30)

### `jingzhong_bafa/` （1 个，基线缺失 3 条）

- [ ] ❌ `jingzhong_bafa/bafa.ex` ← `jingzhong-bafa/bafa.c`  (miss=3)

### `jinshe_jian/` （2 个，基线缺失 18 条）

- [ ] ❌ `jinshe_jian/kun.ex` ← `jinshe-jian/kun.c`  (miss=8)
- [ ] ❌ `jinshe_jian/shi.ex` ← `jinshe-jian/shi.c`  (miss=10)

### `jinshe_zhang/` （1 个，基线缺失 1 条）

- [ ] ❌ `jinshe_zhang/fugu.ex` ← `jinshe-zhang/fugu.c`  (miss=1)

### `jinshe_zhui/` （1 个，基线缺失 6 条）

- [ ] ❌ `jinshe_zhui/feng.ex` ← `jinshe-zhui/feng.c`  (miss=6)

### `jinwu_daofa/` （1 个，基线缺失 9 条）

- [ ] ❌ `jinwu_daofa/chi.ex` ← `jinwu-daofa/chi.c`  (miss=9)

### `jinwu_goufa/` （1 个，基线缺失 13 条）

- [ ] ❌ `jinwu_goufa/duo.ex` ← `jinwu-goufa/duo.c`  (miss=13)

### `jinyu_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `jinyu_quan/man.ex` ← `jinyu-quan/man.c`  (miss=6)

### `jinyuan_gun/` （1 个，基线缺失 7 条）

- [ ] ❌ `jinyuan_gun/qian.ex` ← `jinyuan-gun/qian.c`  (miss=7)

### `jiuyang_shengong/` （8 个，基线缺失 70 条）

- [ ] ❌ `jiuyang_shengong/hun.ex` ← `jiuyang-shengong/hun.c`  (miss=6)
- [ ] ❌ `jiuyang_shengong/jiu.ex` ← `jiuyang-shengong/jiu.c`  (miss=8)
- [ ] ❌ `jiuyang_shengong/pi.ex` ← `jiuyang-shengong/pi.c`  (miss=11)
- [ ] ❌ `jiuyang_shengong/po.ex` ← `jiuyang-shengong/po.c`  (miss=11)
- [ ] ❌ `jiuyang_shengong/powerup.ex` ← `jiuyang-shengong/powerup.c`  (miss=4)
- [ ] ❌ `jiuyang_shengong/ri.ex` ← `jiuyang-shengong/ri.c`  (miss=23)
- [ ] ❌ `jiuyang_shengong/roar.ex` ← `jiuyang-shengong/roar.c`  (miss=3)
- [ ] ❌ `jiuyang_shengong/shield.ex` ← `jiuyang-shengong/shield.c`  (miss=4)

### `jiuyin_baiguzhao/` （2 个，基线缺失 16 条）

- [ ] ❌ `jiuyin_baiguzhao/duo.ex` ← `jiuyin-baiguzhao/duo.c`  (miss=9)
- [ ] ❌ `jiuyin_baiguzhao/zhua.ex` ← `jiuyin-baiguzhao/zhua.c`  (miss=7)

### `jiuyin_shengong/` （10 个，基线缺失 54 条）

- [ ] ❌ `jiuyin_shengong/powerup.ex` ← `jiuyin-shengong/powerup.c`  (miss=4)
- [ ] ❌ `jiuyin_shengong/quan.ex` ← `jiuyin-shengong/quan.c`  (miss=4)
- [ ] ❌ `jiuyin_shengong/roar.ex` ← `jiuyin-shengong/roar.c`  (miss=3)
- [ ] ❌ `jiuyin_shengong/shield.ex` ← `jiuyin-shengong/shield.c`  (miss=4)
- [ ] ❌ `jiuyin_shengong/shou.ex` ← `jiuyin-shengong/shou.c`  (miss=4)
- [ ] ❌ `jiuyin_shengong/xin.ex` ← `jiuyin-shengong/xin.c`  (miss=7)
- [ ] ❌ `jiuyin_shengong/zhang.ex` ← `jiuyin-shengong/zhang.c`  (miss=3)
- [ ] ❌ `jiuyin_shengong/zhen.ex` ← `jiuyin-shengong/zhen.c`  (miss=6)
- [ ] ❌ `jiuyin_shengong/zhi.ex` ← `jiuyin-shengong/zhi.c`  (miss=11)
- [ ] ❌ `jiuyin_shengong/zhua.ex` ← `jiuyin-shengong/zhua.c`  (miss=8)

### `jueming_tui/` （1 个，基线缺失 8 条）

- [ ] ❌ `jueming_tui/jue.ex` ← `jueming-tui/jue.c`  (miss=8)

### `jueqing_zhang/` （2 个，基线缺失 13 条）

- [ ] ❌ `jueqing_zhang/hun.ex` ← `jueqing-zhang/hun.c`  (miss=6)
- [ ] ❌ `jueqing_zhang/wan.ex` ← `jueqing-zhang/wan.c`  (miss=7)

### `kongming_quan/` （2 个，基线缺失 15 条）

- [ ] ❌ `kongming_quan/kong.ex` ← `kongming-quan/kong.c`  (miss=7)
- [ ] ❌ `kongming_quan/ruo.ex` ← `kongming-quan/ruo.c`  (miss=8)

### `kuangfeng_blade/` （1 个，基线缺失 1 条）

- [ ] ❌ `kuangfeng_blade/kuang.ex` ← `kuangfeng-blade/kuang.c`  (miss=1)

### `kuangfeng_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `kuangfeng_jian/yong.ex` ← `kuangfeng-jian/yong.c`  (miss=10)

### `kuihua_mogong/` （8 个，基线缺失 67 条）

- [ ] ❌ `kuihua_mogong/bian.ex` ← `kuihua-mogong/bian.c`  (miss=20)
- [ ] ❌ `kuihua_mogong/powerup.ex` ← `kuihua-mogong/powerup.c`  (miss=4)
- [ ] ❌ `kuihua_mogong/qiong.ex` ← `kuihua-mogong/qiong.c`  (miss=9)
- [ ] ❌ `kuihua_mogong/roar.ex` ← `kuihua-mogong/roar.c`  (miss=3)
- [ ] ❌ `kuihua_mogong/sheng.ex` ← `kuihua-mogong/sheng.c`  (miss=5)
- [ ] ❌ `kuihua_mogong/shield.ex` ← `kuihua-mogong/shield.c`  (miss=4)
- [ ] ❌ `kuihua_mogong/tian.ex` ← `kuihua-mogong/tian.c`  (miss=9)
- [ ] ❌ `kuihua_mogong/wswd.ex` ← `kuihua-mogong/wswd.c`  (miss=13)

### `kunlun_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `kunlun_jian/fanyin.ex` ← `kunlun-jian/fanyin.c`  (miss=10)

### `kunlun_zhang/` （1 个，基线缺失 8 条）

- [ ] ❌ `kunlun_zhang/kong.ex` ← `kunlun-zhang/kong.c`  (miss=8)

### `kurong_changong/` （1 个，基线缺失 7 条）

- [ ] ❌ `kurong_changong/powerup.ex` ← `kurong-changong/powerup.c`  (miss=7)

### `lanhua_shou/` （2 个，基线缺失 13 条）

- [ ] ❌ `lanhua_shou/fei.ex` ← `lanhua-shou/fei.c`  (miss=6)
- [ ] ❌ `lanhua_shou/fu.ex` ← `lanhua-shou/fu.c`  (miss=7)

### `lansha_shou/` （1 个，基线缺失 10 条）

- [ ] ❌ `lansha_shou/po.ex` ← `lansha-shou/po.c`  (miss=10)

### `leiming_bian/` （1 个，基线缺失 8 条）

- [ ] ❌ `leiming_bian/cibei.ex` ← `leiming-bian/cibei.c`  (miss=8)

### `leiting_fu/` （1 个，基线缺失 7 条）

- [ ] ❌ `leiting_fu/sanda.ex` ← `leiting-fu/sanda.c`  (miss=7)

### `lengyue_shengong/` （1 个，基线缺失 4 条）

- [ ] ❌ `lengyue_shengong/powerup.ex` ← `lengyue-shengong/powerup.c`  (miss=4)

### `liangyi_jian/` （1 个，基线缺失 9 条）

- [ ] ❌ `liangyi_jian/ren.ex` ← `liangyi-jian/ren.c`  (miss=9)

### `liangyi_shengong/` （1 个，基线缺失 4 条）

- [ ] ❌ `liangyi_shengong/powerup.ex` ← `liangyi-shengong/powerup.c`  (miss=4)

### `lianhuan_mizongtui/` （1 个，基线缺失 8 条）

- [ ] ❌ `lianhuan_mizongtui/lian.ex` ← `lianhuan-mizongtui/lian.c`  (miss=8)

### `lingshe_quan/` （1 个，基线缺失 1 条）

- [ ] ❌ `lingshe_quan/rou.ex` ← `lingshe-quan/rou.c`  (miss=1)

### `lingshe_zhangfa/` （3 个，基线缺失 14 条）

- [ ] ❌ `lingshe_zhangfa/qianshe.ex` ← `lingshe-zhangfa/qianshe.c`  (miss=5)
- [ ] ❌ `lingshe_zhangfa/wanshi.ex` ← `lingshe-zhangfa/wanshi.c`  (miss=5)
- [ ] ❌ `lingshe_zhangfa/wuji.ex` ← `lingshe-zhangfa/wuji.c`  (miss=4)

### `lingxiao_quan/` （2 个，基线缺失 15 条）

- [ ] ❌ `lingxiao_quan/jue.ex` ← `lingxiao-quan/jue.c`  (miss=7)
- [ ] ❌ `lingxiao_quan/san.ex` ← `lingxiao-quan/san.c`  (miss=8)

### `lingyuan_xinfa/` （1 个，基线缺失 7 条）

- [ ] ❌ `lingyuan_xinfa/break.ex` ← `lingyuan-xinfa/break.c`  (miss=7)

### `lingyun_jian/` （1 个，基线缺失 8 条）

- [ ] ❌ `lingyun_jian/xiao.ex` ← `lingyun-jian/xiao.c`  (miss=8)

### `linji_zhuang/` （1 个，基线缺失 10 条）

- [ ] ❌ `linji_zhuang/powerup.ex` ← `linji-zhuang/powerup.c`  (miss=10)

### `liuhe_bian/` （1 个，基线缺失 19 条）

- [ ] ❌ `liuhe_bian/lianhuan.ex` ← `liuhe-bian/lianhuan.c`  (miss=19)

### `liuhe_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `liuhe_zhang/tan.ex` ← `liuhe-zhang/tan.c`  (miss=7)

### `liumai_shenjian/` （3 个，基线缺失 35 条）

- [ ] ❌ `liumai_shenjian/qi.ex` ← `liumai-shenjian/qi.c`  (miss=13)
- [ ] ❌ `liumai_shenjian/six.ex` ← `liumai-shenjian/six.c`  (miss=6)
- [ ] ❌ `liumai_shenjian/zong.ex` ← `liumai-shenjian/zong.c`  (miss=16)

### `liuyang_zhang/` （3 个，基线缺失 22 条）

- [ ] ❌ `liuyang_zhang/huan.ex` ← `liuyang-zhang/huan.c`  (miss=6)
- [ ] ❌ `liuyang_zhang/po.ex` ← `liuyang-zhang/po.c`  (miss=10)
- [ ] ❌ `liuyang_zhang/zhong.ex` ← `liuyang-zhang/zhong.c`  (miss=6)

### `liuyue_jian/` （2 个，基线缺失 12 条）

- [ ] ❌ `liuyue_jian/liu.ex` ← `liuyue-jian/liu.c`  (miss=7)
- [ ] ❌ `liuyue_jian/sheng.ex` ← `liuyue-jian/sheng.c`  (miss=5)

### `liuyun_zhang/` （2 个，基线缺失 13 条）

- [ ] ❌ `liuyun_zhang/die.ex` ← `liuyun-zhang/die.c`  (miss=7)
- [ ] ❌ `liuyun_zhang/pai.ex` ← `liuyun-zhang/pai.c`  (miss=6)

### `lonely_sword/` （3 个，基线缺失 20 条）

- [ ] ❌ `lonely_sword/jue.ex` ← `lonely-sword/jue.c`  (miss=7)
- [ ] ❌ `lonely_sword/po.ex` ← `lonely-sword/po.c`  (miss=9)
- [ ] ❌ `lonely_sword/yi.ex` ← `lonely-sword/yi.c`  (miss=4)

### `longcheng_shendao/` （1 个，基线缺失 5 条）

- [ ] ❌ `longcheng_shendao/fengyu.ex` ← `longcheng-shendao/fengyu.c`  (miss=5)

### `longxiang/` （2 个，基线缺失 9 条）

- [ ] ❌ `longxiang/powerup.ex` ← `longxiang/powerup.c`  (miss=5)
- [ ] ❌ `longxiang/shield.ex` ← `longxiang/shield.c`  (miss=4)

### `longxiang_gong/` （6 个，基线缺失 53 条）

- [ ] ❌ `longxiang_gong/die.ex` ← `longxiang-gong/die.c`  (miss=11)
- [ ] ❌ `longxiang_gong/ji.ex` ← `longxiang-gong/ji.c`  (miss=10)
- [ ] ❌ `longxiang_gong/powerup.ex` ← `longxiang-gong/powerup.c`  (miss=6)
- [ ] ❌ `longxiang_gong/shield.ex` ← `longxiang-gong/shield.c`  (miss=6)
- [ ] ❌ `longxiang_gong/tun.ex` ← `longxiang-gong/tun.c`  (miss=9)
- [ ] ❌ `longxiang_gong/zhen.ex` ← `longxiang-gong/zhen.c`  (miss=11)

### `longzhua_gong/` （1 个，基线缺失 0 条）

- [x] ✅ `longzhua_gong/zhua.ex` ← `longzhua-gong/zhua.c`  (miss=0)

### `lunhui_jian/` （1 个，基线缺失 38 条）

- [ ] ❌ `lunhui_jian/hui.ex` ← `lunhui-jian/hui.c`  (miss=38)

### `luohan_fumogong/` （2 个，基线缺失 20 条）

- [ ] ❌ `luohan_fumogong/fireice.ex` ← `luohan-fumogong/fireice.c`  (miss=8)
- [ ] ❌ `luohan_fumogong/powerup.ex` ← `luohan-fumogong/powerup.c`  (miss=12)

### `luohan_gun/` （1 个，基线缺失 21 条）

- [ ] ❌ `luohan_gun/shibaluohan.ex` ← `luohan-gun/shibaluohan.c`  (miss=21)

### `luohan_jian/` （1 个，基线缺失 6 条）

- [ ] ❌ `luohan_jian/wuxing.ex` ← `luohan-jian/wuxing.c`  (miss=6)

### `luoyan_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `luoyan_jian/luo.ex` ← `luoyan-jian/luo.c`  (miss=7)

### `luoying_shenzhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `luoying_shenzhang/zhuan.ex` ← `luoying-shenzhang/zhuan.c`  (miss=7)

### `mantian_xing/` （1 个，基线缺失 17 条）

- [ ] ❌ `mantian_xing/xing.ex` ← `mantian-xing/xing.c`  (miss=17)

### `meinv_quan/` （1 个，基线缺失 7 条）

- [ ] ❌ `meinv_quan/you.ex` ← `meinv-quan/you.c`  (miss=7)

### `miaojia_jian/` （3 个，基线缺失 32 条）

- [ ] ❌ `miaojia_jian/gan.ex` ← `miaojia-jian/gan.c`  (miss=17)
- [ ] ❌ `miaojia_jian/zhai.ex` ← `miaojia-jian/zhai.c`  (miss=7)
- [ ] ❌ `miaojia_jian/zhu.ex` ← `miaojia-jian/zhu.c`  (miss=8)

### `miaojia_neigong/` （1 个，基线缺失 4 条）

- [ ] ❌ `miaojia_neigong/powerup.ex` ← `miaojia-neigong/powerup.c`  (miss=4)

### `miaojia_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `miaojia_zhang/dan.ex` ← `miaojia-zhang/dan.c`  (miss=7)

### `murong_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `murong_jian/xing.ex` ← `murong-jian/xing.c`  (miss=7)

### `murong_sword/` （1 个，基线缺失 2 条）

- [ ] ❌ `murong_sword/qixing.ex` ← `murong-sword/qixing.c`  (miss=2)

### `nei_bagua/` （1 个，基线缺失 4 条）

- [ ] ❌ `nei_bagua/powerup.ex` ← `nei-bagua/powerup.c`  (miss=4)

### `never_defeated/` （8 个，基线缺失 41 条）

- [ ] ❌ `never_defeated/juemie.ex` ← `never-defeated/juemie.c`  (miss=2)
- [ ] ❌ `never_defeated/lei.ex` ← `never-defeated/lei.c`  (miss=4)
- [ ] ❌ `never_defeated/po.ex` ← `never-defeated/po.c`  (miss=10)
- [ ] ❌ `never_defeated/powerup.ex` ← `never-defeated/powerup.c`  (miss=4)
- [ ] ❌ `never_defeated/shield.ex` ← `never-defeated/shield.c`  (miss=4)
- [ ] ❌ `never_defeated/tianhua.ex` ← `never-defeated/tianhua.c`  (miss=3)
- [ ] ❌ `never_defeated/wanli.ex` ← `never-defeated/wanli.c`  (miss=6)
- [ ] ❌ `never_defeated/yuce.ex` ← `never-defeated/yuce.c`  (miss=8)

### `ningxue_shenzhao/` （1 个，基线缺失 1 条）

- [ ] ❌ `ningxue_shenzhao/ji.ex` ← `ningxue-shenzhao/ji.c`  (miss=1)

### `pangu_qishi/` （1 个，基线缺失 7 条）

- [ ] ❌ `pangu_qishi/kai.ex` ← `pangu-qishi/kai.c`  (miss=7)

### `panlong_suo/` （1 个，基线缺失 8 条）

- [ ] ❌ `panlong_suo/sha.ex` ← `panlong-suo/sha.c`  (miss=8)

### `panlong_zhao/` （1 个，基线缺失 5 条）

- [ ] ❌ `panlong_zhao/tan.ex` ← `panlong-zhao/tan.c`  (miss=5)

### `panyang_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `panyang_zhang/pan.ex` ← `panyang-zhang/pan.c`  (miss=6)

### `piaofeng_quan/` （1 个，基线缺失 4 条）

- [ ] ❌ `piaofeng_quan/juan.ex` ← `piaofeng-quan/juan.c`  (miss=4)

### `piaoxu_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `piaoxu_zhang/piao.ex` ← `piaoxu-zhang/piao.c`  (miss=6)

### `piaoxue_zhang/` （2 个，基线缺失 14 条）

- [ ] ❌ `piaoxue_zhang/yun.ex` ← `piaoxue-zhang/yun.c`  (miss=6)
- [ ] ❌ `piaoxue_zhang/zhao.ex` ← `piaoxue-zhang/zhao.c`  (miss=8)

### `pikong_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `pikong_zhang/dai.ex` ← `pikong-zhang/dai.c`  (miss=7)

### `pili_quan/` （1 个，基线缺失 3 条）

- [ ] ❌ `pili_quan/jin.ex` ← `pili-quan/jin.c`  (miss=3)

### `pili_shou/` （1 个，基线缺失 5 条）

- [ ] ❌ `pili_shou/hun.ex` ← `pili-shou/hun.c`  (miss=5)

### `pixie_jian/` （4 个，基线缺失 49 条）

- [ ] ❌ `pixie_jian/duo.ex` ← `pixie-jian/duo.c`  (miss=12)
- [ ] ❌ `pixie_jian/gui.ex` ← `pixie-jian/gui.c`  (miss=4)
- [ ] ❌ `pixie_jian/pi.ex` ← `pixie-jian/pi.c`  (miss=14)
- [ ] ❌ `pixie_jian/po.ex` ← `pixie-jian/po.c`  (miss=19)

### `pobei_tui/` （1 个，基线缺失 7 条）

- [ ] ❌ `pobei_tui/kai.ex` ← `pobei-tui/kai.c`  (miss=7)

### `poguang_dao/` （1 个，基线缺失 7 条）

- [ ] ❌ `poguang_dao/yang.ex` ← `poguang-dao/yang.c`  (miss=7)

### `pokong_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `pokong_quan/kong.ex` ← `pokong-quan/kong.c`  (miss=6)

### `pomopima_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `pomopima_jian/zui.ex` ← `pomopima-jian/zui.c`  (miss=7)

### `poshui_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `poshui_zhang/tai.ex` ← `poshui-zhang/tai.c`  (miss=7)

### `poxu_daxuefa/` （1 个，基线缺失 18 条）

- [ ] ❌ `poxu_daxuefa/tong.ex` ← `poxu-daxuefa/tong.c`  (miss=18)

### `poyang_jian/` （2 个，基线缺失 21 条）

- [ ] ❌ `poyang_jian/long.ex` ← `poyang-jian/long.c`  (miss=13)
- [ ] ❌ `poyang_jian/xian.ex` ← `poyang-jian/xian.c`  (miss=8)

### `poyu_quan/` （3 个，基线缺失 12 条）

- [ ] ❌ `poyu_quan/feng.ex` ← `poyu-quan/feng.c`  (miss=4)
- [ ] ❌ `poyu_quan/lei.ex` ← `poyu-quan/lei.c`  (miss=4)
- [ ] ❌ `poyu_quan/po.ex` ← `poyu-quan/po.c`  (miss=4)

### `poyue_zhao/` （1 个，基线缺失 6 条）

- [ ] ❌ `poyue_zhao/duan.ex` ← `poyue-zhao/duan.c`  (miss=6)

### `pudu_zhang/` （1 个，基线缺失 3 条）

- [ ] ❌ `pudu_zhang/zhao.ex` ← `pudu-zhang/zhao.c`  (miss=3)

### `qiankun_danuoyi/` （1 个，基线缺失 5 条）

- [ ] ❌ `qiankun_danuoyi/nuoyi.ex` ← `qiankun-danuoyi/nuoyi.c`  (miss=5)

### `qiankun_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `qiankun_jian/ni.ex` ← `qiankun-jian/ni.c`  (miss=10)

### `qiantian_zhi/` （1 个，基线缺失 7 条）

- [ ] ❌ `qiantian_zhi/zhi.ex` ← `qiantian-zhi/zhi.c`  (miss=7)

### `qianzhu_wandushou/` （3 个，基线缺失 20 条）

- [ ] ❌ `qianzhu_wandushou/suck.ex` ← `qianzhu-wandushou/suck.c`  (miss=15)
- [ ] ❌ `qianzhu_wandushou/wan.ex` ← `qianzhu-wandushou/wan.c`  (miss=1)
- [ ] ❌ `qianzhu_wandushou/zhugu.ex` ← `qianzhu-wandushou/zhugu.c`  (miss=4)

### `qingliang_daxuefa/` （1 个，基线缺失 8 条）

- [ ] ❌ `qingliang_daxuefa/ding.ex` ← `qingliang-daxuefa/ding.c`  (miss=8)

### `qingyun_bian/` （1 个，基线缺失 6 条）

- [ ] ❌ `qingyun_bian/duan.ex` ← `qingyun-bian/duan.c`  (miss=6)

### `qingyun_shou/` （1 个，基线缺失 6 条）

- [ ] ❌ `qingyun_shou/zhuo.ex` ← `qingyun-shou/zhuo.c`  (miss=6)

### `qishang_quan/` （1 个，基线缺失 5 条）

- [ ] ❌ `qishang_quan/fei.ex` ← `qishang-quan/fei.c`  (miss=5)

