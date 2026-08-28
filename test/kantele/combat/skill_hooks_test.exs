defmodule Kantele.Combat.SkillHooksTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills

  defmodule AbsorbSkill do
    use Kantele.Combat.Skill

    @impl true
    def id(), do: "absorb-test"

    @impl true
    def valid_enable(_usage), do: true

    @impl true
    def query_action(_, _rng \\ &:rand.uniform/1) do
      %{
        "action" => "$N施出「借力打力」，将$n的攻击尽数卸去",
        "force" => 0,
        "attack" => 0,
        "dodge" => 0,
        "parry" => 0,
        "damage" => 10,
        "lvl" => 0,
        "damage_type" => "震伤",
        "skill_name" => "借力打力"
      }
    end

    @impl true
    def valid_damage(_attacker, _victim, _damage, _action), do: {0, "你被化于无形。\n"}

    @impl true
    def query_effect_parry(%{skills: skills}) when map_size(skills) > 0, do: 80
    def query_effect_parry(_), do: 0
  end

  defp max_rng(), do: fn n -> n end

  defp attacker do
    %Fighter{
      id: "attacker",
      name: "张三",
      pid: self(),
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      skills: %{"absorb-test" => 1, "sword" => 1, "dodge" => 1, "parry" => 1},
      mapped: %{"sword" => "absorb-test"},
      applies: %{damage: 22, armor: 0},
      busy: 0,
      jiali: 0,
      neili: 0,
      attack_skill: "sword",
      weapon_name: "长剑"
    }
  end

  defp victim do
    %Fighter{
      id: "victim",
      name: "野猪",
      pid: self(),
      str: 16,
      dex: 20,
      con: 20,
      int: 6,
      combat_exp: 0,
      skills: %{"dodge" => 1, "parry" => 1},
      mapped: %{},
      applies: %{armor: 2},
      busy: 0,
      neili: 0,
      attack_skill: "unarmed",
      weapon_name: nil
    }
  end

  setup do
    Skills.register("absorb-test", AbsorbSkill)

    on_exit(fn -> Skills.unregister("absorb-test") end)
    :ok
  end

  describe "Skill 行为钩子默认值" do
    test "未实现的钩子有安全默认" do
      # 内建 liuxin-jian 未实现 valid_damage，走默认透传
      assert AbsorbSkill.skill_improved(%{}) |> is_map()
      assert AbsorbSkill.practice_check(%{}) == :ok
      assert AbsorbSkill.difficult_level(%{}) == 100
      assert AbsorbSkill.query_effect_dodge(%{}) == 0
    end
  end

  describe "valid_damage 钩子在引擎中生效" do
    test "映射特技的 valid_damage 完全化解伤害并追加文案" do
      round = Engine.attack_round(attacker(), victim(), rng: max_rng())

      assert round.outcome == :hit
      assert round.damage == 0
      assert Enum.any?(round.segments, &String.contains?(&1, "化于无形"))
    end

    test "query_effect_parry 阶梯加成可读" do
      assert AbsorbSkill.query_effect_parry(%{skills: %{"a" => 1}}) == 80
      assert AbsorbSkill.query_effect_parry(%{}) == 0
    end
  end
end
