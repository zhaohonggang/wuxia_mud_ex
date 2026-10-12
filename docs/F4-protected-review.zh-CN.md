# F4 迁移计划 — 受保护文件复核（P0 · 严格判据）

> 生成时间：2026-10-12　|　工具：`scripts/perf_acceptance.py`

## 背景

`scripts/protected_performs.txt` 当前共 **192** 条受保护 perform。
用**严格判据**（`.ex` 代码内中文文案 vs `.c` 代码内中文文案，**逐条字面一致，不做模糊等价**）复核：

- **PASS = 38**，**FAIL = 154**，MISSING 合计 **1482** 条。
- 判据 = `check_one`：`Counter(norm(src)) - Counter(norm(tgt))` 为空才 PASS（MISSING 必须为空；EXTRA 不判错）。
- 本计划**独立于 A/B 号计划**，可并行执行；A/B 只处理非受保护文件。

## 已 PASS（无需处理）

- `bagua_biao/xian.ex`
- `bagua_dao/tian.ex`
- `bagua_quan/gua.ex`
- `bagua_zhang/ding.ex`
- `bagua_zhang/jia.ex`
- `bahuang_gong/powerup.ex`
- `bahuang_gong/shield.ex`
- `baihua_cuoquan/luan.ex`
- `baihua_cuoquan/yi.ex`
- `baihua_quan/cuo.ex`
- `baisheng_quan/kai.ex`
- `banruo_zhang/feng.ex`
- `beiming_shengong/powerup.ex`
- `beiming_shengong/shield.ex`
- `qishang_quan/shang.ex`
- `qixian_wuxingjian/shan.ex`
- `qixian_wuxingjian/yin.ex`
- `qixian_wuxingjian/zhu.ex`
- `qixing_quan/zhai.ex`
- `qixing_shou/po.ex`
- `quanzhen_jian/hua.ex`
- `quanzhen_jian/lian.ex`
- `quemen_jian/can.ex`
- `qufannao_zhi/lingkong.ex`
- `qujing_gunfa/zhen.ex`
- `riyue_lun/lian.ex`
- `riyue_lun/po.ex`
- `rouyun_jian/tao.ex`
- `ruanhong_zhusuo/bohu.ex`
- `ruanhong_zhusuo/pan.ex`
- `ruanhong_zhusuo/suo.ex`
- `rulai_zhang/zong.ex`
- `ruyi_dao/ruyi.ex`
- `ruying_suixingtui/ruying.ex`
- `sad_strike/tuo.ex`
- `sougu/muyeyingyang.ex`
- `xiangmo_chu/zhen.ex`
- `yunlong_bian/chan.ex`

## 待复核 / 待修订

