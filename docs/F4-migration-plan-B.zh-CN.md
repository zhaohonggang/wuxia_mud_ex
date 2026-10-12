# F4 招式迁移 · B 组（按目录字母顺序，283 个文件）

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
python scripts/perf_acceptance.py --json scripts/f4-plan-B-rel.json   # 批量
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

### `qishang_quan/` （1 个，基线缺失 5 条）

- [x] ✅ `qishang_quan/shang.ex` ← `qishang-quan/shang.c`  (miss=5)

### `qishi_ji/` （1 个，基线缺失 7 条）

- [ ] ❌ `qishi_ji/chong.ex` ← `qishi-ji/chong.c`  (miss=7)

### `quanzhen_jian/` （2 个，基线缺失 18 条）

- [ ] ❌ `quanzhen_jian/hua.ex` ← `quanzhen-jian/hua.c`  (miss=10)
- [ ] ❌ `quanzhen_jian/lian.ex` ← `quanzhen-jian/lian.c`  (miss=8)

### `quemen_jian/` （1 个，基线缺失 8 条）

- [ ] ❌ `quemen_jian/can.ex` ← `quemen-jian/can.c`  (miss=8)

### `qufannao_zhi/` （1 个，基线缺失 3 条）

- [ ] ❌ `qufannao_zhi/lingkong.ex` ← `qufannao-zhi/lingkong.c`  (miss=3)

### `qujing_gunfa/` （1 个，基线缺失 11 条）

- [ ] ❌ `qujing_gunfa/zhen.ex` ← `qujing-gunfa/zhen.c`  (miss=11)

### `ranmu_daofa/` （1 个，基线缺失 2 条）

- [ ] ❌ `ranmu_daofa/huo.ex` ← `ranmu-daofa/huo.c`  (miss=2)

### `riyue_lun/` （2 个，基线缺失 22 条）

- [ ] ❌ `riyue_lun/lian.ex` ← `riyue-lun/lian.c`  (miss=12)
- [ ] ❌ `riyue_lun/po.ex` ← `riyue-lun/po.c`  (miss=10)

### `rouyun_jian/` （1 个，基线缺失 5 条）

- [ ] ❌ `rouyun_jian/tao.ex` ← `rouyun-jian/tao.c`  (miss=5)

### `ruanhong_zhusuo/` （3 个，基线缺失 21 条）

- [ ] ❌ `ruanhong_zhusuo/bohu.ex` ← `ruanhong-zhusuo/bohu.c`  (miss=9)
- [ ] ❌ `ruanhong_zhusuo/pan.ex` ← `ruanhong-zhusuo/pan.c`  (miss=5)
- [ ] ❌ `ruanhong_zhusuo/suo.ex` ← `ruanhong-zhusuo/suo.c`  (miss=7)

### `rulai_zhang/` （1 个，基线缺失 8 条）

- [ ] ❌ `rulai_zhang/zong.ex` ← `rulai-zhang/zong.c`  (miss=8)

### `ruyi_dao/` （1 个，基线缺失 5 条）

- [ ] ❌ `ruyi_dao/ruyi.ex` ← `ruyi-dao/ruyi.c`  (miss=5)

### `ruying_suixingtui/` （1 个，基线缺失 11 条）

- [ ] ❌ `ruying_suixingtui/ruying.ex` ← `ruying-suixingtui/ruying.c`  (miss=11)

### `sad_strike/` （2 个，基线缺失 16 条）

- [ ] ❌ `sad_strike/tuo.ex` ← `sad-strike/tuo.c`  (miss=10)
- [ ] ❌ `sad_strike/xiao.ex` ← `sad-strike/xiao.c`  (miss=6)

### `sanfen_jianshu/` （1 个，基线缺失 5 条）

- [ ] ❌ `sanfen_jianshu/haishi.ex` ← `sanfen-jianshu/haishi.c`  (miss=5)

### `sanku_shengong/` （3 个，基线缺失 25 条）

- [ ] ❌ `sanku_shengong/dispel.ex` ← `sanku-shengong/dispel.c`  (miss=15)
- [ ] ❌ `sanku_shengong/powerup.ex` ← `sanku-shengong/powerup.c`  (miss=5)
- [ ] ❌ `sanku_shengong/roar.ex` ← `sanku-shengong/roar.c`  (miss=5)

### `sanwu_shou/` （2 个，基线缺失 17 条）

- [ ] ❌ `sanwu_shou/kong.ex` ← `sanwu-shou/kong.c`  (miss=9)
- [ ] ❌ `sanwu_shou/zhi.ex` ← `sanwu-shou/zhi.c`  (miss=8)

### `sanyin_shou/` （1 个，基线缺失 5 条）

- [ ] ❌ `sanyin_shou/sun.ex` ← `sanyin-shou/sun.c`  (miss=5)

### `sanyin_wugongzhao/` （1 个，基线缺失 5 条）

- [ ] ❌ `sanyin_wugongzhao/zhua.ex` ← `sanyin-wugongzhao/zhua.c`  (miss=5)

### `shangqing_jian/` （2 个，基线缺失 18 条）

- [ ] ❌ `shangqing_jian/qing.ex` ← `shangqing-jian/qing.c`  (miss=11)
- [ ] ❌ `shangqing_jian/zhuo.ex` ← `shangqing-jian/zhuo.c`  (miss=7)

### `shedao_qigong/` （6 个，基线缺失 32 条）

- [ ] ❌ `shedao_qigong/chang1.ex` ← `shedao-qigong/chang1.c`  (miss=2)
- [ ] ❌ `shedao_qigong/chang2.ex` ← `shedao-qigong/chang2.c`  (miss=2)
- [ ] ❌ `shedao_qigong/chang3.ex` ← `shedao-qigong/chang3.c`  (miss=4)
- [ ] ❌ `shedao_qigong/cui.ex` ← `shedao-qigong/cui.c`  (miss=9)
- [ ] ❌ `shedao_qigong/fei.ex` ← `shedao-qigong/fei.c`  (miss=7)
- [ ] ❌ `shedao_qigong/xian.ex` ← `shedao-qigong/xian.c`  (miss=8)

