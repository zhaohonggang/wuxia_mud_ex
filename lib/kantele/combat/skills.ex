defmodule Kantele.Combat.Skills do
  @moduledoc """
  武学注册表：技能 id -> 实现 module

  注册表=静态内建 `@skills` + 运行时增量（`:persistent_term`）。运行时可
  `register/2` 追加（测试注入新技能、启动时挂载更多武学），`unregister/1` 移除。
  """

  @static %{
    "liuxin-jian" => Kantele.Combat.Skills.LiuxinJian,
    "liuxi-neigong" => Kantele.Combat.Skills.LiuxiNeigong,
    "taiji-quan" => Kantele.Combat.Skills.TaijiQuan,
    "dugu-jiujian" => Kantele.Combat.Skills.DuguJiujian,
    "huashan-jian" => Kantele.Combat.Skills.HuashanJian,
    "chousui-zhang" => Kantele.Combat.Skills.ChousuiZhang,
    "force" => Kantele.Combat.Skills.Force,
    "bahuang-gong" => Kantele.Combat.Skills.BahuangGong,
    "bibo-shengong" => Kantele.Combat.Skills.BiboShengong,
    "changsheng-jue" => Kantele.Combat.Skills.ChangshengJue,
    "hunyuan-yiqi" => Kantele.Combat.Skills.HunyuanYiqi,
    "taiji-shengong" => Kantele.Combat.Skills.TaijiShengong,
    "xiaowuxiang" => Kantele.Combat.Skills.Xiaowuxiang,
    "xuanming-shengong" => Kantele.Combat.Skills.XuanmingShengong,
    "zhanshen-xinjing" => Kantele.Combat.Skills.ZhanshenXinjing,
    "xuantian-wujigong" => Kantele.Combat.Skills.XuantianWujigong,
    "shenghuo-shengong" => Kantele.Combat.Skills.ShenghuoShengong,
    "shenghuo-xinfa" => Kantele.Combat.Skills.ShenghuoXinfa,
    "xuanmen-neigong" => Kantele.Combat.Skills.XuanmenNeigong,
    "zixia-shengong" => Kantele.Combat.Skills.ZixiaShengong,
    "bingxin-jue" => Kantele.Combat.Skills.BingxinJue,
    "dahai-wuliang" => Kantele.Combat.Skills.DahaiWuliang,
    "duanshi-xinfa" => Kantele.Combat.Skills.DuanshiXinfa,
    "fushang-neigong" => Kantele.Combat.Skills.FushangNeigong,
    "huntian-qigong" => Kantele.Combat.Skills.HuntianQigong,
    "hongye-daofa" => Kantele.Combat.Skills.HongyeDaofa,
    "huifeng-jian" => Kantele.Combat.Skills.HuifengJian,
    "huilong-bifa" => Kantele.Combat.Skills.HuilongBifa,
    "hujia-daofa" => Kantele.Combat.Skills.HujiaDaofa,
    "fenxin-jue" => Kantele.Combat.Skills.FenxinJue,
    "hanbing-zhenqi" => Kantele.Combat.Skills.HanbingZhenqi,
    "freezing-force" => Kantele.Combat.Skills.FreezingForce,
    "kurong-changong" => Kantele.Combat.Skills.KurongChangong,
    "liangyi-shengong" => Kantele.Combat.Skills.LiangyiShengong,
    "miaojia-neigong" => Kantele.Combat.Skills.MiaojiaNeigong,
    "nei-bagua" => Kantele.Combat.Skills.NeiBagua,
    "wuwang-shengong" => Kantele.Combat.Skills.WuwangShengong,
    "tianhuan-shenjue" => Kantele.Combat.Skills.TianhuanShenjue,
    "tianlei-shengong" => Kantele.Combat.Skills.TianleiShengong,
    "xiuluo-yinshagong" => Kantele.Combat.Skills.XiuluoYinshagong,
    "xixing-dafa" => Kantele.Combat.Skills.XixingDafa,
    "surge-force" => Kantele.Combat.Skills.SurgeForce,
    "shenlong-xinfa" => Kantele.Combat.Skills.ShenlongXinfa,
    "lengyue-shengong" => Kantele.Combat.Skills.LengyueShengong,
    "huagong-dafa" => Kantele.Combat.Skills.HuagongDafa,
    "xiyang-neigong" => Kantele.Combat.Skills.XiyangNeigong,
    "xuehai-mogong" => Kantele.Combat.Skills.XuehaiMogong,
    "yijin-duangu" => Kantele.Combat.Skills.YijinDuangu,
    "yijinjing" => Kantele.Combat.Skills.Yijinjing,
    "yujiashu" => Kantele.Combat.Skills.Yujiashu,
    "yunlong-shengong" => Kantele.Combat.Skills.YunlongShengong,
    "yunv-xinjing" => Kantele.Combat.Skills.YunvXinjing,
    "zhenyue-jue" => Kantele.Combat.Skills.ZhenyueJue,
    "longxiang-gong" => Kantele.Combat.Skills.LongxiangGong,
    "linji-zhuang" => Kantele.Combat.Skills.LinjiZhuang,
    "zihui-xinfa" => Kantele.Combat.Skills.ZihuiXinfa,
    "biyun-xinfa" => Kantele.Combat.Skills.BiyunXinfa,
    "lingyuan-xinfa" => Kantele.Combat.Skills.LingyuanXinfa,
    "beiming-shengong" => Kantele.Combat.Skills.BeimingShengong,
    "luohan-fumogong" => Kantele.Combat.Skills.LuohanFumogong,
    "sanku-shengong" => Kantele.Combat.Skills.SankuShengong,
    "huagong-dafa" => Kantele.Combat.Skills.HuagongDafa,
    "xixing-dafa" => Kantele.Combat.Skills.XixingDafa,
    "zixia-shengong" => Kantele.Combat.Skills.ZixiaShengong,
    "hanbing-zhenqi" => Kantele.Combat.Skills.HanbingZhenqi,
    "bingxin-jue" => Kantele.Combat.Skills.BingxinJue,
    "rouyun-steps" => Kantele.Combat.Skills.RouyunSteps,
    "boyun-suowu" => Kantele.Combat.Skills.BoyunSuowu,
    "dagou-bang" => Kantele.Combat.Skills.DagouBang,
    "duanjia-jian" => Kantele.Combat.Skills.DuanjiaJian,
    "duanjia-sword" => Kantele.Combat.Skills.DuanjiaSword,
    "fenglei-zifa" => Kantele.Combat.Skills.FengleiZifa,
    "furong-jinzhen" => Kantele.Combat.Skills.FurongJinzhen,
    "riyue-bian" => Kantele.Combat.Skills.RiyueBian,
    "cibei-dao" => Kantele.Combat.Skills.CibeiDao,
    "damo-jian" => Kantele.Combat.Skills.DamoJian,
    "fanliangyi-dao" => Kantele.Combat.Skills.FanliangyiDao,
    "jingang-buhuaiti" => Kantele.Combat.Skills.JingangBuhuaiti,
    "jidian-jian" => Kantele.Combat.Skills.JidianJian,
    "jimie-zhua" => Kantele.Combat.Skills.JimieZhua,
    "jingang-zhi" => Kantele.Combat.Skills.JingangZhi,
    "jinzhong-zhao" => Kantele.Combat.Skills.JinzhongZhao,
    "lingbo-weibu" => Kantele.Combat.Skills.LingboWeibu,
    "kuangfeng-jian" => Kantele.Combat.Skills.KuangfengJian,
    "banruo-zhang" => Kantele.Combat.Skills.BanruoZhang,
    "longxing-jian" => Kantele.Combat.Skills.LongxingJian,
    "ranmu-daofa" => Kantele.Combat.Skills.RanmuDaofa,
    "riyue-lun" => Kantele.Combat.Skills.RiyueLun,
    "shenxing-baibian" => Kantele.Combat.Skills.ShenxingBaibian,
    "taiji-jian" => Kantele.Combat.Skills.TaijiJian,
    "chuangwang-dao" => Kantele.Combat.Skills.ChuangwangDao,
    "duanyun-fu" => Kantele.Combat.Skills.DuanyunFu,
    "emei-jian" => Kantele.Combat.Skills.EmeiJian,
    "hanmei-jian" => Kantele.Combat.Skills.HanmeiJian,
    "houquan" => Kantele.Combat.Skills.Houquan,
    "huoyan-dao" => Kantele.Combat.Skills.HuoyanDao,
    "henshan-jian" => Kantele.Combat.Skills.HenshanJian,
    "kuimang-dao" => Kantele.Combat.Skills.KuimangDao,
    "jueqing-jian" => Kantele.Combat.Skills.JueqingJian,
    "qixing-jian" => Kantele.Combat.Skills.QixingJian,
    "wudang-jian" => Kantele.Combat.Skills.WudangJian,
    "liuhe-dao" => Kantele.Combat.Skills.LiuheDao,
    "qingliang-jian" => Kantele.Combat.Skills.QingliangJian,
    "hanwang-qingdao" => Kantele.Combat.Skills.HanwangQingdao,
    "qishi-ji" => Kantele.Combat.Skills.QishiJi,
    "qiufeng-chenfa" => Kantele.Combat.Skills.QiufengChenfa,
    "suqin-beijian" => Kantele.Combat.Skills.SuqinBeijian,
    "suxin-jian" => Kantele.Combat.Skills.SuxinJian,
    "xiyang-jian" => Kantele.Combat.Skills.XiyangJian,
    "shangjia-dao" => Kantele.Combat.Skills.ShangjiaDao,
    "songshan-jian" => Kantele.Combat.Skills.SongshanJian,
    "luohan-quan" => Kantele.Combat.Skills.LuohanQuan,
    "luohan-gun" => Kantele.Combat.Skills.LuohanGun,
    "lutou-zhang" => Kantele.Combat.Skills.LutouZhang,
    "pichen-jian" => Kantele.Combat.Skills.PichenJian,
    "shunv-jian" => Kantele.Combat.Skills.ShunvJian,
    "mingwang-jian" => Kantele.Combat.Skills.MingwangJian,
    "yunhe-jian" => Kantele.Combat.Skills.YunheJian,
    "qiankun-jian" => Kantele.Combat.Skills.QiankunJian,
    "quanzhen-jian" => Kantele.Combat.Skills.QuanzhenJian,
    "raozhi-roujian" => Kantele.Combat.Skills.RaozhiRoujian,
    "ruanhong-zhusuo" => Kantele.Combat.Skills.RuanhongZhusuo,
    "sanhua-zhang" => Kantele.Combat.Skills.SanhuaZhang,
    "sanwu-shou" => Kantele.Combat.Skills.SanwuShou,
    "qianye-shou" => Kantele.Combat.Skills.QianyeShou,
    "bagua-biao" => Kantele.Combat.Skills.BaguaBiao,
    "chanhun-suo" => Kantele.Combat.Skills.ChanhunSuo,
    "dacheng-fosuo" => Kantele.Combat.Skills.DachengFosuo,
    "guxing-jian" => Kantele.Combat.Skills.GuxingJian,
    "guyue-chan" => Kantele.Combat.Skills.GuyueChan,
    "hansha-sheying" => Kantele.Combat.Skills.HanshaSheying,
    "jinbiao-jue" => Kantele.Combat.Skills.JinbiaoJue,
    "duoming-jinhua" => Kantele.Combat.Skills.DuomingJinhua,
    "duoluoye-zhi" => Kantele.Combat.Skills.DuoluoyeZhi,
    "feixing-shu" => Kantele.Combat.Skills.FeixingShu,
    "feifeng-whip" => Kantele.Combat.Skills.FeifengWhip,
    "feilong-zhang" => Kantele.Combat.Skills.FeilongZhang,
    "fenglei-panfa" => Kantele.Combat.Skills.FengleiPanfa,
    "fengyun-shou" => Kantele.Combat.Skills.FengyunShou,
    "fireice-strike" => Kantele.Combat.Skills.FireiceStrike,
    "fumo-jian" => Kantele.Combat.Skills.FumoJian,
    "fumo-zhang" => Kantele.Combat.Skills.FumoZhang,
    "furong-jian" => Kantele.Combat.Skills.FurongJian,
    "heixue-shenzhen" => Kantele.Combat.Skills.HeixueShenzhen,
    "damo-jian" => Kantele.Combat.Skills.DamoJian,
    "jiandun-zhusuo" => Kantele.Combat.Skills.JiandunZhusuo,
    "jingyue-bifa" => Kantele.Combat.Skills.JingyueBifa,
    "baibian-daxue" => Kantele.Combat.Skills.BaibianDaxue,
    "bingpo-shenzhen" => Kantele.Combat.Skills.BingpoShenzhen,
    "hanxing-bada" => Kantele.Combat.Skills.HanxingBada,
    "hexing-bifa" => Kantele.Combat.Skills.HexingBifa,
    "jingang-quan" => Kantele.Combat.Skills.JingangQuan,
    "jinguan-yusuo" => Kantele.Combat.Skills.JinguanYusuo,
    "jinshe-jian" => Kantele.Combat.Skills.JinsheJian,
    "jinshe-zhui" => Kantele.Combat.Skills.JinsheZhui,
    "jiuqu-jian" => Kantele.Combat.Skills.JiuquJian,
    "kunlun-qifa" => Kantele.Combat.Skills.KunlunQifa,
    "lingshe-zhangfa" => Kantele.Combat.Skills.LingsheZhangfa,
    "longcheng-shendao" => Kantele.Combat.Skills.LongchengShendao,
    "longxing-jian" => Kantele.Combat.Skills.LongxingJian,
    "luoying-shenjian" => Kantele.Combat.Skills.LuoyingShenjian,
    "luoyun-dao" => Kantele.Combat.Skills.LuoyunDao,
    "mantian-xing" => Kantele.Combat.Skills.MantianXing,
    "mantianhuayu-zhen" => Kantele.Combat.Skills.MantianhuayuZhen,
    "mingwang-jian" => Kantele.Combat.Skills.MingwangJian,
    "mizong-houquan" => Kantele.Combat.Skills.MizongHouquan,
    "nianhua-zhi" => Kantele.Combat.Skills.NianhuaZhi,
    "ningxue-zhang" => Kantele.Combat.Skills.NingxueZhang,
    "pangen-cuojiefu" => Kantele.Combat.Skills.PangenCuojiefu,
    "panlong-suo" => Kantele.Combat.Skills.PanlongSuo,
    "pidi-shenzhen" => Kantele.Combat.Skills.PidiShenzhen,
    "miaojia-jian" => Kantele.Combat.Skills.MiaojiaJian,
    "poguang-dao" => Kantele.Combat.Skills.PoguangDao,
    "pomie-jinzhen" => Kantele.Combat.Skills.PomieJinzhen,
    "qiankun-jian" => Kantele.Combat.Skills.QiankunJian,
    "qiulin-shiye" => Kantele.Combat.Skills.QiulinShiye,
    "sun-finger" => Kantele.Combat.Skills.SunFinger,
    "taiji-jian" => Kantele.Combat.Skills.TaijiJian,
    "tangmen-throwing" => Kantele.Combat.Skills.TangmenThrowing,
    "tiangang-zhi" => Kantele.Combat.Skills.TiangangZhi,
    "sougu" => Kantele.Combat.Skills.Sougu,
    "bagua-dao" => Kantele.Combat.Skills.BaguaDao,
    "baisheng-daofa" => Kantele.Combat.Skills.BaishengDaofa,
    "baxian-jian" => Kantele.Combat.Skills.BaxianJian,
    "bizhen-qingzhang" => Kantele.Combat.Skills.BizhenQingzhang,
    "caiyan-gong" => Kantele.Combat.Skills.CaiyanGong,
    "canghong-bifa" => Kantele.Combat.Skills.CanghongBifa,
    "chanhun-suo" => Kantele.Combat.Skills.ChanhunSuo,
    "chuanxin-zhang" => Kantele.Combat.Skills.ChuanxinZhang,
    "chuanyue-jian" => Kantele.Combat.Skills.ChuanyueJian,
    "dagou-bang" => Kantele.Combat.Skills.DagouBang,
    "dali-chu" => Kantele.Combat.Skills.DaliChu,
    "danding-dao" => Kantele.Combat.Skills.DandingDao,
    "daojian-guizhen" => Kantele.Combat.Skills.DaojianGuizhen,
    "dongyang-dao" => Kantele.Combat.Skills.DongyangDao,
    # 六个「绝学内功」（`inherit FORCE`）：LPC 招式表变量名是 `actionf`/`actionw`，
    # 之前既没进注册表、招式表也在生成时整表丢失，等于 `enable` 报「没有这项武功」。
    # 现按源补齐双表 + `valid_enable`（含九阳/九阴/太玄的 this_player 分支）。
    "bluesea-force" => Kantele.Combat.Skills.BlueseaForce,
    "jiuyang-shengong" => Kantele.Combat.Skills.JiuyangShengong,
    "jiuyin-shengong" => Kantele.Combat.Skills.JiuyinShengong,
    "kuihua-mogong" => Kantele.Combat.Skills.KuihuaMogong,
    "taixuan-gong" => Kantele.Combat.Skills.TaixuanGong,
    "zhonghua-aojue" => Kantele.Combat.Skills.ZhonghuaAojue,
    # 不败神功：招式表变量名是 `action_default` / `action_whip`（按武器 skill_type 分表），
    # 同样在生成时整表丢失 + 没进注册表。现按源补齐（`valid_enable` 11 项）。
    "never-defeated" => Kantele.Combat.Skills.NeverDefeated,
    # hit_ob 批次（C-PVE23）：这些模块早已生成且招式表非空（1~18 式），但从未
    # 进注册表 → `Skills.get/1` 返回 nil，`enable` 报「没有这项武功」，且引擎
    # 的 `hit_ob` / `valid_damage` 钩子永不触发（死代码）。此处一并注册。
    "dabei-zhang" => Kantele.Combat.Skills.DabeiZhang,
    "guanchong-sword" => Kantele.Combat.Skills.GuanchongSword,
    "jiuqu-zhegufa" => Kantele.Combat.Skills.JiuquZhegufa,
    "jiuyin-baiguzhao" => Kantele.Combat.Skills.JiuyinBaiguzhao,
    "piaoxue-zhang" => Kantele.Combat.Skills.PiaoxueZhang,
    "pixie-jian" => Kantele.Combat.Skills.PixieJian,
    "sad-strike" => Kantele.Combat.Skills.SadStrike,
    "shangyang-sword" => Kantele.Combat.Skills.ShangyangSword,
    "shaochong-sword" => Kantele.Combat.Skills.ShaochongSword,
    "shaoshang-sword" => Kantele.Combat.Skills.ShaoshangSword,
    "shaoze-sword" => Kantele.Combat.Skills.ShaozeSword,
    "shou-yin" => Kantele.Combat.Skills.ShouYin,
    "tie-zhang" => Kantele.Combat.Skills.TieZhang,
    "xianglong-zhang" => Kantele.Combat.Skills.XianglongZhang,
    "zhongchong-sword" => Kantele.Combat.Skills.ZhongchongSword,
    # hit_ob 中毒系批次（C-PVE23 选项 2）：同上，这些模块早已生成且招式表非空，
    # 但从未进注册表 → `Skills.get/1` 返回 nil，引擎 hit_ob 钩子永不触发（死代码）。
    # 现一并注册，使其 `hit_ob` 上毒效果生效。
    "bingcan-duzhang" => Kantele.Combat.Skills.BingcanDuzhang,
    "cuixin-zhang" => Kantele.Combat.Skills.CuixinZhang,
    "dusha-zhang" => Kantele.Combat.Skills.DushaZhang,
    "hanbing-mianzhang" => Kantele.Combat.Skills.HanbingMianzhang,
    "heisha-zhang" => Kantele.Combat.Skills.HeishaZhang,
    "huagu-mianzhang" => Kantele.Combat.Skills.HuaguMianzhang,
    "lansha-shou" => Kantele.Combat.Skills.LanshaShou,
    "ningxue-shenzhao" => Kantele.Combat.Skills.NingxueShenzhao,
    "qianzhu-wandushou" => Kantele.Combat.Skills.QianzhuWandushou,
    "shenzhaojing" => Kantele.Combat.Skills.Shenzhaojing,
    "tougu-zhen" => Kantele.Combat.Skills.TouguZhen,
    "xuanming-zhang" => Kantele.Combat.Skills.XuanmingZhang,
    "xuantian-zhi" => Kantele.Combat.Skills.XuantianZhi,
    "yinfeng-dao" => Kantele.Combat.Skills.YinfengDao,
    "bagua-xinfa" => Kantele.Combat.Skills.BaguaXinfa,
    "baituo-xinfa" => Kantele.Combat.Skills.BaituoXinfa,
    "emei-xinfa" => Kantele.Combat.Skills.EmeiXinfa,
    "guixi-gong" => Kantele.Combat.Skills.GuixiGong,
    "henshan-xinfa" => Kantele.Combat.Skills.HenshanXinfa,
    "honghua-xinfa" => Kantele.Combat.Skills.HonghuaXinfa,
    "huashan-xinfa" => Kantele.Combat.Skills.HuashanXinfa,
    "jiaohua-neigong" => Kantele.Combat.Skills.JiaohuaNeigong,
    "jueqing-xinfa" => Kantele.Combat.Skills.JueqingXinfa,
    "kunlun-xinfa" => Kantele.Combat.Skills.KunlunXinfa,
    "lingjiu-xinfa" => Kantele.Combat.Skills.LingjiuXinfa,
    "luoying-xinfa" => Kantele.Combat.Skills.LuoyingXinfa,
    "minggu-xinfa" => Kantele.Combat.Skills.MingguXinfa,
    "mizong-neigong" => Kantele.Combat.Skills.MizongNeigong,
    "murong-xinfa" => Kantele.Combat.Skills.MurongXinfa,
    "qingcheng-neigong" => Kantele.Combat.Skills.QingchengNeigong,
    "quanzhen-xinfa" => Kantele.Combat.Skills.QuanzhenXinfa,
    "riyue-xinfa" => Kantele.Combat.Skills.RiyueXinfa,
    "shangjia-neigong" => Kantele.Combat.Skills.ShangjiaNeigong,
    "shaolin-xinfa" => Kantele.Combat.Skills.ShaolinXinfa,
    "songshan-xinfa" => Kantele.Combat.Skills.SongshanXinfa,
    "suxin-jue" => Kantele.Combat.Skills.SuxinJue,
    "tiezhang-xinfa" => Kantele.Combat.Skills.TiezhangXinfa,
    "wudang-xinfa" => Kantele.Combat.Skills.WudangXinfa,
    "wudu-xinfa" => Kantele.Combat.Skills.WuduXinfa,
    "wuliang-xinfa" => Kantele.Combat.Skills.WuliangXinfa,
    "wuzheng-xinfa" => Kantele.Combat.Skills.WuzhengXinfa,
    "xiaoyao-xinfa" => Kantele.Combat.Skills.XiaoyaoXinfa,
    "xueshan-neigong" => Kantele.Combat.Skills.XueshanNeigong,
    "yaogu-xinfa" => Kantele.Combat.Skills.YaoguXinfa,
    "hamagong" => Kantele.Combat.Skills.Hamagong,
    "xiantian-gong" => Kantele.Combat.Skills.XiantianGong,
    "xuedao-dafa" => Kantele.Combat.Skills.XuedaoDafa,
    "shennong-xinjing" => Kantele.Combat.Skills.ShennongXinjing,
    "tianchi-neigong" => Kantele.Combat.Skills.TianchiNeigong,
    "yunv-xinfa" => Kantele.Combat.Skills.YunvXinfa,
    # --- 白名单补全 batch1：有静态招式、无 performs、无自定义门槛的门派特技（2026-10-31）---
    "badao-daofa" => Kantele.Combat.Skills.BadaoDaofa,
    "cha-quan" => Kantele.Combat.Skills.ChaQuan,
    "changquan" => Kantele.Combat.Skills.Changquan,
    "chongling-jian" => Kantele.Combat.Skills.ChonglingJian,
    "da-qinna" => Kantele.Combat.Skills.DaQinna,
    "datianlong-zhi" => Kantele.Combat.Skills.DatianlongZhi,
    "emei-jiuyang" => Kantele.Combat.Skills.EmeiJiuyang,
    "feilong-shou" => Kantele.Combat.Skills.FeilongShou,
    "fuhu-quan" => Kantele.Combat.Skills.FuhuQuan,
    "hengshan-jian" => Kantele.Combat.Skills.HengshanJian,
    "hengshan-sword" => Kantele.Combat.Skills.HengshanSword,
    "hongjian-yulu" => Kantele.Combat.Skills.HongjianYulu,
    "huashan-quanfa" => Kantele.Combat.Skills.HuashanQuanfa,
    "huashan-zhangfa" => Kantele.Combat.Skills.HuashanZhangfa,
    "jiaohua-bangfa" => Kantele.Combat.Skills.JiaohuaBangfa,
    "juemen-gun" => Kantele.Combat.Skills.JuemenGun,
    "lianhua-zhi" => Kantele.Combat.Skills.LianhuaZhi,
    "liuhe-quan" => Kantele.Combat.Skills.LiuheQuan,
    "liuxing-chui" => Kantele.Combat.Skills.LiuxingChui,
    "paiyun-shou" => Kantele.Combat.Skills.PaiyunShou,
    "piaomiao-zhang" => Kantele.Combat.Skills.PiaomiaoZhang,
    "pixie-sword" => Kantele.Combat.Skills.PixieSword,
    "pona-gong" => Kantele.Combat.Skills.PonaGong,
    "qianlong-wuyong" => Kantele.Combat.Skills.QianlongWuyong,
    "qilian-zhi" => Kantele.Combat.Skills.QilianZhi,
    "qingmang-zhang" => Kantele.Combat.Skills.QingmangZhang,
    "qinna-shibada" => Kantele.Combat.Skills.QinnaShibada,
    "qixing-gun" => Kantele.Combat.Skills.QixingGun,
    "qixing-zhi" => Kantele.Combat.Skills.QixingZhi,
    "shaolin-jiuyang" => Kantele.Combat.Skills.ShaolinJiuyang,
    "shaolin-quan" => Kantele.Combat.Skills.ShaolinQuan,
    "shaolin-tantui" => Kantele.Combat.Skills.ShaolinTantui,
    "shenfeng-bian" => Kantele.Combat.Skills.ShenfengBian,
    "shenlong-baiwei" => Kantele.Combat.Skills.ShenlongBaiwei,
    "shennong-zhang" => Kantele.Combat.Skills.ShennongZhang,
    "siji-jianfa" => Kantele.Combat.Skills.SijiJianfa,
    "songfeng-jian" => Kantele.Combat.Skills.SongfengJian,
    "songshan-sword" => Kantele.Combat.Skills.SongshanSword,
    "suoming-zhang" => Kantele.Combat.Skills.SuomingZhang,
    "taiji-dao" => Kantele.Combat.Skills.TaijiDao,
    "taishan-sword" => Kantele.Combat.Skills.TaishanSword,
    "tianzhu-fuzhi" => Kantele.Combat.Skills.TianzhuFuzhi,
    "wudang-jiuyang" => Kantele.Combat.Skills.WudangJiuyang,
    "wudang-zhang" => Kantele.Combat.Skills.WudangZhang,
    "xiao-qinna" => Kantele.Combat.Skills.XiaoQinna,
    "yanqing-quan" => Kantele.Combat.Skills.YanqingQuan,
    "yipai-liangsan" => Kantele.Combat.Skills.YipaiLiangsan,
    "youming-zhi" => Kantele.Combat.Skills.YoumingZhi,
    "yunlong-shou" => Kantele.Combat.Skills.YunlongShou,
    "yunlong-zhua" => Kantele.Combat.Skills.YunlongZhua,
    "zhenjing-baili" => Kantele.Combat.Skills.ZhenjingBaili,
    "zuiquan-sanda" => Kantele.Combat.Skills.ZuiquanSanda,
    # --- 白名单补全 batch2：有招式 + 带 performs 的门派特技（2026-10-31）---
    "bagua-quan" => Kantele.Combat.Skills.BaguaQuan,
    "bagua-zhang" => Kantele.Combat.Skills.BaguaZhang,
    "baihua-cuoquan" => Kantele.Combat.Skills.BaihuaCuoquan,
    "baihua-quan" => Kantele.Combat.Skills.BaihuaQuan,
    "baisheng-quan" => Kantele.Combat.Skills.BaishengQuan,
    "bazhen-zhang" => Kantele.Combat.Skills.BazhenZhang,
    "benlei-zhang" => Kantele.Combat.Skills.BenleiZhang,
    "biluo-zhang" => Kantele.Combat.Skills.BiluoZhang,
    "biyan-dao" => Kantele.Combat.Skills.BiyanDao,
    "canglang-zhi" => Kantele.Combat.Skills.CanglangZhi,
    "canhe-zhi" => Kantele.Combat.Skills.CanheZhi,
    "chansi-shou" => Kantele.Combat.Skills.ChansiShou,
    "chilian-shenzhang" => Kantele.Combat.Skills.ChilianShenzhang,
    "chongtian-zhang" => Kantele.Combat.Skills.ChongtianZhang,
    "chongyang-shenzhang" => Kantele.Combat.Skills.ChongyangShenzhang,
    "chuncan-zhang" => Kantele.Combat.Skills.ChuncanZhang,
    "dacidabei-shou" => Kantele.Combat.Skills.DacidabeiShou,
    "dashou-yin" => Kantele.Combat.Skills.DashouYin,
    "dragon-strike" => Kantele.Combat.Skills.DragonStrike,
    "dulong-shenzhua" => Kantele.Combat.Skills.DulongShenzhua,
    "feifeng-bian" => Kantele.Combat.Skills.FeifengBian,
    "feihua-zhang" => Kantele.Combat.Skills.FeihuaZhang,
    "fengmo-zhang" => Kantele.Combat.Skills.FengmoZhang,
    "guanri-jian" => Kantele.Combat.Skills.GuanriJian,
    "guhong-zhang" => Kantele.Combat.Skills.GuhongZhang,
    "gun" => Kantele.Combat.Skills.Gun,
    "guzhuo-zhang" => Kantele.Combat.Skills.GuzhuoZhang,
    "haotian-zhang" => Kantele.Combat.Skills.HaotianZhang,
    "henshan-quan" => Kantele.Combat.Skills.HenshanQuan,
    "honglian-dao" => Kantele.Combat.Skills.HonglianDao,
    "hua-quan" => Kantele.Combat.Skills.HuaQuan,
    "huashan-quan" => Kantele.Combat.Skills.HuashanQuan,
    "huashan-zhang" => Kantele.Combat.Skills.HuashanZhang,
    "huilong-zhang" => Kantele.Combat.Skills.HuilongZhang,
    "hujia-quan" => Kantele.Combat.Skills.HujiaQuan,
    "hunyuan-zhang" => Kantele.Combat.Skills.HunyuanZhang,
    "huzhua-shou" => Kantele.Combat.Skills.HuzhuaShou,
    "jiasha-fumogong" => Kantele.Combat.Skills.JiashaFumogong,
    "jiechen-dao" => Kantele.Combat.Skills.JiechenDao,
    "jieshou-jiushi" => Kantele.Combat.Skills.JieshouJiushi,
    "jifeng-cixuefa" => Kantele.Combat.Skills.JifengCixuefa,
    "jinding-zhang" => Kantele.Combat.Skills.JindingZhang,
    "jingzhong-bafa" => Kantele.Combat.Skills.JingzhongBafa,
    "jinwu-daofa" => Kantele.Combat.Skills.JinwuDaofa,
    "jinwu-goufa" => Kantele.Combat.Skills.JinwuGoufa,
    "jinyu-quan" => Kantele.Combat.Skills.JinyuQuan,
    "jinyuan-gun" => Kantele.Combat.Skills.JinyuanGun,
    "jueming-tui" => Kantele.Combat.Skills.JuemingTui,
    "jueqing-zhang" => Kantele.Combat.Skills.JueqingZhang,
    "kongming-quan" => Kantele.Combat.Skills.KongmingQuan,
    "kuangfeng-blade" => Kantele.Combat.Skills.KuangfengBlade,
    "kunlun-jian" => Kantele.Combat.Skills.KunlunJian,
    "kunlun-zhang" => Kantele.Combat.Skills.KunlunZhang,
    "lanhua-shou" => Kantele.Combat.Skills.LanhuaShou,
    "leiming-bian" => Kantele.Combat.Skills.LeimingBian,
    "liangyi-jian" => Kantele.Combat.Skills.LiangyiJian,
    "lianhuan-mizongtui" => Kantele.Combat.Skills.LianhuanMizongtui,
    "lingshe-quan" => Kantele.Combat.Skills.LingsheQuan,
    "lingxiao-quan" => Kantele.Combat.Skills.LingxiaoQuan,
    "liuhe-bian" => Kantele.Combat.Skills.LiuheBian,
    "liuhe-zhang" => Kantele.Combat.Skills.LiuheZhang,
    "liumai-shenjian" => Kantele.Combat.Skills.LiumaiShenjian,
    "liuyang-zhang" => Kantele.Combat.Skills.LiuyangZhang,
    "liuyue-jian" => Kantele.Combat.Skills.LiuyueJian,
    "liuyun-zhang" => Kantele.Combat.Skills.LiuyunZhang,
    "longzhua-gong" => Kantele.Combat.Skills.LongzhuaGong,
    "luohan-jian" => Kantele.Combat.Skills.LuohanJian,
    "luoyan-jian" => Kantele.Combat.Skills.LuoyanJian,
    "luoying-shenzhang" => Kantele.Combat.Skills.LuoyingShenzhang,
    "meinv-quan" => Kantele.Combat.Skills.MeinvQuan,
    "miaojia-zhang" => Kantele.Combat.Skills.MiaojiaZhang,
    "murong-jian" => Kantele.Combat.Skills.MurongJian,
    "murong-sword" => Kantele.Combat.Skills.MurongSword,
    "pangu-qishi" => Kantele.Combat.Skills.PanguQishi,
    "panyang-zhang" => Kantele.Combat.Skills.PanyangZhang,
    "piaofeng-quan" => Kantele.Combat.Skills.PiaofengQuan,
    "piaoxu-zhang" => Kantele.Combat.Skills.PiaoxuZhang,
    "pikong-zhang" => Kantele.Combat.Skills.PikongZhang,
    "pili-quan" => Kantele.Combat.Skills.PiliQuan,
    "pili-shou" => Kantele.Combat.Skills.PiliShou,
    "pobei-tui" => Kantele.Combat.Skills.PobeiTui,
    "pokong-quan" => Kantele.Combat.Skills.PokongQuan,
    "pomopima-jian" => Kantele.Combat.Skills.PomopimaJian,
    "poshui-zhang" => Kantele.Combat.Skills.PoshuiZhang,
    "poxu-daxuefa" => Kantele.Combat.Skills.PoxuDaxuefa,
    "poyu-quan" => Kantele.Combat.Skills.PoyuQuan,
    "poyue-zhao" => Kantele.Combat.Skills.PoyueZhao,
    "pudu-zhang" => Kantele.Combat.Skills.PuduZhang,
    "qiantian-zhi" => Kantele.Combat.Skills.QiantianZhi,
    "qingliang-daxuefa" => Kantele.Combat.Skills.QingliangDaxuefa,
    "qingyun-shou" => Kantele.Combat.Skills.QingyunShou,
    "qishang-quan" => Kantele.Combat.Skills.QishangQuan,
    "qixing-quan" => Kantele.Combat.Skills.QixingQuan,
    "qixing-shou" => Kantele.Combat.Skills.QixingShou,
    "quemen-jian" => Kantele.Combat.Skills.QuemenJian,
    "qufannao-zhi" => Kantele.Combat.Skills.QufannaoZhi,
    "qujing-gunfa" => Kantele.Combat.Skills.QujingGunfa,
    "rouyun-jian" => Kantele.Combat.Skills.RouyunJian,
    "rulai-zhang" => Kantele.Combat.Skills.RulaiZhang,
    "ruyi-dao" => Kantele.Combat.Skills.RuyiDao,
    "ruying-suixingtui" => Kantele.Combat.Skills.RuyingSuixingtui,
    "sanfen-jianshu" => Kantele.Combat.Skills.SanfenJianshu,
    "sanyin-shou" => Kantele.Combat.Skills.SanyinShou,
    "sanyin-wugongzhao" => Kantele.Combat.Skills.SanyinWugongzhao,
    "shangqing-jian" => Kantele.Combat.Skills.ShangqingJian,
    "shedao-qigong" => Kantele.Combat.Skills.ShedaoQigong,
    "shedu-qiqiao" => Kantele.Combat.Skills.SheduQiqiao,
    "shenghuo-ling" => Kantele.Combat.Skills.ShenghuoLing,
    "shenlong-bashi" => Kantele.Combat.Skills.ShenlongBashi,
    "shenmen-jian" => Kantele.Combat.Skills.ShenmenJian,
    "shenzhang-bada" => Kantele.Combat.Skills.ShenzhangBada,
    "shexing-lifan" => Kantele.Combat.Skills.ShexingLifan,
    "shigu-bifa" => Kantele.Combat.Skills.ShiguBifa,
    "shilin-jian" => Kantele.Combat.Skills.ShilinJian,
    "shiying-lianhuan" => Kantele.Combat.Skills.ShiyingLianhuan,
    "six-finger" => Kantele.Combat.Skills.SixFinger,
    "sixiang-zhang" => Kantele.Combat.Skills.SixiangZhang,
    "songshan-quan" => Kantele.Combat.Skills.SongshanQuan,
    "songshan-zhang" => Kantele.Combat.Skills.SongshanZhang,
    "sougu-yingzhua" => Kantele.Combat.Skills.SouguYingzhua,
    "suohou-gong" => Kantele.Combat.Skills.SuohouGong,
    "tan-tui" => Kantele.Combat.Skills.TanTui,
    "tianchan-zhang" => Kantele.Combat.Skills.TianchanZhang,
    "tianchang-zhang" => Kantele.Combat.Skills.TianchangZhang,
    "tiangang-chenfa" => Kantele.Combat.Skills.TiangangChenfa,
    "tianjue-dao" => Kantele.Combat.Skills.TianjueDao,
    "tianlei-dao" => Kantele.Combat.Skills.TianleiDao,
    "tianlong-jian" => Kantele.Combat.Skills.TianlongJian,
    "tianluo-diwang" => Kantele.Combat.Skills.TianluoDiwang,
    "tianshan-zhang" => Kantele.Combat.Skills.TianshanZhang,
    "tianyu-qijian" => Kantele.Combat.Skills.TianyuQijian,
    "tianzhu-jian" => Kantele.Combat.Skills.TianzhuJian,
    "tiexian-quan" => Kantele.Combat.Skills.TiexianQuan,
    "tiexue-dao" => Kantele.Combat.Skills.TiexueDao,
    "tongbi-zhang" => Kantele.Combat.Skills.TongbiZhang,
    "tongchui-zhang" => Kantele.Combat.Skills.TongchuiZhang,
    "tonggui-jian" => Kantele.Combat.Skills.TongguiJian,
    "weituo-chu" => Kantele.Combat.Skills.WeituoChu,
    "weituo-gun" => Kantele.Combat.Skills.WeituoGun,
    "woshi-zhang" => Kantele.Combat.Skills.WoshiZhang,
    "wuchang-zhang" => Kantele.Combat.Skills.WuchangZhang,
    "wudoumi-shengong" => Kantele.Combat.Skills.WudoumiShengong,
    "wudu-shenzhang" => Kantele.Combat.Skills.WuduShenzhang,
    "wuhu-duanmendao" => Kantele.Combat.Skills.WuhuDuanmendao,
    "wuliang-jian" => Kantele.Combat.Skills.WuliangJian,
    "wuluo-zhang" => Kantele.Combat.Skills.WuluoZhang,
    "wusheng-zhao" => Kantele.Combat.Skills.WushengZhao,
    "wuxiang-zhi" => Kantele.Combat.Skills.WuxiangZhi,
    "wuzhan-mei" => Kantele.Combat.Skills.WuzhanMei,
    "xiangmo-chu" => Kantele.Combat.Skills.XiangmoChu,
    "xiaoyao-jian" => Kantele.Combat.Skills.XiaoyaoJian,
    "xiaoyaoyou" => Kantele.Combat.Skills.Xiaoyaoyou,
    "xiewei-bian" => Kantele.Combat.Skills.XieweiBian,
    "xiuluo-dao" => Kantele.Combat.Skills.XiuluoDao,
    "xiuluo-zhi" => Kantele.Combat.Skills.XiuluoZhi,
    "xuanfeng-tui" => Kantele.Combat.Skills.XuanfengTui,
    "xuangong-quan" => Kantele.Combat.Skills.XuangongQuan,
    "xuantie-jian" => Kantele.Combat.Skills.XuantieJian,
    "xuanxu-dao" => Kantele.Combat.Skills.XuanxuDao,
    "xue-dao" => Kantele.Combat.Skills.XueDao,
    "xueshan-dao" => Kantele.Combat.Skills.XueshanDao,
    "xueshan-jian" => Kantele.Combat.Skills.XueshanJian,
    "xumishan-zhang" => Kantele.Combat.Skills.XumishanZhang,
    "xunlei-jian" => Kantele.Combat.Skills.XunleiJian,
    "yanxing-dao" => Kantele.Combat.Skills.YanxingDao,
    "yecha-gun" => Kantele.Combat.Skills.YechaGun,
    "yingzhua-gong" => Kantele.Combat.Skills.YingzhuaGong,
    "yinhu-zhang" => Kantele.Combat.Skills.YinhuZhang,
    "yinlong-bian" => Kantele.Combat.Skills.YinlongBian,
    "yinsuo-jinling" => Kantele.Combat.Skills.YinsuoJinling,
    "yintuoluo-zhua" => Kantele.Combat.Skills.YintuoluoZhua,
    "yinyang-ren" => Kantele.Combat.Skills.YinyangRen,
    "yinyang-zhang" => Kantele.Combat.Skills.YinyangZhang,
    "yitian-jian" => Kantele.Combat.Skills.YitianJian,
    "yitian-zhang" => Kantele.Combat.Skills.YitianZhang,
    "yizhi-chan" => Kantele.Combat.Skills.YizhiChan,
    "youshen-zhang" => Kantele.Combat.Skills.YoushenZhang,
    "yuanshi-jian" => Kantele.Combat.Skills.YuanshiJian,
    "yuenv-jian" => Kantele.Combat.Skills.YuenvJian,
    "yuezhao-gong" => Kantele.Combat.Skills.YuezhaoGong,
    "yujiamu-quan" => Kantele.Combat.Skills.YujiamuQuan,
    "yujian-shu" => Kantele.Combat.Skills.YujianShu,
    "yunlong-bian" => Kantele.Combat.Skills.YunlongBian,
    "yunlong-jian" => Kantele.Combat.Skills.YunlongJian,
    "yunu-sword" => Kantele.Combat.Skills.YunuSword,
    "yunv-jian" => Kantele.Combat.Skills.YunvJian,
    "yunzhou-fufa" => Kantele.Combat.Skills.YunzhouFufa,
    "yuxiao-jian" => Kantele.Combat.Skills.YuxiaoJian,
    "zhemei-shou" => Kantele.Combat.Skills.ZhemeiShou,
    "zhengliangyi-jian" => Kantele.Combat.Skills.ZhengliangyiJian,
    "zhenshan-zhang" => Kantele.Combat.Skills.ZhenshanZhang,
    "zhentian-quan" => Kantele.Combat.Skills.ZhentianQuan,
    "zhenyu-quan" => Kantele.Combat.Skills.ZhenyuQuan,
    "zhongnan-zhi" => Kantele.Combat.Skills.ZhongnanZhi,
    "zhongping-qiang" => Kantele.Combat.Skills.ZhongpingQiang,
    "zhougong-jian" => Kantele.Combat.Skills.ZhougongJian,
    "zhuihun-jian" => Kantele.Combat.Skills.ZhuihunJian,
    "zigai-jian" => Kantele.Combat.Skills.ZigaiJian,
    "zilei-jian" => Kantele.Combat.Skills.ZileiJian,
    "zui-gun" => Kantele.Combat.Skills.ZuiGun,
    # --- 白名单补全 batch3：空招式但非攻击类（知识/身法/医术/乐器/毒术/force/parry）（2026-10-31）---
    "anying-fuxiang" => Kantele.Combat.Skills.AnyingFuxiang,
    "bagua-bu" => Kantele.Combat.Skills.BaguaBu,
    "baituo-michuan" => Kantele.Combat.Skills.BaituoMichuan,
    "begging" => Kantele.Combat.Skills.Begging,
    "beidou-xianzong" => Kantele.Combat.Skills.BeidouXianzong,
    "bencao-changshi" => Kantele.Combat.Skills.BencaoChangshi,
    "bencao-shuli" => Kantele.Combat.Skills.BencaoShuli,
    "bihai-chaosheng" => Kantele.Combat.Skills.BihaiChaosheng,
    "buddhism" => Kantele.Combat.Skills.Buddhism,
    "calligraphy" => Kantele.Combat.Skills.Calligraphy,
    "chanchu-bufa" => Kantele.Combat.Skills.ChanchuBufa,
    "checking" => Kantele.Combat.Skills.Checking,
    "chess" => Kantele.Combat.Skills.Chess,
    "chuancai-jiyi" => Kantele.Combat.Skills.ChuancaiJiyi,
    "chuanyun-bu" => Kantele.Combat.Skills.ChuanyunBu,
    "cooking" => Kantele.Combat.Skills.Cooking,
    "count" => Kantele.Combat.Skills.Count,
    "craft-cognize" => Kantele.Combat.Skills.CraftCognize,
    "dengping-dushui" => Kantele.Combat.Skills.DengpingDushui,
    "dispel-poison" => Kantele.Combat.Skills.DispelPoison,
    "douzhuan-xingyi" => Kantele.Combat.Skills.DouzhuanXingyi,
    "drawing" => Kantele.Combat.Skills.Drawing,
    "feiyan-huixiang" => Kantele.Combat.Skills.FeiyanHuixiang,
    "feiyan-zoubi" => Kantele.Combat.Skills.FeiyanZoubi,
    "guangling-san" => Kantele.Combat.Skills.GuanglingSan,
    "guoshi-xinfa" => Kantele.Combat.Skills.GuoshiXinfa,
    "henshan-shenfa" => Kantele.Combat.Skills.HenshanShenfa,
    "higgling" => Kantele.Combat.Skills.Higgling,
    "huashan-shenfa" => Kantele.Combat.Skills.HuashanShenfa,
    "hunting" => Kantele.Combat.Skills.Hunting,
    "jian-jia" => Kantele.Combat.Skills.JianJia,
    "jingluo-xue" => Kantele.Combat.Skills.JingluoXue,
    "jinshe-youshenbu" => Kantele.Combat.Skills.JinsheYoushenbu,
    "jinyan-gong" => Kantele.Combat.Skills.JinyanGong,
    "juechen-shenfa" => Kantele.Combat.Skills.JuechenShenfa,
    "jueqing-shenfa" => Kantele.Combat.Skills.JueqingShenfa,
    "jueqing-yaoli" => Kantele.Combat.Skills.JueqingYaoli,
    "lamaism" => Kantele.Combat.Skills.Lamaism,
    "liandan-shu" => Kantele.Combat.Skills.LiandanShu,
    "lingxu-bu" => Kantele.Combat.Skills.LingxuBu,
    "liquor" => Kantele.Combat.Skills.Liquor,
    "literate" => Kantele.Combat.Skills.Literate,
    "liuying-bu" => Kantele.Combat.Skills.LiuyingBu,
    "longxiang" => Kantele.Combat.Skills.Longxiang,
    "magic" => Kantele.Combat.Skills.Magic,
    "mahayana" => Kantele.Combat.Skills.Mahayana,
    "martial-cognize" => Kantele.Combat.Skills.MartialCognize,
    "mathematics" => Kantele.Combat.Skills.Mathematics,
    "meihua-zhuang" => Kantele.Combat.Skills.MeihuaZhuang,
    "muslim" => Kantele.Combat.Skills.Muslim,
    "persuading" => Kantele.Combat.Skills.Persuading,
    "pretending" => Kantele.Combat.Skills.Pretending,
    "qiankun-danuoyi" => Kantele.Combat.Skills.QiankunDanuoyi,
    "qingfu-shenfa" => Kantele.Combat.Skills.QingfuShenfa,
    "qingxin-pushan" => Kantele.Combat.Skills.QingxinPushan,
    "qiuyue-lai" => Kantele.Combat.Skills.QiuyueLai,
    "qixing-bu" => Kantele.Combat.Skills.QixingBu,
    "sanscrit" => Kantele.Combat.Skills.Sanscrit,
    "shaolin-shenfa" => Kantele.Combat.Skills.ShaolinShenfa,
    "shaolin-yishu" => Kantele.Combat.Skills.ShaolinYishu,
    "shenghuo-bu" => Kantele.Combat.Skills.ShenghuoBu,
    "shenkong-xing" => Kantele.Combat.Skills.ShenkongXing,
    "shenlong-mixin" => Kantele.Combat.Skills.ShenlongMixin,
    "sixiang-bufa" => Kantele.Combat.Skills.SixiangBufa,
    "stealing" => Kantele.Combat.Skills.Stealing,
    "taishan-xinfa" => Kantele.Combat.Skills.TaishanXinfa,
    "tangmen-medical" => Kantele.Combat.Skills.TangmenMedical,
    "tangmen-poison" => Kantele.Combat.Skills.TangmenPoison,
    "taohua-yaoli" => Kantele.Combat.Skills.TaohuaYaoli,
    "taohua-yuan" => Kantele.Combat.Skills.TaohuaYuan,
    "taoism" => Kantele.Combat.Skills.Taoism,
    "taxue-wuhen" => Kantele.Combat.Skills.TaxueWuhen,
    "tiannan-bu" => Kantele.Combat.Skills.TiannanBu,
    "tiannan-step" => Kantele.Combat.Skills.TiannanStep,
    "tianshan-feidu" => Kantele.Combat.Skills.TianshanFeidu,
    "tieqin-yin" => Kantele.Combat.Skills.TieqinYin,
    "tiyunzong" => Kantele.Combat.Skills.Tiyunzong,
    "training" => Kantele.Combat.Skills.Training,
    "wai-bagua" => Kantele.Combat.Skills.WaiBagua,
    "wudang-yaoli" => Kantele.Combat.Skills.WudangYaoli,
    "wudu-qishu" => Kantele.Combat.Skills.WuduQishu,
    "wudu-shu" => Kantele.Combat.Skills.WuduShu,
    "wushe-qu" => Kantele.Combat.Skills.WusheQu,
    "xiaoao-jianghu" => Kantele.Combat.Skills.XiaoaoJianghu,
    "xiaoxiang-yeyu" => Kantele.Combat.Skills.XiaoxiangYeyu,
    "xiaoyao-qixue" => Kantele.Combat.Skills.XiaoyaoQixue,
    "xingxiu-qishu" => Kantele.Combat.Skills.XingxiuQishu,
    "xixing-xiaofa" => Kantele.Combat.Skills.XixingXiaofa,
    "xiyu-tiezheng" => Kantele.Combat.Skills.XiyuTiezheng,
    "xuefu-mizong" => Kantele.Combat.Skills.XuefuMizong,
    "yan-fly" => Kantele.Combat.Skills.YanFly,
    "yangyan-shu" => Kantele.Combat.Skills.YangyanShu,
    "yanzi-chuanyun" => Kantele.Combat.Skills.YanziChuanyun,
    "yaowang-miaoshu" => Kantele.Combat.Skills.YaowangMiaoshu,
    "yiwei-dujiang" => Kantele.Combat.Skills.YiweiDujiang,
    "yixingbu" => Kantele.Combat.Skills.Yixingbu,
    "yueying-wubu" => Kantele.Combat.Skills.YueyingWubu,
    "yunlong-shenfa" => Kantele.Combat.Skills.YunlongShenfa,
    "yunv-shenfa" => Kantele.Combat.Skills.YunvShenfa,
    "zhaixing-gong" => Kantele.Combat.Skills.ZhaixingGong,
    "zhaixinggong" => Kantele.Combat.Skills.Zhaixinggong,
    "zhenjiu-shu" => Kantele.Combat.Skills.ZhenjiuShu,
    "zhuangzi-wu" => Kantele.Combat.Skills.ZhuangziWu,
    "zhutian-bu" => Kantele.Combat.Skills.ZhutianBu,
    "zuixian-bu" => Kantele.Combat.Skills.ZuixianBu,
    # --- 白名单补全 batch4：知识类无招式（源无 valid_enable）+ 纯 perform 的暗器（2026-10-31）---
    "idle-force" => Kantele.Combat.Skills.IdleForce,
    "mihun-dafa" => Kantele.Combat.Skills.MihunDafa,
    "qimen-wuxing" => Kantele.Combat.Skills.QimenWuxing,
    "xiaoli-feidao" => Kantele.Combat.Skills.XiaoliFeidao,
    "xuanyuan-arrow" => Kantele.Combat.Skills.XuanyuanArrow,
    "yufeng-zhen" => Kantele.Combat.Skills.YufengZhen,
    "yunlong-xinfa" => Kantele.Combat.Skills.YunlongXinfa,
    "zuoyou-hubo" => Kantele.Combat.Skills.ZuoyouHubo,
    # --- 白名单补全 batch5：招式表已迁（动态/双表）的 4 个攻击类特技（2026-10-31）---
    "qingyun-bian" => Kantele.Combat.Skills.QingyunBian,
    "qixian-wuxingjian" => Kantele.Combat.Skills.QixianWuxingjian,
    "tanzhi-shentong" => Kantele.Combat.Skills.TanzhiShentong,
    "yiyang-zhi" => Kantele.Combat.Skills.YiyangZhi,
    # --- 白名单补全 batch6：其余未注册特技，按 data/world/ 引用次数降序（2026-10-31）---
    # 核心 22 个：data/world/ 有实际引用（ref_file_count > 0）
    "dodge" => Kantele.Combat.Skills.Dodge,
    "parry" => Kantele.Combat.Skills.Parry,
    "unarmed" => Kantele.Combat.Skills.Unarmed,
    "sword" => Kantele.Combat.Skills.Sword,
    "blade" => Kantele.Combat.Skills.Blade,
    "strike" => Kantele.Combat.Skills.Strike,
    "cuff" => Kantele.Combat.Skills.Cuff,
    "staff" => Kantele.Combat.Skills.Staff,
    "finger" => Kantele.Combat.Skills.Finger,
    "hand" => Kantele.Combat.Skills.Hand,
    "claw" => Kantele.Combat.Skills.Claw,
    "whip" => Kantele.Combat.Skills.Whip,
    "club" => Kantele.Combat.Skills.Club,
    "hammer" => Kantele.Combat.Skills.Hammer,
    "throwing" => Kantele.Combat.Skills.Throwing,
    "dagger" => Kantele.Combat.Skills.Dagger,
    "medical" => Kantele.Combat.Skills.Medical,
    "poison" => Kantele.Combat.Skills.Poison,
    "axe" => Kantele.Combat.Skills.Axe,
    "tanqin-jifa" => Kantele.Combat.Skills.TanqinJifa,
    "chuixiao-jifa" => Kantele.Combat.Skills.ChuixiaoJifa,
    "guzheng-jifa" => Kantele.Combat.Skills.GuzhengJifa,
    # 其余 87 个：data/world/ 引用次数为 0（按字母序）
    "array" => Kantele.Combat.Skills.Array,
    "baicao-jue" => Kantele.Combat.Skills.BaicaoJue,
    "baji-quan" => Kantele.Combat.Skills.BajiQuan,
    "certosina" => Kantele.Combat.Skills.Certosina,
    "chaoyang-fengwu" => Kantele.Combat.Skills.ChaoyangFengwu,
    "chinese-anthem" => Kantele.Combat.Skills.ChineseAnthem,
    "chixin-jian" => Kantele.Combat.Skills.ChixinJian,
    "culture-cognize" => Kantele.Combat.Skills.CultureCognize,
    "dafumo-quan" => Kantele.Combat.Skills.DafumoQuan,
    "dian-canghai" => Kantele.Combat.Skills.DianCanghai,
    "diyang-chufan" => Kantele.Combat.Skills.DiyangChufan,
    "driving" => Kantele.Combat.Skills.Driving,
    "feed-power" => Kantele.Combat.Skills.FeedPower,
    "feilong-zaitian" => Kantele.Combat.Skills.FeilongZaitian,
    "five-avoid" => Kantele.Combat.Skills.FiveAvoid,
    "force-dispel" => Kantele.Combat.Skills.ForceDispel,
    "force-heal" => Kantele.Combat.Skills.ForceHeal,
    "force-inspire" => Kantele.Combat.Skills.ForceInspire,
    "force-lifeheal" => Kantele.Combat.Skills.ForceLifeheal,
    "force-power" => Kantele.Combat.Skills.ForcePower,
    "force-recover" => Kantele.Combat.Skills.ForceRecover,
    "force-regenerate" => Kantele.Combat.Skills.ForceRegenerate,
    "force-roar" => Kantele.Combat.Skills.ForceRoar,
    "force-shot" => Kantele.Combat.Skills.ForceShot,
    "force-tianmo" => Kantele.Combat.Skills.ForceTianmo,
    "force-xun" => Kantele.Combat.Skills.ForceXun,
    "hanbing-zhang" => Kantele.Combat.Skills.HanbingZhang,
    "huanyin-zhi" => Kantele.Combat.Skills.HuanyinZhi,
    "huashan-sword" => Kantele.Combat.Skills.HuashanSword,
    "huntian-baojian" => Kantele.Combat.Skills.HuntianBaojian,
    "huoyue-zaiyuan" => Kantele.Combat.Skills.HuoyueZaiyuan,
    "huzhao-shou" => Kantele.Combat.Skills.HuzhaoShou,
    "japanese" => Kantele.Combat.Skills.Japanese,
    "jianlong-zaitian" => Kantele.Combat.Skills.JianlongZaitian,
    "jin-chenxi" => Kantele.Combat.Skills.JinChenxi,
    "jinshe-zhang" => Kantele.Combat.Skills.JinsheZhang,
    "kanglong-youhui" => Kantele.Combat.Skills.KanglongYouhui,
    "kuihua-xinfa" => Kantele.Combat.Skills.KuihuaXinfa,
    "leiting-fu" => Kantele.Combat.Skills.LeitingFu,
    "lingyun-jian" => Kantele.Combat.Skills.LingyunJian,
    "lishe-dachuan" => Kantele.Combat.Skills.LisheDachuan,
    "lonely-sword" => Kantele.Combat.Skills.LonelySword,
    "longzhan-yuye" => Kantele.Combat.Skills.LongzhanYuye,
    "lunhui-jian" => Kantele.Combat.Skills.LunhuiJian,
    "lvshuang-bingzhi" => Kantele.Combat.Skills.LvshuangBingzhi,
    "miyun-buyu" => Kantele.Combat.Skills.MiyunBuyu,
    "necromancy" => Kantele.Combat.Skills.Necromancy,
    "panlong-zhao" => Kantele.Combat.Skills.PanlongZhao,
    "piaoyibu" => Kantele.Combat.Skills.Piaoyibu,
    "poyang-jian" => Kantele.Combat.Skills.PoyangJian,
    "qufeng" => Kantele.Combat.Skills.Qufeng,
    "renshu" => Kantele.Combat.Skills.Renshu,
    "russian" => Kantele.Combat.Skills.Russian,
    "shedao-neigong" => Kantele.Combat.Skills.ShedaoNeigong,
    "shicheng-liulong" => Kantele.Combat.Skills.ShichengLiulong,
    "shuanglong-qushui" => Kantele.Combat.Skills.ShuanglongQushui,
    "songyang-zhang" => Kantele.Combat.Skills.SongyangZhang,
    "sunze-youfu" => Kantele.Combat.Skills.SunzeYoufu,
    "swimming" => Kantele.Combat.Skills.Swimming,
    "tadpole" => Kantele.Combat.Skills.Tadpole,
    "taohua-zhangfa" => Kantele.Combat.Skills.TaohuaZhangfa,
    "technic-cognize" => Kantele.Combat.Skills.TechnicCognize,
    "tianlong-zhi" => Kantele.Combat.Skills.TianlongZhi,
    "tianmo-jue" => Kantele.Combat.Skills.TianmoJue,
    "turu-qilai" => Kantele.Combat.Skills.TuruQilai,
    "wushen-jian" => Kantele.Combat.Skills.WushenJian,
    "wuxing-jueming" => Kantele.Combat.Skills.WuxingJueming,
    "wuxing-quan" => Kantele.Combat.Skills.WuxingQuan,
    "wuyue-blade" => Kantele.Combat.Skills.WuyueBlade,
    "wuyun-jianfa" => Kantele.Combat.Skills.WuyunJianfa,
    "xiake-force" => Kantele.Combat.Skills.XiakeForce,
    "xiyang-boji" => Kantele.Combat.Skills.XiyangBoji,
    "xuanfeng-leg" => Kantele.Combat.Skills.XuanfengLeg,
    "xuantian-shengong" => Kantele.Combat.Skills.XuantianShengong,
    "xue-qiongcang" => Kantele.Combat.Skills.XueQiongcang,
    "xuwen-qixingding" => Kantele.Combat.Skills.XuwenQixingding,
    "yaowang-shenxin" => Kantele.Combat.Skills.YaowangShenxin,
    "yingzhao-shou" => Kantele.Combat.Skills.YingzhaoShou,
    "yinyang-shiertian" => Kantele.Combat.Skills.YinyangShiertian,
    "yuyue-yuyuan" => Kantele.Combat.Skills.YuyueYuyuan,
    "zhengqi-jue" => Kantele.Combat.Skills.ZhengqiJue,
    "zhenxin-fa" => Kantele.Combat.Skills.ZhenxinFa,
    "zhenxin-yimaifa" => Kantele.Combat.Skills.ZhenxinYimaifa,
    "zhuifeng-steps" => Kantele.Combat.Skills.ZhuifengSteps,
    "zhurong-jian" => Kantele.Combat.Skills.ZhurongJian,
    "zijinbagua-dao" => Kantele.Combat.Skills.ZijinbaguaDao,
    "ziwu-daxuefa" => Kantele.Combat.Skills.ZiwuDaxuefa
  }

  @doc "运行时注册一门武学（覆盖同名内建）"
  def register(id, module) when is_binary(id) and is_atom(module) do
    :persistent_term.put({__MODULE__, :extra}, Map.put(extras(), id, module))
    :ok
  end

  @doc "运行时移除一门武学（仅影响运行时增量，不碰内建）"
  def unregister(id) when is_binary(id) do
    :persistent_term.put({__MODULE__, :extra}, Map.delete(extras(), id))
    :ok
  end

  def all(), do: Map.merge(@static, extras())

  def get(id) when is_binary(id), do: Map.get(all(), id)
  def get(_id), do: nil

  def known?(id), do: Map.has_key?(all(), id)

  @doc """
  按用法解析可 enable 的特技（对应 valid_enable）

  玩家 map_skill 之后，攻击/招架/内功都会映射到特技模块
  """
  def enabled_for(stats, usage) do
    case Kantele.Character.Stats.mapped(stats, usage) do
      nil -> nil
      skill_id -> get(skill_id)
    end
  end

  @doc """
  技能力量 / 武学上限（对应 `feature/sadjust.c` 的 `skill_adjust`）

  LPC: `lmt = combat_exp^3 / 10`，把超过上限的 martial 类技能压回 `lmt`。
  返回压制后的 skills 映射。`martial_keys` 为判定"martial 类"的技能名集合，
  调用方提供（由技能元数据决定）。
  """
  def skill_adjust(skills, combat_exp, martial_keys \\ :auto) when is_map(skills) do
    lmt = div(combat_exp * combat_exp * combat_exp, 10)
    selected = if martial_keys == :auto, do: Map.keys(skills), else: martial_keys

    Enum.reduce(selected, skills, fn name, acc ->
      if Map.get(acc, name, 0) > lmt do
        Map.put(acc, name, lmt)
      else
        acc
      end
    end)
  end

  @doc """
  死亡技能惩罚（对应 `feature/skill.c skill_death_penalty`）

  无 `learned` 映射：每技能 -1，跌破 1 删除。
  有 `learned` 映射（`%{技能 => 领悟点数}`）：若 `learned[sk] > (skills[sk]+1)^2/2`
  则删 learned[sk]，否则 skills[sk]--，跌破 0 删除。
  返回 `{skills_after, learned_after}`。
  """
  def skill_death_penalty(skills, learned \\ %{})

  def skill_death_penalty(skills, learned) when map_size(learned) == 0 do
    skills =
      Enum.reduce(skills, %{}, fn {name, lvl}, acc ->
        if lvl - 1 < 1, do: acc, else: Map.put(acc, name, lvl - 1)
      end)

    {skills, %{}}
  end

  def skill_death_penalty(skills, learned) do
    {skills, learned} =
      Enum.reduce(skills, {skills, learned}, fn {name, lvl}, {sk_acc, ln_acc} ->
        learned_lvl = Map.get(ln_acc, name, 0)

        if learned_lvl > div((lvl + 1) * (lvl + 1), 2) do
          {sk_acc, Map.delete(ln_acc, name)}
        else
          new_lvl = if lvl - 1 < 0, do: nil, else: lvl - 1
          sk_acc = if new_lvl, do: Map.put(sk_acc, name, new_lvl), else: Map.delete(sk_acc, name)
          {sk_acc, ln_acc}
        end
      end)

    {skills, learned}
  end

  @doc """
  逐出师门技能惩罚（对应 `feature/skill.c skill_expell_penalty`）

  - 技能文件不存在（`missing?/1` 谓词）→ 删除该技能
  - 非 martial 类或 `martial-cognize` → 保留
  - 可 enable parry/dodge/throwing/force（`guard_special?/1` 谓词）→ 删除
  - 其余 >100 压回 100
  `meta` 由调用方提供（按技能名查 type / valid_enable），形如
  `%{name => %{type: "martial", guards: ["parry"]}}`。
  """
  def skill_expell_penalty(skills, meta) when is_map(skills) do
    {done, _} =
      Enum.reduce(skills, {%{}, meta}, fn {name, lvl}, {acc, m} ->
        rel = Map.get(m, name, %{})

        cond do
          Map.get(rel, :missing, false) ->
            {acc, m}

          Map.get(rel, :type) != "martial" or name == "martial-cognize" ->
            {Map.put(acc, name, lvl), m}

          guards_special?(rel) ->
            {acc, m}

          lvl >= 100 ->
            {Map.put(acc, name, 100), m}

          true ->
            {Map.put(acc, name, lvl), m}
        end
      end)

    done
  end

  @doc "技能是否可 enable parry/dodge/throwing/force（skill_expell_penalty 谓词）"
  def guards_special?(rel) do
    guards = Map.get(rel, :guards, [])
    Enum.any?(["parry", "dodge", "throwing", "force"], &(&1 in guards))
  end

  defp extras() do
    :persistent_term.get({__MODULE__, :extra}, %{})
  end
