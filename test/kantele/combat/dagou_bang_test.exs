defmodule Kantele.Combat.DagouBangTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DagouBang
  alias Kantele.Combat.Skills.Performs.DagouBang.Chan
  alias Kantele.Combat.Skills.Performs.DagouBang.Feng
  alias Kantele.Combat.Skills.Performs.DagouBang.Tian

  @vitals %{Vitals.new() | neili: 200, max_neili: 200}
  @room "gaibang:yard"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "恶犬", room_id: @room}

  defp fighter(opts, skill_type \\ "staff") do
    character = build_character(opts)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, %{name: "打狗棒", skill_type: skill_type})
      |> Map.put(:enemies, [enemy()])

    %{character | meta: %{character.meta | combat: combat}}
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

  defp perform(opts, move, skill_type \\ "staff") do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["dagou-bang/#{move}"]))
    PerformCommand.run(build_conn(fighter(opts, skill_type)), %{"action" => "dagou-bang.#{move}"})
  end

  describe "打狗棒法（技能表）" do
    test "已注册且可 enable staff/parry" do
      assert Skills.known?("dagou-bang")
      assert Skills.get("dagou-bang") == DagouBang
      assert DagouBang.valid_enable("staff")
      assert DagouBang.valid_enable("parry")
      refute DagouBang.valid_enable("sword")
    end

    test "perform_list 含三诀" do
      assert DagouBang.perform_list() == %{"chan" => Chan, "feng" => Feng, "tian" => Tian}
    end
  end

  describe "缠字诀（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"dagou-bang" => 60}, performs: MapSet.new()], "chan")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "武器不对被拒" do
      conn = perform([skills: %{"dagou-bang" => 60}, mapped: %{"staff" => "dagou-bang"}], "chan", "sword")
      assert output_text(conn) =~ "武器不对"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"dagou-bang" => 60}], "chan")
      assert output_text(conn) =~ "没有激发打狗棒法"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"dagou-bang" => 59}, mapped: %{"staff" => "dagou-bang"}], "chan")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"dagou-bang" => 66, "force" => 100}, mapped: %{"staff" => "dagou-bang"}, vitals: %{@vitals | neili: 99}],
          "chan"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "成功放招投递目标侧事件" do
      conn = perform([skills: %{"dagou-bang" => 66, "force" => 100}, mapped: %{"staff" => "dagou-bang"}], "chan")
      assert published_text(conn) =~ "缠"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "dagou-bang/chan", level: 66, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "缠字诀（目标侧结算）" do
    defp target(skills) do
      combat = %{Combat.new() | enemies: [enemy()]}
      build_character(skills: skills, combat: combat)
    end

    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "命中：目标 busy level/18+2，攻击方回执 -50/1" do
      data = %{perform_id: "dagou-bang/chan", level: 180, rng: fn _ -> 180 end}
      conn = incoming(build_conn(target(%{"dodge" => 0})), data)

      assert conn.private.update_character.meta.combat.busy == div(180, 18) + 2
      assert published_text(conn) =~ "手忙脚乱"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 50, busy: 1}}
    end

    test "失手：攻击方回执 -50/2，目标不动" do
      data = %{perform_id: "dagou-bang/chan", level: 60, rng: fn _ -> 1 end}
      conn = incoming(build_conn(target(%{"dodge" => 400})), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "镇定解招"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 50, busy: 2}}
    end

    test "目标忙乱则忽略" do
      character = target(%{"dodge" => 0})
      combat = %{character.meta.combat | busy: 2}
      character = %{character | meta: %{character.meta | combat: combat}}
      data = %{perform_id: "dagou-bang/chan", level: 180, rng: fn _ -> 180 end}

      assert incoming(build_conn(character), data).private.update_character == nil
    end
  end

  describe "封字诀（自我增益）" do
    test "扣 150 内力并挂 parry buff" do
      conn =
        perform(
          [skills: %{"dagou-bang" => 120, "force" => 180}, mapped: %{"staff" => "dagou-bang"}, vitals: %{@vitals | neili: 500}],
          "feng"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 350
      assert updated.meta.combat.temp.parry == 40
      assert Combat.buff_active?(updated.meta.combat, "feng_zijue")
      assert published_text(conn) =~ "封"
    end

    test "已在自己施展中则拒绝" do
      character =
        fighter(
          skills: %{"dagou-bang" => 120, "force" => 180},
          mapped: %{"staff" => "dagou-bang"},
          performs: MapSet.new(["dagou-bang/feng"]),
          vitals: %{@vitals | neili: 500}
        )

      combat = %{character.meta.combat | buffs: [%Combat.Buff{key: "feng_zijue", applies: []}]}
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = PerformCommand.run(build_conn(character), %{"action" => "dagou-bang.feng"})
      assert output_text(conn) =~ "正在施展"
    end
  end

  describe "天下无狗（攻击方门槛）" do
    test "等级不足被拒" do
      conn = perform([skills: %{"dagou-bang" => 219, "force" => 300}, mapped: %{"staff" => "dagou-bang"}], "tian")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "成功放招投递事件且带 ap" do
      conn =
        perform(
          [
            skills: %{"dagou-bang" => 300, "force" => 300, "begging" => 100, "martial-cognize" => 50},
            mapped: %{"staff" => "dagou-bang"},
            vitals: %{@vitals | neili: 2000, max_neili: 2000}
          ],
          "tian"
        )

      assert published_text(conn) =~ "层层叠叠"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "dagou-bang/tian", ap: 450}
      }
    end
  end

  describe "天下无狗（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    test "命中：造成伤害并回执扣内力" do
      character = build_character(skills: %{"dodge" => 0})
      data = %{perform_id: "dagou-bang/tian", ap: 450, rng: fn _ -> 1 end}

      conn =
        CombatEvent.perform_incoming(build_conn(character), %{data: Map.merge(%{attacker: attacker()}, data)})

      assert conn.private.update_character.meta.vitals.qi < Vitals.new().qi
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 150, busy: 1}}
    end
  end
end
