defmodule Kantele.World.InquiryHandlers.GiveItemOwnerTest do
  @moduledoc """
  #820 LPC `adm/daemons/masterd.c:474-509` give_item 持有者遍历五分支：
  owner == 玩家 / 非角色 / NPC 同门 / 玩家同门 / 外人；门序在技能门之后、
  门派贡献门之前。owner 快照由 NPC 侧 `npc_shop_event.zhihuan_owner/3` 产出。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    stats = %Stats{
      combat_exp: 1_000_000,
      shen: -30_000,
      gongxian: Keyword.get(opts, :gongxian, 0),
      skills: %{"hexing-bifa" => Keyword.get(opts, :skill, 120)}
    }

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: stats,
      family: %{name: Keyword.get(opts, :family, "玄冥谷")}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xuanminggu:xuanminggu",
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

  defp config(opts \\ []) do
    cfg = %{
      "kind" => "give_item",
      "item" => "clone_lib:hexingbi",
      "match" => "hexingbi",
      "unique" => false,
      "family" => Keyword.get(opts, :family, "玄冥谷"),
      "family_deny" => "与我玄冥谷素无渊源，不知此话从何说起。",
      "owner_check" => true,
      "owner_item_label" => "那支鹤形笔",
      "owner_self_deny" => "{item}不就是你拿着在用么，怎么反倒找我了？",
      "owner_lost_deny" => "{item}我已经借出去了，你还是隔段时间再来吧。",
      "owner_sect_deny" => "{item}现在是我派的{name}在用，你若需要就去找他吧。",
      "owner_ally_deny" => "{item}现在是你派的{name}在用，你自己去问他要吧。",
      "owner_outsider_deny" => "{item}现在落在了{name}手中，你去把它取回来吧。",
      "min_skill_levels" => %{"hexing-bifa" => 100},
      "min_skill_deny" => "你的鹤形笔法火候未到，就算拿着也没用。",
      "max_shen" => -10_000,
      "max_shen_deny" => "哼！像你这样的心慈手软之辈，就算拿着也是无用。",
      "min_gongxian" => Keyword.get(opts, :min_gongxian, 0),
      "success" => "既然这样，那这支鹤形笔你就暂时拿去吧。",
      "exhausted" => "抱歉，已经发完了。"
    }

    # LPC masterd 先要求玩家与 NPC 同门，故「你派的 X 在用」仅在
    # 无 family 门（NPC 无门派、公共物品）时可触达。
    if Keyword.has_key?(opts, :family) and is_nil(Keyword.get(opts, :family)) do
      Map.delete(cfg, "family")
    else
      cfg
    end
  end

  defp data(owner \\ nil) do
    base = %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "xuanming_he",
      npc_name: "鹤笔翁",
      npc_pid: self(),
      npc_room_id: "xuanminggu:xuanminggu",
      remaining: 0
    }

    if is_nil(owner), do: base, else: Map.put(base, :owner, owner)
  end

  test "owner == 玩家本人：返回 owner_self_deny，{item} 被替换" do
    result = GiveItem.run(conn(), config(), data(%{kind: :asker, name: "测试玩家"}))

    assert output_text(result) =~ "那支鹤形笔不就是你拿着在用么"
  end

  test "owner 非角色（地上/容器）：返回 owner_lost_deny" do
    result = GiveItem.run(conn(), config(), data(%{kind: :object, name: "逍遥神仙环"}))

    assert output_text(result) =~ "那支鹤形笔我已经借出去了"
  end

  test "owner 是 NPC 同门：返回 owner_sect_deny 并填入持有者姓名" do
    owner = %{kind: :character, name: "鹿杖客", family: "玄冥谷"}
    result = GiveItem.run(conn(), config(), data(owner))

    assert output_text(result) =~ "那支鹤形笔现在是我派的鹿杖客在用"
  end

  test "owner 与玩家同门（非 NPC 门派）：返回 owner_ally_deny" do
    owner = %{kind: :character, name: "殷天正", family: "明教"}
    result = GiveItem.run(conn(family: "明教"), config(family: nil), data(owner))

    assert output_text(result) =~ "那支鹤形笔现在是你派的殷天正在用"
  end

  test "owner 是外人：返回 owner_outsider_deny" do
    owner = %{kind: :character, name: "张无忌", family: "武当派"}
    result = GiveItem.run(conn(), config(), data(owner))

    assert output_text(result) =~ "那支鹤形笔现在落在了张无忌手中"
  end

  test "owner 为 :npc（物品在发放者身上）或未取快照：不拦，走后续库存门" do
    for data <- [data(%{kind: :npc, name: "鹤笔翁"}), data()] do
      result = GiveItem.run(conn(), config(), data)
      assert output_text(result) =~ "抱歉，已经发完了。"
      refute output_text(result) =~ "不就是你拿着"
    end
  end

  test "门序：技能门先于 owner 门；owner 门先于贡献门" do
    owner = %{kind: :asker, name: "测试玩家"}

    low_skill = GiveItem.run(conn(skill: 50), config(), data(owner))
    assert output_text(low_skill) =~ "鹤形笔法火候未到"
    refute output_text(low_skill) =~ "不就是你拿着"

    gongxian = GiveItem.run(conn(gongxian: 0), config(min_gongxian: 9999), data(owner))
    assert output_text(gongxian) =~ "不就是你拿着"
    refute output_text(gongxian) =~ "抱歉"
  end

  test "未开启 owner_check 的 give_item：即使 owner=:asker 也不拦" do
    config = config() |> Map.delete("owner_check")
    result = GiveItem.run(conn(), config, data(%{kind: :asker, name: "测试玩家"}))

    assert output_text(result) =~ "抱歉，已经发完了。"
    refute output_text(result) =~ "不就是你拿着"
  end
end