end

defmodule Kantele.Combat.Skills.DefaultActions do
  @moduledoc """
  未启用特技时的通用招式（拳脚与基础兵刃）
  """

  @unarmed [
    %{
      "action" => "$N右拳一收一送，直捣$n的$l",
      "force" => 0,
      "attack" => 10,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "挥拳猛击"
    },
    %{
      "action" => "$N侧身进步，一记肘锤撞向$n的$l",
      "force" => 0,
      "attack" => 15,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 8,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "肘锤"
    },
    %{
      "action" => "$N双掌翻飞，连环拍向$n的$l",
      "force" => 0,
      "attack" => 20,
      "dodge" => 5,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "震伤",
      "skill_name" => "连环双掌"
    }
  ]

  @weaponed [
    %{
      "action" => "$N手中兵刃一振，斜劈向$n的$l",
      "force" => 0,
      "attack" => 12,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 6,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "基础挥砍"
    },
    %{
      "action" => "$N手腕翻转，兵刃化作一道寒光罩向$n的$l",
      "force" => 0,
      "attack" => 18,
      "dodge" => 0,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "突刺"
    }
  ]

  def query_action(attack_skill, level, rng \\ &:rand.uniform/1)

  def query_action("unarmed", level, rng) do
    Kantele.Combat.Skill.pick_action(@unarmed, level, rng)
  end

  def query_action(_skill_type, level, rng) do
    Kantele.Combat.Skill.pick_action(@weaponed, level, rng)
  end
end
