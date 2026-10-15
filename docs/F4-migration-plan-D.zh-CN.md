# Plan D — Remaining unplanned failing performs (F4 migration)

> 动态清单：每次全量严格验收扫描后重新生成，仅列出仍 FAIL 的未计划文件。
> 验收工具：`scripts/perf_acceptance.py`（`check_one`，严格 multiset 比对，MISSING=0 为 PASS）。
> 约定（沿用 plan A/B）：手工 `.ex` 必须保留 `# ===== 原始 LPC 源码 =====` 注释块；
> 文案字面量必须在代码字符串中（注释被验收工具剥除）；按 `scripts/protected_performs.txt` 登记保护；按顶层目录批次提交。

## 统计
- 剩余文件数：**135**
- 缺失字面量合计（miss 之和）：**1447**
- 严重度：A严重(>=15) / B中等(5-14) / C轻微(1-4)

| 严重度 | 文件数 | miss 合计 |
|--------|--------|-----------|
| A严重(>=15) | 12 | 233 |
| B中等(5-14) | 118 | 1196 |
| C轻微(1-4) | 5 | 18 |

## 按顶层目录分组（提交批次）

### bagua_biao（1 个）
- [ ] ❌ `bagua_biao/zhi.ex` ← `bagua-biao/zhi.c` (miss=11)

### bagua_dao（2 个）
- [ ] ❌ `bagua_dao/mang.ex` ← `bagua-dao/mang.c` (miss=13)
- [ ] ❌ `bagua_dao/sha.ex` ← `bagua-dao/sha.c` (miss=12)

### baibian_daxue（1 个）
- [ ] ❌ `baibian_daxue/dian.ex` ← `baibian-daxue/dian.c` (miss=9)

### baisheng_daofa（1 个）
- [ ] ❌ `baisheng_daofa/heng.ex` ← `baisheng-daofa/heng.c` (miss=17)

### baxian_jian（1 个）
- [ ] ❌ `baxian_jian/dian.ex` ← `baxian-jian/dian.c` (miss=11)

### bingpo_shenzhen（1 个）
- [ ] ❌ `bingpo_shenzhen/bing.ex` ← `bingpo-shenzhen/bing.c` (miss=20)

### bizhen_qingzhang（1 个）
- [ ] ❌ `bizhen_qingzhang/pengpai.ex` ← `bizhen-qingzhang/pengpai.c` (miss=12)

### caiyan_gong（1 个）
- [ ] ❌ `caiyan_gong/huan.ex` ← `caiyan-gong/huan.c` (miss=14)

### canghong_bifa（1 个）
- [ ] ❌ `canghong_bifa/jing.ex` ← `canghong-bifa/jing.c` (miss=11)

### chanhun_suo（2 个）
- [ ] ❌ `chanhun_suo/duo.ex` ← `chanhun-suo/duo.c` (miss=13)
- [ ] ❌ `chanhun_suo/suo.ex` ← `chanhun-suo/suo.c` (miss=10)

### chousui_zhang（1 个）
- [ ] ❌ `chousui_zhang/dan.ex` ← `chousui-zhang/dan.c` (miss=19)

### chuangwang_dao（1 个）
- [ ] ❌ `chuangwang_dao/xiong.ex` ← `chuangwang-dao/xiong.c` (miss=11)

### chuanxin_zhang（1 个）
- [ ] ❌ `chuanxin_zhang/zhui.ex` ← `chuanxin-zhang/zhui.c` (miss=8)

### chuanyue_jian（1 个）
- [ ] ❌ `chuanyue_jian/hao.ex` ← `chuanyue-jian/hao.c` (miss=11)

### dacheng_fosuo（1 个）
- [ ] ❌ `dacheng_fosuo/chanrao.ex` ← `dacheng-fosuo/chanrao.c` (miss=9)

### dagou_bang（2 个）
- [ ] ❌ `dagou_bang/ban.ex` ← `dagou-bang/ban.c` (miss=14)
- [ ] ❌ `dagou_bang/chuo.ex` ← `dagou-bang/chuo.c` (miss=10)

### dali_chu（1 个）
- [ ] ❌ `dali_chu/hong.ex` ← `dali-chu/hong.c` (miss=12)

