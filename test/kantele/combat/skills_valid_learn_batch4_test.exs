defmodule Kantele.Combat.SkillsValidLearnBatch4Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次 4（HIDDEN_A1×6 + HIDDEN_A2×6）。

  HIDDEN_A1（仅 stats 派生门，arity-1）：chuixiao-jifa / guzheng-jifa / tanqin-jifa /
  yaowang-shenxin / zhenxin-fa / zhenxin-yimaifa
  HIDDEN_A2（需 arity-2）：chixin-jian / dafumo-quan / dian-canghai / hanbing-zhang /
  huanyin-zhi / jin-chenxi

  对照口径（与试点批一致）：`query("con"/"int"/"str")→Stats.query_*`；`query_skill(X,1)→
  Stats.skill`；`query_skill(X)`（1 参=有效等级）→`Stats.effective`；`max_neili`→
  arity-2 的 `max_neili_of`；`query_temp("weapon")/("secondary_weapon")→Skill.wielding?/
  secondary_wielding?`。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  defp stats(map \\ %{}) do
    base = Stats.new()
    {skills, attrs} = Enum.split_with(Map.to_list(map), fn {k, _} -> is_binary(k) end)
    stats = %{base | skills: Map.merge(base.skills, Map.new(skills))}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp char(opts \\ []) do
    meta = %{
      vitals: %{
        max_neili: Keyword.get(opts, :max_neili, 20_000),
        neili: Keyword.get(opts, :neili, 20_000)
      },
      env: %{gender: Keyword.get(opts, :gender, "男性")},
      combat: %{equipped: Keyword.get(opts, :equipped, %{})}
    }

    %{meta: meta}
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- HIDDEN_A1：派生命理 / query_skill 门（arity-1） ----

  test "chuixiao-jifa：query_int < 24 → 拦，>= 24 → 放" do
    assert_error("chuixiao-jifa", stats(), char(), "就你那悟性？五音不全，学什么吹箫")
    assert :ok = learn("chuixiao-jifa", stats(%{int: 30}), char())
  end

  test "guzheng-jifa / tanqin-jifa：同口径（int<24 拦，>=24 放）" do
    for id <- ~w(guzheng-jifa tanqin-jifa) do
      assert_error(id, stats(), char(), "五音不全")
      assert :ok = learn(id, stats(%{int: 30}), char())
    end
  end

  test "yaowang-shenxin：poison<150 拦 / dispel-poison<150 拦 / poison<本门 拦 / dispel<本门 拦 / 达标放" do
    assert_error("yaowang-shenxin", stats(%{"dispel-poison" => 200, "yaowang-shenxin" => 10}), char(), "你的基本毒技造诣太浅")
    assert_error("yaowang-shenxin", stats(%{"poison" => 200, "yaowang-shenxin" => 10}), char(), "你的妙手驱毒造诣太浅")
    assert_error("yaowang-shenxin", stats(%{"poison" => 200, "dispel-poison" => 200, "yaowang-shenxin" => 250}), char(), "你的基本毒技水平有限")
    assert_error("yaowang-shenxin", stats(%{"poison" => 250, "dispel-poison" => 200, "yaowang-shenxin" => 250}), char(), "你的妙手驱毒水平有限")
    assert :ok = learn("yaowang-shenxin", stats(%{"poison" => 200, "dispel-poison" => 200, "yaowang-shenxin" => 100}), char())
  end

  test "zhenxin-fa / zhenxin-yimaifa：medical<100 拦 / <本门拦 / 达标放" do
    for id <- ~w(zhenxin-fa zhenxin-yimaifa) do
      assert_error(id, stats(%{id => 10}), char(), "你的基本医术造诣太浅")
      assert_error(id, stats(%{"medical" => 200, id => 250}), char(), "你的基本医术水平有限")
      assert :ok = learn(id, stats(%{"medical" => 200, id => 100}), char())
    end
  end

  # ---- HIDDEN_A2：vitals / weapon / 派生根骨 / query_skill 门（arity-2） ----

  test "chixin-jian：max_neili<900 拦" do
    assert_error("chixin-jian", stats(%{"sword" => 200, "chixin-jian" => 10}),
      char(max_neili: 500, equipped: %{weapon: %{skill_type: "sword"}}), "你的内力不够")
  end

  test "chixin-jian：未持剑 / 持非剑 → 拦" do
    assert_error("chixin-jian", stats(%{"force" => 300, "sword" => 5, "chixin-jian" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}),
      "你的基本剑法火候不够，无法学习痴心情长剑")
    assert_error("chixin-jian", stats(%{"force" => 300, "sword" => 5, "chixin-jian" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{skill_type: "blade"}}),
      "你的基本剑法火候不够，无法学习痴心情长剑")
  end

  test "chixin-jian：force(eff)<120 → 拦" do
    # force skill=200 → effective=100 < 120
    assert_error("chixin-jian", stats(%{"force" => 200, "sword" => 200, "chixin-jian" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的内功火候太浅")
  end

  test "chixin-jian：全达标 → :ok" do
    assert :ok =
             learn("chixin-jian", stats(%{"force" => 300, "sword" => 200, "chixin-jian" => 10}),
               char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}})
             )
  end

  test "dafumo-quan：持武器 → 拦" do
    assert_error("dafumo-quan", stats(%{"force" => 300, "unarmed" => 200, "dafumo-quan" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{}}), "练大伏魔拳必须空手")
  end

  test "dafumo-quan：str<32 / max_neili<1500 / force(eff)<150 / unarmed<120 / <本门 拦" do
    assert_error("dafumo-quan", stats(%{:"str" => 20, "force" => 300, "dafumo-quan" => 10}),
      char(max_neili: 20000), "你先天臂力太弱，无法练大伏魔拳")
    assert_error("dafumo-quan", stats(%{:"str" => 40, "force" => 300, "unarmed" => 200, "dafumo-quan" => 10}),
      char(max_neili: 1000), "你的内力太弱，无法练大伏魔拳")
    assert_error("dafumo-quan", stats(%{:"str" => 40, "force" => 200, "unarmed" => 200, "dafumo-quan" => 10}),
      char(max_neili: 20000), "你的内功火候不够，无法练大伏魔拳")
    assert_error("dafumo-quan", stats(%{:"str" => 40, "force" => 300, "unarmed" => 50, "dafumo-quan" => 10}),
      char(max_neili: 20000), "你的基本拳脚火候不够，无法练大伏魔拳")
    assert_error("dafumo-quan", stats(%{:"str" => 40, "force" => 300, "unarmed" => 150, "dafumo-quan" => 200}),
      char(max_neili: 20000), "你的基本拳脚水平有限，无法领会更高深的大伏魔拳")
  end

  test "dafumo-quan：全达标（空手）→ :ok" do
    assert :ok =
             learn("dafumo-quan", stats(%{:"str" => 40, "force" => 300, "unarmed" => 200, "dafumo-quan" => 10}),
               char(max_neili: 20000)
             )
  end

  test "dian-canghai：huntian-baojian>0 → 拦" do
    assert_error("dian-canghai", stats(%{"huntian-baojian" => 1, "unarmed" => 200, "force" => 200, "dian-canghai" => 10}),
      char(max_neili: 20000), "你已经将浑天宝鉴神功合一，不必再单独学习")
  end

  test "dian-canghai：空手门 / con<35 / unarmed<200 / force<200 / max_neili<5000 拦" do
    assert_error("dian-canghai", stats(%{"unarmed" => 200, "force" => 200, "dian-canghai" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{}}), "修行靛沧海心法必须空手")
    assert_error("dian-canghai", stats(%{:"con" => 20, "unarmed" => 200, "dian-canghai" => 10}),
      char(max_neili: 20000), "你身子骨太弱，无法练习浑天宝鉴神功")
    assert_error("dian-canghai", stats(%{:"con" => 40, "unarmed" => 50, "force" => 200, "dian-canghai" => 10}),
      char(max_neili: 20000), "你的拳脚火候无法学习靛沧海心法")
    assert_error("dian-canghai", stats(%{:"con" => 40, "unarmed" => 200, "force" => 50, "dian-canghai" => 10}),
      char(max_neili: 20000), "你的内功火候无法学习靛沧海心法")
    assert_error("dian-canghai", stats(%{:"con" => 40, "unarmed" => 200, "force" => 200, "dian-canghai" => 10}),
      char(max_neili: 1000), "你的内力修为太差，无法学习靛沧海心法")
  end

  test "dian-canghai：xuan-huntun-10 < 本门 → 拦" do
    # xuan-huntun=100, dian-canghai=200 → 100-10=90 < 200
    assert_error("dian-canghai", stats(%{:"con" => 40, "unarmed" => 200, "force" => 200, "xuan-huntun" => 100, "dian-canghai" => 200}),
      char(max_neili: 20000), "你必须先提高你的玄馄饨心法")
  end

  test "dian-canghai：全达标 → :ok" do
    assert :ok =
             learn("dian-canghai",
               stats(%{:"con" => 40, "unarmed" => 200, "force" => 200, "xuan-huntun" => 300, "dian-canghai" => 100}),
               char(max_neili: 20000)
             )
  end

  test "hanbing-zhang：空手门 / force<120 / max_neili<600 / strike<100 / <本门 拦" do
    assert_error("hanbing-zhang", stats(%{"force" => 300, "strike" => 200, "hanbing-zhang" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{}}), "练寒冰掌必须空手")
    assert_error("hanbing-zhang", stats(%{"force" => 200, "strike" => 200, "hanbing-zhang" => 10}),
      char(max_neili: 20000), "你的内功火候不够，无法学寒冰掌")
    assert_error("hanbing-zhang", stats(%{"force" => 300, "strike" => 200, "hanbing-zhang" => 10}),
      char(max_neili: 100), "你的内力太弱，无法练寒冰掌")
    assert_error("hanbing-zhang", stats(%{"force" => 300, "strike" => 50, "hanbing-zhang" => 10}),
      char(max_neili: 20000), "你的基本掌法火候太浅")
    assert_error("hanbing-zhang", stats(%{"force" => 300, "strike" => 150, "hanbing-zhang" => 200}),
      char(max_neili: 20000), "你的基本掌法水平有限，无法领会更高深的寒冰掌")
  end

  test "hanbing-zhang：全达标（空手）→ :ok" do
    assert :ok =
             learn("hanbing-zhang", stats(%{"force" => 300, "strike" => 200, "hanbing-zhang" => 10}),
               char(max_neili: 20000)
             )
  end

  test "huanyin-zhi：空手门 / force<200 / max_neili<800 / finger<本门 拦" do
    assert_error("huanyin-zhi", stats(%{"force" => 300, "huanyin-zhi" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{}}), "练幻阴指法必须空手")
    assert_error("huanyin-zhi", stats(%{"force" => 200, "huanyin-zhi" => 10}),
      char(max_neili: 20000), "你的内功火候不够，无法学幻阴指法")
    assert_error("huanyin-zhi", stats(%{"force" => 450, "huanyin-zhi" => 10}),
      char(max_neili: 100), "你的内力太弱，无法练幻阴指法")
    assert_error("huanyin-zhi", stats(%{"force" => 450, "finger" => 50, "huanyin-zhi" => 100}),
      char(max_neili: 20000), "你的基本执法水平有限，无法领会更高深的幻阴指法")
  end

  test "huanyin-zhi：全达标（空手）→ :ok" do
    assert :ok =
             learn("huanyin-zhi", stats(%{"force" => 450, "finger" => 200, "huanyin-zhi" => 10}),
               char(max_neili: 20000)
             )
  end

  test "jin-chenxi：huntian>0 / 空手 / con<35 / unarmed<220 / force<220 / max_neili<6000 / dian-canghai-10<本门 拦" do
    assert_error("jin-chenxi", stats(%{"huntian-baojian" => 1, "unarmed" => 200, "force" => 200, "jin-chenxi" => 10}),
      char(max_neili: 20000), "你已经将浑天宝鉴神功合一，不必再单独学习")
    assert_error("jin-chenxi", stats(%{"unarmed" => 200, "force" => 200, "jin-chenxi" => 10}),
      char(max_neili: 20000, equipped: %{weapon: %{}}), "修行金晨曦心法必须空手")
    assert_error("jin-chenxi", stats(%{:"con" => 20, "unarmed" => 200, "jin-chenxi" => 10}),
      char(max_neili: 20000), "你身子骨太弱，无法练习浑天宝鉴神功")
    assert_error("jin-chenxi", stats(%{:"con" => 40, "unarmed" => 50, "force" => 200, "jin-chenxi" => 10}),
      char(max_neili: 20000), "你的拳脚火候无法学习金晨曦心法")
    assert_error("jin-chenxi", stats(%{:"con" => 40, "unarmed" => 250, "force" => 50, "jin-chenxi" => 10}),
      char(max_neili: 20000), "你的内功火候无法学习金晨曦心法")
    assert_error("jin-chenxi", stats(%{:"con" => 40, "unarmed" => 250, "force" => 250, "jin-chenxi" => 10}),
      char(max_neili: 1000), "你的内力修为太差，无法学习金晨曦心法")
    # dian-canghai=100, jin-chenxi=200 → 100-10=90 < 200
    assert_error("jin-chenxi", stats(%{:"con" => 40, "unarmed" => 250, "force" => 250, "dian-canghai" => 100, "jin-chenxi" => 200}),
      char(max_neili: 20000), "你必须先提高你的靛沧海心法")
  end

  test "jin-chenxi：全达标 → :ok" do
    assert :ok =
             learn("jin-chenxi",
               stats(%{:"con" => 40, "unarmed" => 250, "force" => 250, "dian-canghai" => 300, "jin-chenxi" => 100}),
               char(max_neili: 20000)
             )
  end

  test "批次4 共 12 技能均已注册并导出 valid_learn/2" do
    for id <- ~w(chuixiao-jifa guzheng-jifa tanqin-jifa yaowang-shenxin zhenxin-fa zhenxin-yimaifa
                 chixin-jian dafumo-quan dian-canghai hanbing-zhang huanyin-zhi jin-chenxi) do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end
end
