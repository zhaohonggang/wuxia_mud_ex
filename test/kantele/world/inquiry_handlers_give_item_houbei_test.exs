defmodule Kantele.World.InquiryHandlers.GiveItemHoubeiTest do
  @moduledoc """
  #833 王维扬 `ask_dao` 厚背紫金刀持有者遍历（LPC wangweiyang.c:565-614）。

  与 #820 masterd.c 的五分支共用引擎 `GiveItem.owner_denial/3`；ask_dao 因
  family 门已限八卦门，LPC 仅有四分支（本人 / 借出 / 同门师兄 / 外人夺回），
  无「你派」分支。本测试用 loader 载入的真实配置驱动，且断言逐字文案与门序。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem
  alias Kantele.World.Loader

  defp conn(opts \\ []) do
    stats = %Stats{
      combat_exp: 500_000,
      shen: 0,
      gongxian: 0,
      skills: %{"bagua-dao" => Keyword.get(opts, :skill, 120)}
    }

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: stats,
      family: %{name: "八卦门"}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "beijing:shufang",
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

  setup_all do
    world = Loader.load()

    npc =
      Enum.find(world.characters, fn c ->
        c.name == "王维扬" and c.room_id == "beijing:shufang"
      end) || raise "王维扬 not found"

    %{config: npc.meta.inquiries["厚背紫金刀"] || raise("厚背紫金刀 inquiry not found")}
  end

  defp data(owner \\ nil) do
    base = %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "zhenyuan_wangweiyang",
      npc_name: "王维扬",
      npc_pid: self(),
      npc_room_id: "beijing:shufang",
      remaining: 0
    }

    if is_nil(owner), do: base, else: Map.put(base, :owner, owner)
  end

  test "loaded config：owner_check 四分支文案逐字对齐 LPC ask_dao", %{config: cfg} do
    assert cfg["owner_check"] in [true, "true"]
    assert cfg["owner_self_deny"] == "咦？厚背紫金刀现在不正是你拿着吗，怎么还反过来问我？"
    assert cfg["owner_lost_deny"] == "你来晚了一步，我已经把厚背紫金刀借出去了。"
    assert cfg["owner_sect_deny"] == "厚背紫金刀在暂时是你同门师兄{name}在用，你要用就去找他吧。"
    assert cfg["owner_outsider_deny"] == "本门的厚背紫金刀现在落在了{name}手中，你要用就去把它夺回来吧！"
  end

  test "owner == 玩家本人：返回 LPC 原文「咦？...反过来问我？」", %{config: config} do
    result = GiveItem.run(conn(), config, data(%{kind: :asker, name: "测试玩家"}))
    assert output_text(result) =~ "咦？厚背紫金刀现在不正是你拿着吗，怎么还反过来问我？"
  end

  test "owner 非角色（借出/容器）：返回「你来晚了一步...借出去了」", %{config: config} do
    result = GiveItem.run(conn(), config, data(%{kind: :object, name: "某容器"}))
    assert output_text(result) =~ "你来晚了一步，我已经把厚背紫金刀借出去了。"
  end

  test "owner 是八卦门同门：返回「同门师兄{name}在用」", %{config: config} do
    owner = %{kind: :character, name: "王剑杰", family: "八卦门"}
    result = GiveItem.run(conn(), config, data(owner))
    assert output_text(result) =~ "厚背紫金刀在暂时是你同门师兄王剑杰在用，你要用就去找他吧。"
  end

  test "owner 是外人：返回「落在了{name}手中...夺回来」", %{config: config} do
    owner = %{kind: :character, name: "张无忌", family: "武当派"}
    result = GiveItem.run(conn(), config, data(owner))
    assert output_text(result) =~ "本门的厚背紫金刀现在落在了张无忌手中，你要用就去把它夺回来吧！"
  end

  test "门序：八卦刀技能门先于 owner 门", %{config: config} do
    owner = %{kind: :asker, name: "测试玩家"}
    result = GiveItem.run(conn(skill: 50), config, data(owner))
    assert output_text(result) =~ "你还是下去再练练你的八卦刀法吧。"
    refute output_text(result) =~ "反过来问我"
  end

  test "owner 为 :npc 或未取快照：不拦，走发放分支", %{config: config} do
    for data <- [data(%{kind: :npc, name: "王维扬"}), data()] do
      result = GiveItem.run(conn(), config, data)
      refute output_text(result) =~ "反过来问我"
      refute output_text(result) =~ "借出去了"
    end
  end
end
