defmodule Kantele.Combat.SkillsValidLearnBatch1Test do
  @moduledoc """
  白名单补全后的一轮 `valid_learn/2` 批量迁移（116 个技能）。

  这些技能的 LPC 源都有非平凡 `valid_learn(object me)`（含 `notify_fail`），
  但 Elixir 侧此前只有基类默认的 `:ok` —— 等于任何角色都能无门槛学习。
  本批按源逐条迁移门槛，并保持判定顺序（源内 `if` 的先后即优先级）。

  覆盖的判定形态：
    - 基本技能等级下限 / 不得低于本门等级（`query_skill(X) < N` / `< 本门`）
    - `max_neili`（vitals，不在 Stats）/ `neili`（vitals 当前值）
    - 裸属性 `str/con/int/dex` 与派生 `query_dex()`
    - `shen` 正邪值、`gender` 性别门、`&&` / `||` 复合条件
    - 源内无条件 `notify_fail`（martial-cognize / persuading）→ 恒不可学
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  # 本批迁移的技能 id（全部应可 `Skills.get/1` 且带真实门槛）
  @generated ~w(
    baituo-michuan bencao-shuli bihai-chaosheng biyan-dao calligraphy douzhuan-xingyi
    dragon-strike emei-jiuyang fengmo-zhang guangling-san guanri-jian guoshi-xinfa
    hengshan-jian honglian-dao huilong-zhang jian-jia jiaohua-bangfa jiechen-dao
    jifeng-cixuefa jinwu-daofa jinwu-goufa jinyan-gong juemen-gun jueqing-yaoli
    kuangfeng-blade kunlun-jian liandan-shu liangyi-jian liuhe-bian liuyue-jian
    longxiang luohan-jian mahayana martial-cognize mathematics murong-jian
    murong-sword muslim pangu-qishi persuading pixie-sword pomopima-jian
    pudu-zhang qingfu-shenfa qingliang-daxuefa qingxin-pushan qiuyue-lai qixing-gun
    quemen-jian rouyun-jian ruyi-dao sanfen-jianshu sanscrit shangqing-jian
    shaolin-jiuyang shaolin-yishu shedao-qigong shenghuo-ling shenlong-mixin shenmen-jian
    shennong-zhang shigu-bifa shiying-lianhuan siji-jianfa songfeng-jian suoming-zhang
    taiji-dao tangmen-medical tangmen-poison taohua-yaoli taohua-yuan taoism
    tianlei-dao tianlong-jian tianshan-zhang tianyu-qijian tieqin-yin tiexue-dao
    tiyunzong tonggui-jian wai-bagua weituo-gun wuchang-zhang wudang-jiuyang
    wudang-yaoli wudu-qishu wuhu-duanmendao wuliang-jian wushe-qu wuzhan-mei
    xiangmo-chu xiaoao-jianghu xiaoxiang-yeyu xiaoyao-jian xiaoyao-qixue xingxiu-qishu
    xiuluo-dao xixing-xiaofa xiyu-tiezheng xuanxu-dao xue-dao xueshan-dao
    xueshan-jian xunlei-jian yanxing-dao yaowang-miaoshu yitian-jian yiwei-dujiang
    yuanshi-jian yuenv-jian yunlong-jian yuxiao-jian zhengliangyi-jian zhenjiu-shu
    zhougong-jian zui-gun
  )

  # ---- helpers ----

  defp stats(skills \\ %{}, attrs \\ %{}) do
    base = Stats.new()
    stats = %{base | skills: Map.merge(base.skills, skills)}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  # 默认「内力充足、男性、shen 为正」的角色切片（teach 事件给的就是这种形状）
  defp char(opts \\ []) do
    %{
      meta: %{
        vitals: %{
          max_neili: Keyword.get(opts, :max_neili, 20_000),
          neili: Keyword.get(opts, :neili, 20_000)
        },
        stats: %{shen: Keyword.get(opts, :shen, 100)},
        env: %{gender: Keyword.get(opts, :gender, "男性")}
      }
    }
  end

  defp learn(id, stats, character) do
    Skills.get(id).valid_learn(stats, character)
  end

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- 基本技能门槛 ----

  test "hengshan-jian：max_neili 150 与 force 30 两道门，顺序不可换" do
    # 内力不够优先报内力
    assert_error("hengshan-jian", stats(), char(max_neili: 149), "你的内力不够。")
    # 内力够了才轮到内功火候
    assert_error("hengshan-jian", stats(%{"force" => 29}), char(max_neili: 150), "你的内功火候不够。")
    assert :ok = learn("hengshan-jian", stats(%{"force" => 30}), char(max_neili: 150))
  end

  test "hengshan-jian：角色切片缺 vitals 时 max_neili 视为未知，跳过该门" do
    # LPC 里 me 一定有 max_neili；引擎切片可能没有，此时不误拦（与既有迁移一致）
    assert :ok = learn("hengshan-jian", stats(%{"force" => 30}), %{})
  end

  test "biyan-dao：force / max_neili / blade 三道常量门 + blade 不得低于本门" do
    assert_error("biyan-dao", stats(), char(), "你的内功火候不到")
    assert_error("biyan-dao", stats(%{"force" => 50}), char(max_neili: 349), "你的内力太差")
    assert_error("biyan-dao", stats(%{"force" => 50}), char(max_neili: 350), "你的基本刀法火候太浅")
    # blade 30 够常量门，但低于本门 40
    assert_error(
      "biyan-dao",
      stats(%{"force" => 50, "blade" => 30, "biyan-dao" => 40}),
      char(max_neili: 350),
      "你的基本刀法水平有限"
    )

    assert :ok = learn("biyan-dao", stats(%{"force" => 50, "blade" => 30, "biyan-dao" => 30}), char(max_neili: 350))
  end

  test "luohan-jian：复合条件 (fumo<80 && qingliang<80) 只要一门达标即放行" do
    base = %{"sword" => 100, "hunyuan-yiqi" => 120}
    c = char(max_neili: 650)

    # 两门都不到 80 → 拦
    assert_error("luohan-jian", stats(base), c, "你得必须先精通伏魔剑")
    # 伏魔剑达标即可（&& 的另一支不满足也无妨）
    assert :ok = learn("luohan-jian", stats(Map.put(base, "fumo-jian", 80), %{int: 22}), c)
    assert :ok = learn("luohan-jian", stats(Map.put(base, "qingliang-jian", 80), %{int: 22}), c)
  end

  test "luohan-jian：后续 max_neili / 内功 / 悟性 / 剑法四道门依次生效" do
    ok = stats(%{"fumo-jian" => 80, "sword" => 100, "hunyuan-yiqi" => 120}, %{int: 22})
    assert_error("luohan-jian", ok, char(max_neili: 649), "你的内力不够。")

    no_hunyuan = stats(%{"fumo-jian" => 80, "sword" => 100}, %{int: 22})
    assert_error("luohan-jian", no_hunyuan, char(max_neili: 650), "你的内功火候太浅。")

    no_int = stats(%{"fumo-jian" => 80, "sword" => 100, "hunyuan-yiqi" => 120}, %{int: 21})
    assert_error("luohan-jian", no_int, char(max_neili: 650), "你的先天悟性不够。")

    no_sword = stats(%{"fumo-jian" => 80, "hunyuan-yiqi" => 120}, %{int: 22})
    assert_error("luohan-jian", no_sword, char(max_neili: 650), "你的基本剑法不够。")

    low_self = stats(%{"fumo-jian" => 80, "sword" => 100, "hunyuan-yiqi" => 120, "luohan-jian" => 120}, %{int: 22})
    assert_error("luohan-jian", low_self, char(max_neili: 650), "你的基本剑法水平有限")
    assert :ok = learn("luohan-jian", ok, char(max_neili: 650))
  end

  test "dragon-strike：str / con / force / max_neili / strike 五道门" do
    c = char(max_neili: 1500)
    assert_error("dragon-strike", stats(), c, "就你这身子骨还练降龙十八掌")
    assert_error("dragon-strike", stats(%{}, %{str: 31}), c, "算了吧，你先天根骨不好")
    assert_error("dragon-strike", stats(%{}, %{str: 31, con: 24}), c, "你的内功火候不够")
    assert_error("dragon-strike", stats(%{"force" => 150}, %{str: 31, con: 24}), char(max_neili: 1499), "你的内力这么差")
    assert_error("dragon-strike", stats(%{"force" => 150}, %{str: 31, con: 24}), c, "你的基本掌法火候不够")

    ok = stats(%{"force" => 150, "strike" => 30}, %{str: 31, con: 24})
    assert :ok = learn("dragon-strike", ok, c)
  end

  test "calligraphy / mathematics / liandan-shu：literate|medical 常量门 + 不得低于本门" do
    assert_error("calligraphy", stats(), char(), "你连读书写字都没学好")
    assert_error("calligraphy", stats(%{"literate" => 100, "calligraphy" => 101}), char(), "你的读书写字水平有限")
    assert :ok = learn("calligraphy", stats(%{"literate" => 100, "calligraphy" => 100}), char())

    assert_error("mathematics", stats(%{"literate" => 99}), char(), "你连读书写字都没学好")
    assert :ok = learn("mathematics", stats(%{"literate" => 100}), char())

    assert_error("liandan-shu", stats(%{"medical" => 99}), char(), "你的基本医术造诣太浅")
    assert :ok = learn("liandan-shu", stats(%{"medical" => 100}), char())
  end

  test "qingfu-shenfa：裸属性 dex 与 dodge 双门（无 character 依赖）" do
    assert_error("qingfu-shenfa", stats(%{}, %{dex: 25}), char(), "你先天身法太差")
    assert_error("qingfu-shenfa", stats(%{"dodge" => 99}, %{dex: 26}), char(), "你轻功根基不足")
    assert :ok = learn("qingfu-shenfa", stats(%{"dodge" => 100}, %{dex: 26}), char())
  end

  # ---- 派生属性 ----

  test "juemen-gun：query_dex() 是派生值（base + tattoo + reborn + dodge/10）" do
    # dex 20 + dodge 100/10 = 30 >= 23 → 通过
    assert :ok = learn("juemen-gun", stats(%{"dodge" => 100}, %{dex: 20}), char(max_neili: 200))
    # 派生值不足 23 才拦
    assert_error("juemen-gun", stats(%{"dodge" => 20}, %{dex: 20}), char(max_neili: 200), "你的身法不够灵活")
    assert_error("juemen-gun", stats(%{"dodge" => 100}, %{dex: 20}), char(max_neili: 199), "你的内力太弱")
  end

  # ---- shen / gender ----

  test "mahayana：shen < 0 才拦，0 与正数放行" do
    assert_error("mahayana", stats(), char(shen: -1), "你的邪气太重")
    assert :ok = learn("mahayana", stats(), char(shen: 0))
    assert :ok = learn("mahayana", stats(), char(shen: 500))
    # 切片缺 meta.stats.shen 时按 0 处理（不误拦）
    assert :ok = learn("mahayana", stats(), %{})
  end

  test "taoism：无性且等级 > 19 才拦（19 级及以下不拦）" do
    assert_error("taoism", stats(%{"taoism" => 20}), char(gender: "无性"), "你刚听一会儿")
    assert :ok = learn("taoism", stats(%{"taoism" => 19}), char(gender: "无性"))
    assert :ok = learn("taoism", stats(%{"taoism" => 999}), char(gender: "男性"))
  end

  test "longxiang：force 门先于性别门（顺序保真）" do
    # force 不足时先报内功，即使性别也不符
    assert_error("longxiang", stats(%{"longxiang" => 60}), char(gender: "无性"), "你的基本内功火候还不够")
    assert_error("longxiang", stats(%{"force" => 70, "longxiang" => 50}), char(gender: "无性"), "你无根无性")
    assert :ok = learn("longxiang", stats(%{"force" => 70, "longxiang" => 49}, %{str: 30}), char(gender: "无性"))
    assert_error("longxiang", stats(%{"force" => 70}, %{str: 29}), char(), "你先天膂力不足")
  end

  test "guoshi-xinfa：性别门阈值 49，且 force 门在其后" do
    assert_error("guoshi-xinfa", stats(%{"guoshi-xinfa" => 50}), char(gender: "无性"), "你无根无性")
    assert :ok = learn("guoshi-xinfa", stats(%{"guoshi-xinfa" => 49, "force" => 10}), char(gender: "无性"))
    assert_error("guoshi-xinfa", stats(%{"force" => 9}), char(), "你的基本内功火候还不够")
  end

  # ---- neili（当前内力，vitals）----

  test "siji-jianfa / shenmen-jian：neili 读的是 vitals 当前值而非上限" do
    assert_error("siji-jianfa", stats(%{"sword" => 100, "force" => 30}), char(neili: 199), "你的内力太差")
    assert :ok = learn("siji-jianfa", stats(%{"sword" => 100, "force" => 30}), char(neili: 200))
    # 上限够但当前内力不够 → 依然拦
    assert_error("siji-jianfa", stats(%{"sword" => 100, "force" => 30}), char(max_neili: 20_000, neili: 10), "你的内力太差")

    assert_error("shenmen-jian", stats(%{"force" => 60}), char(neili: 299), "你的内力太差")
    assert :ok = learn("shenmen-jian", stats(%{"force" => 60}), char(neili: 300))
  end

  # ---- 无条件 notify_fail ----

  test "martial-cognize / persuading：源内无条件 notify_fail → 恒不可学" do
    assert_error("martial-cognize", stats(), char(), "无法通过简单学习获得提升")
    assert_error("martial-cognize", stats(%{"martial-cognize" => 999}), char(max_neili: 99_999), "无法通过简单学习获得提升")
    assert_error("persuading", stats(), char(), "渡世济人要在实践中提高")
  end

  # ---- 覆盖性与健壮性 ----

  test "全部 116 个技能都已注册且可调用 valid_learn/2" do
    for id <- @generated do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "任意角色形状下都不抛异常，只返回 :ok 或 {:error, binary}" do
    shapes = [
      %{},
      char(),
      char(max_neili: 0, neili: 0, shen: -100, gender: "无性"),
      %{meta: %{vitals: %{max_neili: nil, neili: nil}, stats: %{shen: nil}, env: %{gender: nil}}}
    ]

    for id <- @generated, shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != "", "#{id} 文案异常"
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
