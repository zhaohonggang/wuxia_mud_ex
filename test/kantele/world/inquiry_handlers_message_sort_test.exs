defmodule Kantele.World.InquiryHandlersMessageSortTest do
  @moduledoc """
  #803 侠客岛腊八粥：`message_sort` 问询广播（问者「你」版 + 旁观者姓名版）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.MessageSort
  alias Kantele.World.Loader

  @text "这是本岛特有的东西，它主要由一味“断肠独骨腐心草”构成，要开花后效力方著，但这种草每十年才开一次花，所以一般人很难得到的，小兄弟想要就要看你的缘分了！"
  @config %{"kind" => "message_sort", "text" => "$N对$n说：“#{@text}”"}

  defp conn do
    %Conn{
      character: %Character{
        id: "player:test",
        name: "李四",
        room_id: "xiakedao:test",
        meta: %PlayerMeta{vitals: Vitals.new(), stats: Stats.new()}
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: Keyword.get(opts, :asker_id, "player:test"),
      asker_name: Keyword.get(opts, :asker_name, "李四"),
      npc_id: "xiakedao_long_hash",
      npc_name: Keyword.get(opts, :npc_name, "龙岛主"),
      npc_room_id: Keyword.get(opts, :npc_room_id, "xiakedao:test")
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: text} -> text
      %Conn.EventText{text: %Conn.Text{data: text}} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
  end

  test "问询玩家收到「龙岛主对你说…」私有 vision" do
    result = MessageSort.run(conn(), @config, data())
    assert output_text(result) == "龙岛主对你说：“#{@text}”"
  end

  test "旁观者收到「龙岛主对李四说…」房间广播，且排除问询玩家" do
    result = MessageSort.run(conn(), @config, data())

    assert [{:publish, channel, event, options, _fun}] = publishes(result)
    assert channel == "rooms:xiakedao:test"
    assert event.data.text == "龙岛主对李四说：“#{@text}”"
    assert options[:meta][:exclude_actor] == true
  end

  test "转换器归一化的 {npc}/{name} 占位同样按三视角渲染" do
    config = %{"kind" => "message_sort", "text" => "{npc}对{name}说道：“本岛特有。”"}
    result = MessageSort.run(conn(), config, data())

    assert output_text(result) == "龙岛主对你说道：“本岛特有。”"
    assert [{:publish, _channel, event, _options, _fun}] = publishes(result)
    assert event.data.text == "龙岛主对李四说道：“本岛特有。”"
  end

  test "无 npc_room_id 时只发私有文案，不广播" do
    result = MessageSort.run(conn(), @config, data(npc_room_id: nil))

    assert output_text(result) == "龙岛主对你说：“#{@text}”"
    assert publishes(result) == []
  end

  test "非问询者本人完全沉默" do
    result = MessageSort.run(conn(), @config, data(asker_id: "player:other"))

    assert output_text(result) == ""
    assert publishes(result) == []
  end

  test "未配置 text 时完全沉默" do
    result = MessageSort.run(conn(), %{"kind" => "message_sort"}, data())
    assert output_text(result) == ""
    assert publishes(result) == []
  end

  test "clone_lib 两名岛主的腊八粥均已落 message_sort 配置" do
    world = Loader.load()

    for {block_id, npc_name} <- [{"xiakedao_long", "龙岛主"}, {"xiakedao_mu", "木岛主"}] do
      npc = Enum.find(world.characters, &(&1.name == npc_name))
      assert block_id in npc.meta.aliases
      config = Map.get(npc.meta.inquiries, "腊八粥")
      assert (config["kind"] || config[:kind]) == "message_sort"
      text = config["text"] || config[:text]
      assert String.contains?(text, "$N对$n说")
      assert String.contains?(text, "断肠独骨腐心草")
    end
  end
end
