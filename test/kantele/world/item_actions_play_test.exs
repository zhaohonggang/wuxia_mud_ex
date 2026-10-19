defmodule Kantele.World.ItemActions.PlayTest do
  @moduledoc """
  乐器 `play` 动作单测（第十二批，物品动作通道）。

  直接调用 `Play.run/2`，构造 `params` 与真实 `%Conn{}`，覆盖：守卫四态、
  7 档分级文案、`$n`/`$N` 替换、`start_busy`、`<song> with <id>` 的 id 匹配
  语义（匹配 → 演奏，不匹配 → 返回 `:not_handled` 等价 LPC `return 0`）。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.ItemActions.Play
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  # 选 guangling-san：valid_enable 含 tanqin-jifa，jifa 设为 tanqin-jifa，
  # 这样 song_level + div(jifa_level, 2) 直接等于 song_level，便于精确卡档。
  @song "guangling-san"
  @handler "play_qin"
  @jifa "tanqin-jifa"
  @item_name "胡琴"

  defp player(skills, combat \\ nil) when is_map(skills) do
    %Kalevala.Character{
      name: "玩家",
      room_id: "z:room",
      meta: %{stats: %Stats{skills: skills}, combat: combat}
    }
  end

  defp item(name, aliases \\ []) do
    %Item{
      id: "z:#{name}",
      name: name,
      meta: %{actions: [%{verb: "play", handler: @handler}], aliases: aliases}
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

  describe "守卫：空 arg" do
    test "未给曲名 → 「你要弹什么曲子？」只给玩家" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params("", item(@item_name)))

      assert String.contains?(out_text(c2), "你要弹什么曲子？")
      assert vision_texts(c2) == []
    end
  end

  describe "守卫：不会弹（song_level == 0）" do
    test "未习得该曲 → 「你不会弹这首曲子。」" do
      # song 不在 skills 中 → query_skill 为 0
      c = conn(player(%{@jifa => 60}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      assert String.contains?(out_text(c2), "你不会弹这首曲子。")
      assert vision_texts(c2) == []
    end
  end

  describe "守卫：valid_enable 不通过" do
    test "曲名不被该乐器 enable → 「这不能用来弹奏。」" do
      # xiyu-tiezheng 只 enable guzheng-jifa，用 tanqin 弹应被拦
      c = conn(player(%{"xiyu-tiezheng" => 100, @jifa => 60}))
      c2 = Play.run(c, params("xiyu-tiezheng", item(@item_name)))

      assert String.contains?(out_text(c2), "这不能用来弹奏。")
      assert vision_texts(c2) == []
    end
  end

  describe "守卫：忙乱" do
    test "combat.busy > 0 → 「你现在正忙，等会儿再弹琴吧。」" do
      c = conn(player(%{@song => 100}, %Combat{busy: 5}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      assert String.contains?(out_text(c2), "你现在正忙，等会儿再弹琴吧。")
      assert vision_texts(c2) == []
    end
  end

  describe "分级文案（7 档，逐字对 LPC message_vision）" do
    test "lvl < 15 → 杂音档" do
      c = conn(player(%{@song => 10}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &(&1 == "\n{npc}胡乱拨了拨胡琴，结果只是发出了几下刺耳的杂音。\n"))
    end

    test "15 <= lvl < 30 → 怪响档" do
      c = conn(player(%{@song => 20}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &(&1 == "\n{npc}拨拉了一下胡琴，发出几声怪响，难听的一塌糊涂。\n"))
    end

    test "30 <= lvl < 60 → 清脆档" do
      c = conn(player(%{@song => 40}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "声音还算清脆"))
    end

    test "60 <= lvl < 90 → 韵律不错档（含曲名）" do
      c = conn(player(%{@song => 70}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &(&1 == "\n{npc}摆好胡琴弹了一首广陵散，韵律洋洋洒洒，颇为不错。\n"))
    end

    test "90 <= lvl < 150 → 动人档" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &(&1 == "\n{npc}摆好胡琴弹了一首广陵散，颇为动人，引人入胜。\n"))
    end

    test "150 <= lvl < 225 → 感慨档" do
      c = conn(player(%{@song => 160}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "听得众人感慨万千"))
    end

    test "225 <= lvl < 300 → 溪水档" do
      c = conn(player(%{@song => 230}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "琴音宛若溪水荡流"))
    end

    test "lvl >= 300 → 仙境档" do
      c = conn(player(%{@song => 300}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      assert Enum.any?(vision_texts(c2), &(&1 == "\n{npc}摆好胡琴弹了一首广陵散，宛若清溪流上心头，令人无酒自醉，却又似身至仙境，心灵空明。\n"))
    end
  end

  describe "start_busy" do
    test "成功演奏后玩家进入忙乱（busy ∈ 4..6）" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params(@song, item(@item_name)))

      combat = updated_character(c2).meta.combat
      assert %Combat{} = combat
      assert combat.busy in 4..6
    end

    test "忙乱守卫不重置忙乱（仍被挡）" do
      c = conn(player(%{@song => 100}, %Combat{busy: 5}))
      c2 = Play.run(c, params(@song, item(@item_name)))
      # 守卫拦截，未进入 do_play，busy 不被改动
      assert updated_character(c2).meta.combat.busy == 5
      assert vision_texts(c2) == []
    end
  end

  describe "<song> with <id> 语义（LPC sscanf + return 0）" do
    test "id 匹配本乐器 → 正常演奏" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params("#{@song} with 胡琴", item(@item_name)))
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "广陵散"))
    end

    test "id 不匹配本乐器 → :not_handled（交还分发器尝试下一个候选）" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params("#{@song} with 古筝", item(@item_name)))
      assert c2 == :not_handled
    end

    test "id 命中乐器别名 → 视为匹配" do
      c = conn(player(%{@song => 100}))
      c2 = Play.run(c, params("#{@song} with huqin", item(@item_name, ["huqin"])))
      assert Enum.any?(vision_texts(c2), &String.contains?(&1, "广陵散"))
    end
  end

  describe "handler 名分派（qin / xiao / zheng）" do
    test "play_xiao 用 chuixiao 守门措辞" do
      # handler 为 play_xiao → jifa chuixiao-jifa；空 arg 触发其 no_arg 守门
      item = %Item{id: "z:箫", name: "箫", meta: %{actions: [%{verb: "play", handler: "play_xiao"}]}}
      c = conn(player(%{"xiaoao-jianghu" => 10, "chuixiao-jifa" => 0}))
      c2 = Play.run(c, params("", item))
      assert String.contains?(out_text(c2), "你要吹什么曲子？")
    end

    test "play_zheng 用 guzheng 守门措辞" do
      item = %Item{id: "z:筝", name: "筝", meta: %{actions: [%{verb: "play", handler: "play_zheng"}]}}
      c = conn(player(%{"wushe-qu" => 10, "guzheng-jifa" => 0}))
      c2 = Play.run(c, params("", item))
      assert String.contains?(out_text(c2), "你要演奏什么曲子？")
    end
  end
end
