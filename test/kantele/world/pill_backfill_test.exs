defmodule Kantele.World.PillBackfillTest do
  @moduledoc """
  验证 P5-5 回填脚本把 LPC `do_effect` 正确写进了 UCL 物品数据
  （meta.medicine + meta.effect.kind="pill"），且能被 loader 正确解析。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  @moduletag :world_data

  setup_all do
    %{world: Loader.load()}
  end

  defp find_pill(world, pred), do: Enum.find(world.items, pred)

  test "养精丹(danA_1) 回填：jing 治疗 + 冷却 + 满状态拒服 + 广播", %{world: world} do
    pill =
      find_pill(world, fn it ->
        effect = it.meta.effect
        effect && effect[:kind] == "pill" && effect[:cooldown_key] == "last_eat/dan(A)" &&
          it.meta.medicine[:jing] == 100
      end)

    assert pill, "未找到养精丹"
    assert pill.meta.effect[:kind] == "pill"
    assert pill.meta.effect[:cooldown] == 5
    assert pill.meta.effect[:cooldown_key] == "last_eat/dan(A)"
    assert pill.meta.effect[:full_vital] == "jing"
    assert pill.meta.effect[:busy] == 1
    assert pill.meta.effect[:stack] in [true, "true"]
    assert pill.meta.effect[:vision_text] =~ "{npc}"
    refute pill.meta.effect[:vision_text] =~ "$N"
  end

  test "少林金创药(jinchuang_yao) 回填：qi 治疗（无冷却/满状态约束）", %{world: world} do
    pill =
      find_pill(world, fn it ->
        effect = it.meta.effect
        effect && effect[:kind] == "pill" && it.meta.medicine[:qi] == 50
      end)

    assert pill, "未找到金创药"
    assert pill.meta.effect[:busy] == 1
    assert pill.meta.effect[:cooldown_key] == nil
  end

  test "黑玉断续膏(heiyugao) 回填：tell_object 自述写入 self_text", %{world: world} do
    pill =
      find_pill(world, fn it ->
        effect = it.meta.effect
        effect && effect[:kind] == "pill" && Map.has_key?(effect, :self_text)
      end)

    assert pill, "未找到黑玉断续膏"
    assert pill.meta.effect[:self_text] =~ "你只觉一股热流"
    assert pill.meta.medicine[:jing] == 1000
    assert pill.meta.medicine[:qi] == 2000
  end
end