| # | 文件 | MISSING | 对应 LPC 源 |
|---:|---|---:|---|
| 1 | `bagua_biao/zhi.ex` | 11 | `kungfu/skill/bagua-biao/zhi.c` |
| 2 | `bagua_dao/mang.ex` | 13 | `kungfu/skill/bagua-dao/mang.c` |
| 3 | `bagua_dao/sha.ex` | 12 | `kungfu/skill/bagua-dao/sha.c` |
| 4 | `baibian_daxue/dian.ex` | 9 | `kungfu/skill/baibian-daxue/dian.c` |
| 5 | `baisheng_daofa/heng.ex` | 17 | `kungfu/skill/baisheng-daofa/heng.c` |
| 6 | `baxian_jian/dian.ex` | 11 | `kungfu/skill/baxian-jian/dian.c` |
| 7 | `beiming_shengong/suck.ex` | 1 | `kungfu/skill/beiming-shengong/suck.c` |
| 8 | `bingpo_shenzhen/bing.ex` | 20 | `kungfu/skill/bingpo-shenzhen/bing.c` |
| 9 | `bizhen_qingzhang/pengpai.ex` | 12 | `kungfu/skill/bizhen-qingzhang/pengpai.c` |
| 10 | `boyun_suowu/dian.ex` | 3 | `kungfu/skill/boyun-suowu/dian.c` |
| 11 | `boyun_suowu/meng.ex` | 1 | `kungfu/skill/boyun-suowu/meng.c` |
| 12 | `caiyan_gong/huan.ex` | 14 | `kungfu/skill/caiyan-gong/huan.c` |
| 13 | `canghong_bifa/jing.ex` | 11 | `kungfu/skill/canghong-bifa/jing.c` |
| 14 | `chanhun_suo/duo.ex` | 13 | `kungfu/skill/chanhun-suo/duo.c` |
| 15 | `chanhun_suo/suo.ex` | 10 | `kungfu/skill/chanhun-suo/suo.c` |
| 16 | `chousui_zhang/dan.ex` | 19 | `kungfu/skill/chousui-zhang/dan.c` |
| 17 | `chuangwang_dao/xiong.ex` | 11 | `kungfu/skill/chuangwang-dao/xiong.c` |
| 18 | `chuanxin_zhang/zhui.ex` | 8 | `kungfu/skill/chuanxin-zhang/zhui.c` |
| 19 | `chuanyue_jian/hao.ex` | 11 | `kungfu/skill/chuanyue-jian/hao.c` |
| 20 | `cibei_dao/sheshen.ex` | 2 | `kungfu/skill/cibei-dao/sheshen.c` |
| 21 | `dacheng_fosuo/chanrao.ex` | 9 | `kungfu/skill/dacheng-fosuo/chanrao.c` |
| 22 | `dagou_bang/ban.ex` | 14 | `kungfu/skill/dagou-bang/ban.c` |
| 23 | `dagou_bang/chan.ex` | 3 | `kungfu/skill/dagou-bang/chan.c` |
| 24 | `dagou_bang/chuo.ex` | 10 | `kungfu/skill/dagou-bang/chuo.c` |
| 25 | `dagou_bang/feng.ex` | 2 | `kungfu/skill/dagou-bang/feng.c` |
| 26 | `dagou_bang/tian.ex` | 2 | `kungfu/skill/dagou-bang/tian.c` |
| 27 | `dali_chu/hong.ex` | 12 | `kungfu/skill/dali-chu/hong.c` |
| 28 | `damo_jian/qingxin.ex` | 3 | `kungfu/skill/damo-jian/qingxin.c` |
| 29 | `damo_jian/sanjue.ex` | 8 | `kungfu/skill/damo-jian/sanjue.c` |
| 30 | `danding_dao/kou.ex` | 10 | `kungfu/skill/danding-dao/kou.c` |
| 31 | `daojian_guizhen/daojian.ex` | 23 | `kungfu/skill/daojian-guizhen/daojian.c` |
| 32 | `dongyang_dao/zhan.ex` | 9 | `kungfu/skill/dongyang-dao/zhan.c` |
| 33 | `duanjia_jian/jing.ex` | 1 | `kungfu/skill/duanjia-jian/jing.c` |
| 34 | `duanjia_jian/lian.ex` | 1 | `kungfu/skill/duanjia-jian/lian.c` |
| 35 | `duanjia_sword/jing.ex` | 9 | `kungfu/skill/duanjia-sword/jing.c` |
| 36 | `duanyun_fu/tiaoyan.ex` | 7 | `kungfu/skill/duanyun-fu/tiaoyan.c` |
| 37 | `dugu_jiujian/qi.ex` | 12 | `kungfu/skill/dugu-jiujian/qi.c` |
| 38 | `dugu_jiujian/yi.ex` | 10 | `kungfu/skill/dugu-jiujian/yi.c` |
| 39 | `duoluoye_zhi/jimie.ex` | 14 | `kungfu/skill/duoluoye-zhi/jimie.c` |
| 40 | `duoming_jinhua/hua.ex` | 11 | `kungfu/skill/duoming-jinhua/hua.c` |
| 41 | `emei_jian/xian.ex` | 10 | `kungfu/skill/emei-jian/xian.c` |
| 42 | `fanliangyi_dao/makearray.ex` | 8 | `kungfu/skill/fanliangyi-dao/makearray.c` |
| 43 | `fanliangyi_dao/san.ex` | 18 | `kungfu/skill/fanliangyi-dao/san.c` |
| 44 | `feifeng_whip/wu.ex` | 9 | `kungfu/skill/feifeng-whip/wu.c` |
| 45 | `feilong_zhang/fei.ex` | 11 | `kungfu/skill/feilong-zhang/fei.c` |
| 46 | `feixing_shu/hua.ex` | 12 | `kungfu/skill/feixing-shu/hua.c` |
| 47 | `fenglei_panfa/fenglei.ex` | 19 | `kungfu/skill/fenglei-panfa/fenglei.c` |
| 48 | `fenglei_zifa/she.ex` | 7 | `kungfu/skill/fenglei-zifa/she.c` |
| 49 | `fengyun_shou/qinna.ex` | 5 | `kungfu/skill/fengyun-shou/qinna.c` |
| 50 | `fireice_strike/binghuo.ex` | 14 | `kungfu/skill/fireice-strike/binghuo.c` |
| 51 | `force/power.ex` | 25 | `kungfu/skill/force/power.c` |
| 52 | `fumo_jian/foxin.ex` | 11 | `kungfu/skill/fumo-jian/foxin.c` |
| 53 | `fumo_zhang/lun.ex` | 7 | `kungfu/skill/fumo-zhang/lun.c` |
| 54 | `furong_jian/luan.ex` | 9 | `kungfu/skill/furong-jian/luan.c` |
| 55 | `furong_jinzhen/xian.ex` | 4 | `kungfu/skill/furong-jinzhen/xian.c` |
| 56 | `guxing_jian/lian.ex` | 10 | `kungfu/skill/guxing-jian/lian.c` |
| 57 | `guyue_chan/jing.ex` | 9 | `kungfu/skill/guyue-chan/jing.c` |
| 58 | `hanmei_jian/leng.ex` | 11 | `kungfu/skill/hanmei-jian/leng.c` |
| 59 | `hansha_sheying/zhen.ex` | 11 | `kungfu/skill/hansha-sheying/zhen.c` |
| 60 | `hanwang_qingdao/ying.ex` | 11 | `kungfu/skill/hanwang-qingdao/ying.c` |
| 61 | `hanxing_bada/lastrisk.ex` | 7 | `kungfu/skill/hanxing-bada/lastrisk.c` |
| 62 | `heixue_shenzhen/luo.ex` | 12 | `kungfu/skill/heixue-shenzhen/luo.c` |
| 63 | `henshan_jian/huan.ex` | 13 | `kungfu/skill/henshan-jian/huan.c` |
| 64 | `hexing_bifa/dian.ex` | 9 | `kungfu/skill/hexing-bifa/dian.c` |
| 65 | `hongye_daofa/leiting.ex` | 7 | `kungfu/skill/hongye-daofa/leiting.c` |
| 66 | `houquan/zhen.ex` | 8 | `kungfu/skill/houquan/zhen.c` |
| 67 | `huashan_jian/jie.ex` | 6 | `kungfu/skill/huashan-jian/jie.c` |
| 68 | `huashan_jian/lian.ex` | 7 | `kungfu/skill/huashan-jian/lian.c` |
| 69 | `huashan_jian/long.ex` | 6 | `kungfu/skill/huashan-jian/long.c` |
| 70 | `huashan_jian/xian.ex` | 16 | `kungfu/skill/huashan-jian/xian.c` |
| 71 | `huifeng_jian/jue.ex` | 25 | `kungfu/skill/huifeng-jian/jue.c` |
| 72 | `huifeng_jian/mie.ex` | 8 | `kungfu/skill/huifeng-jian/mie.c` |
| 73 | `huilong_bifa/cang.ex` | 8 | `kungfu/skill/huilong-bifa/cang.c` |
| 74 | `hujia_daofa/xian.ex` | 7 | `kungfu/skill/hujia-daofa/xian.c` |
| 75 | `hujia_daofa/zhui.ex` | 5 | `kungfu/skill/hujia-daofa/zhui.c` |
| 76 | `huoyan_dao/fen.ex` | 4 | `kungfu/skill/huoyan-dao/fen.c` |
| 77 | `jiandun_zhusuo/fu.ex` | 12 | `kungfu/skill/jiandun-zhusuo/fu.c` |
| 78 | `jiandun_zhusuo/qian.ex` | 16 | `kungfu/skill/jiandun-zhusuo/qian.c` |
| 79 | `jidian_jian/dian.ex` | 6 | `kungfu/skill/jidian-jian/dian.c` |
| 80 | `jimie_zhua/wuwo.ex` | 4 | `kungfu/skill/jimie-zhua/wuwo.c` |
| 81 | `jinbiao_jue/huan.ex` | 10 | `kungfu/skill/jinbiao-jue/huan.c` |
| 82 | `jingang_buhuaiti/jingang.ex` | 2 | `kungfu/skill/jingang-buhuaiti/jingang.c` |
| 83 | `jingang_quan/jingang.ex` | 12 | `kungfu/skill/jingang-quan/jingang.c` |
| 84 | `jingang_zhi/fumo.ex` | 5 | `kungfu/skill/jingang-zhi/fumo.c` |
| 85 | `jinguan_yusuo/suo.ex` | 9 | `kungfu/skill/jinguan-yusuo/suo.c` |
| 86 | `jingyue_bifa/ci.ex` | 12 | `kungfu/skill/jingyue-bifa/ci.c` |
| 87 | `jinshe_jian/wan.ex` | 10 | `kungfu/skill/jinshe-jian/wan.c` |
| 88 | `jinshe_zhui/tuwu.ex` | 11 | `kungfu/skill/jinshe-zhui/tuwu.c` |
| 89 | `jinzhong_zhao/zhao.ex` | 2 | `kungfu/skill/jinzhong-zhao/zhao.c` |
| 90 | `jiuqu_jian/wan.ex` | 10 | `kungfu/skill/jiuqu-jian/wan.c` |
| 91 | `jueqing_jian/liu.ex` | 12 | `kungfu/skill/jueqing-jian/liu.c` |
| 92 | `kuangfeng_jian/sao.ex` | 9 | `kungfu/skill/kuangfeng-jian/sao.c` |
| 93 | `kuimang_dao/pan.ex` | 11 | `kungfu/skill/kuimang-dao/pan.c` |
| 94 | `kunlun_qifa/liu.ex` | 11 | `kungfu/skill/kunlun-qifa/liu.c` |
| 95 | `lingbo_weibu/ling.ex` | 3 | `kungfu/skill/lingbo-weibu/ling.c` |
| 96 | `lingshe_zhangfa/chan.ex` | 9 | `kungfu/skill/lingshe-zhangfa/chan.c` |
| 97 | `liuhe_dao/shan.ex` | 11 | `kungfu/skill/liuhe-dao/shan.c` |
| 98 | `longcheng_shendao/feng.ex` | 11 | `kungfu/skill/longcheng-shendao/feng.c` |
| 99 | `longxing_jian/kong.ex` | 10 | `kungfu/skill/longxing-jian/kong.c` |
| 100 | `longxing_jian/xian.ex` | 1 | `kungfu/skill/longxing-jian/xian.c` |
| 101 | `luohan_gun/xiangmo.ex` | 7 | `kungfu/skill/luohan-gun/xiangmo.c` |
| 102 | `luohan_quan/xiangmo.ex` | 8 | `kungfu/skill/luohan-quan/xiangmo.c` |
| 103 | `luoying_shenjian/sui.ex` | 12 | `kungfu/skill/luoying-shenjian/sui.c` |
| 104 | `luoyun_dao/tian.ex` | 11 | `kungfu/skill/luoyun-dao/tian.c` |
| 105 | `lutou_zhang/tong.ex` | 11 | `kungfu/skill/lutou-zhang/tong.c` |
| 106 | `mantian_xing/shan.ex` | 10 | `kungfu/skill/mantian-xing/shan.c` |
| 107 | `mantianhuayu_zhen/zheng.ex` | 11 | `kungfu/skill/mantianhuayu-zhen/zheng.c` |
| 108 | `miaojia_jian/qian.ex` | 12 | `kungfu/skill/miaojia-jian/qian.c` |
| 109 | `mingwang_jian/ruo.ex` | 12 | `kungfu/skill/mingwang-jian/ruo.c` |
| 110 | `mingwang_jian/xiang.ex` | 10 | `kungfu/skill/mingwang-jian/xiang.c` |
| 111 | `mizong_houquan/zhou.ex` | 16 | `kungfu/skill/mizong-houquan/zhou.c` |
| 112 | `nianhua_zhi/fuxue.ex` | 10 | `kungfu/skill/nianhua-zhi/fuxue.c` |
| 113 | `ningxue_zhang/xue.ex` | 8 | `kungfu/skill/ningxue-zhang/xue.c` |
| 114 | `pangen_cuojiefu/cuo.ex` | 13 | `kungfu/skill/pangen-cuojiefu/cuo.c` |
| 115 | `panlong_suo/chan.ex` | 13 | `kungfu/skill/panlong-suo/chan.c` |
| 116 | `pichen_jian/ao.ex` | 10 | `kungfu/skill/pichen-jian/ao.c` |
| 117 | `pidi_shenzhen/huan.ex` | 11 | `kungfu/skill/pidi-shenzhen/huan.c` |
| 118 | `poguang_dao/bing.ex` | 14 | `kungfu/skill/poguang-dao/bing.c` |
| 119 | `pomie_jinzhen/du.ex` | 13 | `kungfu/skill/pomie-jinzhen/du.c` |
| 120 | `qiankun_jian/qian.ex` | 12 | `kungfu/skill/qiankun-jian/qian.c` |
| 121 | `qiankun_jian/riyue.ex` | 11 | `kungfu/skill/qiankun-jian/riyue.c` |
| 122 | `qianye_shou/qianye.ex` | 8 | `kungfu/skill/qianye-shou/qianye.c` |
| 123 | `qingliang_jian/ming.ex` | 11 | `kungfu/skill/qingliang-jian/ming.c` |
| 124 | `qishi_ji/juan.ex` | 12 | `kungfu/skill/qishi-ji/juan.c` |
| 125 | `qiufeng_chenfa/chan.ex` | 8 | `kungfu/skill/qiufeng-chenfa/chan.c` |
| 126 | `qiulin_shiye/wu.ex` | 8 | `kungfu/skill/qiulin-shiye/wu.c` |
| 127 | `qixing_jian/xing.ex` | 11 | `kungfu/skill/qixing-jian/xing.c` |
| 128 | `quanzhen_jian/chan.ex` | 11 | `kungfu/skill/quanzhen-jian/chan.c` |
| 129 | `quanzhen_jian/ding.ex` | 11 | `kungfu/skill/quanzhen-jian/ding.c` |
| 130 | `ranmu_daofa/zhenyan.ex` | 2 | `kungfu/skill/ranmu-daofa/zhenyan.c` |
| 131 | `raozhi_roujian/chuan.ex` | 11 | `kungfu/skill/raozhi-roujian/chuan.c` |
| 132 | `riyue_bian/chan.ex` | 2 | `kungfu/skill/riyue-bian/chan.c` |
| 133 | `riyue_bian/he.ex` | 1 | `kungfu/skill/riyue-bian/he.c` |
| 134 | `riyue_bian/shang.ex` | 8 | `kungfu/skill/riyue-bian/shang.c` |
| 135 | `riyue_lun/yuan.ex` | 2 | `kungfu/skill/riyue-lun/yuan.c` |
| 136 | `rouyun_steps/zong.ex` | 2 | `kungfu/skill/rouyun-steps/zong.c` |
| 137 | `ruanhong_zhusuo/teng.ex` | 11 | `kungfu/skill/ruanhong-zhusuo/teng.c` |
| 138 | `sanhua_zhang/san.ex` | 9 | `kungfu/skill/sanhua-zhang/san.c` |
| 139 | `sanwu_shou/wei.ex` | 12 | `kungfu/skill/sanwu-shou/wei.c` |
| 140 | `shangjia_dao/juan.ex` | 11 | `kungfu/skill/shangjia-dao/juan.c` |
| 141 | `shenxing_baibian/piao.ex` | 1 | `kungfu/skill/shenxing-baibian/piao.c` |
| 142 | `shunv_jian/ning.ex` | 12 | `kungfu/skill/shunv-jian/ning.c` |
| 143 | `songshan_jian/meng.ex` | 12 | `kungfu/skill/songshan-jian/meng.c` |
| 144 | `sun_finger/dian.ex` | 8 | `kungfu/skill/sun-finger/dian.c` |
| 145 | `suqin_beijian/can.ex` | 11 | `kungfu/skill/suqin-beijian/can.c` |
| 146 | `suxin_jian/lian.ex` | 10 | `kungfu/skill/suxin-jian/lian.c` |
| 147 | `taiji_jian/chan.ex` | 10 | `kungfu/skill/taiji-jian/chan.c` |
| 148 | `taiji_jian/sui.ex` | 4 | `kungfu/skill/taiji-jian/sui.c` |
| 149 | `taiji_jian/zhuan.ex` | 10 | `kungfu/skill/taiji-jian/zhuan.c` |
| 150 | `tangmen_throwing/biao.ex` | 19 | `kungfu/skill/tangmen-throwing/biao.c` |
| 151 | `tiangang_zhi/ling.ex` | 10 | `kungfu/skill/tiangang-zhi/ling.c` |
| 152 | `wudang_jian/sheng.ex` | 11 | `kungfu/skill/wudang-jian/sheng.c` |
| 153 | `xiyang_jian/ci.ex` | 10 | `kungfu/skill/xiyang-jian/ci.c` |
| 154 | `yunhe_jian/chong.ex` | 11 | `kungfu/skill/yunhe-jian/chong.c` |