### damo_jian（2 个）
- [ ] ❌ `damo_jian/sanjue.ex` ← `damo-jian/sanjue.c` (miss=8)
- [ ] ❌ `damo_jian/qingxin.ex` ← `damo-jian/qingxin.c` (miss=3)

### danding_dao（1 个）
- [ ] ❌ `danding_dao/kou.ex` ← `danding-dao/kou.c` (miss=10)

### daojian_guizhen（1 个）
- [ ] ❌ `daojian_guizhen/daojian.ex` ← `daojian-guizhen/daojian.c` (miss=23)

### dongyang_dao（1 个）
- [ ] ❌ `dongyang_dao/zhan.ex` ← `dongyang-dao/zhan.c` (miss=9)

### duanjia_sword（1 个）
- [ ] ❌ `duanjia_sword/jing.ex` ← `duanjia-sword/jing.c` (miss=9)

### duanyun_fu（1 个）
- [ ] ❌ `duanyun_fu/tiaoyan.ex` ← `duanyun-fu/tiaoyan.c` (miss=7)

### dugu_jiujian（2 个）
- [ ] ❌ `dugu_jiujian/qi.ex` ← `dugu-jiujian/qi.c` (miss=12)
- [ ] ❌ `dugu_jiujian/yi.ex` ← `dugu-jiujian/yi.c` (miss=10)

### duoluoye_zhi（1 个）
- [ ] ❌ `duoluoye_zhi/jimie.ex` ← `duoluoye-zhi/jimie.c` (miss=14)

### duoming_jinhua（1 个）
- [ ] ❌ `duoming_jinhua/hua.ex` ← `duoming-jinhua/hua.c` (miss=11)

### emei_jian（1 个）
- [ ] ❌ `emei_jian/xian.ex` ← `emei-jian/xian.c` (miss=10)

### fanliangyi_dao（2 个）
- [ ] ❌ `fanliangyi_dao/san.ex` ← `fanliangyi-dao/san.c` (miss=18)
- [ ] ❌ `fanliangyi_dao/makearray.ex` ← `fanliangyi-dao/makearray.c` (miss=8)

### feifeng_whip（1 个）
- [ ] ❌ `feifeng_whip/wu.ex` ← `feifeng-whip/wu.c` (miss=9)

### feilong_zhang（1 个）
- [ ] ❌ `feilong_zhang/fei.ex` ← `feilong-zhang/fei.c` (miss=11)

### feixing_shu（1 个）
- [ ] ❌ `feixing_shu/hua.ex` ← `feixing-shu/hua.c` (miss=12)

### fenglei_panfa（1 个）
- [ ] ❌ `fenglei_panfa/fenglei.ex` ← `fenglei-panfa/fenglei.c` (miss=19)

### fenglei_zifa（1 个）
- [ ] ❌ `fenglei_zifa/she.ex` ← `fenglei-zifa/she.c` (miss=7)

### fengyun_shou（1 个）
- [ ] ❌ `fengyun_shou/qinna.ex` ← `fengyun-shou/qinna.c` (miss=5)

### fireice_strike（1 个）
- [ ] ❌ `fireice_strike/binghuo.ex` ← `fireice-strike/binghuo.c` (miss=14)

### force（1 个）
- [ ] ❌ `force/power.ex` ← `force/power.c` (miss=25)

### fumo_jian（1 个）
- [ ] ❌ `fumo_jian/foxin.ex` ← `fumo-jian/foxin.c` (miss=11)

### fumo_zhang（1 个）
- [ ] ❌ `fumo_zhang/lun.ex` ← `fumo-zhang/lun.c` (miss=7)

### furong_jian（1 个）
- [ ] ❌ `furong_jian/luan.ex` ← `furong-jian/luan.c` (miss=9)

### furong_jinzhen（1 个）
- [ ] ❌ `furong_jinzhen/xian.ex` ← `furong-jinzhen/xian.c` (miss=4)

### guxing_jian（1 个）
- [ ] ❌ `guxing_jian/lian.ex` ← `guxing-jian/lian.c` (miss=10)

### guyue_chan（1 个）
- [ ] ❌ `guyue_chan/jing.ex` ← `guyue-chan/jing.c` (miss=9)

### hanmei_jian（1 个）
- [ ] ❌ `hanmei_jian/leng.ex` ← `hanmei-jian/leng.c` (miss=11)

### hansha_sheying（1 个）
- [ ] ❌ `hansha_sheying/zhen.ex` ← `hansha-sheying/zhen.c` (miss=11)

