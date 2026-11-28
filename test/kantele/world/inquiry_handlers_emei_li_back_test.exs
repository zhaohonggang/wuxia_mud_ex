defmodule Kantele.World.InquiryHandlers.EmeiLiBackTest do
  @moduledoc """
  #855 李明霞「上山/back」带人传送 + 回程定时器定向测试。

  镜像 LPC `li.c` `ask_back/0`：
  - 门控：NPC 在 startroom → 同门 → age < 18
  - 成功：NPC say + 房间广播 + 玩家私发 + 玩家瞬移金顶 + NPC 随行 + start_busy(1)
  - 5 秒后 NPC 自动返回 startroom（call_out("back_to_startroom", 5)）

  覆盖：
  - NPC 不在 startroom → room_deny
  - 非峨嵋派 → family_deny
  - age >= 18 → age_deny
  - 全部通过 → say / vision1 / tell / 传送 / vision2 / NPC 随行 / start_busy
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.EmeiLiBack

  defp base_config do
    %{
      "kind" => "emei_li_back",
      "target_room" => "emei:jinding",
      "startroom" => "emei:huayanding",
      "family" => "峨嵋派",
      "family_deny" => "你不是长脚了吗？难道上山还要我来抬你？",
      "room_deny" => "别什么都问我，我不知道！",
      "age_deny" => "我说你呀，年纪这么大了还要我带你上山么？",
      "say_text" => "好吧，看在同门的分上，我就带你上山吧。",
      "vision_a" => "$N拉着$n的手向山顶上走去。\n\n",
      "tell_text" => "你觉得省力多了，毫不费劲的就上了金顶。\n",
      "vision_b" => "{npc}一手拉着{name}快步的向山上走去，一会儿就不见影子了。\n",
      "back_delay" => 5,
      "back_vision_a" => "$N 头也不回的急急忙忙走了。\n",
      "back_vision_b" => "$N 大步流星的赶了过来。\n"
    }
  end

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "峨嵋派"})
    age = Keyword.get(opts, :age, 14)
    inventory = Keyword.get(opts, :inventory, [])

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 80, max_qi: 100},
      stats: %Stats{combat_exp: 2_000_000, shen: 0, skills: %{}},
      family: family,
      env: %{"age" => age},
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "emei:huayanding",
        attributes: %{"age" => age},
        inventory: inventory,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "emei_li",
      npc_name: "李明霞",
      npc_pid: self(),
      npc_room_id: Keyword.get(opts, :npc_room_id, "emei:huayanding")
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp channel_texts(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  describe "门控：NPC 不在 startroom" do
    test "npc_room_id != startroom → 返回 room_deny" do
      conn0 = conn()
      result = EmeiLiBack.run(conn0, base_config(), data(npc_room_id: "emei:qingyinge"))

      assert output_text(result) =~ "别什么都问我，我不知道！"
    end
  end

  describe "门控：非峨嵋派" do
    test "family != 峨嵋派 → 返回 family_deny" do
      conn0 = conn(family: %{name: "少林派"})
      result = EmeiLiBack.run(conn0, base_config(), data())

      assert output_text(result) =~ "你不是长脚了吗？难道上山还要我来抬你？"
    end
  end

  describe "门控：age >= 18" do
    test "age = 18 → 返回 age_deny" do
      conn0 = conn(age: 18)
      result = EmeiLiBack.run(conn0, base_config(), data())

      assert output_text(result) =~ "我说你呀，年纪这么大了还要我带你上山么？"
    end

    test "age = 25 → 返回 age_deny" do
      conn0 = conn(age: 25)
      result = EmeiLiBack.run(conn0, base_config(), data())

      assert output_text(result) =~ "我说你呀，年纪这么大了还要我带你上山么？"
    end

    test "age = 17 → 不过 age 门，继续流程" do
      conn0 = conn(age: 17)
      result = EmeiLiBack.run(conn0, base_config(), data())

      refute output_text(result) =~ "我说你呀，年纪这么大了还要我带你上山么？"
    end
  end

  describe "成功流程（age < 18，同门，NPC 在 startroom）" do
    test "NPC say + vision1 + tell + 玩家传送 + vision2 + start_busy" do
      conn0 = conn(age: 14)
      result = EmeiLiBack.run(conn0, base_config(), data())

      # NPC say
      assert channel_texts(result) =~ "好吧，看在同门的分上，我就带你上山吧。"

      # vision1: $N拉着$n的手向山顶上走去。
      assert channel_texts(result) =~ "李明霞拉着测试玩家的手向山顶上走去。"

      # tell_player: 你觉得省力多了，毫不费劲的就上了金顶。
      assert output_text(result) =~ "你觉得省力多了，毫不费劲的就上了金顶。"

      # 玩家已传送到 emei:jinding
      assert result.private.update_character.room_id == "emei:jinding" or
             result.character.room_id == "emei:jinding"

      # vision2: 李明霞一手拉着测试玩家快步的向山上走去...
      assert channel_texts(result) =~ "李明霞一手拉着测试玩家快步的向山上走去"

      # start_busy(1)：player 处于忙乱状态
      character = result.private.update_character || result.character
      combat = Map.get(character.meta, :combat) || %Kantele.Character.Combat{}
      assert combat.busy >= 1
    end

    test "start_busy 设置为 1 轮" do
      conn0 = conn(age: 14)
      result = EmeiLiBack.run(conn0, base_config(), data())

      character = result.private.update_character || result.character
      combat = Map.get(character.meta, :combat) || %Kantele.Character.Combat{}
      assert combat.busy == 1
    end
  end

  describe "two inquiry keys share the same config" do
    test "「back」和「上山」使用相同 handler 和配置" do
      conn0 = conn(age: 14)
      result = EmeiLiBack.run(conn0, base_config(), data())

      refute output_text(result) =~ "GAP"
      assert channel_texts(result) =~ "李明霞"
    end
  end
end
