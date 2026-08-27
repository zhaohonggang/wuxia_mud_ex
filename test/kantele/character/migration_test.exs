defmodule Kantele.Character.MigrationTest do
  use ExUnit.Case, async: true

  alias ExVenture.Characters.Metadata
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  describe "P2 learned_points 存档迁移" do
    test "旧存档（无 learned_points 列）默认 0，不追溯" do
      metadata = %Metadata{
        character_id: 999_901,
        str: 20,
        dex: 22,
        con: 20,
        int: 25,
        combat_exp: 500,
        potential: 100,
        max_neili: 400,
        skills: %{"liuxin-jian" => 30, "liuxi-neigong" => 25},
        equipment: %{
          "weapon" => %{"name" => "铁剑", "skill_type" => "sword", "damage" => 12}
        }
      }

      character = fresh_character()
      result = Records.apply_to_character(character, {:ok, metadata})
      stats = result.meta.stats

      assert stats.learned_points == 0
      assert stats.potential == 100
      assert Stats.available_potential(stats) == 100
      # 特技等级保留（非 base skill 不受 default merge 影响）
      assert stats.skills["liuxin-jian"] == 30
      assert stats.skills["liuxi-neigong"] == 25
      # base skill 取 max(default, loaded)
      assert stats.skills["sword"] >= 60
    end

    test "新存档（含 learned_points）正确恢复" do
      metadata = %Metadata{
        character_id: 999_902,
        potential: 100,
        learned_points: 20,
        skills: %{"liuxin-jian" => 15}
      }

      character = fresh_character()
      result = Records.apply_to_character(character, {:ok, metadata})
      stats = result.meta.stats

      assert stats.learned_points == 20
      assert Stats.available_potential(stats) == 80
    end
  end

  describe "B4 装备双读兼容" do
    test "旧单槽位 equipment（weapon + armor）恢复到正确槽位" do
      metadata = %Metadata{
        character_id: 999_903,
        equipment: %{
          "weapon" => %{"name" => "铁剑", "skill_type" => "sword", "damage" => 12},
          "armor" => %{"name" => "布衣", "armor" => 5}
        }
      }

      character = fresh_character()
      result = Records.apply_to_character(character, {:ok, metadata})
      combat = result.meta.combat

      weapon = Map.get(combat.equipped, :weapon)
      assert weapon != nil
      assert weapon.name == "铁剑"

      # armor → :cloth 槽位（旧 key 归一化）
      cloth = Map.get(combat.equipped, :cloth)
      assert cloth != nil
      assert cloth.name == "布衣"
    end

    test "新多槽位 equipment 正确恢复" do
      metadata = %Metadata{
        character_id: 999_904,
        equipment: %{
          "weapon" => %{"name" => "长剑", "skill_type" => "sword", "damage" => 15},
          "cloth" => %{"name" => "皮甲", "armor" => 10},
          "head" => %{"name" => "斗笠", "armor" => 3}
        }
      }

      character = fresh_character()
      result = Records.apply_to_character(character, {:ok, metadata})
      combat = result.meta.combat

      assert Map.get(combat.equipped, :weapon).name == "长剑"
      assert Map.get(combat.equipped, :cloth).name == "皮甲"
      assert Map.get(combat.equipped, :head).name == "斗笠"
    end
  end

  defp fresh_character do
    %Kalevala.Character{
      id: "test-1",
      name: "test",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new()
      }
    }
  end
end