## 处理流程（每个文件）

1. 读对应 `.c`（上表末列；注意 `perform/`、`exert/`、`-`/`'` 变体）。
2. **逐条字面一致**修正 `.ex`：
   - 措辞差异（`难以施展`↔`无法施展`、`修为不够`↔`不够娴熟`、`真气不够`↔`真气不足`）**改成与 `.c` 完全一致**；
   - 名字插在字符串中间而被 `.c` 拆成多段时，`.ex` **必须同样拆段**：`"…手中" <> weapon_name <> "，发出…"`；
   - 中文弯引号 `“”‘’` 与直引号按 `.c` 原样保留。
3. `python scripts/perf_acceptance.py <rel>` 须 PASS。
4. `docker exec wuxia_mud_dev-app-1 sh -c "cd /app && mix compile"` 须 EXIT=0。
5. 文件本就在 `protected_performs.txt` 中，无需追加。

## 例外登记（判定为工具误报 / 无需修改）

| 文件 | 理由 | 处理 |
|---|---|---|
| beiming_shengong/suck.ex | .c 源文件第 143 行 `不能吸取对方的丹元！` 后的 `\n` 转义反斜杠已损坏为 U+FFFD + 字面 n（字节 ef bc 81 ef bf bd 6e），工具按字面抽出 `丹元！�n`；照抄会把乱码带进游戏文案，故保留正确转义 `！\n`。 | 保留正确文案，工具该条记为已知例外 |
