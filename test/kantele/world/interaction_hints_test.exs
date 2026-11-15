defmodule Kantele.World.InteractionHintsTest do
  @moduledoc """
  `InteractionHints` 聚合器回归：重点是「只列可执行命令」这条契约。

  UCL 里声明的 `add_action` 动词远多于已移植的 handler，若原样展示，
  玩家照着输入只会得到 "What?"。这些用例把过滤规则钉死。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.InteractionHints

  defp room(overrides \\ %{}) do
    Map.merge(%{id: "test:room", item_desc: %{}, actions: %{}, exits: []}, overrides)
  end

  defp verb(key, locations) do
    %Kalevala.Verb{
      key: key,
      conditions: %Kalevala.Verb.Conditions{location: locations}
    }
  end

  defp item(overrides \\ %{}) do
    Map.merge(
      %Kalevala.World.Item{
        id: "test:thing",
        name: "木柴",
        verbs: [verb(:get, ["room"]), verb(:eat, ["inventory/self"])],
        meta: %{actions: []}
      },
      overrides
    )
  end

  defp instance(item \\ item()) do
    %Kalevala.World.Item.Instance{id: "inst:1", item_id: item.id, item: item}
  end

  defp npc(overrides \\ %{}) do
    Map.merge(
      %{
        id: "npc:hunter",
        name: "猎人",
        meta: %{}
      },
      overrides
    )
  end

  defp commands_for(groups, label) do
    case Enum.find(groups, &(&1.label == label)) do
      %{commands: commands} -> commands
      _ -> nil
    end
  end

  describe "房间本身" do
    test "item_desc 关键词生成 look <关键词>" do
      groups =
        InteractionHints.build(room(%{item_desc: %{"pen" => "花盆", "paizi" => "牌子"}}), [], [],
          limit: :none
        )

      assert commands_for(groups, "房间") == ["look paizi", "look pen"]
    end

    test "已注册 handler 的房间动作列出，未移植的死动词不列" do
      # baituo:neishi 的 do_move 已在 RoomActionHandlers 注册
      groups =
        InteractionHints.build(
          room(%{id: "baituo:neishi", actions: %{"move" => "do_move", "zzz" => "do_nothing"}}),
          [],
          [],
          limit: :none
        )

      assert "move" in commands_for(groups, "房间")
      refute "zzz" in commands_for(groups, "房间")
    end

    test "无专属 handler 但是全局命令的房间动词也列出" do
      groups =
        InteractionHints.build(room(%{actions: %{"map" => "do_map", "zzz" => "do_nothing"}}), [], [],
          limit: :none
        )

      assert commands_for(groups, "房间") == ["map"]
    end
  end

  describe "NPC" do
    test "问询关键词 + 全局 add_action 动词 + talk/give" do
      npc =
        npc(%{
          meta: %{
            ask_topics: ["hunting", "捕猎"],
            ask_handler: "Kantele.NPC.Hunter",
            init: %{add_actions: ["list", "buy", "totally_dead"]}
          }
        })

      groups = InteractionHints.build(room(), [npc], [], limit: :none)
      commands = commands_for(groups, "猎人")

      assert "ask 猎人 hunting" in commands
      assert "ask 猎人 捕猎" in commands
      assert "list" in commands
      assert "buy" in commands
      assert "talk 猎人" in commands
      assert "give <物品> to 猎人" in commands
      refute Enum.any?(commands, &String.contains?(&1, "totally_dead"))
    end

    test "有 ask_handler 但没有 inquiries 时给通用问询形式" do
      npc = npc(%{meta: %{ask_topics: [], ask_handler: "Kantele.NPC.Niutou"}})
      groups = InteractionHints.build(room(), [npc], [], limit: :none)

      assert "ask 猎人 <关键词>" in commands_for(groups, "猎人")
    end

    test "没有问答资源的 NPC 不列 talk（TalkCommand 会回不想聊天）" do
      groups = InteractionHints.build(room(), [npc()], [], limit: :none)
      commands = commands_for(groups, "猎人")

      refute Enum.any?(commands, &String.starts_with?(&1, "talk"))
      assert "give <物品> to 猎人" in commands
    end

    test "已注册 NPC 私有动词列出（beijing:majuan 的 rideyz）" do
      npc = npc(%{meta: %{init: %{add_actions: ["rideyz", "do_nothing"]}}})
      groups = InteractionHints.build(room(%{id: "beijing:majuan"}), [npc], [], limit: :none)
      commands = commands_for(groups, "猎人")

      assert "rideyz" in commands
      refute "do_nothing" in commands
    end

    test "玩家角色不出现在 NPC 分组里" do
      player = %{id: "player:42", name: "张三", meta: %{}}
      groups = InteractionHints.build(room(), [player], [], limit: :none)

      refute Enum.any?(groups, &(&1.label == "张三"))
    end
  end

  describe "地上物品" do
    test "只列匹配 room 位置的动词，不列背包动词" do
      groups = InteractionHints.build(room(), [], [instance()], limit: :none)

      assert commands_for(groups, "木柴") == ["get 木柴"]
    end

    test "不列 look <物品>（look 带参走 item_desc，会回「这里没有这个东西」）" do
      groups = InteractionHints.build(room(), [], [instance()], limit: :none)

      refute "look 木柴" in commands_for(groups, "木柴")
    end

    test "已注册物品 handler 的动词列出，未注册的不列" do
      item = item(%{meta: %{actions: [%{verb: "play", handler: "play_qin"}, %{verb: "zzz", handler: "no_handler"}]}})
      groups = InteractionHints.build(room(), [], [instance(item)], limit: :none)

      assert "play 木柴" in commands_for(groups, "木柴")
      refute "zzz 木柴" in commands_for(groups, "木柴")
    end

    test "同名物品合并成一组" do
      groups =
        InteractionHints.build(room(), [], [instance(), instance()], limit: :none)

      assert length(Enum.filter(groups, &(&1.label == "木柴"))) == 1
    end

    test "没有任何可执行动词的物品不出现" do
      bare = item(%{verbs: [], meta: %{actions: []}})
      groups = InteractionHints.build(room(), [], [instance(bare)], limit: :none)

      refute Enum.any?(groups, &(&1.label == "木柴"))
    end
  end

  describe "输出格式" do
    test "无交互时 lines/2 返回空列表（不渲染空标题）" do
      assert InteractionHints.build(room(), [], [], limit: :none) == []
      assert InteractionHints.lines([]) == []
    end

    test "limit 截断分组数，:none 不截断" do
      rooms = room(%{item_desc: %{"a" => "a"}})
      people = Enum.map(1..8, fn i -> npc(%{id: "npc:#{i}", name: "NPC#{i}"}) end)

      assert length(InteractionHints.build(rooms, people, [])) == 6
      assert length(InteractionHints.build(rooms, people, [], limit: :none)) == 9
    end

    test "lines/2 输出标题、分组和关闭提示，且每行独立" do
      groups = InteractionHints.build(room(%{item_desc: %{"pen" => "花盆"}}), [], [], limit: :none)
      lines = InteractionHints.lines(groups)

      assert hd(lines) =~ "可交互"
      assert Enum.any?(lines, &String.contains?(&1, "look pen"))
      assert List.last(lines) =~ "hints_hidden"
    end
  end
end
