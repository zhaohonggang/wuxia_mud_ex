defmodule Kantele.Character.StatsEffectiveTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Character

  defp stats(skills, mapped \\ %{}) do
    struct(Stats.new(), skills: skills, mapped: mapped)
  end

  describe "Stats.effective/3（LPC query_skill 语义）" do
    test "未映射：基本技能折半" do
      s = stats(%{"sword" => 60})
      assert Stats.effective(s, "sword") == 30
    end

    test "已映射：基本折半 + 特技全值" do
      s = stats(%{"sword" => 60, "liuxin-jian" => 15}, %{"sword" => "liuxin-jian"})
      assert Stats.effective(s, "sword") == 45
    end

    test "未习得技能为 0" do
      assert Stats.effective(stats(%{}), "sword") == 0
    end

    test "apply 加成叠加在折半结果之上（LPC apply/<skill>）" do
      s = stats(%{"sword" => 60, "liuxin-jian" => 15}, %{"sword" => "liuxin-jian"})
      assert Stats.effective(s, "sword", %{sword: 5}) == 50
    end

    test "applies 支持字符串键（从 JSON 恢复的 prop）" do
      s = stats(%{"sword" => 60})
      assert Stats.effective(s, "sword", %{"sword" => 5}) == 35
    end

    test "applies 缺该键时为 0" do
      s = stats(%{"sword" => 60})
      assert Stats.effective(s, "sword", %{parry: 9}) == 30
    end

    test "applies 传 nil 也安全" do
      s = stats(%{"sword" => 60})
      assert Stats.effective(s, "sword", nil) == 30
    end
  end

  describe "Combat.skill_applies/1" do
    test "角色无 combat 状态 → 空表（不抛错）" do
      character = %Character{id: "p1", name: "张三", meta: %PlayerMeta{}}
      assert Combat.skill_applies(character) == %{}
      assert Combat.skill_applies(nil) == %{}
    end

    test "combat.temp 的 apply 键被带出" do
      combat = Combat.new() |> Combat.apply_temp(%{sword: 7, parry: 3})
      character = %Character{id: "p1", name: "张三", meta: %PlayerMeta{combat: combat}}

      applies = Combat.skill_applies(character)
      assert applies.sword == 7
      assert applies.parry == 3
    end

    test "装备 prop（护腕 armor_prop）计入 applies，从而抬高有效等级" do
      # 护腕 armor_prop: sword => apply_armor()/6+1，简化为 prop %{sword: 4}
      combat = %Combat{Combat.new() | equipped: %{wrists: %{name: "护腕", prop: %{sword: 4}}}}
      character = %Character{id: "p1", name: "张三", meta: %PlayerMeta{combat: combat}}

      s = stats(%{"sword" => 60, "liuxin-jian" => 15}, %{"sword" => "liuxin-jian"})
      assert Stats.effective(s, "sword", Combat.skill_applies(character)) == 49
    end

    test "vitals 存在也不影响 applies" do
      combat = Combat.new() |> Combat.apply_temp(%{whip: 2})
      meta = %PlayerMeta{vitals: %Vitals{qi: 100}, combat: combat}
      character = %Character{id: "p1", name: "张三", meta: meta}
      assert Combat.skill_applies(character).whip == 2
    end
  end
end
