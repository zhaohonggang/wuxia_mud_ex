defmodule Kantele.World.GiveItemMasterGateOrderTest do
  @moduledoc """
  #1188 `master_before_gates = true` 门序修复定向测试。

  该键只能把「师父门」移到 shen/技能门之前，不能关闭整条 gate 链。
  以红花会陈家洛「剑盾珠索」真实 UCL 配置驱动，逐条锁定 LPC 顺序。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem
  alias Kantele.World.Items
  alias Kantele.World.Loader

  setup_all do
    world = Loader.load()
    npc = Enum.find(world.characters, &(&1.name == "陈家洛")) || raise "陈家洛 not found"
    config = npc.meta.inquiries["剑盾珠索"] || raise "剑盾珠索 inquiry not found"

    case Items.start_link(name: Items) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    item = Enum.find(world.items, &(&1.id == "clone_lib:jiansuo")) || raise "jiansuo not found"
    Items.put(item.id, item)

    %{config: config}
  end

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{
        combat_exp: Keyword.get(opts, :exp, 500_000),
        shen: Keyword.get(opts, :shen, 100_000),
        skills: %{"jiandun-zhusuo" => Keyword.get(opts, :skill, 120)}
      },
      family: %{
        name: "红花会",
        master_id: Keyword.get(opts, :master_id, "npc:chen")
      }
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "kaifeng:honghua",
        inventory: [],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "npc:chen",
      npc_name: "陈家洛",
      npc_pid: self(),
      npc_room_id: "kaifeng:hh_woshi",
      remaining: 1
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

  test "师父门仍先于侠义/技能门", %{config: config} do
    result = GiveItem.run(conn(master_id: "other", shen: 0, skill: 0), config, data())
    assert output_text(result) =~ "只有我的弟子才能用我这剑盾珠索。"
    refute output_text(result) =~ "侠义正事做得还不够"
    refute output_text(result) =~ "连剑盾珠索都没学好"
  end

  test "师父门通过后侠义门仍执行（旧实现会整条跳过）", %{config: config} do
    result = GiveItem.run(conn(shen: 79_999, skill: 0), config, data())
    assert output_text(result) =~ "你侠义正事做得还不够，这剑盾珠索我不能教给你。"
    refute output_text(result) =~ "连剑盾珠索都没学好"
  end

  test "侠义门通过后技能门仍执行", %{config: config} do
    result = GiveItem.run(conn(shen: 80_000, skill: 119), config, data())
    assert output_text(result) =~ "你连剑盾珠索都没学好，就算用也是白搭。"
  end

  test "三门全过后正常发放", %{config: config} do
    result = GiveItem.run(conn(shen: 80_000, skill: 120), config, data())
    refute output_text(result) =~ "只有我的弟子"
    refute output_text(result) =~ "侠义正事做得还不够"
    refute output_text(result) =~ "连剑盾珠索都没学好"
    assert output_text(result) =~ "这剑盾珠索你就拿去，多用它行侠仗义，惩奸除恶。"
  end
end