### `shedu_qiqiao/` （2 个，基线缺失 29 条）

- [ ] ❌ `shedu_qiqiao/da.ex` ← `shedu-qiqiao/da.c`  (miss=16)
- [ ] ❌ `shedu_qiqiao/liandu.ex` ← `shedu-qiqiao/liandu.c`  (miss=13)

### `shenghuo_ling/` （4 个，基线缺失 36 条）

- [ ] ❌ `shenghuo_ling/can.ex` ← `shenghuo-ling/can.c`  (miss=10)
- [ ] ❌ `shenghuo_ling/hua.ex` ← `shenghuo-ling/hua.c`  (miss=7)
- [ ] ❌ `shenghuo_ling/lian.ex` ← `shenghuo-ling/lian.c`  (miss=8)
- [ ] ❌ `shenghuo_ling/xi.ex` ← `shenghuo-ling/xi.c`  (miss=11)

### `shenghuo_shengong/` （2 个，基线缺失 8 条）

- [ ] ❌ `shenghuo_shengong/powerup.ex` ← `shenghuo-shengong/powerup.c`  (miss=4)
- [ ] ❌ `shenghuo_shengong/shield.ex` ← `shenghuo-shengong/shield.c`  (miss=4)

### `shenghuo_xinfa/` （1 个，基线缺失 4 条）

- [ ] ❌ `shenghuo_xinfa/powerup.ex` ← `shenghuo-xinfa/powerup.c`  (miss=4)

### `shenlong_bashi/` （1 个，基线缺失 1 条）

- [ ] ❌ `shenlong_bashi/xian.ex` ← `shenlong-bashi/xian.c`  (miss=1)

### `shenlong_xinfa/` （1 个，基线缺失 4 条）

- [ ] ❌ `shenlong_xinfa/powerup.ex` ← `shenlong-xinfa/powerup.c`  (miss=4)

### `shenmen_jian/` （1 个，基线缺失 11 条）

- [ ] ❌ `shenmen_jian/ci.ex` ← `shenmen-jian/ci.c`  (miss=11)

### `shenzhang_bada/` （1 个，基线缺失 1 条）

- [ ] ❌ `shenzhang_bada/bafang.ex` ← `shenzhang-bada/bafang.c`  (miss=1)

### `shenzhaojing/` （4 个，基线缺失 23 条）

- [ ] ❌ `shenzhaojing/powerup.ex` ← `shenzhaojing/powerup.c`  (miss=4)
- [ ] ❌ `shenzhaojing/shield.ex` ← `shenzhaojing/shield.c`  (miss=4)
- [ ] ❌ `shenzhaojing/wu.ex` ← `shenzhaojing/wu.c`  (miss=8)
- [ ] ❌ `shenzhaojing/ying.ex` ← `shenzhaojing/ying.c`  (miss=7)

### `shexing_lifan/` （1 个，基线缺失 3 条）

- [ ] ❌ `shexing_lifan/guiyuan.ex` ← `shexing-lifan/guiyuan.c`  (miss=3)

### `shigu_bifa/` （2 个，基线缺失 14 条）

- [ ] ❌ `shigu_bifa/feng.ex` ← `shigu-bifa/feng.c`  (miss=7)
- [ ] ❌ `shigu_bifa/shiyi.ex` ← `shigu-bifa/shiyi.c`  (miss=7)

### `shilin_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `shilin_jian/luo.ex` ← `shilin-jian/luo.c`  (miss=7)

### `shiying_lianhuan/` （1 个，基线缺失 8 条）

- [ ] ❌ `shiying_lianhuan/sha.ex` ← `shiying-lianhuan/sha.c`  (miss=8)

### `shou_yin/` （1 个，基线缺失 1 条）

- [ ] ❌ `shou_yin/jie.ex` ← `shou-yin/jie.c`  (miss=1)

### `six_finger/` （4 个，基线缺失 37 条）

- [ ] ❌ `six_finger/qi.ex` ← `six-finger/qi.c`  (miss=14)
- [ ] ❌ `six_finger/six.ex` ← `six-finger/six.c`  (miss=6)
- [ ] ❌ `six_finger/zong.ex` ← `six-finger/zong.c`  (miss=16)
- [ ] ❌ `six_finger/zongheng.ex` ← `six-finger/zongheng.c`  (miss=1)

### `sixiang_bufa/` （1 个，基线缺失 8 条）

- [ ] ❌ `sixiang_bufa/fei.ex` ← `sixiang-bufa/fei.c`  (miss=8)

### `sixiang_zhang/` （1 个，基线缺失 5 条）

- [ ] ❌ `sixiang_zhang/xing.ex` ← `sixiang-zhang/xing.c`  (miss=5)

### `songshan_quan/` （1 个，基线缺失 5 条）

- [ ] ❌ `songshan_quan/chui.ex` ← `songshan-quan/chui.c`  (miss=5)

### `songshan_zhang/` （1 个，基线缺失 5 条）

- [ ] ❌ `songshan_zhang/po.ex` ← `songshan-zhang/po.c`  (miss=5)

### `songyang_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `songyang_zhang/ying.ex` ← `songyang-zhang/ying.c`  (miss=6)

### `sougu_yingzhua/` （2 个，基线缺失 8 条）

- [ ] ❌ `sougu_yingzhua/xue.ex` ← `sougu-yingzhua/xue.c`  (miss=6)
- [ ] ❌ `sougu_yingzhua/ying.ex` ← `sougu-yingzhua/ying.c`  (miss=2)

