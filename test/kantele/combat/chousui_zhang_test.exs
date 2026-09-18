defmodule Kantele.Combat.ChousuiZhangTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ChousuiZhang
  alias Kantele.Combat.Skills.Performs.ChousuiZhang.Dan

  @room "xingxiu:shanhoushu"
  @dan "chousui-zhang/dan"
  @cmd "chousui-zhang.dan"

  defp build_character(stats_overrides) do
    stats = struct(Stats.new(), stats_overrides)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new()
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "野猪", room_id: @room}

  defp ready_stats do
    %{
      skills: %{"chousui-zhang" => 120, "poison" => 180, "throwing" => 190, "strike" => 120},
      mapped: %{"strike" => "chousui-zhang"},
      performs: MapSet.new([@dan])
    }
  end

  defp ready_character(overrides \\ %{}) do
    character = build_character(Map.merge(ready_stats(), overrides))

    vitals = %{character.meta.vitals | max_neili: 1800, neili: 300}
    combat = %{character.meta.combat | enemies: [enemy()]}

    %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} ->
        [data.text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  describe "抽髓掌（技能表）" do
    test "已注册且可 enable strike/parry" do
      assert Skills.known?("chousui-zhang")
      assert Skills.get("chousui-zhang") == ChousuiZhang
      assert ChousuiZhang.valid_enable("strike")
      assert ChousuiZhang.valid_enable("parry")
      refute ChousuiZhang.valid_enable("sword")
    end

    test "perform_list 含炼心弹" do
      assert ChousuiZhang.perform_list() == %{"dan" => Dan}
    end

    test "query_action 取静态招式（源用 dmage，已修正为 damage）" do
      action = ChousuiZhang.query_action(120, fn _ -> 1 end)
      assert action["damage_type"] == "瘀伤"
      assert action["damage"] > 0
    end
  end

  describe "炼心弹（攻击方门槛）" do
    test "未学会被拒" do
      character = ready_character(%{performs: MapSet.new()})

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "不在战斗中/无目标被拒" do
      character = %{ready_character() | meta: %{ready_character().meta | combat: Combat.new()}}

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "只能对战斗中的对手使用"
    end

    test "抽髓掌不足被拒" do
      character = ready_character(%{skills: Map.put(ready_stats().skills, "chousui-zhang", 119)})

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "抽髓掌不够娴熟"
    end

    test "毒技不足被拒" do
      character = ready_character(%{skills: Map.put(ready_stats().skills, "poison", 179)})

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "对毒技的了解不够"
    end

    test "暗器手法不足被拒" do
      character = ready_character(%{skills: Map.put(ready_stats().skills, "throwing", 189)})

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "暗器手法火候不够"
    end

    test "未激发抽髓掌被拒" do
      character = ready_character(%{mapped: %{}})

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "没有激发抽髓掌"
    end

    test "内力修为不足被拒" do
      character = ready_character()
      character = put_in(character.meta.vitals.max_neili, 1799)

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "内力修为不足"
    end

    test "当前内息不足被拒" do
      character = ready_character()
      character = put_in(character.meta.vitals.neili, 299)

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "内息不足"
    end

    test "手持毒药缺少 meta：安全拒绝而不抛异常" do
      character = ready_character()
      temp = Map.put(character.meta.temp, "handing", %{"poison_type" => "火毒"})
      character = %{character | meta: %{character.meta | temp: temp}}

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})
      assert output_text(conn) =~ "拿着(hand)些毒药"
    end

    test "成功放招：放出主文案、投递目标侧事件、暂不扣内力" do
      character = ready_character()

      conn = PerformCommand.run(build_conn(character), %{"action" => @cmd})

      assert conn.private.update_character.meta.vitals.neili == 300
      assert published_text(conn) =~ "炼心弹"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{
          perform_id: "chousui-zhang/dan",
          level: 120,
          poison: 180,
          userp: true,
          attacker: %{id: "player-1"}
        }
      }
    end
  end

  describe "炼心弹（目标侧与回执）" do
    defp target(stats_overrides, combat_overrides \\ %{}) do
      character = build_character(stats_overrides)
      combat = struct(Combat.new(), combat_overrides)
      %{character | meta: %{character.meta | combat: %{combat | enemies: [enemy()]}}}
    end

    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "对方内力过高：震灭，回执 -150 / busy 3" do
      character = target(%{"dodge" => 0})

      data = %{perform_id: @dan, an: 10, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      assert published_text(conn) =~ "震灭"
      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 150, busy: 3}
      }
    end

    test "命中：扣 jing、回执 -220 / busy 2" do
      character = target(%{"dodge" => 0, "martial-cognize" => 0})
      jing = character.meta.vitals.jing

      data = %{perform_id: @dan, an: 100_000, ap: 100_000, damage: 60, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      assert conn.private.update_character.meta.vitals.jing == jing - div(60, 2)
      assert published_text(conn) =~ "嗤嗤作响"
      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 220, busy: 2}
      }
    end

    test "命中：火毒只施加一次（level 不翻倍）" do
      character = target(%{"dodge" => 0, "martial-cognize" => 0})

      data = %{perform_id: @dan, an: 100_000, ap: 100_000, poison: 300, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      poison = conn.session["conditions"]["poison"]
      assert poison["level"] == 150
      assert poison["duration"] == 3
    end

    test "被闪避：状态不变，回执 -100 / busy 3" do
      character = target(%{"dodge" => 100_000, "martial-cognize" => 100_000})

      data = %{perform_id: @dan, an: 100_000, ap: 10, damage: 60, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "避开了"
      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 100, busy: 3}
      }
    end

    test "死亡目标忽略" do
      character = target(%{"dodge" => 0}, %{dead: true})

      data = %{perform_id: @dan, an: 10, rng: fn _ -> 1 end}
      assert incoming(build_conn(character), data).private.update_character == nil
    end
  end

  describe "回执落账（攻击方）" do
    test "按回执扣内力并进入忙乱" do
      character = ready_character()

      conn =
        CombatEvent.perform_feedback(build_conn(character), %{
          data: %{neili_cost: 220, busy: 2}
        })

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 80
      assert updated.meta.combat.busy == 2
    end

    test "死亡攻击方忽略回执" do
      character = ready_character()
      character = put_in(character.meta.combat.dead, true)

      conn =
        CombatEvent.perform_feedback(build_conn(character), %{
          data: %{neili_cost: 220, busy: 2}
        })

      assert conn.private.update_character == nil
    end
  end
end
