defmodule Kantele.World.InquiryHandlers.GiveItemHenshanTest do
  @moduledoc """
  #863 莫大「镇岳尚方」give_item：master_id（仅直传弟子）、min_shen=50000、
  min_skill_levels henshan_jian=120、owner_check 五分支。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    stats = %Stats{
      combat_exp: Keyword.get(opts, :combat_exp, 1_000_000),
      shen: Keyword.get(opts, :shen, 60_000),
      gongxian: Keyword.get(opts, :gongxian, 1000),
      skills: %{"henshan-jian" => Keyword.get(opts, :henshan_jian, 150)}
    }

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: stats,
      family: %{
        name: "衡山派",
        master_id: Keyword.get(opts, :master_id, "henshan_mo")
      }
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "hengyang:zhurongfeng",
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
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp data(opts \\ []) do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "henshan_mo",
      npc_name: "莫大",
      npc_room_id: "hengyang:zhurongfeng",
      npc_family: "衡山派"
    }
  end

  defp config do
    %{
      "kind" => "give_item",
      "item" => "clone_lib:zhenyue",
      "match" => "zhenyue",
      "master_id" => true,
      "master_deny" => "这柄镇岳尚方乃我衡山镇派之宝，仅传直传弟子，你非我门下，休要妄求。",
      "min_shen" => 50_000,
      "min_shen_deny" => "你目前所做的侠义正事不够，这柄宝剑暂时不能交给你。",
      "min_skill_levels" => %{"henshan_jian" => 120},
      "min_skill_deny" => "你的衡山剑法还不够熟练，下去练练再来吧。",
      "owner_check" => true,
      "owner_item_label" => "那支镇岳尚方宝剑",
      "owner_self_deny" => "{item}不就是你拿着在用么，怎么反倒找我了？",
      "owner_lost_deny" => "{item}我已经借出去了，你还是隔段时间再来吧。",
      "owner_sect_deny" => "{item}现在是我派的{name}在用，你若需要就去找他吧。",
      "owner_ally_deny" => "{item}现在是你派的{name}在用，你自己去问他要吧。",
      "owner_outsider_deny" => "{item}现在落在了{name}手中，你去把它取回来吧。",
      "success" => "既是我门下有剑法根基之人，这柄镇岳尚方你就暂且拿去用用。"
    }
  end

  test "直传弟子+足够shen+足够剑法：通过全部门控，无拒绝文案" do
    result = GiveItem.run(conn(), config, data())
    text = output_text(result)
    refute text =~ "休要妄求"
    refute text =~ "暂时不能交给你"
    refute text =~ "还不够熟练"
  end

  test "非直传弟子：master_id 门拒绝" do
    result = GiveItem.run(conn(master_id: "xiang danian"), config, data())
    assert output_text(result) =~ "非我门下，休要妄求"
  end

  test "shen 不足：min_shen 门拒绝" do
    result = GiveItem.run(conn(shen: 49_999), config, data())
    assert output_text(result) =~ "暂时不能交给你"
  end

  test "剑法不足：min_skill_levels henshan_jian 门拒绝" do
    result = GiveItem.run(conn(henshan_jian: 119), config, data())
    assert output_text(result) =~ "还不够熟练"
  end
end