### `sun_finger/` （2 个，基线缺失 9 条）

- [ ] ❌ `sun_finger/heal.ex` ← `sun-finger/heal.c`  (miss=9)
- [x] ✅ `sun_finger/qiankun.ex` ← `sun-finger/qiankun.c`  (miss=0)

### `suohou_gong/` （1 个，基线缺失 10 条）

- [ ] ❌ `suohou_gong/suo.ex` ← `suohou-gong/suo.c`  (miss=10)

### `surge_force/` （2 个，基线缺失 7 条）

- [ ] ❌ `surge_force/powerup.ex` ← `surge-force/powerup.c`  (miss=4)
- [ ] ❌ `surge_force/roar.ex` ← `surge-force/roar.c`  (miss=3)

### `suxin_jian/` （1 个，基线缺失 1 条）

- [ ] ❌ `suxin_jian/he.ex` ← `suxin-jian/he.c`  (miss=1)

### `taiji_jian/` （2 个，基线缺失 17 条）

- [ ] ❌ `taiji_jian/jia.ex` ← `taiji-jian/jia.c`  (miss=11)
- [ ] ❌ `taiji_jian/zhenwu.ex` ← `taiji-jian/zhenwu.c`  (miss=6)

### `taiji_quan/` （5 个，基线缺失 40 条）

- [ ] ❌ `taiji_quan/ji.ex` ← `taiji-quan/ji.c`  (miss=5)
- [ ] ❌ `taiji_quan/tu.ex` ← `taiji-quan/tu.c`  (miss=19)
- [ ] ❌ `taiji_quan/yin.ex` ← `taiji-quan/yin.c`  (miss=5)
- [ ] ❌ `taiji_quan/zhan.ex` ← `taiji-quan/zhan.c`  (miss=5)
- [ ] ❌ `taiji_quan/zhen.ex` ← `taiji-quan/zhen.c`  (miss=6)

### `taiji_shengong/` （3 个，基线缺失 20 条）

- [ ] ❌ `taiji_shengong/dian.ex` ← `taiji-shengong/dian.c`  (miss=12)
- [ ] ❌ `taiji_shengong/powerup.ex` ← `taiji-shengong/powerup.c`  (miss=4)
- [ ] ❌ `taiji_shengong/shield.ex` ← `taiji-shengong/shield.c`  (miss=4)

### `taixuan_gong/` （6 个，基线缺失 72 条）

- [ ] ❌ `taixuan_gong/hun.ex` ← `taixuan-gong/hun.c`  (miss=7)
- [ ] ❌ `taixuan_gong/jing.ex` ← `taixuan-gong/jing.c`  (miss=25)
- [ ] ❌ `taixuan_gong/po.ex` ← `taixuan-gong/po.c`  (miss=22)
- [ ] ❌ `taixuan_gong/powerup.ex` ← `taixuan-gong/powerup.c`  (miss=4)
- [ ] ❌ `taixuan_gong/shield.ex` ← `taixuan-gong/shield.c`  (miss=4)
- [ ] ❌ `taixuan_gong/xuan.ex` ← `taixuan-gong/xuan.c`  (miss=10)

### `tan_tui/` （1 个，基线缺失 6 条）

- [ ] ❌ `tan_tui/wang.ex` ← `tan-tui/wang.c`  (miss=6)

### `tangmen_throwing/` （3 个，基线缺失 51 条）

- [ ] ❌ `tangmen_throwing/hua.ex` ← `tangmen-throwing/hua.c`  (miss=15)
- [ ] ❌ `tangmen_throwing/qian.ex` ← `tangmen-throwing/qian.c`  (miss=19)
- [ ] ❌ `tangmen_throwing/san.ex` ← `tangmen-throwing/san.c`  (miss=17)

### `tanzhi_shentong/` （4 个，基线缺失 39 条）

- [ ] ❌ `tanzhi_shentong/ding.ex` ← `tanzhi-shentong/ding.c`  (miss=11)
- [ ] ❌ `tanzhi_shentong/po.ex` ← `tanzhi-shentong/po.c`  (miss=13)
- [ ] ❌ `tanzhi_shentong/xiao.ex` ← `tanzhi-shentong/xiao.c`  (miss=7)
- [ ] ❌ `tanzhi_shentong/zhuan.ex` ← `tanzhi-shentong/zhuan.c`  (miss=8)

### `tianchan_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `tianchan_zhang/chan.ex` ← `tianchan-zhang/chan.c`  (miss=7)

### `tianchang_zhang/` （1 个，基线缺失 0 条）

- [x] ✅ `tianchang_zhang/huang.ex` ← `tianchang-zhang/huang.c`  (miss=0)

### `tiangang_chenfa/` （1 个，基线缺失 9 条）

- [ ] ❌ `tiangang_chenfa/bai.ex` ← `tiangang-chenfa/bai.c`  (miss=9)

### `tianhuan_shenjue/` （1 个，基线缺失 4 条）

- [ ] ❌ `tianhuan_shenjue/powerup.ex` ← `tianhuan-shenjue/powerup.c`  (miss=4)

### `tianjue_dao/` （1 个，基线缺失 9 条）

- [ ] ❌ `tianjue_dao/suo.ex` ← `tianjue-dao/suo.c`  (miss=9)

### `tianlei_dao/` （2 个，基线缺失 16 条）

- [ ] ❌ `tianlei_dao/shan.ex` ← `tianlei-dao/shan.c`  (miss=9)
- [ ] ❌ `tianlei_dao/zha.ex` ← `tianlei-dao/zha.c`  (miss=7)

### `tianlei_shengong/` （1 个，基线缺失 4 条）

- [ ] ❌ `tianlei_shengong/powerup.ex` ← `tianlei-shengong/powerup.c`  (miss=4)

### `tianlong_jian/` （1 个，基线缺失 14 条）

