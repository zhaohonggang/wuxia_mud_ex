defmodule Kantele.World.NpcSkillsLoaderTest do
  @moduledoc """
  #1040：LPC `set_skill` / `map_skill` 被转换器写成角色块顶层 `skills = [...]`，
  此前 loader 只读 `combat.skills`，1,300+ NPC 的技能等级全部丢失。
  本文件用真实 UCL 数据锁住解析结果、技能名归一、教学门控与旧格式兼容。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  @moduletag :npc_skills

  setup_all do
    %{world: Loader.load()}
  end

  defp zone_npc(world, zone_id, key) do
    zone = Enum.find(world.zones, &(&1.id == zone_id))
    Map.get(zone.characters || %{}, String.to_atom(key))
  end

  test "顶层 skills 列表进入 stats.skills，{type, skill} 进入 stats.mapped", ctx do
    dao = zone_npc(ctx.world, "clone_lib", "shaolin_dao_chen")

    # LPC kungfu/class/shaolin/dao-chen.c 的 11 条 set_skill
    for {skill, level} <- [
          {"force", 50},
          {"hunyuan-yiqi", 50},
          {"shaolin-xinfa", 50},
          {"dodge", 50},
          {"shaolin-shenfa", 50},
          {"strike", 50},
          {"banruo-zhang", 50},
          {"parry", 50},
          {"damo-jian", 50},
          {"buddhism", 50},
          {"literate", 50}
        ] do
      assert dao.meta.stats.skills[skill] == level, "#{skill} 应读到顶层 skills 列表"
    end

    # LPC 同文件 4 条 map_skill
    assert dao.meta.stats.mapped == %{
             "force" => "hunyuan-yiqi",
             "dodge" => "shaolin-shenfa",
             "strike" => "banruo-zhang",
             "parry" => "damo-jian"
           }
  end

  test "下划线技能名按 Stats.skills 约定归一为横线", ctx do
    jiumozhi = zone_npc(ctx.world, "clone_lib", "tianlongsi_jiumozhi")

    assert jiumozhi.meta.stats.skills["mizong-neigong"] == 260
    refute Map.has_key?(jiumozhi.meta.stats.skills, "mizong_neigong")
  end

  test "师父技能等级生效：teachable? 不再因 skill_level=0 恒拒", ctx do
    dao = zone_npc(ctx.world, "clone_lib", "shaolin_dao_chen")
    student = %{meta: %{family: %{}, stats: %{skills: %{}}, env: %{}, temp: %{}}}

    assert Kantele.SectMaster.teachable?(dao, student, "banruo-zhang") == :ok
  end

  test "旧 combat.skills 格式与真的零技能 NPC 不受影响", ctx do
    heihu = Enum.find(ctx.world.characters, &String.contains?(&1.name, "黑虎"))
    assert heihu != nil
    assert heihu.meta.stats.skills["unarmed"] == 80
    assert heihu.meta.stats.skills["dodge"] == 70

    horse = Enum.find(ctx.world.characters, &(&1.name == "枣红马"))
    assert horse != nil
    assert horse.meta.stats.skills == %{}
  end
end
