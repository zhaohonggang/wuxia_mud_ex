defmodule Kantele.Combat.SkillForceHitObTest do
  @moduledoc """
  攻击方内功（force）命中回调集成测试：验证 `Engine.apply_force_hit_ob`
  （combatd.c:707 路径，对应 LPC `freezing-force` / `hanbing-zhenqi` 的 `hit_ob`）
  在 `attack_round` 中经 `attacker.mapped["force"]` 触发，并把 `affect_by`
  上到防守方 `round.conditions`。

  攻击方用内联武学模块当映射特技（仅负责造成命中），force 技能直接用已注册的
  真实 `FreezingForce` / `HanbingZhenqi` 模块。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills

  defmodule MartialSkill do
    use Kantele.Combat.Skill

    @impl true
    def id(), do: "force-martial-test"

    @impl true
    def valid_enable(_usage), do: true

    @impl true
    def query_action(_, _rng \\ &:rand.uniform/1) do
      %{
        "action" => "出招",
        "force" => 0,
        "attack" => 0,
        "dodge" => 0,
        "parry" => 0,
        "damage" => 20,
        "lvl" => 0,
        "damage_type" => "外伤",
        "skill_name" => "test"
      }
    end
  end

  defp max_rng(), do: fn n -> n end

  defp base_attacker(force_skill) do
    %Fighter{
      id: "attacker",
      name: "张三",
      pid: self(),
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      skills: %{"force-martial-test" => 1, force_skill => 200, "force" => 200},
      mapped: %{"sword" => "force-martial-test", "force" => force_skill},
      applies: %{damage: 30, armor: 0},
      busy: 0,
      jiali: 20,
      neili: 500,
      max_neili: 1000,
      attack_skill: "sword",
      weapon_name: nil
    }
  end

  defp low_force_victim do
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
      applies: %{armor: 0},
      busy: 0,
      neili: 0,
      attack_skill: "unarmed",
      weapon_name: nil
    }
  end

  setup do
    Skills.register("force-martial-test", MartialSkill)

    on_exit(fn -> Skills.unregister("force-martial-test") end)
    :ok
  end

  describe "force 技能 hit_ob 经 apply_force_hit_ob 触发（combatd.c:707）" do
    test "freezing-force：命中后给 victim 上 freezingbc 寒毒" do
      round = Engine.attack_round(base_attacker("freezing-force"), low_force_victim(), rng: max_rng())

      assert round.outcome == :hit

      assert Enum.any?(round.conditions, fn
        {"freezingbc", para} ->
          para["id"] == "attacker" and is_integer(para["level"]) and para["level"] > 0

        _ ->
          false
      end)
    end

    test "未映射 force 技能时不触发冰封" do
      attacker = %{base_attacker("freezing-force") | mapped: %{"sword" => "force-martial-test"}}
      round = Engine.attack_round(attacker, low_force_victim(), rng: max_rng())

      assert round.outcome == :hit
      refute Enum.any?(round.conditions, fn {cnd, _} -> cnd == "freezingbc" end)
    end

    test "jiali 不足（combatd.c:703 门控）时不触发冰封" do
      attacker = %{base_attacker("freezing-force") | jiali: 0}
      round = Engine.attack_round(attacker, low_force_victim(), rng: max_rng())

      assert round.outcome == :hit
      refute Enum.any?(round.conditions, fn {cnd, _} -> cnd == "freezingbc" end)
    end

    test "hanbing-zhenqi：已运 freezing 且全门通过时给 victim 上 freezing 寒毒" do
      attacker =
        %{base_attacker("hanbing-zhenqi") | jiali: 120, neili: 900,
          skills: %{"force-martial-test" => 1, "hanbing-zhenqi" => 300, "force" => 300},
          freezing_buff: true}

      round = Engine.attack_round(attacker, low_force_victim(), rng: max_rng())

      assert round.outcome == :hit

      assert Enum.any?(round.conditions, fn
        {"freezing", para} ->
          para["id"] == "attacker" and para["level"] == 360

        _ ->
          false
      end)
    end

    test "hanbing-zhenqi：未运 freezing（freezing_buff=false）不触发" do
      attacker =
        %{base_attacker("hanbing-zhenqi") | jiali: 120, neili: 900,
          skills: %{"force-martial-test" => 1, "hanbing-zhenqi" => 300, "force" => 300},
          freezing_buff: false}

      round = Engine.attack_round(attacker, low_force_victim(), rng: max_rng())

      assert round.outcome == :hit
      refute Enum.any?(round.conditions, fn {cnd, _} -> cnd == "freezing" end)
    end
  end
end