### hanwang_qingdao（1 个）
- [ ] ❌ `hanwang_qingdao/ying.ex` ← `hanwang-qingdao/ying.c` (miss=11)

### hanxing_bada（1 个）
- [ ] ❌ `hanxing_bada/lastrisk.ex` ← `hanxing-bada/lastrisk.c` (miss=7)

### heixue_shenzhen（1 个）
- [ ] ❌ `heixue_shenzhen/luo.ex` ← `heixue-shenzhen/luo.c` (miss=12)

### henshan_jian（1 个）
- [ ] ❌ `henshan_jian/huan.ex` ← `henshan-jian/huan.c` (miss=13)

### hexing_bifa（1 个）
- [ ] ❌ `hexing_bifa/dian.ex` ← `hexing-bifa/dian.c` (miss=9)

### hongye_daofa（1 个）
- [ ] ❌ `hongye_daofa/leiting.ex` ← `hongye-daofa/leiting.c` (miss=7)

### houquan（1 个）
- [ ] ❌ `houquan/zhen.ex` ← `houquan/zhen.c` (miss=8)

### huashan_jian（4 个）
- [ ] ❌ `huashan_jian/xian.ex` ← `huashan-jian/xian.c` (miss=16)
- [ ] ❌ `huashan_jian/lian.ex` ← `huashan-jian/lian.c` (miss=7)
- [ ] ❌ `huashan_jian/jie.ex` ← `huashan-jian/jie.c` (miss=6)
- [ ] ❌ `huashan_jian/long.ex` ← `huashan-jian/long.c` (miss=6)

### huifeng_jian（2 个）
- [ ] ❌ `huifeng_jian/jue.ex` ← `huifeng-jian/jue.c` (miss=25)
- [ ] ❌ `huifeng_jian/mie.ex` ← `huifeng-jian/mie.c` (miss=8)

### huilong_bifa（1 个）
- [ ] ❌ `huilong_bifa/cang.ex` ← `huilong-bifa/cang.c` (miss=8)

### hujia_daofa（2 个）
- [ ] ❌ `hujia_daofa/xian.ex` ← `hujia-daofa/xian.c` (miss=7)
- [ ] ❌ `hujia_daofa/zhui.ex` ← `hujia-daofa/zhui.c` (miss=5)

### jiandun_zhusuo（2 个）
- [ ] ❌ `jiandun_zhusuo/qian.ex` ← `jiandun-zhusuo/qian.c` (miss=16)
- [ ] ❌ `jiandun_zhusuo/fu.ex` ← `jiandun-zhusuo/fu.c` (miss=12)

### jidian_jian（1 个）
- [ ] ❌ `jidian_jian/dian.ex` ← `jidian-jian/dian.c` (miss=6)

### jimie_zhua（1 个）
- [ ] ❌ `jimie_zhua/wuwo.ex` ← `jimie-zhua/wuwo.c` (miss=4)

### jinbiao_jue（1 个）
- [ ] ❌ `jinbiao_jue/huan.ex` ← `jinbiao-jue/huan.c` (miss=10)

### jingang_quan（1 个）
- [ ] ❌ `jingang_quan/jingang.ex` ← `jingang-quan/jingang.c` (miss=12)

### jingang_zhi（1 个）
- [ ] ❌ `jingang_zhi/fumo.ex` ← `jingang-zhi/fumo.c` (miss=5)

### jinguan_yusuo（1 个）
- [ ] ❌ `jinguan_yusuo/suo.ex` ← `jinguan-yusuo/suo.c` (miss=9)

### jingyue_bifa（1 个）
- [ ] ❌ `jingyue_bifa/ci.ex` ← `jingyue-bifa/ci.c` (miss=12)

### jinshe_jian（1 个）
- [ ] ❌ `jinshe_jian/wan.ex` ← `jinshe-jian/wan.c` (miss=10)

### jinshe_zhui（1 个）
- [ ] ❌ `jinshe_zhui/tuwu.ex` ← `jinshe-zhui/tuwu.c` (miss=11)

### jiuqu_jian（1 个）
- [ ] ❌ `jiuqu_jian/wan.ex` ← `jiuqu-jian/wan.c` (miss=10)

### jueqing_jian（1 个）
- [ ] ❌ `jueqing_jian/liu.ex` ← `jueqing-jian/liu.c` (miss=12)

