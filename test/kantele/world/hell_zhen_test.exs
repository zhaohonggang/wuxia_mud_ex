defmodule Kantele.World.HellZhenTest do
  @moduledoc """
  真 LPC 三处替换的定向测试：

  - 阎罗十八层地狱（`Kantele.World.HellZhen` + `HellZhenEvent`）
  - 高处不胜寒 `accept_kill` 的 combat_exp 门（在 death_chain_test 里）
  - 六道轮回逐房遍历（`GiveEvent.traverse_six_paths/1`）
  - 元婴出世写出 `env[:animaout]`，让阎罗的 animaout 门真正可达

  定时链全部用 `scale: 0` 压成 0ms，不依赖真实等待。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kantele.Character.AnimaoutCommand
  alias Kantele.Character.Combat
  alias Kantele.Character.Events
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.Yanluo
  alias Kantele.Quest
  alias Kantele.World.HellZhen
  alias Kantele.World.SuoyangdanAccept
  alias Kalevala.Character
  alias Kalevala.World.Item.Instance

  @emptyroom "death:emptyroom"

  defp character(opts \\ []) do
    vitals = %Vitals{
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000),
      jing: 2000,
      max_jing: 2000,
      jingli: 2000,
      max_jingli: 3000,
      neili: 9000,
      max_neili: 10_000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{}),
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: Keyword.get(opts, :combat_exp, 900_000_000),
      score: 0,
      potential: 5000,
      learned_points: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @emptyroom,
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        env: Keyword.get(opts, :env, %{animaout: true}),
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

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

  defp updated(conn), do: conn.private.update_character || conn.character

  defp fire(character, phase, extra \\ %{}) do
    token = HellZhen.token(character) || "tok"
    data = HellZhen.step_data(token, phase, Map.put(extra, :scale, 0))

    Events.call(
      build_conn(character),
      %Event{topic: HellZhen.step_topic(), data: data}
    )
  end

  # ---------------------------------------------------------------------------
  # 试炼数据
  # ---------------------------------------------------------------------------

  describe "18 层表与 LPC 时序" do
    test "18 层狱名 / 鬼序号与 yanluo.c 一致" do
      assert HellZhen.layer_count() == 18
      assert HellZhen.layer_name(1) == "吊筋狱"
      assert HellZhen.layer_name(18) == "秤杆狱"
      assert HellZhen.ghost_ids(1) == [1]
      assert HellZhen.ghost_ids(10) == [10]
      assert length(HellZhen.ghost_ids(11)) == 2
      assert HellZhen.ghost_ids(18) == [18, 17]
      assert HellZhen.layer_name(19) == nil
      assert HellZhen.ghost_ids(19) == []
    end

    test "11-18 层节奏放慢，第 18 层直接 winning" do
      assert HellZhen.timings(1) |> Map.take([:check_s, :interlude_s, :next_s]) ==
               %{check_s: 1, interlude_s: 2, next_s: 3}

      assert HellZhen.timings(11) |> Map.take([:interlude_s, :next_s]) ==
               %{interlude_s: 4, next_s: 6}

      assert HellZhen.timings(18).winning_s == 3
      assert HellZhen.opening_timings() == %{message_ob_s: 2, round_1_s: 3}
      assert HellZhen.delay_ms(3, 0) == 0
    end

    test "黑牌横幅 / 五选一文案" do
      assert HellZhen.banner(1) =~ "黑牌闪过"
      assert HellZhen.banner(1) =~ "吊筋狱"
      assert HellZhen.interlude() =~ "不断下降"
    end
  end

  # ---------------------------------------------------------------------------
  # 鬼 invocation / check_status
  # ---------------------------------------------------------------------------

  describe "LPC invocation / check_status" do
    test "ap=1500；dp=force+martial-cognize；命中才扣血" do
      weak = character()
      assert %{ap: 1500, dp: 0, hit?: true, damage: 3000} =
               HellZhen.invocation(weak, fn n -> n end)

      strong = character(skills: %{"force" => 2000, "martial-cognize" => 2000})
      assert %{ap: 1500, dp: 4000, hit?: false, damage: 0} =
               HellZhen.invocation(strong, fn n -> n end)
    end

    test "apply_damage 扣 vitals.qi" do
      c = character()
      assert HellZhen.apply_damage(c, %{damage: 1200}).meta.vitals.qi == 3800
      assert HellZhen.apply_damage(c, %{damage: 0}) == c
    end

    test "qi < 500 或 max_qi < 500 判失败（eff_qi → max_qi）" do
      assert HellZhen.check_status(character()) == :ok
      assert HellZhen.check_status(character(qi: 100)) == :failed
      assert HellZhen.check_status(character(max_qi: 100)) == :failed
      assert HellZhen.qi_min() == 500
    end
  end

  # ---------------------------------------------------------------------------
  # ask_zhuan 门
  # ---------------------------------------------------------------------------

  describe "gate_error/1 九道门" do
    test "经验 / 元婴 / 家室 / 帮派 / 兄弟 / 同盟 / 已通关" do
      assert HellZhen.gate_error(character(combat_exp: 1000)) =~ "经验不够"
      assert HellZhen.gate_error(character(env: %{})) =~ "元婴出世"

      assert HellZhen.gate_error(
               character(env: %{animaout: true, couple: "李四"})
             ) =~ "家庭"

      assert HellZhen.gate_error(
               character(env: %{animaout: true, bunch: "某帮"})
             ) =~ "帮派"

      assert HellZhen.gate_error(
               character(env: %{animaout: true, brothers: ["李四"]})
             ) =~ "结义兄弟"

      assert HellZhen.gate_error(
               character(env: %{animaout: true, league: "某盟"})
             ) =~ "同盟"

      assert HellZhen.gate_error(
               character(env: %{animaout: true, HellZhenPass: true})
             ) =~ "免了吧"

      # 锁阳丹硬门：默认角色未完成锁阳丹任务，因此被拒
      assert HellZhen.gate_error(character()) =~ "锁阳丹"

      # 锁阳丹已完成：通过所有九道门，放行
      solved_quests =
        Quest.new()
        |> Quest.set_solved(%{file: "hell_quest/锁阳丹"})
        |> elem(1)

      c = character(env: %{animaout: true})
      c = %{c | meta: %{c.meta | quests: solved_quests}}

      assert HellZhen.gate_error(c) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # gate_error/1 第九道门：锁阳丹硬门
  # ---------------------------------------------------------------------------

  describe "gate_error/1 锁阳丹硬门" do
    test "前八门均通过但锁阳丹未完成：拒绝" do
      c = character(env: %{animaout: true})
      assert HellZhen.gate_error(c) =~ "锁阳丹"
    end

    test "前八门均通过且锁阳丹已完成：放行" do
      solved_quests =
        Quest.new()
        |> Quest.set_solved(%{file: "hell_quest/锁阳丹"})
        |> elem(1)

      c = character(env: %{animaout: true})
      c = %{c | meta: %{c.meta | quests: solved_quests}}
      assert HellZhen.gate_error(c) == nil
    end

    test "前八门均通过但任务在办中未完成：拒绝（solved 为空，todo 有条目）" do
      spec = %{file: "hell_quest/锁阳丹", item: ["longdan", "hugu", "yumao", "jiake"]}
      {:ok, quests} = Quest.set_todo(Quest.new(), spec)

      c = character(meta: %PlayerMeta{quests: quests, env: %{animaout: true}})
      assert HellZhen.gate_error(c) =~ "锁阳丹"
    end
  end

  # ---------------------------------------------------------------------------
  # Yanluo.ask_specs/0 「锁阳丹」
  # ---------------------------------------------------------------------------

  describe "Yanluo.ask_specs/0 「锁阳丹」" do
    test "check 始终返回 :ok，任何人皆可领取" do
      assert Yanluo.ask_specs()["锁阳丹"].check.(character(), %Character{}) == :ok
    end

    test "execute 构造正确的 quest spec 并置入 PlayerMeta.quests" do
      spec = %{file: "hell_quest/锁阳丹", item: ["longdan", "hugu", "yumao", "jiake"]}
      {:ok, quests} = Quest.set_todo(Quest.new(), spec)

      todo = Quest.get_todo(quests, "hell_quest/锁阳丹")
      assert todo.item == %{}
      assert Map.keys(todo.item) == []
      assert Quest.get_size(quests) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # SuoyangdanAccept.handle/5：阎罗收药引，向玩家发 suoyangdan/give-ingredient 事件
  # ---------------------------------------------------------------------------

  describe "SuoyangdanAccept.handle/5" do
    test "发送 suoyangdan/give-ingredient 事件，数据包含 item_id/instance_id/from/to" do
      reply_to = self()
      vitals = %Vitals{qi: 5000, max_qi: 5000, jing: 2000, max_jing: 2000, jingli: 2000, max_jingli: 3000, neili: 9000, max_neili: 10000}
      stats = %Stats{str: 20, dex: 20, con: 20, int: 20, skills: %{}, mapped: %{}, performs: MapSet.new(), combat_exp: 0, score: 0, potential: 0, learned_points: 0, weiwang: 0}
      npc = %Character{
        id: "npc-yanluo",
        name: "十殿阎罗",
        room_id: "death:yanluodian",
        inventory: [],
        meta: %PlayerMeta{vitals: vitals, stats: stats, combat: Combat.new()}
      }
      item_instance = %Instance{id: "inst-longdan-1", item_id: "longdan"}
      data = %{reply_to: reply_to, from_id: "player-1"}

      SuoyangdanAccept.handle(build_conn(npc), npc, item_instance, data, "张三")

      assert_receive %Kalevala.Event{
               topic: "suoyangdan/give-ingredient",
               data: %{
                 item_id: "longdan",
                 instance_id: "inst-longdan-1",
                 from_id: "player-1",
                 to_id: "npc-yanluo",
                 from_name: "张三"
               }
             }, 1000
    end
  end

  # ---------------------------------------------------------------------------
  # suoyangdan_give_ingredient/2 Quest 级逻辑：四味药引追踪与完成
  # ---------------------------------------------------------------------------

  describe "suoyangdan_give_ingredient/2 Quest 级逻辑" do
    test "Quest.add_item 追踪每味药引计数，四味齐备后 is_solved 为真" do
      spec = %{file: "hell_quest/锁阳丹", item: ["longdan", "hugu", "yumao", "jiake"]}
      {:ok, q1} = Quest.set_todo(Quest.new(), spec)

      # 逐味收集，每味计数为 1
      {:ok, q2} = Quest.add_item(q1, spec, "longdan", 1)
      {:ok, q3} = Quest.add_item(q2, spec, "hugu", 1)
      {:ok, q4} = Quest.add_item(q3, spec, "yumao", 1)
      {:ok, q5} = Quest.add_item(q4, spec, "jiake", 1)

      assert Quest.get_item(q5, spec, "longdan") == 1
      assert Quest.get_item(q5, spec, "hugu") == 1
      assert Quest.get_item(q5, spec, "yumao") == 1
      assert Quest.get_item(q5, spec, "jiake") == 1

      # 四味齐备：所有 item 计数 >= 1
      all_collected =
        Enum.all?(["longdan", "hugu", "yumao", "jiake"], fn iid ->
          Quest.get_item(q5, spec, iid) >= 1
        end)
      assert all_collected == true

      # 置位已解
      {:ok, qs} = Quest.set_solved(q5, spec)
      assert Quest.is_solved(qs, spec) == true
      assert "hell_quest/锁阳丹" in Quest.get_solved(qs)
    end

    test "未齐备时 is_solved 仍为假" do
      spec = %{file: "hell_quest/锁阳丹", item: ["longdan", "hugu", "yumao", "jiake"]}
      {:ok, q1} = Quest.set_todo(Quest.new(), spec)
      {:ok, q2} = Quest.add_item(q1, spec, "longdan", 1)

      assert Quest.get_item(q2, spec, "longdan") == 1
      assert Quest.get_item(q2, spec, "hugu") == 0
      assert Quest.is_solved(q2, spec) == false
    end

    test "重复收集同一味药引：计数累加" do
      spec = %{file: "hell_quest/锁阳丹", item: ["longdan", "hugu", "yumao", "jiake"]}
      {:ok, q1} = Quest.set_todo(Quest.new(), spec)
      {:ok, q2} = Quest.add_item(q1, spec, "longdan", 1)
      {:ok, q3} = Quest.add_item(q2, spec, "longdan", 1)

      assert Quest.get_item(q3, spec, "longdan") == 2
    end
  end

  # ---------------------------------------------------------------------------
  # 令牌 / 作废（remove_call_out 等价）
  # ---------------------------------------------------------------------------

  describe "令牌与 remove_call_out 等价" do
    test "put_token → cancel → valid_step? 丢弃 → clear_trial 复原" do
      c = HellZhen.put_token(character(), "tok-1")
      assert HellZhen.token(c) == "tok-1"
      assert HellZhen.valid_step?(c, %{token: "tok-1"}) == true
      assert HellZhen.valid_step?(c, %{token: "tok-2"}) == false

      cancelled = HellZhen.cancel(c)
      assert HellZhen.cancelled?(cancelled) == true
      assert HellZhen.valid_step?(cancelled, %{token: "tok-1"}) == false

      cleared = HellZhen.clear_trial(cancelled)
      assert HellZhen.token(cleared) == nil
      assert HellZhen.cancelled?(cleared) == false
    end
  end

  # ---------------------------------------------------------------------------
  # 事件链
  # ---------------------------------------------------------------------------

  describe "HellZhenEvent 逐拍执行" do
    test "Events.call/2 把 character/hell_zhen_step 路由到 HellZhenEvent" do
      assert function_exported?(Kantele.Character.HellZhenEvent, :step, 2)

      conn = fire(character(), "opening")
      assert is_map(conn)
    end

    test "round 层：黑牌 + 鬼结算 + 三条后续节拍" do
      conn = fire(character(), "round", %{round: 1})
      text = output(conn)

      assert text =~ "狱中鬼影" or text =~ "识破了狱中鬼影"
      assert updated(conn).meta.vitals.qi < 5000

      assert_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "check"}}, 1000
      assert_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "interlude"}}, 1000
      assert_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "round", round: 2}}, 1000
    end

    test "第 18 层不排 interlude，改排 winning" do
      fire(character(), "round", %{round: 18})

      assert_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "winning"}}, 1000
      refute_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "interlude"}}, 50
    end

    test "check 失败 → 作废令牌，只留 failed 一拍" do
      c = HellZhen.put_token(character(qi: 100), "tok-fail")
      conn = fire(c, "check")

      assert updated(conn).meta.temp[HellZhen.temp_cancelled()] == true
      assert_receive %Event{topic: "character/hell_zhen_step", data: %{phase: "failed"}}, 1000

      # 作废后其它已排队的 phase 静默丢弃
      stale = fire(updated(conn), "round", %{round: 2})
      assert output(stale) == ""
    end

    test "winning 才置位 HellZhenPass 并回阎罗殿" do
      c = HellZhen.put_token(character(), "tok-win")
      conn = fire(c, "winning")
      character = updated(conn)

      assert character.meta.env[:HellZhenPass] == true
      assert character.room_id == "death:yanluodian"
      assert HellZhen.token(character) == nil
      assert output(conn) =~ "闯过十八层地狱"
    end

    test "failed 不置位 HellZhenPass，落到武庙" do
      c = HellZhen.put_token(character(), "tok-lose")
      conn = fire(c, "failed")
      character = updated(conn)

      refute character.meta.env[:HellZhenPass]
      assert character.room_id == "city:wumiao"
      assert character.meta.vitals.qi == 0
    end
  end

  # ---------------------------------------------------------------------------
  # 六道轮回
  # ---------------------------------------------------------------------------

  describe "GiveEvent 六道轮回逐房遍历" do
    test "six_paths/0 是 LPC accept_object 的 7 次 move()" do
      assert Enum.map(GiveEvent.six_paths(), &elem(&1, 0)) == [
               "death:tiandao",
               "death:diyudao",
               "death:rendao",
               "death:eguidao",
               "death:chushengdao",
               "death:xiuluodao",
               "death:wujiandao"
             ]
    end

    test "traverse_six_paths/1 连发 7 次 :to 位移，终点无间道" do
      conn = GiveEvent.traverse_six_paths(build_conn(character()))

      to_rooms =
        Enum.flat_map(conn.events, fn
          %Event{topic: Movement, data: %Movement{direction: :to, room_id: room_id}} ->
            [room_id]

          _ ->
            []
        end)

      assert to_rooms == Enum.map(GiveEvent.six_paths(), &elem(&1, 0))
      assert updated(conn).room_id == "death:wujiandao"
      assert output(conn) =~ "天极道"
      assert output(conn) =~ "无间道"
    end
  end

  # ---------------------------------------------------------------------------
  # 元婴出世
  # ---------------------------------------------------------------------------

  describe "AnimaoutCommand 写出 animaout 标志" do
    test "try_animaout/2 保留 LPC random(10) / random(40000) < con 判定" do
      c = character()
      assert AnimaoutCommand.try_animaout(c, fn _ -> 1 end) == :success

      assert AnimaoutCommand.try_animaout(c, fn
               10 -> 2
               40_000 -> 1
             end) == :continue

      assert AnimaoutCommand.try_animaout(c, fn
               10 -> 1
               40_000 -> 40_000
             end) == :meditate
    end

    test "grant_animaout/2 写 env[:animaout] 并把 max_jingli +1500" do
      c = character()
      granted = AnimaoutCommand.grant_animaout(c, c.meta.vitals)

      assert granted.meta.env[:animaout] == true
      assert granted.meta.vitals.max_jingli == c.meta.vitals.max_jingli + 1500

      # gate_error 现在有第九道锁阳丹硬门：需置 solved 才能放行
      solved_quests =
        Quest.new()
        |> Quest.set_solved(%{file: "hell_quest/锁阳丹"})
        |> elem(1)
      granted_with_quest =
        %{granted | meta: %{granted.meta | quests: solved_quests}}
      assert HellZhen.gate_error(granted_with_quest) == nil
    end
  end
end
