defmodule Kantele.Character.SkillsCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Character.SkillsCommand

  describe "skills 列表格式" do
    test "列出所有已学技能" do
      stats = %Stats{
        str: 20,
        dex: 20,
        con: 20,
        int: 20,
        combat_exp: 1000,
        potential: 100,
        learned_points: 0,
        skills: %{
          "unarmed" => 60,
          "sword" => 60,
          "dodge" => 60,
          "parry" => 60,
          "force" => 20,
          "liuxin-jian" => 15,
          "liuxi-neigong" => 10
        },
        mapped: %{"sword" => "liuxin-jian"},
        performs: MapSet.new()
      }

      text = SkillsCommand.format_skills(stats)

      assert text =~ "所有技能"
      assert text =~ "基本内功 (force)"
      assert text =~ "基本剑法 (sword)"
      assert text =~ "柳心剑法 (liuxin-jian)"
      assert text =~ "柳溪内功 (liuxi-neigong)"
      assert text =~ "轻功 (dodge)"
      assert text =~ "招架 (parry)"
      assert text =~ "基本拳脚 (unarmed)"
    end

    test "映射技能显示有效等级" do
      stats = %Stats{
        str: 20,
        dex: 20,
        con: 20,
        int: 20,
        combat_exp: 1000,
        potential: 100,
        learned_points: 0,
        skills: %{"sword" => 60, "liuxin-jian" => 15},
        mapped: %{"sword" => "liuxin-jian"},
        performs: MapSet.new()
      }

      text = SkillsCommand.format_skills(stats)

      assert text =~ "→"
      assert text =~ "有效 75 级"
    end

    test "未映射技能不显示有效等级" do
      stats = %Stats{
        str: 20,
        dex: 20,
        con: 20,
        int: 20,
        combat_exp: 1000,
        potential: 100,
        learned_points: 0,
        skills: %{"sword" => 60},
        mapped: %{},
        performs: MapSet.new()
      }

      text = SkillsCommand.format_skills(stats)

      refute text =~ "→"
    end
  end
end