- [ ] ❌ `tianlong_jian/zhui.ex` ← `tianlong-jian/zhui.c`  (miss=14)

### `tianluo_diwang/` （1 个，基线缺失 6 条）

- [ ] ❌ `tianluo_diwang/wang.ex` ← `tianluo-diwang/wang.c`  (miss=6)

### `tianshan_zhang/` （2 个，基线缺失 7 条）

- [ ] ❌ `tianshan_zhang/fugu.ex` ← `tianshan-zhang/fugu.c`  (miss=5)
- [ ] ❌ `tianshan_zhang/xue.ex` ← `tianshan-zhang/xue.c`  (miss=2)

### `tianyu_qijian/` （3 个，基线缺失 18 条）

- [ ] ❌ `tianyu_qijian/huan.ex` ← `tianyu-qijian/huan.c`  (miss=5)
- [ ] ❌ `tianyu_qijian/ju.ex` ← `tianyu-qijian/ju.c`  (miss=7)
- [ ] ❌ `tianyu_qijian/shan.ex` ← `tianyu-qijian/shan.c`  (miss=6)

### `tianzhu_jian/` （1 个，基线缺失 13 条）

- [ ] ❌ `tianzhu_jian/suo.ex` ← `tianzhu-jian/suo.c`  (miss=13)

### `tie_zhang/` （5 个，基线缺失 44 条）

- [ ] ❌ `tie_zhang/dao.ex` ← `tie-zhang/dao.c`  (miss=10)
- [ ] ❌ `tie_zhang/juesha.ex` ← `tie-zhang/juesha.c`  (miss=5)
- [ ] ❌ `tie_zhang/lei.ex` ← `tie-zhang/lei.c`  (miss=9)
- [ ] ❌ `tie_zhang/long.ex` ← `tie-zhang/long.c`  (miss=10)
- [ ] ❌ `tie_zhang/yin.ex` ← `tie-zhang/yin.c`  (miss=10)

### `tiexian_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `tiexian_quan/tui.ex` ← `tiexian-quan/tui.c`  (miss=6)

### `tiexue_dao/` （1 个，基线缺失 7 条）

- [ ] ❌ `tiexue_dao/xue.ex` ← `tiexue-dao/xue.c`  (miss=7)

### `tongbi_zhang/` （1 个，基线缺失 5 条）

- [ ] ❌ `tongbi_zhang/chu.ex` ← `tongbi-zhang/chu.c`  (miss=5)

### `tongchui_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `tongchui_zhang/kai.ex` ← `tongchui-zhang/kai.c`  (miss=7)

### `tonggui_jian/` （1 个，基线缺失 26 条）

- [ ] ❌ `tonggui_jian/fen.ex` ← `tonggui-jian/fen.c`  (miss=26)

### `tougu_zhen/` （1 个，基线缺失 6 条）

- [ ] ❌ `tougu_zhen/feng.ex` ← `tougu-zhen/feng.c`  (miss=6)

### `wai_bagua/` （1 个，基线缺失 5 条）

- [ ] ❌ `wai_bagua/zhen.ex` ← `wai-bagua/zhen.c`  (miss=5)

### `weituo_chu/` （1 个，基线缺失 11 条）

- [ ] ❌ `weituo_chu/jishi.ex` ← `weituo-chu/jishi.c`  (miss=11)

### `weituo_gun/` （1 个，基线缺失 4 条）

- [ ] ❌ `weituo_gun/fumo.ex` ← `weituo-gun/fumo.c`  (miss=4)

### `woshi_zhang/` （1 个，基线缺失 1 条）

- [ ] ❌ `woshi_zhang/po.ex` ← `woshi-zhang/po.c`  (miss=1)

### `wuchang_zhang/` （1 个，基线缺失 3 条）

- [ ] ❌ `wuchang_zhang/wuchang.ex` ← `wuchang-zhang/wuchang.c`  (miss=3)

### `wudoumi_shengong/` （2 个，基线缺失 13 条）

- [ ] ❌ `wudoumi_shengong/gui.ex` ← `wudoumi-shengong/gui.c`  (miss=9)
- [ ] ❌ `wudoumi_shengong/powerup.ex` ← `wudoumi-shengong/powerup.c`  (miss=4)

### `wudu_shenzhang/` （2 个，基线缺失 14 条）

- [ ] ❌ `wudu_shenzhang/huan.ex` ← `wudu-shenzhang/huan.c`  (miss=7)
- [ ] ❌ `wudu_shenzhang/shi.ex` ← `wudu-shenzhang/shi.c`  (miss=7)

### `wuhu_duanmendao/` （1 个，基线缺失 4 条）

- [ ] ❌ `wuhu_duanmendao/duan.ex` ← `wuhu-duanmendao/duan.c`  (miss=4)

### `wuliang_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `wuliang_jian/qian.ex` ← `wuliang-jian/qian.c`  (miss=7)

### `wuluo_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `wuluo_zhang/bian.ex` ← `wuluo-zhang/bian.c`  (miss=6)

### `wushen_jian/` （3 个，基线缺失 25 条）

- [ ] ❌ `wushen_jian/hui.ex` ← `wushen-jian/hui.c`  (miss=8)
- [ ] ❌ `wushen_jian/qian.ex` ← `wushen-jian/qian.c`  (miss=7)
- [ ] ❌ `wushen_jian/shen.ex` ← `wushen-jian/shen.c`  (miss=10)

### `wusheng_zhao/` （1 个，基线缺失 5 条）

- [ ] ❌ `wusheng_zhao/lian.ex` ← `wusheng-zhao/lian.c`  (miss=5)

### `wuwang_shengong/` （1 个，基线缺失 4 条）

- [ ] ❌ `wuwang_shengong/powerup.ex` ← `wuwang-shengong/powerup.c`  (miss=4)

