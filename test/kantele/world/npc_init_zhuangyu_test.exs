defmodule Kantele.World.NpcInitZhuangyuTest do
  @moduledoc """
  #1245 庄允城 `init()` 定向测试（LPC `d/beijing/npc/zhuangyu.c:45-62`）。

  覆盖：
    - 威望 <20 → +10、房间广播「江湖威望提高了」、私有 tell 新值；
    - 威望 >=20 → 只 tell 现值，不广播提升；
    - NPC 战斗中 → 求救台词被跳过，但威望链仍执行（LPC 两个分支互不嵌套）；
    - 非庄允城 → NpcInit 不处理；
    - `npc/init/weiwang` 路由到玩家侧 `NpcInitEvent.weiwang/1` 并写 stats。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.{Combat, NpcInitEvent, PlayerMeta, Stats, Vitals}
  alias Kantele.Character.Events
  alias Kantele.World.Loader
  alias Kantele.World.NpcInit

  setup_all do
    %{world: Loader.load()}
  end

  defp zhuangyu(world) do
    zone = Enum.find(world.zones, &(&1.id == "beijing"))
    Map.get(zone.characters || %{}, :zhuangyu)
  end

  defp fighting(npc) do
    combat = %{npc.meta.combat | enemies: ["some-enemy"]}
    %{npc | meta: %{npc.meta | combat: combat}}
  end

  defp player(opts) do
    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100, max_qi: 100},
      stats: %Stats{weiwang: Keyword.get(opts, :weiwang, 0)},
      combat: %Combat{},
      env: %{},
      temp: %{}
    }

    %{
      id: "player:test",
      name: "测试玩家",
      meta: meta,
      pid: Keyword.get(opts, :pid)
    }
  end

  defp event_conn(weiwang) do
    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100, max_qi: 100},
      stats: %Stats{weiwang: weiwang},
      combat: %Combat{},
      env: %{},
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "beijing:aofu_naofang",
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
      %Conn.Text{data: data} -> IO.iodata_to_binary(data)
      %Conn.EventText{text: %Conn.Text{data: data}} -> IO.iodata_to_binary(data)
      _ -> ""
    end)
    |> Enum.join()
  end

  test "威望低于 20：求救台词 + 提升广播，事件携带新值 15", %{world: world} do
    npc = zhuangyu(world)
    assert npc.name == "庄允城"

    assert {:vision, text} = NpcInit.init(npc, player(pid: self(), weiwang: 5))

    assert text =~ "庄允城哈哈笑道：终于有人来救我了！\n"
    assert text =~ "这位{respect}，鳌府的宝贝可不少啊"
    assert text =~ "\n{name}的江湖威望提高了！\n"

    assert_receive %Event{
                     topic: "npc/init/weiwang",
                     data: %{weiwang: 15, npc_name: "庄允城"}
                   }
  end

  test "威望不低于 20：不广播提升，只 tell 现值", %{world: world} do
    assert {:vision, text} =
             NpcInit.init(zhuangyu(world), player(pid: self(), weiwang: 25))

    assert text =~ "终于有人来救我了"
    refute text =~ "江湖威望提高了"

    assert_receive %Event{topic: "npc/init/weiwang", data: %{weiwang: 25}}
  end

  test "NPC 战斗中：跳过求救台词，但威望提升链仍执行", %{world: world} do
    npc = zhuangyu(world) |> fighting()

    assert {:vision, text} = NpcInit.init(npc, player(pid: self(), weiwang: 0))

    refute text =~ "终于有人来救我了"
    assert text == "\n{name}的江湖威望提高了！\n"

    assert_receive %Event{topic: "npc/init/weiwang", data: %{weiwang: 10}}
  end

  test "非庄允城 NPC 不触发 init 回执" do
    other = %{name: "别的NPC", meta: %{aliases: []}}

    assert NpcInit.init(other, player(pid: self(), weiwang: 0)) == :skip
    refute_receive %Event{topic: "npc/init/weiwang"}
  end

  test "npc/init/weiwang 路由到玩家侧，写 stats 并显示 tell" do
    result =
      Events.call(
        event_conn(0),
        %Event{
          topic: "npc/init/weiwang",
          from_pid: self(),
          data: %{weiwang: 15, npc_name: "庄允城"}
        }
      )

    assert result.private.update_character.meta.stats.weiwang == 15
    assert output_text(result) =~ "你现在的江湖威望是 15\n"
  end

  test "NpcInitEvent 对坏事件保持 conn 不变" do
    conn = event_conn(3)

    assert NpcInitEvent.weiwang(conn, %{data: %{weiwang: "15"}}) == conn
  end
end
