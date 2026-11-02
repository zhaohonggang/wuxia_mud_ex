defmodule Kantele.Combat.SkillsValidLearnBatch5Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次5（16 个 HIDDEN_A2，无 personality 门）。
  对照口径同批次4：query_skill 1参→effective、2参→skill；max_neili→max_neili_of；
  武器门→Skill.wielding?/secondary_wielding?/wielded_skill_type。
  """
  use ExUnit.Case, async: true
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  # 派生属性（str/int/dex/con/per）走 struct 字段；其余一律当作技能等级放 :skills。
  # 未显式给出的派生属性默认给 100（足够通过门槛），仅“目标门槛测试”会显式给低值。
  @stat_keys ["str", "int", "dex", "con", "per"]
  @stat_default 100

  defp stats(map) do
    provided = MapSet.new(for({k, _} <- map, k in @stat_keys, do: k))

    base =
      Enum.reduce(map, Stats.new(), fn
        {k, v}, acc when k in @stat_keys -> Map.put(acc, String.to_atom(k), v)
        {_k, _v}, acc -> acc
      end)

    base =
      Enum.reduce(@stat_keys, base, fn k, acc ->
        if MapSet.member?(provided, k), do: acc, else: Map.put(acc, String.to_atom(k), @stat_default)
      end)

    skills = Map.new(for({k, v} <- map, not (k in @stat_keys), do: {k, v}))
    Map.put(base, :skills, skills)
  end
  defp char(opts), do: %{meta: %{vitals: %{max_neili: Keyword.get(opts, :max_neili, 20000)}, env: %{gender: Keyword.get(opts, :gender, "男性")}, combat: %{equipped: Keyword.get(opts, :equipped, %{})}}}
  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)
  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  test "jinshe-zhang：全达标 → :ok" do
    assert :ok = learn("jinshe-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "jinshe-zhang" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "jinshe-zhang：门1 max_neili_lt → 拦" do
    assert_error("jinshe-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "jinshe-zhang" => 1000}), char(max_neili: 499, equipped: {}), "你的内力不足，无法练金蛇游身掌。")
  end

  test "jinshe-zhang：门2 force_eff_lt → 拦" do
    assert_error("jinshe-zhang", stats(%{"force" => 158, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "jinshe-zhang" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候不够，无法练金蛇游身掌。")
  end

  test "jinshe-zhang：门3 skill_lt_self → 拦" do
    assert_error("jinshe-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "jinshe-zhang" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本掌法水平有限，无法领会更高深的金蛇游身掌。")
  end

  test "leiting-fu：全达标 → :ok" do
    assert :ok = learn("leiting-fu", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "leiting-fu：门1 stat_lt → 拦" do
    assert_error("leiting-fu", stats(%{"force" => 1000, "sword" => 1000, "strike" => 0, "hammer" => 1000, "blade" => 1000, "claw" => 0, "finger" => 0, "unarmed" => 0, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1000, "str" => 34}), char(max_neili: 20000, equipped: {}), "你的先天膂力孱弱，无法修炼雷霆斧法。")
  end

  test "leiting-fu：门2 max_neili_lt → 拦" do
    assert_error("leiting-fu", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1000}), char(max_neili: 2999, equipped: {}), "你的内力修为太浅，无法修炼雷霆斧法。")
  end

  test "leiting-fu：门3 force_eff_lt → 拦" do
    assert_error("leiting-fu", stats(%{"force" => 598, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候太浅，无法修炼雷霆斧法。")
  end

  test "leiting-fu：门4 skill_raw_lt → 拦" do
    assert_error("leiting-fu", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 179, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本锤法火候太浅，无法修炼雷霆斧法。")
  end

  test "leiting-fu：门5 skill_lt_self → 拦" do
    assert_error("leiting-fu", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "leiting-fu" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本锤法水平有限，无法领会更高深的雷霆斧法。")
  end

  test "lingyun-jian：全达标 → :ok" do
    assert :ok = learn("lingyun-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}))
  end

  test "lingyun-jian：门1 sword_required → 拦" do
    assert_error("lingyun-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "blade"}}), "你必须先找一把剑才能练剑法。")
  end

  test "lingyun-jian：门2 max_neili_lt → 拦" do
    assert_error("lingyun-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1000}), char(max_neili: 299, equipped: %{weapon: %{skill_type: "sword"}}), "你的内力不够，没有办法练凌云剑法。")
  end

  test "lingyun-jian：门3 force_eff_lt → 拦" do
    assert_error("lingyun-jian", stats(%{"force" => 198, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的内功火候太浅。")
  end

  test "lingyun-jian：门4 skill_raw_lt → 拦" do
    assert_error("lingyun-jian", stats(%{"force" => 1000, "sword" => 89, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法火候不够，无法学习凌云剑法。")
  end

  test "lingyun-jian：门5 skill_lt_self → 拦" do
    assert_error("lingyun-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lingyun-jian" => 1001}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法火候有限，无法领会更高深的凌云剑法。")
  end

  test "lunhui-jian：全达标 → :ok" do
    assert :ok = learn("lunhui-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lunhui-jian" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "lunhui-jian：门1 max_neili_lt → 拦" do
    assert_error("lunhui-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lunhui-jian" => 1000}), char(max_neili: 4999, equipped: {}), "你的内力修为不够，难以修炼释迦轮回剑。")
  end

  test "lunhui-jian：门2 force_eff_lt → 拦" do
    assert_error("lunhui-jian", stats(%{"force" => 698, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lunhui-jian" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候太浅，难以修炼释迦轮回剑。")
  end

  test "lunhui-jian：门3 skill_raw_lt → 拦" do
    assert_error("lunhui-jian", stats(%{"force" => 1000, "sword" => 249, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lunhui-jian" => 1000}), char(max_neili: 20000, equipped: {}), "你的剑法根基不足，难以修炼释迦轮回剑。")
  end

  test "lunhui-jian：门4 skill_lt_self → 拦" do
    assert_error("lunhui-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "lunhui-jian" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本剑法水平有限，无法领会更高深的释迦轮回剑。")
  end

  test "panlong-zhao：全达标 → :ok" do
    assert :ok = learn("panlong-zhao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "panlong-zhao：门1 empty_hand → 拦" do
    assert_error("panlong-zhao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "练越空盘龙爪必须空手。")
  end

  test "panlong-zhao：门2 force_eff_lt → 拦" do
    assert_error("panlong-zhao", stats(%{"force" => 98, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候不够，无法学越空盘龙爪。")
  end

  test "panlong-zhao：门3 max_neili_lt → 拦" do
    assert_error("panlong-zhao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1000}), char(max_neili: 399, equipped: {}), "你的内力太弱，无法练越空盘龙爪。")
  end

  test "panlong-zhao：门4 skill_eff_lt → 拦" do
    assert_error("panlong-zhao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 58, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本爪法等级太低，无法学越空盘龙爪。")
  end

  test "panlong-zhao：门5 skill_lt_self → 拦" do
    assert_error("panlong-zhao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "panlong-zhao" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本爪法火候水平有限，无法领会更高深的越空盘龙爪。")
  end

  test "poyang-jian：全达标 → :ok" do
    assert :ok = learn("poyang-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}))
  end

  test "poyang-jian：门1 sword_required → 拦" do
    assert_error("poyang-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "blade"}}), "你使用的武器不对。")
  end

  test "poyang-jian：门2 force_eff_lt → 拦" do
    assert_error("poyang-jian", stats(%{"force" => 298, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的内功火候不够，不能学习破阳冷光剑。")
  end

  test "poyang-jian：门3 max_neili_lt → 拦" do
    assert_error("poyang-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1000}), char(max_neili: 1799, equipped: %{weapon: %{skill_type: "sword"}}), "你的内力修为不够，不能学习破阳冷光剑。")
  end

  test "poyang-jian：门4 skill_raw_lt → 拦" do
    assert_error("poyang-jian", stats(%{"force" => 1000, "sword" => 99, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法火候不够，不能学习破阳冷光剑。")
  end

  test "poyang-jian：门5 skill_lt_self → 拦" do
    assert_error("poyang-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "poyang-jian" => 1001}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法水平有限，无法领会更高深的破阳冷光剑。")
  end

  test "qufeng：全达标 → :ok" do
    assert :ok = learn("qufeng", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "qufeng" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "qufeng：门1 skill_raw_lt → 拦" do
    assert_error("qufeng", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 29, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "qufeng" => 1000}), char(max_neili: 20000, equipped: {}), "你的玉女心法火候不够，无法学驱蜂之术。")
  end

  test "qufeng：门2 max_neili_lt → 拦" do
    assert_error("qufeng", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "qufeng" => 1000}), char(max_neili: 299, equipped: {}), "你的内力太弱，无法学习驱蜂之术。")
  end

  test "songyang-zhang：全达标 → :ok" do
    assert :ok = learn("songyang-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "songyang-zhang：门1 empty_hand → 拦" do
    assert_error("songyang-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "练嵩阳掌必须空手。")
  end

  test "songyang-zhang：门2 force_eff_lt → 拦" do
    assert_error("songyang-zhang", stats(%{"force" => 158, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候不够，无法学嵩阳掌。")
  end

  test "songyang-zhang：门3 max_neili_lt → 拦" do
    assert_error("songyang-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1000}), char(max_neili: 399, equipped: {}), "你的内力太弱，无法嵩阳掌。")
  end

  test "songyang-zhang：门4 skill_raw_lt → 拦" do
    assert_error("songyang-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 79, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本掌法火候太浅。")
  end

  test "songyang-zhang：门5 skill_lt_self → 拦" do
    assert_error("songyang-zhang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "songyang-zhang" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本掌法水平有限，无法领会更高深的嵩阳掌。")
  end

  test "taohua-zhangfa：全达标 → :ok" do
    assert :ok = learn("taohua-zhangfa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "taohua-zhangfa" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "taohua-zhangfa：门1 empty_hand → 拦" do
    assert_error("taohua-zhangfa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "taohua-zhangfa" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "练桃花掌法必须空手。")
  end

  test "taohua-zhangfa：门2 max_neili_lt → 拦" do
    assert_error("taohua-zhangfa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "taohua-zhangfa" => 1000}), char(max_neili: 99, equipped: {}), "你的内力太弱，无法练桃花掌法。")
  end

  test "taohua-zhangfa：门3 skill_lt_self → 拦" do
    assert_error("taohua-zhangfa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "taohua-zhangfa" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本掌法水平有限，无法领会更高深的桃花掌法。")
  end

  test "tianlong-zhi：全达标 → :ok" do
    assert :ok = learn("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "tianlong-zhi：门1 other_raw_gt → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 1, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 20000, equipped: {}), "你已将这种指法融入参合指，不必再分开练习了。")
  end

  test "tianlong-zhi：门2 empty_hand → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "大天龙指必须空手。")
  end

  test "tianlong-zhi：门3 force_eff_lt → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 198, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候不够，无法学大天龙指。")
  end

  test "tianlong-zhi：门4 skill_raw_lt → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 39, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本指法火候不够，无法学大天龙指。")
  end

  test "tianlong-zhi：门5 max_neili_lt → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1000}), char(max_neili: 999, equipped: {}), "你的内力太弱，无法练大天龙指。")
  end

  test "tianlong-zhi：门6 skill_lt_self → 拦" do
    assert_error("tianlong-zhi", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "tianlong-zhi" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本指法太差，无法领会更高深的大天龙指。")
  end

  test "wushen-jian：全达标 → :ok" do
    assert :ok = learn("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}))
  end

  test "wushen-jian：门1 sword_required → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "blade"}}), "你必须先找一柄剑才能够练习。")
  end

  test "wushen-jian：门2 stat_lt → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0, "int" => 29}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的先天悟性不足，没有办法练衡山五神剑。")
  end

  test "wushen-jian：门3 stat_lt → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0, "dex" => 27}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的先天身法孱弱，没有办法练衡山五神剑。")
  end

  test "wushen-jian：门4 skill_raw_lt → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 179, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你觉得衡山五神剑极其深奥，依照自己的武学修养难以理解。")
  end

  test "wushen-jian：门5 max_neili_lt → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0}), char(max_neili: 3999, equipped: %{weapon: %{skill_type: "sword"}}), "你的内力修为不够，没有办法练衡山五神剑。")
  end

  test "wushen-jian：门6 skill_raw_lt → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 199, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1000, "baihua-cuoquan" => 0}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法太差，没有办法练衡山五神剑。")
  end

  test "wushen-jian：门7 skill_lt_self → 拦" do
    assert_error("wushen-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1001, "baihua-cuoquan" => 0}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法火候有限，无法领会更高深的衡山五神剑。")
  end

  test "xue-qiongcang：全达标 → :ok" do
    assert :ok = learn("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "jin-chenxi" => 2000, "xue-qiongcang" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "xue-qiongcang：门1 other_raw_gt → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 1, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000}), char(max_neili: 20000, equipped: {}), "你已经将浑天宝鉴神功合一，不必再单独学习。")
  end

  test "xue-qiongcang：门2 empty_hand → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "修行血穹苍心法必须空手。")
  end

  test "xue-qiongcang：门3 stat_lt → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 0, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000, "con" => 34}), char(max_neili: 20000, equipped: {}), "你身子骨太弱，无法练习浑天宝鉴神功。")
  end

  test "xue-qiongcang：门4 skill_raw_lt → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 239, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000}), char(max_neili: 20000, equipped: {}), "你的拳脚火候无法学习血穹苍心法。")
  end

  test "xue-qiongcang：门5 skill_raw_lt → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 239, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候无法学习血穹苍心法。")
  end

  test "xue-qiongcang：门6 max_neili_lt → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 1000}), char(max_neili: 6999, equipped: {}), "你的内力修为太差，无法学习血穹苍心法。")
  end

  test "xue-qiongcang：门7 special_jin_chenxi → 拦" do
    assert_error("xue-qiongcang", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "xue-qiongcang" => 200, "jin-chenxi" => 100}), char(max_neili: 20000, equipped: {}), "你必须先提高你的金晨曦心法。")
  end

  test "yingzhao-shou：全达标 → :ok" do
    assert :ok = learn("yingzhao-shou", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "yingzhao-shou" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "yingzhao-shou：门1 other_raw_gt → 拦" do
    assert_error("yingzhao-shou", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 1, "yingzhao-shou" => 1000}), char(max_neili: 20000, equipped: {}), "你已经练成了百花错拳，不必再单独学习了。")
  end

  test "yingzhao-shou：门2 empty_hand → 拦" do
    assert_error("yingzhao-shou", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "yingzhao-shou" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{}}), "练鹰爪手必须空手。")
  end

  test "yingzhao-shou：门3 skill_lt_self → 拦" do
    assert_error("yingzhao-shou", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "yingzhao-shou" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本爪法火候不足，无法领会更高深的鹰爪手。")
  end

  test "zhurong-jian：全达标 → :ok" do
    assert :ok = learn("zhurong-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zhurong-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}))
  end

  test "zhurong-jian：门1 other_raw_gt → 拦" do
    assert_error("zhurong-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 1, "baihua-cuoquan" => 0, "zhurong-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你已演练合成了衡山五神剑，不必再单独学习。")
  end

  test "zhurong-jian：门2 sword_required → 拦" do
    assert_error("zhurong-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zhurong-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "blade"}}), "你必须先找一把剑才能练剑法。")
  end

  test "zhurong-jian：门3 max_neili_lt → 拦" do
    assert_error("zhurong-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zhurong-jian" => 1000}), char(max_neili: 799, equipped: %{weapon: %{skill_type: "sword"}}), "你的内力不够，没有办法练祝融剑法。")
  end

  test "zhurong-jian：门4 skill_raw_lt → 拦" do
    assert_error("zhurong-jian", stats(%{"force" => 1000, "sword" => 119, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zhurong-jian" => 1000}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法太差，没有办法练祝融剑法。")
  end

  test "zhurong-jian：门5 skill_lt_self → 拦" do
    assert_error("zhurong-jian", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zhurong-jian" => 1001}), char(max_neili: 20000, equipped: %{weapon: %{skill_type: "sword"}}), "你的基本剑法火候有限，无法领会更高深的祝融剑法。")
  end

  test "zijinbagua-dao：全达标 → :ok" do
    assert :ok = learn("zijinbagua-dao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zijinbagua-dao" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "zijinbagua-dao：门1 max_neili_lt → 拦" do
    assert_error("zijinbagua-dao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zijinbagua-dao" => 1000}), char(max_neili: 1199, equipped: {}), "你的内力修为尚浅，无法练习紫金八卦刀。")
  end

  test "zijinbagua-dao：门2 force_eff_lt → 拦" do
    assert_error("zijinbagua-dao", stats(%{"force" => 298, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zijinbagua-dao" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候太浅。")
  end

  test "zijinbagua-dao：门3 skill_raw_lt → 拦" do
    assert_error("zijinbagua-dao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 119, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zijinbagua-dao" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本刀法水平有限，无法练习紫金八卦刀。")
  end

  test "zijinbagua-dao：门4 skill_lt_self → 拦" do
    assert_error("zijinbagua-dao", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "zijinbagua-dao" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本刀法水平有限，无法领会更高深的紫金八卦刀。")
  end

  test "ziwu-daxuefa：全达标 → :ok" do
    assert :ok = learn("ziwu-daxuefa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "ziwu-daxuefa" => 1000}), char(max_neili: 20000, equipped: {}))
  end

  test "ziwu-daxuefa：门1 max_neili_lt → 拦" do
    assert_error("ziwu-daxuefa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "ziwu-daxuefa" => 1000}), char(max_neili: 499, equipped: {}), "你的内力修为太浅，无法练子午打穴法。")
  end

  test "ziwu-daxuefa：门2 force_eff_lt → 拦" do
    assert_error("ziwu-daxuefa", stats(%{"force" => 198, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "ziwu-daxuefa" => 1000}), char(max_neili: 20000, equipped: {}), "你的内功火候太浅，无法练子午打穴法。")
  end

  test "ziwu-daxuefa：门3 skill_raw_lt → 拦" do
    assert_error("ziwu-daxuefa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 79, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "ziwu-daxuefa" => 1000}), char(max_neili: 20000, equipped: {}), "你的基本短兵火候太浅，无法练子午打穴法。")
  end

  test "ziwu-daxuefa：门4 skill_lt_self → 拦" do
    assert_error("ziwu-daxuefa", stats(%{"force" => 1000, "sword" => 1000, "strike" => 1000, "hammer" => 1000, "blade" => 1000, "claw" => 1000, "finger" => 1000, "unarmed" => 1000, "dagger" => 1000, "martial-cognize" => 1000, "yunv-xinfa" => 1000, "huntian-baojian" => 0, "canhe-zhi" => 0, "wushen-jian" => 0, "baihua-cuoquan" => 0, "ziwu-daxuefa" => 1001}), char(max_neili: 20000, equipped: {}), "你的基本短兵水平有限，无法领会更高深的子午打穴法。")
  end

  test "批次5 共 16 技能均已注册并导出 valid_learn/2" do
    for id <- ["jinshe-zhang", "leiting-fu", "lingyun-jian", "lunhui-jian", "panlong-zhao", "poyang-jian", "qufeng", "songyang-zhang", "taohua-zhangfa", "tianlong-zhi", "wushen-jian", "xue-qiongcang", "yingzhao-shou", "zhurong-jian", "zijinbagua-dao", "ziwu-daxuefa"] do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end
end