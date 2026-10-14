# F4 迁移计划 — 受保护文件复核（P0 · 严格判据）

> 生成时间：2026-10-13　|　工具：`scripts/perf_acceptance.py`

## 背景

`scripts/protected_performs.txt` 当前共 **418** 条受保护 perform。
用**严格判据**（`.ex` 代码内中文文案 vs `.c` 代码内中文文案，**逐条字面一致，不做模糊等价**）复核：

- **PASS = 259**，**FAIL = 159**，MISSING 合计 **1482** 条。
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
- `benlei_zhang/lei.ex`
- `bibo_shengong/powerup.ex`
- `biluo_zhang/lian.ex`
- `bingxin_jue/freeze.ex`
- `bingxin_jue/powerup.ex`
- `biyan_dao/luo.ex`
- `biyun_xinfa/powerup.ex`
- `bluesea_force/bo.ex`
- `bluesea_force/mie.ex`
- `bluesea_force/powerup.ex`
- `bluesea_force/shield.ex`
- `bluesea_force/xuan.ex`
- `canglang_zhi/tao.ex`
- `canhe_zhi/canhe.ex`
- `canhe_zhi/jin.ex`
- `canhe_zhi/you.ex`
- `canhe_zhi/zhi.ex`
- `changsheng_jue/powerup.ex`
- `changsheng_jue/shield.ex`
- `chansi_shou/qin.ex`
- `chilian_shenzhang/lian.ex`
- `chongtian_zhang/zhan.ex`
- `chongyang_shenzhang/lian.ex`
- `chousui_zhang/shi.ex`
- `chousui_zhang/tao.ex`
- `chuncan_zhang/jian.ex`
- `cuixin_zhang/cui.ex`
- `dabei_zhang/bei.ex`
- `dacidabei_shou/yin.ex`
- `dahai_wuliang/powerup.ex`
- `damo_jian/luan.ex`
- `damo_jian/shang.ex`
- `damo_jian/zhe.ex`
- `daojian_guizhen/xue.ex`
- `dashou_yin/yin.ex`
- `dongyang_dao/luan.ex`
- `douzhuan_xingyi/yi.ex`
- `dragon_strike/hui.ex`
- `dragon_strike/lei.ex`
- `dragon_strike/qin.ex`
- `dragon_strike/xiang.ex`
- `duanjia_sword/jue.ex`
- `duanshi_xinfa/powerup.ex`
- `dugu_jiujian/jue.ex`
- `dugu_jiujian/po.ex`
- `dulong_shenzhua/bao.ex`
- `dulong_shenzhua/ju.ex`
- `feifeng_bian/xi.ex`
- `feihua_zhang/fei.ex`
- `fengmo_zhang/luan.ex`
- `fenxin_jue/powerup.ex`
- `five_avoid/break.ex`
- `force/dispel.ex`
- `force/heal.ex`
- `force/inspire.ex`
- `force/lifeheal.ex`
- `force/recover.ex`
- `force/regenerate.ex`
- `force/roar.ex`
- `force/shot.ex`
- `force/tianmo.ex`
- `force/xun.ex`
- `freezing_force/powerup.ex`
- `fushang_neigong/powerup.ex`
- `guanri_jian/fen.ex`
- `guanri_jian/guan.ex`
- `guhong_zhang/qian.ex`
- `gun/she.ex`
- `guzhuo_zhang/yu.ex`
- `guzhuo_zhang/zhen.ex`
- `guzhuo_zhang/zhuo.ex`
- `hamagong/hui.ex`
- `hamagong/powerup.ex`
- `hamagong/reserve.ex`
- `hamagong/tan.ex`
- `hamagong/tui.ex`
- `hamagong/zhen.ex`
- `hanbing_mianzhang/jue.ex`
- `hanbing_zhang/han.ex`
- `hanbing_zhang/hen.ex`
- `hanbing_zhenqi/freezing.ex`
- `hanbing_zhenqi/powerup.ex`
- `haotian_zhang/ju.ex`
- `heisha_zhang/cui.ex`
- `henshan_quan/lan.ex`
- `honglian_dao/huo.ex`
- `hongye_daofa/kuang.ex`
- `hua_quan/juan.ex`
- `huagong_dafa/hua.ex`
- `huagong_dafa/powerup.ex`
- `huagu_mianzhang/hua.ex`
- `huanyin_zhi/huanyin.ex`
- `huashan_quan/song.ex`
- `huashan_zhang/piao.ex`
- `huilong_zhang/baiwei.ex`
- `hujia_daofa/cang.ex`
- `hujia_quan/kuai.ex`
- `huntian_baojian/powerup.ex`
- `huntian_baojian/sword.ex`
- `huntian_qigong/powerup.ex`
- `huntian_qigong/shield.ex`
- `hunyuan_yiqi/powerup.ex`
- `hunyuan_zhang/wuji.ex`
- `huoyan_dao/yan.ex`
- `huzhua_shou/juehu.ex`
- `jiasha_fumogong/zhe.ex`
- `jiechen_dao/xiuluo.ex`
- `jieshou_jiushi/jie.ex`
- `jifeng_cixuefa/cang.ex`
- `jinding_zhang/bashi.ex`
- `jingang_zhi/san.ex`
- `jingzhong_bafa/bafa.ex`
- `jinshe_jian/kun.ex`
- `jinshe_jian/shi.ex`
- `jinshe_zhang/fugu.ex`
- `jiuyang_shengong/hun.ex`
- `jiuyang_shengong/jiu.ex`
- `jiuyang_shengong/pi.ex`
- `jiuyang_shengong/po.ex`
- `jiuyang_shengong/powerup.ex`
- `jiuyang_shengong/ri.ex`
- `jiuyang_shengong/roar.ex`
- `jiuyang_shengong/shield.ex`
- `jiuyin_baiguzhao/duo.ex`
- `jiuyin_baiguzhao/zhua.ex`
- `jiuyin_shengong/powerup.ex`
- `jiuyin_shengong/quan.ex`
- `jiuyin_shengong/roar.ex`
- `jiuyin_shengong/shield.ex`
- `jiuyin_shengong/shou.ex`
- `jiuyin_shengong/xin.ex`
- `jiuyin_shengong/zhang.ex`
- `jiuyin_shengong/zhen.ex`
- `jiuyin_shengong/zhi.ex`
- `jiuyin_shengong/zhua.ex`
- `jueming_tui/jue.ex`
- `jueqing_zhang/hun.ex`
- `jueqing_zhang/wan.ex`
- `kongming_quan/kong.ex`
- `kongming_quan/ruo.ex`
- `kuangfeng_blade/kuang.ex`
- `kuangfeng_jian/yong.ex`
- `kuihua_mogong/bian.ex`
- `kuihua_mogong/powerup.ex`
- `kuihua_mogong/qiong.ex`
- `kuihua_mogong/roar.ex`
- `kuihua_mogong/sheng.ex`
- `kuihua_mogong/shield.ex`
- `kuihua_mogong/tian.ex`
- `kuihua_mogong/wswd.ex`
- `kunlun_jian/fanyin.ex`
- `kunlun_zhang/kong.ex`
- `kurong_changong/powerup.ex`
- `lanhua_shou/fei.ex`
- `lanhua_shou/fu.ex`
- `lansha_shou/po.ex`
- `leiming_bian/cibei.ex`
- `leiting_fu/sanda.ex`
- `lengyue_shengong/powerup.ex`
- `liangyi_jian/ren.ex`
- `liangyi_shengong/powerup.ex`
- `lianhuan_mizongtui/lian.ex`
- `lingshe_quan/rou.ex`
- `lingshe_zhangfa/qianshe.ex`
- `lingshe_zhangfa/wanshi.ex`
- `lingshe_zhangfa/wuji.ex`
- `lingxiao_quan/jue.ex`
- `lingxiao_quan/san.ex`
- `lingyuan_xinfa/break.ex`
- `lingyun_jian/xiao.ex`
- `linji_zhuang/powerup.ex`
- `liuhe_bian/lianhuan.ex`
- `liuhe_zhang/tan.ex`
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
- `sanku_shengong/powerup.ex`
- `shedu_qiqiao/da.ex`
- `shedu_qiqiao/liandu.ex`
- `shenghuo_ling/hua.ex`
- `shenghuo_ling/lian.ex`
- `shenghuo_ling/xi.ex`
- `shenghuo_shengong/powerup.ex`
- `shenghuo_shengong/shield.ex`
- `shenghuo_xinfa/powerup.ex`
- `shenlong_bashi/xian.ex`
- `shenlong_xinfa/powerup.ex`
- `shenmen_jian/ci.ex`
- `shenzhaojing/powerup.ex`
- `shenzhaojing/shield.ex`
- `shenzhaojing/wu.ex`
- `shenzhaojing/ying.ex`
- `shexing_lifan/guiyuan.ex`
- `shigu_bifa/feng.ex`
- `shigu_bifa/shiyi.ex`
- `six_finger/qi.ex`
- `six_finger/six.ex`
- `six_finger/zong.ex`
- `six_finger/zongheng.ex`
- `sougu/muyeyingyang.ex`
- `surge_force/powerup.ex`
- `taiji_shengong/powerup.ex`
- `taiji_shengong/shield.ex`
- `taixuan_gong/powerup.ex`
- `taixuan_gong/shield.ex`
- `tianhuan_shenjue/powerup.ex`
- `tianlei_shengong/powerup.ex`
- `wudoumi_shengong/powerup.ex`
- `xiangmo_chu/zhen.ex`
- `xiantian_gong/dang.ex`
- `xiantian_gong/fen.ex`
- `xiantian_gong/hun.ex`
- `xiantian_gong/hup.ex`
- `xiantian_gong/jian.ex`
- `xiantian_gong/powerup.ex`
- `xiantian_gong/shield.ex`
- `xiaowuxiang/powerup.ex`
- `xiaowuxiang/shield.ex`
- `xuanming_shengong/powerup.ex`
- `xuanming_shengong/shield.ex`
- `xuantian_wujigong/powerup.ex`
- `xuantian_wujigong/shield.ex`
- `yijin_duangu/powerup.ex`
- `yijin_duangu/shield.ex`
- `yunlong_bian/chan.ex`
- `zhanshen_xinjing/powerup.ex`
- `zhanshen_xinjing/shield.ex`

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
| 88 | `jinshe_zhui/feng` | 0 | `—` |
| 89 | `jinshe_zhui/tuwu.ex` | 11 | `kungfu/skill/jinshe-zhui/tuwu.c` |
| 90 | `jinwu_daofa/chi` | 0 | `—` |
| 91 | `jinwu_goufa/duo` | 0 | `—` |
| 92 | `jinyu_quan/man` | 0 | `—` |
| 93 | `jinyuan_gun/qian` | 0 | `—` |
| 94 | `jinzhong_zhao/zhao.ex` | 2 | `kungfu/skill/jinzhong-zhao/zhao.c` |
| 95 | `jiuqu_jian/wan.ex` | 10 | `kungfu/skill/jiuqu-jian/wan.c` |
| 96 | `jueqing_jian/liu.ex` | 12 | `kungfu/skill/jueqing-jian/liu.c` |
| 97 | `kuangfeng_jian/sao.ex` | 9 | `kungfu/skill/kuangfeng-jian/sao.c` |
| 98 | `kuimang_dao/pan.ex` | 11 | `kungfu/skill/kuimang-dao/pan.c` |
| 99 | `kunlun_qifa/liu.ex` | 11 | `kungfu/skill/kunlun-qifa/liu.c` |
| 100 | `lingbo_weibu/ling.ex` | 3 | `kungfu/skill/lingbo-weibu/ling.c` |
| 101 | `lingshe_zhangfa/chan.ex` | 9 | `kungfu/skill/lingshe-zhangfa/chan.c` |
| 102 | `liuhe_dao/shan.ex` | 11 | `kungfu/skill/liuhe-dao/shan.c` |
| 103 | `longcheng_shendao/feng.ex` | 11 | `kungfu/skill/longcheng-shendao/feng.c` |
| 104 | `longxing_jian/kong.ex` | 10 | `kungfu/skill/longxing-jian/kong.c` |
| 105 | `longxing_jian/xian.ex` | 1 | `kungfu/skill/longxing-jian/xian.c` |
| 106 | `luohan_gun/xiangmo.ex` | 7 | `kungfu/skill/luohan-gun/xiangmo.c` |
| 107 | `luohan_quan/xiangmo.ex` | 8 | `kungfu/skill/luohan-quan/xiangmo.c` |
| 108 | `luoying_shenjian/sui.ex` | 12 | `kungfu/skill/luoying-shenjian/sui.c` |
| 109 | `luoyun_dao/tian.ex` | 11 | `kungfu/skill/luoyun-dao/tian.c` |
| 110 | `lutou_zhang/tong.ex` | 11 | `kungfu/skill/lutou-zhang/tong.c` |
| 111 | `mantian_xing/shan.ex` | 10 | `kungfu/skill/mantian-xing/shan.c` |
| 112 | `mantianhuayu_zhen/zheng.ex` | 11 | `kungfu/skill/mantianhuayu-zhen/zheng.c` |
| 113 | `miaojia_jian/qian.ex` | 12 | `kungfu/skill/miaojia-jian/qian.c` |
| 114 | `mingwang_jian/ruo.ex` | 12 | `kungfu/skill/mingwang-jian/ruo.c` |
| 115 | `mingwang_jian/xiang.ex` | 10 | `kungfu/skill/mingwang-jian/xiang.c` |
| 116 | `mizong_houquan/zhou.ex` | 16 | `kungfu/skill/mizong-houquan/zhou.c` |
| 117 | `nianhua_zhi/fuxue.ex` | 10 | `kungfu/skill/nianhua-zhi/fuxue.c` |
| 118 | `ningxue_zhang/xue.ex` | 8 | `kungfu/skill/ningxue-zhang/xue.c` |
| 119 | `pangen_cuojiefu/cuo.ex` | 13 | `kungfu/skill/pangen-cuojiefu/cuo.c` |
| 120 | `panlong_suo/chan.ex` | 13 | `kungfu/skill/panlong-suo/chan.c` |
| 121 | `pichen_jian/ao.ex` | 10 | `kungfu/skill/pichen-jian/ao.c` |
| 122 | `pidi_shenzhen/huan.ex` | 11 | `kungfu/skill/pidi-shenzhen/huan.c` |
| 123 | `poguang_dao/bing.ex` | 14 | `kungfu/skill/poguang-dao/bing.c` |
| 124 | `pomie_jinzhen/du.ex` | 13 | `kungfu/skill/pomie-jinzhen/du.c` |
| 125 | `qiankun_jian/qian.ex` | 12 | `kungfu/skill/qiankun-jian/qian.c` |
| 126 | `qiankun_jian/riyue.ex` | 11 | `kungfu/skill/qiankun-jian/riyue.c` |
| 127 | `qianye_shou/qianye.ex` | 8 | `kungfu/skill/qianye-shou/qianye.c` |
| 128 | `qingliang_jian/ming.ex` | 11 | `kungfu/skill/qingliang-jian/ming.c` |
| 129 | `qishi_ji/juan.ex` | 12 | `kungfu/skill/qishi-ji/juan.c` |
| 130 | `qiufeng_chenfa/chan.ex` | 8 | `kungfu/skill/qiufeng-chenfa/chan.c` |
| 131 | `qiulin_shiye/wu.ex` | 8 | `kungfu/skill/qiulin-shiye/wu.c` |
| 132 | `qixing_jian/xing.ex` | 11 | `kungfu/skill/qixing-jian/xing.c` |
| 133 | `quanzhen_jian/chan.ex` | 11 | `kungfu/skill/quanzhen-jian/chan.c` |
| 134 | `quanzhen_jian/ding.ex` | 11 | `kungfu/skill/quanzhen-jian/ding.c` |
| 135 | `ranmu_daofa/zhenyan.ex` | 2 | `kungfu/skill/ranmu-daofa/zhenyan.c` |
| 136 | `raozhi_roujian/chuan.ex` | 11 | `kungfu/skill/raozhi-roujian/chuan.c` |
| 137 | `riyue_bian/chan.ex` | 2 | `kungfu/skill/riyue-bian/chan.c` |
| 138 | `riyue_bian/he.ex` | 1 | `kungfu/skill/riyue-bian/he.c` |
| 139 | `riyue_bian/shang.ex` | 8 | `kungfu/skill/riyue-bian/shang.c` |
| 140 | `riyue_lun/yuan.ex` | 2 | `kungfu/skill/riyue-lun/yuan.c` |
| 141 | `rouyun_steps/zong.ex` | 2 | `kungfu/skill/rouyun-steps/zong.c` |
| 142 | `ruanhong_zhusuo/teng.ex` | 11 | `kungfu/skill/ruanhong-zhusuo/teng.c` |
| 143 | `sanhua_zhang/san.ex` | 9 | `kungfu/skill/sanhua-zhang/san.c` |
| 144 | `sanwu_shou/wei.ex` | 12 | `kungfu/skill/sanwu-shou/wei.c` |
| 145 | `shangjia_dao/juan.ex` | 11 | `kungfu/skill/shangjia-dao/juan.c` |
| 146 | `shenxing_baibian/piao.ex` | 1 | `kungfu/skill/shenxing-baibian/piao.c` |
| 147 | `shunv_jian/ning.ex` | 12 | `kungfu/skill/shunv-jian/ning.c` |
| 148 | `songshan_jian/meng.ex` | 12 | `kungfu/skill/songshan-jian/meng.c` |
| 149 | `sun_finger/dian.ex` | 8 | `kungfu/skill/sun-finger/dian.c` |
| 150 | `suqin_beijian/can.ex` | 11 | `kungfu/skill/suqin-beijian/can.c` |
| 151 | `suxin_jian/lian.ex` | 10 | `kungfu/skill/suxin-jian/lian.c` |
| 152 | `taiji_jian/chan.ex` | 10 | `kungfu/skill/taiji-jian/chan.c` |
| 153 | `taiji_jian/sui.ex` | 4 | `kungfu/skill/taiji-jian/sui.c` |
| 154 | `taiji_jian/zhuan.ex` | 10 | `kungfu/skill/taiji-jian/zhuan.c` |
| 155 | `tangmen_throwing/biao.ex` | 19 | `kungfu/skill/tangmen-throwing/biao.c` |
| 156 | `tiangang_zhi/ling.ex` | 10 | `kungfu/skill/tiangang-zhi/ling.c` |
| 157 | `wudang_jian/sheng.ex` | 11 | `kungfu/skill/wudang-jian/sheng.c` |
| 158 | `xiyang_jian/ci.ex` | 10 | `kungfu/skill/xiyang-jian/ci.c` |
| 159 | `yunhe_jian/chong.ex` | 11 | `kungfu/skill/yunhe-jian/chong.c` |

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