### `wuxiang_zhi/` （1 个，基线缺失 1 条）

- [ ] ❌ `wuxiang_zhi/wuse.ex` ← `wuxiang-zhi/wuse.c`  (miss=1)

### `wuzhan_mei/` （1 个，基线缺失 7 条）

- [ ] ❌ `wuzhan_mei/liu.ex` ← `wuzhan-mei/liu.c`  (miss=7)

### `xianglong_zhang/` （4 个，基线缺失 43 条）

- [ ] ❌ `xianglong_zhang/fei.ex` ← `xianglong-zhang/fei.c`  (miss=8)
- [ ] ❌ `xianglong_zhang/hui.ex` ← `xianglong-zhang/hui.c`  (miss=12)
- [ ] ❌ `xianglong_zhang/qu.ex` ← `xianglong-zhang/qu.c`  (miss=14)
- [ ] ❌ `xianglong_zhang/zhen.ex` ← `xianglong-zhang/zhen.c`  (miss=9)

### `xiangmo_chu/` （1 个，基线缺失 7 条）

- [ ] ❌ `xiangmo_chu/zhen.ex` ← `xiangmo-chu/zhen.c`  (miss=7)

### `xiantian_gong/` （7 个，基线缺失 51 条）

- [ ] ❌ `xiantian_gong/dang.ex` ← `xiantian-gong/dang.c`  (miss=14)
- [ ] ❌ `xiantian_gong/fen.ex` ← `xiantian-gong/fen.c`  (miss=8)
- [ ] ❌ `xiantian_gong/hun.ex` ← `xiantian-gong/hun.c`  (miss=8)
- [ ] ❌ `xiantian_gong/hup.ex` ← `xiantian-gong/hup.c`  (miss=4)
- [ ] ❌ `xiantian_gong/jian.ex` ← `xiantian-gong/jian.c`  (miss=11)
- [ ] ❌ `xiantian_gong/powerup.ex` ← `xiantian-gong/powerup.c`  (miss=4)
- [ ] ❌ `xiantian_gong/shield.ex` ← `xiantian-gong/shield.c`  (miss=2)

### `xiaoli_feidao/` （1 个，基线缺失 3 条）

- [ ] ❌ `xiaoli_feidao/fei.ex` ← `xiaoli-feidao/fei.c`  (miss=3)

### `xiaowuxiang/` （2 个，基线缺失 8 条）

- [ ] ❌ `xiaowuxiang/powerup.ex` ← `xiaowuxiang/powerup.c`  (miss=4)
- [ ] ❌ `xiaowuxiang/shield.ex` ← `xiaowuxiang/shield.c`  (miss=4)

### `xiaoyao_jian/` （3 个，基线缺失 26 条）

- [ ] ❌ `xiaoyao_jian/fei.ex` ← `xiaoyao-jian/fei.c`  (miss=10)
- [ ] ❌ `xiaoyao_jian/kuai.ex` ← `xiaoyao-jian/kuai.c`  (miss=6)
- [ ] ❌ `xiaoyao_jian/qi.ex` ← `xiaoyao-jian/qi.c`  (miss=10)

### `xiaoyaoyou/` （1 个，基线缺失 4 条）

- [ ] ❌ `xiaoyaoyou/xian.ex` ← `xiaoyaoyou/xian.c`  (miss=4)

### `xiewei_bian/` （1 个，基线缺失 7 条）

- [ ] ❌ `xiewei_bian/teng.ex` ← `xiewei-bian/teng.c`  (miss=7)

### `xiuluo_dao/` （1 个，基线缺失 3 条）

- [ ] ❌ `xiuluo_dao/suoming.ex` ← `xiuluo-dao/suoming.c`  (miss=3)

### `xiuluo_yinshagong/` （2 个，基线缺失 17 条）

- [ ] ❌ `xiuluo_yinshagong/powerup.ex` ← `xiuluo-yinshagong/powerup.c`  (miss=4)
- [ ] ❌ `xiuluo_yinshagong/suck.ex` ← `xiuluo-yinshagong/suck.c`  (miss=13)

### `xiuluo_zhi/` （1 个，基线缺失 0 条）

- [x] ✅ `xiuluo_zhi/jueming.ex` ← `xiuluo-zhi/jueming.c`  (miss=0)

### `xixing_dafa/` （3 个，基线缺失 23 条）

- [ ] ❌ `xixing_dafa/powerup.ex` ← `xixing-dafa/powerup.c`  (miss=4)
- [ ] ❌ `xixing_dafa/sangong.ex` ← `xixing-dafa/sangong.c`  (miss=2)
- [ ] ❌ `xixing_dafa/suck.ex` ← `xixing-dafa/suck.c`  (miss=17)

### `xiyang_jian/` （1 个，基线缺失 1 条）

- [ ] ❌ `xiyang_jian/lian.ex` ← `xiyang-jian/lian.c`  (miss=1)

### `xiyang_neigong/` （1 个，基线缺失 4 条）

- [ ] ❌ `xiyang_neigong/powerup.ex` ← `xiyang-neigong/powerup.c`  (miss=4)

### `xuanfeng_leg/` （1 个，基线缺失 1 条）

- [ ] ❌ `xuanfeng_leg/kuangfeng.ex` ← `xuanfeng-leg/kuangfeng.c`  (miss=1)

### `xuanfeng_tui/` （1 个，基线缺失 7 条）

- [ ] ❌ `xuanfeng_tui/kuang.ex` ← `xuanfeng-tui/kuang.c`  (miss=7)

### `xuangong_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `xuangong_quan/xuan.ex` ← `xuangong-quan/xuan.c`  (miss=6)

### `xuanmen_neigong/` （1 个，基线缺失 4 条）

- [ ] ❌ `xuanmen_neigong/powerup.ex` ← `xuanmen-neigong/powerup.c`  (miss=4)