### kuangfeng_jian（1 个）
- [ ] ❌ `kuangfeng_jian/sao.ex` ← `kuangfeng-jian/sao.c` (miss=9)

### kuimang_dao（1 个）
- [ ] ❌ `kuimang_dao/pan.ex` ← `kuimang-dao/pan.c` (miss=11)

### kunlun_qifa（1 个）
- [ ] ❌ `kunlun_qifa/liu.ex` ← `kunlun-qifa/liu.c` (miss=11)

### lingbo_weibu（1 个）
- [ ] ❌ `lingbo_weibu/ling.ex` ← `lingbo-weibu/ling.c` (miss=3)

### lingshe_zhangfa（1 个）
- [ ] ❌ `lingshe_zhangfa/chan.ex` ← `lingshe-zhangfa/chan.c` (miss=9)

### liuhe_dao（1 个）
- [ ] ❌ `liuhe_dao/shan.ex` ← `liuhe-dao/shan.c` (miss=11)

### longcheng_shendao（1 个）
- [ ] ❌ `longcheng_shendao/feng.ex` ← `longcheng-shendao/feng.c` (miss=11)

### longxing_jian（1 个）
- [ ] ❌ `longxing_jian/kong.ex` ← `longxing-jian/kong.c` (miss=10)

### luohan_gun（1 个）
- [ ] ❌ `luohan_gun/xiangmo.ex` ← `luohan-gun/xiangmo.c` (miss=7)

### luohan_quan（1 个）
- [ ] ❌ `luohan_quan/xiangmo.ex` ← `luohan-quan/xiangmo.c` (miss=8)

### luoying_shenjian（1 个）
- [ ] ❌ `luoying_shenjian/sui.ex` ← `luoying-shenjian/sui.c` (miss=12)

### luoyun_dao（1 个）
- [ ] ❌ `luoyun_dao/tian.ex` ← `luoyun-dao/tian.c` (miss=11)

### lutou_zhang（1 个）
- [ ] ❌ `lutou_zhang/tong.ex` ← `lutou-zhang/tong.c` (miss=11)

### mantian_xing（1 个）
- [ ] ❌ `mantian_xing/shan.ex` ← `mantian-xing/shan.c` (miss=10)

### mantianhuayu_zhen（1 个）
- [ ] ❌ `mantianhuayu_zhen/zheng.ex` ← `mantianhuayu-zhen/zheng.c` (miss=11)

### miaojia_jian（1 个）
- [ ] ❌ `miaojia_jian/qian.ex` ← `miaojia-jian/qian.c` (miss=12)

### mingwang_jian（2 个）
- [ ] ❌ `mingwang_jian/ruo.ex` ← `mingwang-jian/ruo.c` (miss=12)
- [ ] ❌ `mingwang_jian/xiang.ex` ← `mingwang-jian/xiang.c` (miss=10)

### mizong_houquan（1 个）
- [ ] ❌ `mizong_houquan/zhou.ex` ← `mizong-houquan/zhou.c` (miss=16)

### nianhua_zhi（1 个）
- [ ] ❌ `nianhua_zhi/fuxue.ex` ← `nianhua-zhi/fuxue.c` (miss=10)

### ningxue_zhang（1 个）
- [ ] ❌ `ningxue_zhang/xue.ex` ← `ningxue-zhang/xue.c` (miss=8)

### pangen_cuojiefu（1 个）
- [ ] ❌ `pangen_cuojiefu/cuo.ex` ← `pangen-cuojiefu/cuo.c` (miss=13)

### panlong_suo（1 个）
- [ ] ❌ `panlong_suo/chan.ex` ← `panlong-suo/chan.c` (miss=13)

### pichen_jian（1 个）
- [ ] ❌ `pichen_jian/ao.ex` ← `pichen-jian/ao.c` (miss=10)

### pidi_shenzhen（1 个）
- [ ] ❌ `pidi_shenzhen/huan.ex` ← `pidi-shenzhen/huan.c` (miss=11)

### poguang_dao（1 个）
- [ ] ❌ `poguang_dao/bing.ex` ← `poguang-dao/bing.c` (miss=14)

### pomie_jinzhen（1 个）
- [ ] ❌ `pomie_jinzhen/du.ex` ← `pomie-jinzhen/du.c` (miss=13)

