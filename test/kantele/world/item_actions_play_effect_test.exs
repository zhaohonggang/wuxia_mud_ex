defmodule Kantele.World.ItemActions.PlayEffectTest do
  @moduledoc """
  play 的 `do_effect` 守卫钩子单测（续第十二批，物品动作通道）。

  覆盖 `maybe_do_effect/3` 的两条分支：
  1. 歌谱技能未登记 或 未导出 `do_effect/2` → 空操作
     （conn 不变、不崩、分级文案照常广播、`start_busy` 照常设置）
  2. 技能已登记且导出 `do_effect/2` → 被调用（模块可改 conn）

  `async: false`：测试经 `Skills.register` 改全局 `:persistent_term` 注册表，
  不能和并行 async 测试共享该全局状态。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills
  alias Kantele.World.ItemActions.Play
  alias Kantele.World.Room

  @song "guangling-san"
  @item_name "胡琴"

  # 导出 do_effect/2 的桩模块：在 conn.output 追加标记，证明被调用。
  defmodule EffectStub do
    def do_effect(conn, _character) do
      %{conn | output: conn.output ++ [%Conn.Text{data: "EFFECT_FIRED", newline: true}]}
    end
  end

  # 不导出 do_effect/2 的桩模块：验证 function_exported? 的 false 分支。
  defmodule NoEffectStub do
    def id, do: "guangling-san"
  end

  defp player(skills, combat \\ nil) when is_map(skills) do
    %Kalevala.Character{
      name: "玩家",
      room_id: "z:room",
      meta: %{stats: %Stats{skills: skills}, combat: combat}
    }
  end

  defp item(name) do
    %Item{
      id: "z:#{name}",
      name: name,
      meta: %{actions: [%{verb: "play", handler: "play_qin"}]}
    }
  end

  defp instance(%Item{} = item) do
    %Instance{id: "inst-#{item.id}", item_id: item.id, item: item, created_at: ~U[2026-01-01 00:00:00Z]}
  end

  defp conn(player, room_id \\ "z:room") do
    %Conn{
      character: player,
      private: %Conn.Private{room: %Room{id: room_id}, channel_changes: []},
      output: []
    }
  end

  defp params(trailing, item, room_id \\ "z:room") do
    handler = Enum.find_value(item.meta.actions, fn a -> if a.verb == "play", do: a.handler end)
    %{verb: "play", trailing: trailing, room_id: room_id, item: item, instance: instance(item), handler: handler}
  end

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp updated_character(conn), do: conn.private.update_character || conn.character

  describe "do_effect 守卫钩子" do
    test "歌谱技能未登记 → 空操作（只播文案 + 忙乱，不崩）" do
      # guangling-san 当前未进 Skills 注册表（Skills.get 返回 nil）
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      # 文案照常广播
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "广陵散"))
      # 忙乱照常设置
      assert updated_character(c2).meta.combat.busy in 4..6
      # 无任何副作用标记
      refute String.contains?(out_text(c2), "EFFECT_FIRED")
    end

    test "歌谱技能已登记但未导出 do_effect/2 → 空操作" do
      Skills.register(@song, NoEffectStub)
      on_exit(fn -> Skills.unregister(@song) end)

      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "广陵散"))
      refute String.contains?(out_text(c2), "EFFECT_FIRED")
    end

    test "歌谱技能已登记且导出 do_effect/2 → 被调用" do
      Skills.register(@song, EffectStub)
      on_exit(fn -> Skills.unregister(@song) end)

      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      # 文案仍照常广播
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "广陵散"))
      # 桩模块的 do_effect 已执行
      assert String.contains?(out_text(c2), "EFFECT_FIRED")
    end
  end
end