### `xuanming_shengong/` （2 个，基线缺失 8 条）

- [ ] ❌ `xuanming_shengong/powerup.ex` ← `xuanming-shengong/powerup.c`  (miss=4)
- [ ] ❌ `xuanming_shengong/shield.ex` ← `xuanming-shengong/shield.c`  (miss=4)

### `xuanming_zhang/` （4 个，基线缺失 40 条）

- [ ] ❌ `xuanming_zhang/lang.ex` ← `xuanming-zhang/lang.c`  (miss=12)
- [ ] ❌ `xuanming_zhang/xing.ex` ← `xuanming-zhang/xing.c`  (miss=12)
- [ ] ❌ `xuanming_zhang/ying.ex` ← `xuanming-zhang/ying.c`  (miss=7)
- [ ] ❌ `xuanming_zhang/zhe.ex` ← `xuanming-zhang/zhe.c`  (miss=9)

### `xuantian_wujigong/` （2 个，基线缺失 8 条）

- [ ] ❌ `xuantian_wujigong/powerup.ex` ← `xuantian-wujigong/powerup.c`  (miss=4)
- [ ] ❌ `xuantian_wujigong/shield.ex` ← `xuantian-wujigong/shield.c`  (miss=4)

### `xuantian_zhi/` （1 个，基线缺失 7 条）

- [ ] ❌ `xuantian_zhi/bing.ex` ← `xuantian-zhi/bing.c`  (miss=7)

### `xuantie_jian/` （3 个，基线缺失 27 条）

- [ ] ❌ `xuantie_jian/dong.ex` ← `xuantie-jian/dong.c`  (miss=15)
- [ ] ❌ `xuantie_jian/juan.ex` ← `xuantie-jian/juan.c`  (miss=7)
- [ ] ❌ `xuantie_jian/xunlei.ex` ← `xuantie-jian/xunlei.c`  (miss=5)

### `xuanxu_dao/` （1 个，基线缺失 5 条）

- [ ] ❌ `xuanxu_dao/huan.ex` ← `xuanxu-dao/huan.c`  (miss=5)

### `xuanyuan_arrow/` （1 个，基线缺失 7 条）

- [ ] ❌ `xuanyuan_arrow/baibu.ex` ← `xuanyuan-arrow/baibu.c`  (miss=7)

### `xue_dao/` （3 个，基线缺失 9 条）

- [ ] ❌ `xue_dao/huan.ex` ← `xue-dao/huan.c`  (miss=2)
- [ ] ❌ `xue_dao/shendao.ex` ← `xue-dao/shendao.c`  (miss=5)
- [ ] ❌ `xue_dao/xueyu.ex` ← `xue-dao/xueyu.c`  (miss=2)

### `xuedao_dafa/` （6 个，基线缺失 50 条）

- [ ] ❌ `xuedao_dafa/chi.ex` ← `xuedao-dafa/chi.c`  (miss=9)
- [ ] ❌ `xuedao_dafa/powerup.ex` ← `xuedao-dafa/powerup.c`  (miss=6)
- [ ] ❌ `xuedao_dafa/resurrect.ex` ← `xuedao-dafa/resurrect.c`  (miss=5)
- [ ] ❌ `xuedao_dafa/shi.ex` ← `xuedao-dafa/shi.c`  (miss=13)
- [ ] ❌ `xuedao_dafa/xue.ex` ← `xuedao-dafa/xue.c`  (miss=7)
- [ ] ❌ `xuedao_dafa/ying.ex` ← `xuedao-dafa/ying.c`  (miss=10)

### `xuehai_mogong/` （1 个，基线缺失 4 条）

- [ ] ❌ `xuehai_mogong/powerup.ex` ← `xuehai-mogong/powerup.c`  (miss=4)

### `xueshan_dao/` （1 个，基线缺失 7 条）

- [ ] ❌ `xueshan_dao/kai.ex` ← `xueshan-dao/kai.c`  (miss=7)

### `xueshan_jian/` （3 个，基线缺失 21 条）

- [ ] ❌ `xueshan_jian/chu.ex` ← `xueshan-jian/chu.c`  (miss=8)
- [ ] ❌ `xueshan_jian/feng.ex` ← `xueshan-jian/feng.c`  (miss=7)
- [ ] ❌ `xueshan_jian/hui.ex` ← `xueshan-jian/hui.c`  (miss=6)

### `xumishan_zhang/` （1 个，基线缺失 1 条）

- [ ] ❌ `xumishan_zhang/ying.ex` ← `xumishan-zhang/ying.c`  (miss=1)

### `xunlei_jian/` （1 个，基线缺失 6 条）

- [ ] ❌ `xunlei_jian/xun.ex` ← `xunlei-jian/xun.c`  (miss=6)

### `yanxing_dao/` （1 个，基线缺失 5 条）

- [ ] ❌ `yanxing_dao/huan.ex` ← `yanxing-dao/huan.c`  (miss=5)

### `yecha_gun/` （1 个，基线缺失 3 条）

- [ ] ❌ `yecha_gun/hongxia.ex` ← `yecha-gun/hongxia.c`  (miss=3)

### `yijin_duangu/` （2 个，基线缺失 7 条）

- [ ] ❌ `yijin_duangu/powerup.ex` ← `yijin-duangu/powerup.c`  (miss=4)
- [ ] ❌ `yijin_duangu/shield.ex` ← `yijin-duangu/shield.c`  (miss=3)

### `yijinjing/` （2 个，基线缺失 8 条）

- [ ] ❌ `yijinjing/powerup.ex` ← `yijinjing/powerup.c`  (miss=4)
- [ ] ❌ `yijinjing/tong.ex` ← `yijinjing/tong.c`  (miss=4)

### `yinfeng_dao/` （1 个，基线缺失 6 条）

