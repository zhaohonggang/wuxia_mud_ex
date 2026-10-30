defmodule Kantele.Combat.SkillsDagouBangTest do
  @moduledoc """
  打狗棒法招式表迁移（C 相位，dagou-bang 真缺口补齐）。

  LPC `kungfu/skill/dagou-bang.c` 有 5 式：前 4 式静态（无 lvl/skill_name，视
  作 lvl 0），第 5 式「极意」（lvl 200，五项数值由 this_player 技能实时
  生成）。Elixir 侧此前 `query_action` 返回 `%{}`，出招无描述无伤害。本测试
  锁定：

  1. 静态表长 4 式，每式 damage_type 皆 挫伤；
  2. `query_action/2` 只取静态表，返回的 lvl 严格小于 level（level 0 回落第一式）；
  3. `query_action/3` 带角色上下文不崩溃，返回动作含 force/attack/dodge/parry/damage；
  4. `valid_enable`：staff/parry 可，其余不可；
  5. `query_skill_name`：level >= 200 为「极意」，其余为 nil（前 4 式无名）；
  6. 已进 `Skills` 注册表，`Engine.select_action` 端到端可出招。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DagouBang
  alias Kantele.Combat.Engine

  defp rng, do: fn _ -> 1 end

  describe "静态招式表（4 式，LPC 前 4 式无 lvl/skill_name 视作 lvl 0）" do
    test "表长 4 式" do
      assert length(DagouBang.actions()) == 4
    end

    test "每式 damage_type 皆 挫伤" do
      assert Enum.all?(DagouBang.actions(), fn a -> a["damage_type"] == "挫伤" end)
    end

    test "前 4 式无 skill_name（与 LPC 一致）" do
      assert Enum.all?(DagouBang.actions(), fn a -> is_nil(a["skill_name"]) end)
    end
  end

  describe "query_action/2 仅取静态表" do
    test "level 0 无可选招式，回落第一式" do
      for _ <- 1..20 do
        assert DagouBang.query_action(0, rng())["skill_name"] == nil
      end
    end

    test "level>=1 返回的 lvl 严格小于 level（前 4 式 lvl 0）" do
      Enum.each([1, 29, 30, 31, 50, 300], fn level ->
        action = DagouBang.query_action(level, rng())
        assert Map.get(action, "lvl", 0) < level
      end)
    end

    test "返回动作含完整数值字段（出招有描述与伤害）" do
      action = DagouBang.query_action(300, rng())
      assert is_binary(action["action"]) and action["action"] != ""
      assert is_integer(action["force"]) and action["force"] > 0
      assert is_integer(action["damage"]) and action["damage"] > 0
    end
  end

  describe "query_action/3 带角色上下文（含动态「极意」）" do
    test "level 300 带角色快照不崩溃，返回完整动作" do
      attacker = %Fighter{
        skills: %{"force" => 300, "staff" => 300, "dodge" => 300, "parry" => 300},
        weapon_name: "staff"
      }

      action = DagouBang.query_action(300, rng(), attacker)
      assert is_map(action)
      assert is_binary(action["action"]) and action["action"] != ""
      assert is_integer(action["force"]) and action["force"] > 0
      assert is_integer(action["attack"]) and action["attack"] > 0
      assert is_integer(action["dodge"]) and action["dodge"] > 0
      assert is_integer(action["parry"]) and action["parry"] > 0
      assert is_integer(action["damage"]) and action["damage"] > 0
    end

    test "attacker 为 nil 也不崩溃（宏回落路径）" do
      assert is_map(DagouBang.query_action(300, rng(), nil))
    end
  end

  describe "valid_enable（staff / parry 可，其余不可）" do
    test "staff / parry 为 true" do
      assert DagouBang.valid_enable("staff")
      assert DagouBang.valid_enable("parry")
    end

    test "其余 usage 为 false" do
      refute DagouBang.valid_enable("sword")
      refute DagouBang.valid_enable("force")
      refute DagouBang.valid_enable("dodge")
    end
  end

  describe "query_skill_name（含极意）" do
    test "level >= 200 为「极意」，其余为 nil" do
      assert DagouBang.query_skill_name(100) == nil
      assert DagouBang.query_skill_name(199) == nil
      assert DagouBang.query_skill_name(200) == "极意"
      assert DagouBang.query_skill_name(300) == "极意"
      assert DagouBang.query_skill_name(-1) == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("dagou-bang") == DagouBang
    end
  end

  describe "Engine.select_action/1 端到端" do
    test "能选出打狗棒招式" do
      fighter = %Fighter{
        attack_skill: "staff",
        mapped: %{"staff" => "dagou-bang"},
        skills: %{"dagou-bang" => 300, "force" => 300, "staff" => 300,
                  "dodge" => 300, "parry" => 300},
        weapon_name: "staff"
      }

      for _ <- 1..30 do
        action = Engine.select_action(fighter)
        # 前 4 式静态招式在 LPC 中无 skill_name（为 nil）；「极意」仅在
        # query_action/3 且 level > 200 时可能并入。此处断言动作本身完整。
        assert action["skill_name"] in [nil, "极意"]
        assert is_binary(action["action"]) and action["action"] != ""
        assert is_integer(action["damage"]) and action["damage"] > 0
      end
    end
  end

  describe "valid_learn/2 学习门槛（LPC dex>=26 / max_neili>=1500 / staff>=100 且 staff>=dagou-bang）" do
    defp stats(dex, staff, dagou) do
      %{dex: dex, skills: %{"staff" => staff, "dagou-bang" => dagou}}
    end

    defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

    test "dex < 26 被拒（先天身法太差）" do
      assert DagouBang.valid_learn(stats(20, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的先天身法太差，无法学习打狗棒法。\n"}
    end

    test "max_neili < 1500 被拒（内力修为不足）" do
      assert DagouBang.valid_learn(stats(30, 200, 50), char_with_max_neili(1000)) ==
               {:error, "你的内力修为不足，无法学习打狗棒法。\n"}
    end

    test "staff < 100 被拒（基本杖法不够）" do
      assert DagouBang.valid_learn(stats(30, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法不够，无法学习打狗棒法。\n"}
    end

    test "staff < dagou-bang 被拒（基本杖法水平有限）" do
      assert DagouBang.valid_learn(stats(30, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法水平有限，无法领会更高深的打狗棒法。\n"}
    end

    test "三项全满足则放行" do
      assert DagouBang.valid_learn(stats(30, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert DagouBang.valid_learn(stats(30, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DagouBang.valid_learn(stats(30, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 75 / neili 80）" do
    test "返回 LPC 一致的消耗" do
      assert DagouBang.practice_cost() == %{qi: 75, neili: 80}
    end
  end
end
