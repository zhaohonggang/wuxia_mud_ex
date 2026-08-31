defmodule Kantele.Combat.ForceTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Force

  describe "valid_learn?" do
    test "requires force skill >= 10" do
      refute Force.valid_learn?(9)
      assert Force.valid_learn?(10)
      assert Force.valid_learn?(100)
    end
  end

  describe "hit_ob" do
    test "low attacker exp consumes neili" do
      assert Force.hit_ob(%{}, %{}, 0, 10,
               attacker_combat_exp: 1000,
               defender_combat_exp: 100_000
             ) == {:neili_consume, 10}
    end

    test "calculates damage with neili factors" do
      result =
        Force.hit_ob(%{}, %{}, 0, 50,
          attacker_neili: 1000,
          attacker_max_neili: 1000,
          defender_neili: 800,
          defender_max_neili: 800,
          attacker_force: 100,
          defender_force: 80,
          attacker_combat_exp: 50_000_000,
          defender_combat_exp: 500_000
        )

      assert elem(result, 0) == :damage
    end

    test "counterattack when defender force is higher" do
      result =
        Force.hit_ob(%{}, %{}, 0, 10,
          attacker_neili: 100,
          attacker_max_neili: 100,
          defender_neili: 1000,
          defender_max_neili: 1000,
          attacker_force: 50,
          defender_force: 150,
          attacker_combat_exp: 50_000_000,
          defender_combat_exp: 500_000,
          attacker_weapon: nil
        )

      assert elem(result, 0) in [:counterattack, :damage]
    end
  end

  describe "classify_counter_damage" do
    test "classifies damage levels" do
      assert Force.classify_counter_damage(5) == :mild
      assert Force.classify_counter_damage(15) == :moderate
      assert Force.classify_counter_damage(30) == :heavy
      assert Force.classify_counter_damage(70) == :severe
      assert Force.classify_counter_damage(100) == :critical
    end
  end

  describe "do_effect" do
    test "NPCs get no effect" do
      assert Force.do_effect(%{}, is_player: false) == {:ok, :no_effect}
    end

    test "low skill gets no effect" do
      assert Force.do_effect(%{}, skills: %{}, is_player: true) == {:ok, :no_effect}
    end

    test "high shaolin skill triggers deviation check" do
      skills = %{"force" => 200, "buddhism" => 200}
      result = Force.do_effect(%{}, skills: skills, is_player: true)
      assert elem(result, 0) in [:ok, :warning]
    end
  end
end
