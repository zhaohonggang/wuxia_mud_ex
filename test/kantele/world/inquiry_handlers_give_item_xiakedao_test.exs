defmodule Kantele.World.InquiryHandlers.GiveItemXiakedaoTest do
  @moduledoc """
  `Kantele.World.InquiryHandlers.GiveItem` 的 #800 侠客岛「赏善罚恶令」give_ling 多状态门控，
  镜像 LPC `kungfu/class/xiakedao/zhangsan2.c:78-129`。

  覆盖：shen < -100000 翻脸开打（emote+say+kill_ob）/ weiwang < 100000 拒绝 /
  force < 200 / martial-cognize < 200 技能门 / 全部门控通过不拒绝。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{
        combat_exp: 2000000,
        shen: Keyword.get(opts, :shen, 0),
        weiwang: Keyword.get(opts, :weiwang, 200000),
        skills: Keyword.get(opts, :skills, %{"force" => 300, "martial-cognize" => 300})
      },
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xiakedao:xiake dao",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Kalevala.Character.Conn.Text{data: data} -> data
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _channel, event, _options, _fun} -> event.data.text end)
  end

  defp base_config do
    %{
      "kind" => "give_item",
      "item" => "clone_lib:shangfaling",
      "unique" => true,
      "hostile_shen" => -100000,
      "hostile_emote" => "哼了一声",
      "hostile_say" => "尔等邪魔歪道，我正欲相除，你却反找上门来了！",
      "min_weiwang" => 100000,
      "min_weiwang_deny" => "阁下非江湖成名人士，还是请回吧！",
      "min_skill_levels" => %{"force" => 200, "martial_cognize" => 200},
      "min_skill_deny" => "阁下内功不济，这腊八粥你还是喝不得！",
      "success" => "拿去吧，记得上侠客岛喝腊八粥！",
      "already" => "阁下也太贪心了吧！"
    }
  end

  defp base_data do
    %{
      asker_id: "player:test",
      npc_id: "xiakedao_zhangsan2",
      npc_name: "张三",
      npc_pid: self(),
      npc_room_id: "xiakedao:xiake dao"
    }
  end

  describe "shen 低于 -100000：翻脸开打（LPC give_ling 首项）" do
    test "shen < -100000：广播 emote 与 say，双方收 combat/start，且不私发文本" do
      conn0 = conn(shen: -200000)
      config = base_config()
      data = base_data()

      conn2 = GiveItem.run(conn0, config, data)

      # `Conn.publish_message` prepend 到 channel_changes：调用序 emote→say，断言序 say→emote。
      assert publishes(conn2) == [
               "张三说道：尔等邪魔歪道，我正欲相除，你却反找上门来了！\n",
               "张三哼了一声。\n"
             ]

      assert conn2.output == []

      assert_receive %Kalevala.Event{
        topic: "combat/start",
        data: %{type: "kill", enemy: %{id: "xiakedao_zhangsan2"}}
      }, 200
      assert_receive %Kalevala.Event{
        topic: "combat/start",
        data: %{type: "kill", enemy: %{id: "player:test"}}
      }, 200
    end

    test "shen = -100000 不触发敌对，后续 weiwang/force 均达标则不拒绝" do
      conn0 = conn(shen: -100000)
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "邪魔歪道"
      refute output_text(result) =~ "请回吧"
      refute output_text(result) =~ "内功不济"
    end
  end

  describe "weiwang 门控" do
    test "weiwang < 100000：返回 min_weiwang_deny" do
      conn0 = conn(weiwang: 50000)
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "阁下非江湖成名人士，还是请回吧！"
    end

    test "weiwang >= 100000：不拒绝，继续门控" do
      conn0 = conn(weiwang: 100000)
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "请回吧"
    end
  end

  describe "技能门控" do
    test "force < 200：返回 min_skill_deny" do
      conn0 = conn(skills: %{"force" => 100, "martial-cognize" => 300})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "阁下内功不济，这腊八粥你还是喝不得！"
    end

    test "martial-cognize < 200（force 达标）：返回 min_skill_deny" do
      conn0 = conn(skills: %{"force" => 300, "martial-cognize" => 100})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "阁下内功不济，这腊八粥你还是喝不得！"
    end

    test "force >= 200 且 martial-cognize >= 200：不拒绝" do
      conn0 = conn(skills: %{"force" => 300, "martial-cognize" => 300})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "内功不济"
    end
  end
end
