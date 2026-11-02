defmodule Kantele.Combat.SkillsValidLearnBatch3Test do
  @moduledoc """
  `valid_learn/2` 批量迁移的第三批（最后 28 个技能）。

  这批的 LPC 源门槛无法用通用模式表达，分两类处理：

    * 生成器可覆盖（18 个）：天性 `query("character")`、门派 `query("family/family_name")`、
      犯戒计数 `query("guilty")`、`wizardp()`，以及源内 `can_learn/` / `can_perform/`
      标记门（本端口未建模、源内恒假 → 整门跳过）。
    * 手写（10 个）：局部派生量（`layer` / `gift` / `mat` / `aa` / `bb` / 门派微调 lvl）、
      `to_chinese()` 循环提示串、`query_condition()`、`learned_literate`。

  未建模层（已在各自模块注释里说明）：
    - `me->query("character")` 天性：本端口无 register 流程 → 恒 `nil`。LPC 未设定时
      `query()` 返回 0，`nil` 与 0 的比较结果一致（`==` 假、`!=` 真），故无需守卫。
    - `me->query("guilty")`：恒 0。
    - `query("special_skill/guimai")`：恒假（见 pixie-jian）。
    - `query_condition("qiankun-except")`：condition 在 daemon 里，切片拿不到（见 qiankun-danuoyi）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  # 本批 28 个技能 id
  @batch ~w(
    badao-daofa bluesea-force buddhism count gun hongjian-yulu jingzhong-bafa
    jiuyang-shengong jiuyin-shengong kuihua-mogong never-defeated pixie-jian
    qiankun-danuoyi qianlong-wuyong qufannao-zhi sad-strike shenlong-baiwei
    taixuan-gong weituo-chu wudoumi-shengong wudu-shenzhang xianglong-zhang
    xuanming-zhang xuantie-jian zhenjing-baili zhonghua-aojue zhuangzi-wu
    zhuihun-jian
  )

  # ---- helpers ----

  defp stats(skills \\ %{}, attrs \\ %{}) do
    base = Stats.new()
    stats = %{base | skills: Map.merge(base.skills, skills)}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  # 角色切片（teach 事件给的就是 `%{meta: %{vitals: ..., env: ..., combat: ...}}` 形状）。
  # `personality` / `family` / `guilty` 只在显式传入时才写进 meta —— 用来覆盖
  # 「字段缺失」与「字段有值」两条路径。
  defp char(opts \\ []) do
    meta = %{
      vitals: %{
        max_neili: Keyword.get(opts, :max_neili, 20_000),
        neili: Keyword.get(opts, :neili, 20_000)
      },
      env: %{gender: Keyword.get(opts, :gender, "男性")},
      combat: %{equipped: Keyword.get(opts, :equipped, %{})}
    }

    # `personality:` 关键字写入规范字段 `meta.character`（LPC `query("character")`，
    # 见 PlayerMeta moduledoc / poison.ex）；`guilty` 仍写 `meta.guilty`。
    meta =
      Enum.reduce([personality: :character, guilty: :guilty], meta, fn {opt_key, meta_key}, acc ->
        case Keyword.fetch(opts, opt_key) do
          {:ok, value} -> Map.put(acc, meta_key, value)
          :error -> acc
        end
      end)

    case Keyword.fetch(opts, :family) do
      {:ok, name} -> %{meta: Map.put(meta, :family, %{name: name})}
      :error -> %{meta: meta}
    end
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- 天性门 `me->query("character")` ----

  test "badao-daofa：天性未设定（nil）等价 LPC 的 0，`!= 心狠手辣 && != 国士无双` 为真 → 拦" do
    # 无 personality 字段 → 两门都不满足 → 拦
    assert_error("badao-daofa", stats(), char(), "过于狠毒")
    # 明示一个别的天性 → 依然拦
    assert_error("badao-daofa", stats(), char(personality: "光明磊落"), "过于狠毒")

    # 命中任一放行天性 → 过此门，轮到内力门
    for p <- ["心狠手辣", "国士无双"] do
      assert_error("badao-daofa", stats(), char(personality: p, max_neili: 1999), "内力不足")
      assert :ok = learn("badao-daofa", stats(%{"blade" => 180, "force" => 150}), char(personality: p, max_neili: 2000))
    end
  end

  test "pixie-jian：`== 光明磊落 || == 狡黠多变` 拦人；男/女都拦（无六阴鬼脉）" do
    for p <- ["光明磊落", "狡黠多变"] do
      assert_error("pixie-jian", stats(), char(personality: p), "损人损己")
    end

    assert_error("pixie-jian", stats(), char(personality: "心狠手辣", gender: "女性"), "没听说过女人")
    assert_error("pixie-jian", stats(), char(personality: "心狠手辣", gender: "男性"), "内息忽然大乱")

    # 只有「无性」能过性别两门（LPC 里需转世特技六阴鬼脉，本端口未建模）
    ok = stats(%{"sword" => 100, "dodge" => 100, "parry" => 100}, %{int: 34, dex: 32})
    assert :ok = learn("pixie-jian", ok, char(personality: "心狠手辣", gender: "无性"))
  end

  test "kuihua-mogong：三连 `!=` 天性门（阴险奸诈 / 心狠手辣 / 国士无双 三者任一可学）" do
    base = stats(%{"martial-cognize" => 150, "unarmed" => 0}, %{combat_exp: 3_000_000, dex: 38, int: 34})

    assert_error("kuihua-mogong", base, char(personality: "光明磊落"), "心惊肉跳")

    for p <- ["阴险奸诈", "心狠手辣", "国士无双"] do
      assert :ok = learn("kuihua-mogong", base, char(personality: p))
    end
  end

  test "kuihua-mogong：`cognize < lvl && cognize < 500` 双条件 —— 修养过 500 后取消限制" do
    c = char(personality: "阴险奸诈")

    # cognize 150 < lvl 200 且 < 500 → 拦
    assert_error(
      "kuihua-mogong",
      stats(%{"martial-cognize" => 150, "kuihua-mogong" => 200}, %{combat_exp: 3_000_000, dex: 38, int: 34}),
      c,
      "武学修养有限"
    )

    # cognize 500 时 `cognize < 500` 为假 → 整门不生效（源内 "MK" 注释的改动）
    high = %{
      "martial-cognize" => 500,
      "kuihua-mogong" => 600,
      "unarmed" => 600,
      "sword" => 600,
      "dodge" => 600,
      "parry" => 600,
      "force" => 600
    }

    assert :ok =
             learn("kuihua-mogong", stats(high, %{combat_exp: 3_000_000, dex: 38, int: 34}), c)
  end

  test "bluesea-force：`con < 22 && query_con() < 63` 是 && —— con 够则整门跳过" do
    c = char(personality: "心狠手辣")

    assert_error(
      "bluesea-force",
      stats(%{"martial-cognize" => 50}, %{con: 21, combat_exp: 3_000_000}),
      c,
      "眼前一黑"
    )

    # con 22 时左半边为假 → 不看 query_con
    assert :ok = learn("bluesea-force", stats(%{"martial-cognize" => 50}, %{con: 22, combat_exp: 3_000_000}), c)
  end

  test "zhonghua-aojue：`!= 光明磊落` 是硬门" do
    assert_error("zhonghua-aojue", stats(), char(), "正大恢弘")
    assert_error("zhonghua-aojue", stats(), char(personality: "阴险奸诈"), "正大恢弘")

    ok = stats(%{"martial-cognize" => 300}, %{combat_exp: 3_000_000, int: 35, con: 31})
    assert :ok = learn("zhonghua-aojue", ok, char(personality: "光明磊落"))
  end

  test "jiuyin-shengong：天性两门 + 循环遍历 usage_skills2（unarmed/dodge/force）" do
    base = stats(%{"martial-cognize" => 260}, %{str: 38, con: 34})

    assert_error("jiuyin-shengong", base, char(personality: "狡黠多变"), "正大恢弘")
    assert_error("jiuyin-shengong", base, char(personality: "阴险奸诈"), "正大恢弘")
    assert :ok = learn("jiuyin-shengong", base, char(personality: "心狠手辣"))

    # 循环门：dodge 低于本门 → 拦（unarmed 够，否则会先命中拳脚门）
    assert_error(
      "jiuyin-shengong",
      stats(%{"martial-cognize" => 260, "jiuyin-shengong" => 100, "unarmed" => 100, "dodge" => 99}, %{str: 38, con: 34}),
      char(personality: "心狠手辣"),
      "基本轻功的理解还不够"
    )
  end

  # ---- 门派门 `me->query("family/family_name")` ----

  test "weituo-chu：无门派（nil）等价 LPC 的 0，`0 != 少林派` 为真 → 拦" do
    assert_error("weituo-chu", stats(), char(), "只能从少林派学到")
    assert_error("weituo-chu", stats(), char(family: "武当派"), "只能从少林派学到")
    assert_error("weituo-chu", stats(), char(family: "少林派", max_neili: 1499), "你的内力不够")
    assert :ok = learn("weituo-chu", stats(), char(family: "少林派", max_neili: 1500))
  end

  test "count：桃花岛弟子 gift 35→30、mat 300→200" do
    # 默认门派
    assert_error("count", stats(%{"mathematics" => 300}, %{int: 34}), char(), "先天悟性不足")
    assert_error("count", stats(%{"mathematics" => 299}, %{int: 35}), char(), "算术知识太差")
    assert :ok = learn("count", stats(%{"mathematics" => 300}, %{int: 35}), char())

    # 桃花岛
    c = char(family: "桃花岛")
    assert_error("count", stats(%{"mathematics" => 200}, %{int: 29}), c, "先天悟性不足")
    assert_error("count", stats(%{"mathematics" => 199}, %{int: 30}), c, "算术知识太差")
    assert :ok = learn("count", stats(%{"mathematics" => 200}, %{int: 30}), c)
  end

  test "zhuangzi-wu：红花会弟子按 `lvl -= 60` 抬高内力门槛" do
    # 非红花会：lvl 0 → 门槛 2400
    assert_error("zhuangzi-wu", stats(%{}, %{dex: 26}), char(max_neili: 2399), "内力不济")
    assert :ok = learn("zhuangzi-wu", stats(%{}, %{dex: 26}), char(max_neili: 2400))

    # 红花会 lvl 100 → base 100-60=40 → 门槛 2400+600=3000
    hh = stats(%{"zhuangzi-wu" => 100}, %{dex: 26})
    assert_error("zhuangzi-wu", hh, char(family: "红花会", max_neili: 2999), "内力不济")
    assert :ok = learn("zhuangzi-wu", hh, char(family: "红花会", max_neili: 3000))
  end

  # ---- 犯戒计数 / 巫师 ----

  test "buddhism：guilty > 0 拦；未建模时恒 0 → 放行" do
    assert :ok = learn("buddhism", stats(), char())
    assert :ok = learn("buddhism", stats(), char(guilty: 0))
    assert_error("buddhism", stats(), char(guilty: 1), "屡犯僧家数戒")
  end

  test "gun：`!wizardp(me)` —— 角色切片不是 Kalevala.Character，恒非巫师 → 恒不可学" do
    assert_error("gun", stats(), char(), "无法学习枪械技术")
    assert_error("gun", stats(%{"gun" => 999}), %{}, "无法学习枪械技术")
  end

  # ---- 源内 can_learn/can_perform 标记门（未建模 → 跳过） ----

  test "jiuyang-shengong：末段 can_learn 副作用分支跳过，不影响其余门槛" do
    base = stats(%{"martial-cognize" => 100, "force" => 200}, %{int: 34, con: 38})

    assert_error("jiuyang-shengong", base, char(gender: "无性"), "无根无性")
    assert_error("jiuyang-shengong", base, char(personality: "狡黠多变"), "正大恢弘")
    assert_error("jiuyang-shengong", base, char(max_neili: 3499), "内力修为太浅")
    assert :ok = learn("jiuyang-shengong", base, char(personality: "心狠手辣", max_neili: 3500))
  end

  # ---- 局部派生量 ----

  test "qiankun-danuoyi：layer = lvl/50（上限 7），明教弟子恒 layer=1" do
    # 无性且已到 50 级 → 拦
    assert_error(
      "qiankun-danuoyi",
      stats(%{"qiankun-danuoyi" => 50}, %{int: 40}),
      char(gender: "无性"),
      "心中一阵迷茫"
    )

    # 同一份 stats（int 29 / force 550）：明教弟子 layer 恒 1 → 第一道门要 30 → 拦；
    # 非明教 layer 0，且第二道门 `39 + 0 - 550/50 = 28` → 29 不低于 28 → 放行。
    # 这一对用例专门锁「layer 计算 + force/50 除法 + family != 明教」三段语义。
    pair = stats(%{"force" => 550}, %{int: 29})

    assert_error("qiankun-danuoyi", pair, char(family: "明教", max_neili: 5000), "深奥无比")
    assert :ok = learn("qiankun-danuoyi", pair, char(max_neili: 5000))

    # 非明教时 int 28 < 29 → 第一道门就拦
    assert_error("qiankun-danuoyi", stats(%{"force" => 550}, %{int: 28}), char(max_neili: 5000), "深奥无比")
  end

  test "qufannao-zhi：aa=hunyuan-yiqi、bb=本门，`bb>=60 && aa<140 && 5*aa<=4*bb`" do
    # 空手门
    assert_error(
      "qufannao-zhi",
      stats(%{"hunyuan-yiqi" => 200}, %{str: 24}),
      char(equipped: %{weapon: %{skill_type: "sword"}}),
      "必须空手"
    )

    # bb 60 / aa 48：5*48=240 <= 4*60=240 → 拦
    assert_error(
      "qufannao-zhi",
      stats(%{"qufannao-zhi" => 60, "hunyuan-yiqi" => 48}, %{str: 24}),
      char(),
      "你的内功不够"
    )

    # aa 49 → 245 > 240 → 过；但 finger 不够
    assert_error(
      "qufannao-zhi",
      stats(%{"qufannao-zhi" => 60, "hunyuan-yiqi" => 49}, %{str: 24}),
      char(),
      "基本指法火候不够"
    )

    assert :ok =
             learn("qufannao-zhi", stats(%{"qufannao-zhi" => 60, "hunyuan-yiqi" => 49, "finger" => 120}, %{str: 24}), char())
  end

  test "taixuan-gong：识字（literate > 0）即参不透蝌蚪文" do
    base = stats(%{}, %{int: 38, dex: 34})
    assert_error("taixuan-gong", stats(%{"literate" => 1}, %{int: 38, dex: 34}), char(), "一时间难以领会")
    assert_error("taixuan-gong", base, char(gender: "无性"), "无根无性")
    assert :ok = learn("taixuan-gong", base, char())
  end

  # ---- 源内被注释掉的门不得生效（生成器去注释回归） ----

  describe "LPC 源内被注释掉的 if 不得迁成门槛" do
    test "pona-gong：`hunyuan-yiqi < 100` 在源里是 /* */ 注释，空手 + 内力够即可学" do
      assert :ok = learn("pona-gong", stats(%{"hunyuan-yiqi" => 0}), char(max_neili: 1500))
    end

    test "qinna-shibada：两处 `hunyuan-yiqi < 100` 都是注释" do
      ok = stats(%{"hunyuan-yiqi" => 0, "unarmed" => 100})
      assert :ok = learn("qinna-shibada", ok, char(max_neili: 1000))
    end

    test "yinlong-bian：`jiuyin-shengong > 0` 在源里是 // 注释" do
      ok = stats(%{"jiuyin-shengong" => 999, "force" => 100, "whip" => 100})
      assert :ok = learn("yinlong-bian", ok, char(max_neili: 1200, equipped: %{weapon: %{skill_type: "whip"}}))
    end

    test "dispel-poison：被注释的 `poison < 30` / `poison < 本门` 不生效，只剩 && 复合门" do
      # poison 0、medical 0、本门 0 → `poison < lvl` 为假 → 复合门整条不触发
      assert :ok = learn("dispel-poison", stats(%{"force" => 80}), char(max_neili: 350))

      # 本门 10 时：poison 0 < 10 且 medical 0 < 30 → 复合门拦
      assert_error(
        "dispel-poison",
        stats(%{"force" => 80, "dispel-poison" => 10}),
        char(max_neili: 350),
        "基本毒技和基本医术都水平有限"
      )
    end
  end

  # ---- 覆盖性与健壮性 ----

  test "全部 28 个技能都已注册且可调用 valid_learn/2" do
    for id <- @batch do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "任意角色形状下都不抛异常，只返回 :ok 或 {:error, binary}" do
    shapes = [
      %{},
      char(),
      char(max_neili: 0, neili: 0, gender: "无性"),
      char(personality: "心狠手辣", family: "少林派", guilty: 3, gender: "女性"),
      %{meta: %{vitals: %{max_neili: nil, neili: nil}, env: %{gender: nil}}},
      %{meta: %{family: nil, character: nil, guilty: nil}}
    ]

    for id <- @batch, shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != "", "#{id} 文案异常"
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
