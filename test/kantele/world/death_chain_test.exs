defmodule Kantele.World.DeathChainTest do
  @moduledoc """
  P4 地府转世链（P4-A~P4-E）定向测试。

  覆盖：死亡落点固定为阎罗殿、阎罗置位 HellZhenPass、地藏王 `ask 转世`
  三分支（含发起生死斗）、高处不胜寒问询、献丹事件投递、UCL 接线。
  决斗/落盘只断言「消息与事件已发出」，不依赖真实房间进程或成功落库。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.Dizangwang
  alias Kantele.NPC.Lonely
  alias Kantele.NPC.Yanluo
  alias Kantele.World
  alias Kantele.World.RebornAccept

  @death_room "death:yanluodian"

  defp character(env \\ %{}) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10_000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @death_room,
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        env: env
      }
    }
  end

  defp npc(name) do
    # RebornAccept.handle 会走 prompt(CommandView, "prompt")，需要 meta.vitals
    %{character() | id: "npc-#{name}", name: name}
  end

  # Kalevala 的 render/4 产出 %Conn.Text{}；prompt/4 产出 %Conn.EventText{}，
  # 其 :data 是 %Vitals{}（不可作 iodata），真正的文案在 text.data。
  # 必须按结构体分派，否则泛化的 %{data: data} 会在 prompt 上抛 ArgumentError。
  defp output(conn) do
    conn.output
    |> Enum.map(fn
      %Kalevala.Character.Conn.Text{data: data} -> IO.iodata_to_binary(data)
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} ->
        IO.iodata_to_binary(data)

      _ -> ""
    end)
    |> Enum.join()
  end

  describe "P4-A 死亡落点" do
    test "death_room_id/0 固定指向地府阎罗殿" do
      assert World.death_room_id() == @death_room
    end
  end

  describe "P4-B 地藏王 ask 转世三分支" do
    test "未过十八层地狱 → 拒绝" do
      assert {:error, msg} = Dizangwang.check(character(), npc("地藏王"), "转世")
      assert msg =~ "十八层地狱"
    end

    test "已过地狱 → check 放行" do
      asker = character(%{HellZhenPass: true})
      assert :ok == Dizangwang.check(asker, npc("地藏王"), "转世")
    end

    test "已取精元丹 → 催交，不发起决斗" do
      asker = character(%{HellZhenPass: true, SkyPass: true})
      assert {:error, msg} = Dizangwang.execute(asker, npc("地藏王"), "转世")
      assert msg =~ "精元丹"
    end

    test "前置齐备但未取丹 → 发起生死斗，双方收 combat/start (type kill)" do
      asker = character(%{HellZhenPass: true})
      assert :ok == Dizangwang.execute(asker, npc("地藏王"), "转世")

      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
      assert_receive {:room_message, msg}
      assert msg =~ "见识见识老夫的手段"
    end
  end

  describe "P4-D 阎罗 / 高处不胜寒问询" do
    test "阎罗 ask 转世 置位 HellZhenPass" do
      assert :ok == Yanluo.check(character(), npc("十殿阎罗"), "转世")
      assert {:ok, updated} = Yanluo.execute(character(), npc("十殿阎罗"), "转世")
      assert updated.meta.env[:HellZhenPass] == true
    end

    test "高处不胜寒 ask 精元丹 放行并发起生死斗" do
      assert :ok == Lonely.check(character(), npc("高处不胜寒"), "精元丹")
      assert :ok == Lonely.execute(character(), npc("高处不胜寒"), "精元丹")

      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
    end
  end

  describe "P4-E 献丹 → 玩家侧事件" do
    test "RebornAccept.handle/5 投递 reborn/give-jingyuandan 并回话" do
      instance = %Instance{
        id: "inst-jingyuandan",
        item_id: "death:jingyuandan",
        created_at: DateTime.utc_now()
      }

      data = %{reply_to: self(), from_id: "player-1"}
      conn = RebornAccept.handle(build_conn(npc("地藏王")), npc("地藏王"), instance, data, "张三")

      assert_receive %Event{
        topic: "reborn/give-jingyuandan",
        data: %{
          item_id: "death:jingyuandan",
          instance_id: "inst-jingyuandan",
          from_id: "player-1"
        }
      }

      assert output(conn) =~ "地藏王接过精元丹"
    end
  end

  describe "NPC 处理器接线" do
    test "阎罗 / 高处不胜寒 / 地藏王 均实现 AskHandler 且关键字正确" do
      assert Map.has_key?(Yanluo.ask_specs(), "转世")
      assert Map.has_key?(Lonely.ask_specs(), "精元丹")
      assert Map.has_key?(Dizangwang.ask_specs(), "转世")
    end

    test "death.ucl 阎罗殿已放置地藏王 NPC" do
      ucl = File.read!("data/world/death.ucl")
      assert ucl =~ "characters.dizangwang.id"
    end
  end
end