- [ ] ❌ `yinfeng_dao/jue.ex` ← `yinfeng-dao/jue.c`  (miss=6)

### `yingzhua_gong/` （1 个，基线缺失 0 条）

- [x] ✅ `yingzhua_gong/chumo.ex` ← `yingzhua-gong/chumo.c`  (miss=0)

### `yinhu_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `yinhu_zhang/lao.ex` ← `yinhu-zhang/lao.c`  (miss=7)

### `yinlong_bian/` （1 个，基线缺失 7 条）

- [ ] ❌ `yinlong_bian/zhu.ex` ← `yinlong-bian/zhu.c`  (miss=7)

### `yinsuo_jinling/` （3 个，基线缺失 35 条）

- [ ] ❌ `yinsuo_jinling/dian.ex` ← `yinsuo-jinling/dian.c`  (miss=10)
- [ ] ❌ `yinsuo_jinling/feng.ex` ← `yinsuo-jinling/feng.c`  (miss=18)
- [ ] ❌ `yinsuo_jinling/kai.ex` ← `yinsuo-jinling/kai.c`  (miss=7)

### `yintuoluo_zhua/` （1 个，基线缺失 8 条）

- [ ] ❌ `yintuoluo_zhua/chixue.ex` ← `yintuoluo-zhua/chixue.c`  (miss=8)

### `yinyang_ren/` （3 个，基线缺失 28 条）

- [ ] ❌ `yinyang_ren/heng.ex` ← `yinyang-ren/heng.c`  (miss=12)
- [ ] ❌ `yinyang_ren/hua.ex` ← `yinyang-ren/hua.c`  (miss=8)
- [ ] ❌ `yinyang_ren/huan.ex` ← `yinyang-ren/huan.c`  (miss=8)

### `yinyang_shiertian/` （1 个，基线缺失 4 条）

- [ ] ❌ `yinyang_shiertian/powerup.ex` ← `yinyang-shiertian/powerup.c`  (miss=4)

### `yinyang_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `yinyang_zhang/qian.ex` ← `yinyang-zhang/qian.c`  (miss=6)

### `yitian_jian/` （1 个，基线缺失 7 条）

- [ ] ❌ `yitian_jian/fumo.ex` ← `yitian-jian/fumo.c`  (miss=7)

### `yitian_zhang/` （1 个，基线缺失 6 条）

- [ ] ❌ `yitian_zhang/zheng.ex` ← `yitian-zhang/zheng.c`  (miss=6)

### `yiwei_dujiang/` （1 个，基线缺失 2 条）

- [ ] ❌ `yiwei_dujiang/dujiang.ex` ← `yiwei-dujiang/dujiang.c`  (miss=2)

### `yiyang_zhi/` （5 个，基线缺失 95 条）

- [ ] ❌ `yiyang_zhi/dian.ex` ← `yiyang-zhi/dian.c`  (miss=12)
- [ ] ❌ `yiyang_zhi/die.ex` ← `yiyang-zhi/die.c`  (miss=45)
- [ ] ❌ `yiyang_zhi/heal.ex` ← `yiyang-zhi/heal.c`  (miss=19)
- [ ] ❌ `yiyang_zhi/jian.ex` ← `yiyang-zhi/jian.c`  (miss=11)
- [ ] ❌ `yiyang_zhi/qian.ex` ← `yiyang-zhi/qian.c`  (miss=8)

### `yizhi_chan/` （1 个，基线缺失 0 条）

- [x] ✅ `yizhi_chan/jingmo.ex` ← `yizhi-chan/jingmo.c`  (miss=0)

### `youshen_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `youshen_zhang/fan.ex` ← `youshen-zhang/fan.c`  (miss=7)

### `yuanshi_jian/` （2 个，基线缺失 15 条）

- [ ] ❌ `yuanshi_jian/gui.ex` ← `yuanshi-jian/gui.c`  (miss=8)
- [ ] ❌ `yuanshi_jian/xuan.ex` ← `yuanshi-jian/xuan.c`  (miss=7)

### `yuenv_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `yuenv_jian/xin.ex` ← `yuenv-jian/xin.c`  (miss=10)

### `yuezhao_gong/` （1 个，基线缺失 8 条）

- [ ] ❌ `yuezhao_gong/shi.ex` ← `yuezhao-gong/shi.c`  (miss=8)

### `yufeng_zhen/` （1 个，基线缺失 9 条）

- [ ] ❌ `yufeng_zhen/ying.ex` ← `yufeng-zhen/ying.c`  (miss=9)

### `yujiamu_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `yujiamu_quan/jiang.ex` ← `yujiamu-quan/jiang.c`  (miss=6)

### `yujian_shu/` （1 个，基线缺失 12 条）

- [ ] ❌ `yujian_shu/yujian.ex` ← `yujian-shu/yujian.c`  (miss=12)

### `yujiashu/` （1 个，基线缺失 4 条）

- [ ] ❌ `yujiashu/powerup.ex` ← `yujiashu/powerup.c`  (miss=4)

### `yunlong_bian/` （1 个，基线缺失 7 条）

- [ ] ❌ `yunlong_bian/chan.ex` ← `yunlong-bian/chan.c`  (miss=7)

### `yunlong_jian/` （1 个，基线缺失 1 条）

- [ ] ❌ `yunlong_jian/xian.ex` ← `yunlong-jian/xian.c`  (miss=1)

### `yunlong_shengong/` （1 个，基线缺失 4 条）

- [ ] ❌ `yunlong_shengong/powerup.ex` ← `yunlong-shengong/powerup.c`  (miss=4)

### `yunu_sword/` （1 个，基线缺失 4 条）

- [ ] ❌ `yunu_sword/wushuang.ex` ← `yunu-sword/wushuang.c`  (miss=4)

### `yunv_jian/` （1 个，基线缺失 9 条）