### qiankun_jian（2 个）
- [ ] ❌ `qiankun_jian/qian.ex` ← `qiankun-jian/qian.c` (miss=12)
- [ ] ❌ `qiankun_jian/riyue.ex` ← `qiankun-jian/riyue.c` (miss=11)

### qianye_shou（1 个）
- [ ] ❌ `qianye_shou/qianye.ex` ← `qianye-shou/qianye.c` (miss=8)

### qingliang_jian（1 个）
- [ ] ❌ `qingliang_jian/ming.ex` ← `qingliang-jian/ming.c` (miss=11)

### qishi_ji（1 个）
- [ ] ❌ `qishi_ji/juan.ex` ← `qishi-ji/juan.c` (miss=12)

### qiufeng_chenfa（1 个）
- [ ] ❌ `qiufeng_chenfa/chan.ex` ← `qiufeng-chenfa/chan.c` (miss=8)

### qiulin_shiye（1 个）
- [ ] ❌ `qiulin_shiye/wu.ex` ← `qiulin-shiye/wu.c` (miss=8)

### qixing_jian（1 个）
- [ ] ❌ `qixing_jian/xing.ex` ← `qixing-jian/xing.c` (miss=11)

### quanzhen_jian（2 个）
- [ ] ❌ `quanzhen_jian/chan.ex` ← `quanzhen-jian/chan.c` (miss=11)
- [ ] ❌ `quanzhen_jian/ding.ex` ← `quanzhen-jian/ding.c` (miss=11)

### raozhi_roujian（1 个）
- [ ] ❌ `raozhi_roujian/chuan.ex` ← `raozhi-roujian/chuan.c` (miss=11)

### riyue_bian（1 个）
- [ ] ❌ `riyue_bian/shang.ex` ← `riyue-bian/shang.c` (miss=8)

### ruanhong_zhusuo（1 个）
- [ ] ❌ `ruanhong_zhusuo/teng.ex` ← `ruanhong-zhusuo/teng.c` (miss=11)

### sanhua_zhang（1 个）
- [ ] ❌ `sanhua_zhang/san.ex` ← `sanhua-zhang/san.c` (miss=9)

### sanwu_shou（1 个）
- [ ] ❌ `sanwu_shou/wei.ex` ← `sanwu-shou/wei.c` (miss=12)

### shangjia_dao（1 个）
- [ ] ❌ `shangjia_dao/juan.ex` ← `shangjia-dao/juan.c` (miss=11)

### shunv_jian（1 个）
- [ ] ❌ `shunv_jian/ning.ex` ← `shunv-jian/ning.c` (miss=12)

### songshan_jian（1 个）
- [ ] ❌ `songshan_jian/meng.ex` ← `songshan-jian/meng.c` (miss=12)

### sun_finger（1 个）
- [ ] ❌ `sun_finger/dian.ex` ← `sun-finger/dian.c` (miss=8)

### suqin_beijian（1 个）
- [ ] ❌ `suqin_beijian/can.ex` ← `suqin-beijian/can.c` (miss=11)

### suxin_jian（1 个）
- [ ] ❌ `suxin_jian/lian.ex` ← `suxin-jian/lian.c` (miss=10)

### taiji_jian（3 个）
- [ ] ❌ `taiji_jian/chan.ex` ← `taiji-jian/chan.c` (miss=10)
- [ ] ❌ `taiji_jian/zhuan.ex` ← `taiji-jian/zhuan.c` (miss=10)
- [ ] ❌ `taiji_jian/sui.ex` ← `taiji-jian/sui.c` (miss=4)

### tangmen_throwing（1 个）
- [ ] ❌ `tangmen_throwing/biao.ex` ← `tangmen-throwing/biao.c` (miss=19)

### tiangang_zhi（1 个）
- [ ] ❌ `tiangang_zhi/ling.ex` ← `tiangang-zhi/ling.c` (miss=10)

### wudang_jian（1 个）
- [ ] ❌ `wudang_jian/sheng.ex` ← `wudang-jian/sheng.c` (miss=11)

### xiyang_jian（1 个）
- [ ] ❌ `xiyang_jian/ci.ex` ← `xiyang-jian/ci.c` (miss=10)

### yunhe_jian（1 个）
- [ ] ❌ `yunhe_jian/chong.ex` ← `yunhe-jian/chong.c` (miss=11)