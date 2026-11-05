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
  alias Kantele.Quest
  alias Kantele.NPC.Lonely
  alias Kantele.NPC.Yanluo
  alias Kantele.World
  alias Kantele.World.HellZhen
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

  # 满足阎罗 ask_zhuan 全部已移植前置：大宗师（Ex 以 combat_exp>=800M 建模）
  # + 元婴出世 + 无家室/帮派/兄弟/同盟 + 未通关地狱 + 锁阳丹任务已解（第九门）。
  defp qualified_character(env \\ %{}) do
    c = character(Map.merge(%{animaout: true}, env))
    stats = Map.put(c.meta.stats, :combat_exp, 900_000_000)
    solved_quests =
      Quest.new()
      |> Quest.set_solved(%{file: "hell_quest/锁阳丹"})
      |> elem(1)
    %{c | meta: %{c.meta | stats: stats, quests: solved_quests}}
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
    test "未达大宗师阈值 → check 先拦（combat_exp<800M）" do
      assert {:error, msg} = Dizangwang.check(character(), npc("地藏王"), "转世")
      assert msg =~ "大宗师"
    end

    test "大宗师但未过十八层地狱 → 拒绝" do
      asker = qualified_character()  # combat_exp 900M，无 HellZhenPass
      assert {:error, msg} = Dizangwang.check(asker, npc("地藏王"), "转世")
      assert msg =~ "十八层地狱"
    end

    test "大宗师且已过地狱 → check 放行" do
      asker = qualified_character(%{HellZhenPass: true})
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

  describe "P4-D / 真 LPC 阎罗十八层地狱起链" do
    test "经验不足 → 阎罗拒绝，不再无条件置位 HellZhenPass" do
      assert {:error, msg} = Yanluo.check(character(), npc("十殿阎罗"), "转世")
      assert msg =~ "经验不够"

      assert {:error, ^msg} = Yanluo.execute(character(), npc("十殿阎罗"), "转世")
    end

    test "前置齐备 → 起链：置令牌 + 送进 emptyroom + 排两条 call_out" do
      asker = qualified_character()
      assert :ok == Yanluo.check(asker, npc("十殿阎罗"), "转世")

      assert {:ok, updated} = Yanluo.execute(asker, npc("十殿阎罗"), "转世")
      assert is_binary(updated.meta.temp[HellZhen.temp_token()])
      # HellZhenPass 只能由 winning 置位，起链时绝不能有
      refute updated.meta.env[:HellZhenPass]

      assert_receive %Event{
        topic: "character/teleport",
        data: %{room_id: "death:emptyroom"}
      }

      assert_receive {:room_message, msg}
      assert msg =~ "陷了下去"

      # t=2s message_ob / t=3s round_1
      assert_receive %Event{
        topic: "character/hell_zhen_step",
        data: %{phase: "opening", token: token}
      }, 4_000

      assert_receive %Event{
        topic: "character/hell_zhen_step",
        data: %{phase: "round", round: 1, token: ^token}
      }, 4_000

      assert token == updated.meta.temp[HellZhen.temp_token()]
    end

    test "已通关十八层地狱 → 直接免试" do
      asker = qualified_character(%{HellZhenPass: true})
      assert {:error, msg} = Yanluo.check(asker, npc("十殿阎罗"), "转世")
      assert msg =~ "免了吧"
    end
  end

  describe "真 LPC 高处不胜寒 accept_kill 经验门" do
    test "combat_exp < 20_000_000 → 拒绝并把玩家击晕" do
      assert {:error, msg, knocked} =
               Lonely.check(character(), npc("高处不胜寒"), "精元丹")

      assert msg =~ "无名小辈"
      assert Lonely.combat_exp_min() == 20_000_000
      # LPC me->unconcious()：qi 归零
      assert knocked.meta.vitals.qi == 0
    end

    test "combat_exp 达标 → 放行并发起生死斗" do
      asker = qualified_character()
      assert :ok == Lonely.check(asker, npc("高处不胜寒"), "精元丹")
      assert :ok == Lonely.execute(asker, npc("高处不胜寒"), "精元丹")

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