- [ ] ❌ `yunv_jian/mei.ex` ← `yunv-jian/mei.c`  (miss=9)

### `yunv_xinjing/` （1 个，基线缺失 4 条）

- [ ] ❌ `yunv_xinjing/powerup.ex` ← `yunv-xinjing/powerup.c`  (miss=4)

### `yunzhou_fufa/` （1 个，基线缺失 7 条）

- [ ] ❌ `yunzhou_fufa/feng.ex` ← `yunzhou-fufa/feng.c`  (miss=7)

### `yuxiao_jian/` （3 个，基线缺失 30 条）

- [ ] ❌ `yuxiao_jian/bihai.ex` ← `yuxiao-jian/bihai.c`  (miss=13)
- [ ] ❌ `yuxiao_jian/qing.ex` ← `yuxiao-jian/qing.c`  (miss=9)
- [ ] ❌ `yuxiao_jian/tian.ex` ← `yuxiao-jian/tian.c`  (miss=8)

### `zhanshen_xinjing/` （2 个，基线缺失 8 条）

- [ ] ❌ `zhanshen_xinjing/powerup.ex` ← `zhanshen-xinjing/powerup.c`  (miss=4)
- [ ] ❌ `zhanshen_xinjing/shield.ex` ← `zhanshen-xinjing/shield.c`  (miss=4)

### `zhemei_shou/` （3 个，基线缺失 21 条）

- [ ] ❌ `zhemei_shou/hai.ex` ← `zhemei-shou/hai.c`  (miss=6)
- [ ] ❌ `zhemei_shou/hua.ex` ← `zhemei-shou/hua.c`  (miss=8)
- [ ] ❌ `zhemei_shou/zhe.ex` ← `zhemei-shou/zhe.c`  (miss=7)

### `zhengliangyi_jian/` （2 个，基线缺失 43 条）

- [ ] ❌ `zhengliangyi_jian/sui.ex` ← `zhengliangyi-jian/sui.c`  (miss=26)
- [ ] ❌ `zhengliangyi_jian/wu.ex` ← `zhengliangyi-jian/wu.c`  (miss=17)

### `zhenshan_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `zhenshan_zhang/da.ex` ← `zhenshan-zhang/da.c`  (miss=7)

### `zhentian_quan/` （1 个，基线缺失 6 条）

- [ ] ❌ `zhentian_quan/shi.ex` ← `zhentian-quan/shi.c`  (miss=6)

### `zhenyu_quan/` （1 个，基线缺失 7 条）

- [ ] ❌ `zhenyu_quan/tong.ex` ← `zhenyu-quan/tong.c`  (miss=7)

### `zhenyue_jue/` （1 个，基线缺失 4 条）

- [ ] ❌ `zhenyue_jue/powerup.ex` ← `zhenyue-jue/powerup.c`  (miss=4)

### `zhonghua_aojue/` （2 个，基线缺失 8 条）

- [ ] ❌ `zhonghua_aojue/powerup.ex` ← `zhonghua-aojue/powerup.c`  (miss=4)
- [ ] ❌ `zhonghua_aojue/shield.ex` ← `zhonghua-aojue/shield.c`  (miss=4)

### `zhongnan_zhi/` （1 个，基线缺失 7 条）

- [ ] ❌ `zhongnan_zhi/zhi.ex` ← `zhongnan-zhi/zhi.c`  (miss=7)

### `zhongping_qiang/` （1 个，基线缺失 9 条）

- [ ] ❌ `zhongping_qiang/ding.ex` ← `zhongping-qiang/ding.c`  (miss=9)

### `zhougong_jian/` （1 个，基线缺失 9 条）

- [ ] ❌ `zhougong_jian/mang.ex` ← `zhougong-jian/mang.c`  (miss=9)

### `zhuangzi_wu/` （1 个，基线缺失 8 条）

- [ ] ❌ `zhuangzi_wu/hua.ex` ← `zhuangzi-wu/hua.c`  (miss=8)

### `zhuihun_jian/` （2 个，基线缺失 21 条）

- [ ] ❌ `zhuihun_jian/zhu.ex` ← `zhuihun-jian/zhu.c`  (miss=14)
- [ ] ❌ `zhuihun_jian/zhui.ex` ← `zhuihun-jian/zhui.c`  (miss=7)

### `zhurong_jian/` （1 个，基线缺失 11 条）

- [ ] ❌ `zhurong_jian/wan.ex` ← `zhurong-jian/wan.c`  (miss=11)

### `zigai_jian/` （1 个，基线缺失 12 条）

- [ ] ❌ `zigai_jian/hui.ex` ← `zigai-jian/hui.c`  (miss=12)

### `zihui_xinfa/` （1 个，基线缺失 4 条）

- [ ] ❌ `zihui_xinfa/powerup.ex` ← `zihui-xinfa/powerup.c`  (miss=4)

### `zijinbagua_dao/` （1 个，基线缺失 3 条）

- [ ] ❌ `zijinbagua_dao/bagua.ex` ← `zijinbagua-dao/bagua.c`  (miss=3)

### `zilei_jian/` （2 个，基线缺失 19 条）

- [ ] ❌ `zilei_jian/feng.ex` ← `zilei-jian/feng.c`  (miss=11)
- [ ] ❌ `zilei_jian/luo.ex` ← `zilei-jian/luo.c`  (miss=8)

### `zixia_shengong/` （2 个，基线缺失 9 条）

- [ ] ❌ `zixia_shengong/powerup.ex` ← `zixia-shengong/powerup.c`  (miss=4)
- [ ] ❌ `zixia_shengong/ziqi.ex` ← `zixia-shengong/ziqi.c`  (miss=5)

### `zui_gun/` （1 个，基线缺失 3 条）

- [ ] ❌ `zui_gun/zuida.ex` ← `zui-gun/zuida.c`  (miss=3)

