defmodule Kantele.Character.CheckskillCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Character.CheckskillCommand

  describe "checkskill 技能详情" do
    test "查询基本技能显示类型和等级" do
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

      text = CheckskillCommand.format_checkskill(stats, "sword")

      assert text =~ "基本剑法 (sword)"
      assert text =~ "等级：60"
      assert text =~ "类型：剑法（基本技能）"
    end

    test "查询已映射技能显示有效等级" do
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

      text = CheckskillCommand.format_checkskill(stats, "liuxin-jian")

      assert text =~ "柳心剑法 (liuxin-jian)"
      assert text =~ "等级：15"
      assert text =~ "映射到：基本剑法"
      assert text =~ "有效 75 级"
    end

    test "查询内功技能显示可启用用法" do
      stats = %Stats{
        str: 20,
        dex: 20,
        con: 20,
        int: 20,
        combat_exp: 1000,
        potential: 100,
        learned_points: 0,
        skills: %{"force" => 20, "liuxi-neigong" => 10},
        mapped: %{"force" => "liuxi-neigong"},
        performs: MapSet.new()
      }

      text = CheckskillCommand.format_checkskill(stats, "liuxi-neigong")

      assert text =~ "柳溪内功 (liuxi-neigong)"
      assert text =~ "可启用到：基本内功"
    end

    test "查询不存在的技能 id 返回基本信息" do
      stats = Stats.new()

      text = CheckskillCommand.format_checkskill(stats, "nonexistent")

      assert text =~ "nonexistent"
      assert text =~ "等级：0"
    end
  end

  describe "resolve_skill_id 技能名解析" do
    test "按 id 解析" do
      assert CheckskillCommand.resolve_skill_id("sword") == "sword"
      assert CheckskillCommand.resolve_skill_id("liuxin-jian") == "liuxin-jian"
    end

    test "按中文标题模糊匹配" do
      assert CheckskillCommand.resolve_skill_id("柳心") == "liuxin-jian"
      assert CheckskillCommand.resolve_skill_id("柳溪") == "liuxi-neigong"
      assert CheckskillCommand.resolve_skill_id("基本内功") == "force"
      assert CheckskillCommand.resolve_skill_id("基本剑法") == "sword"
    end

    test "无法匹配返回 nil" do
      assert CheckskillCommand.resolve_skill_id("不存在的技能") == nil
    end
  end
end
