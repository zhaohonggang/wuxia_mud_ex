defmodule Kantele.Combat.BingxinJueTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BingxinJue
  alias Kantele.Combat.Skills.BingxinJue.Powerup
  alias Kantele.Combat.Skills.BingxinJue.Freeze

  @vitals %{Vitals.new() | neili: 2000, max_neili: 2000}
  @room "emei:hall"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "灭绝师太",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy(opts \\ []) do
    vitals = Keyword.get(opts, :vitals, %{Vitals.new() | neili: 500, max_neili: 500, qi: 500, max_qi: 500})
    skills = Keyword.get(opts, :skills, %{"force" => 150})
    stats = struct(Stats.new(), skills: skills)
    combat = Keyword.get(opts, :combat, %{Combat.new() | enemies: [%{id: "player-1", pid: self(), name: "灭绝师太", room_id: @room}]})

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "周芷若",
      room_id: @room,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp attacker, do: %{id: "player-1", pid: self(), name: "灭绝师太", room_id: @room}

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

  defp perform(opts, move) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["bingxin-jue/#{move}"]))
    opts = Keyword.put_new(opts, :mapped, Keyword.get(opts, :mapped, %{"force" => "bingxin-jue"}))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  describe "冰心诀（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("bingxin-jue")
      assert Skills.get("bingxin-jue") == BingxinJue
      assert BingxinJue.valid_enable("force")
      refute BingxinJue.valid_enable("sword")
    end

    test "exert_list 含 powerup/freeze" do
      assert Map.has_key?(BingxinJue.exert_list(), "powerup")
      assert Map.has_key?(BingxinJue.exert_list(), "freeze")
    end
  end

  describe "powerup（运功）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        perform(
          [
            skills: %{"bingxin-jue" => 150, "force" => 150},
            mapped: %{"force" => "bingxin-jue"},
            vitals: %{@vitals | neili: 500}
          ],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 50
      assert updated.meta.combat.temp.defense == 50
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "白雾缭绕"
    end

    test "内力不足被拒" do
      conn = perform([skills: %{"bingxin-jue" => 150, "force" => 150}, mapped: %{"force" => "bingxin-jue"}, vitals: %{@vitals | neili: 50}], "powerup")
      assert output_text(conn) =~ "真气不够"
    end
  end

  describe "freeze（寒气，攻击方门槛）" do
    test "等级不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"bingxin-jue" => 149, "force" => 150},
          mapped: %{"force" => "bingxin-jue"},
          performs: MapSet.new(["bingxin-jue/freeze"]),
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "freeze"})
      assert output_text(conn) =~ "火候不够"
    end

    test "内力不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"bingxin-jue" => 150, "force" => 150},
          mapped: %{"force" => "bingxin-jue"},
          performs: MapSet.new(["bingxin-jue/freeze"]),
          vitals: %{@vitals | neili: 500},
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "freeze"})
      assert output_text(conn) =~ "内力不够"
    end

    test "无战斗目标被拒" do
      conn =
        build_conn(build_character(
          skills: %{"bingxin-jue" => 150, "force" => 150},
          mapped: %{"force" => "bingxin-jue"},
          performs: MapSet.new(["bingxin-jue/freeze"]),
          combat: Combat.new()
        ))
      conn = ExertCommand.run(conn, %{"function" => "freeze"})
      assert output_text(conn) =~ "只能用寒气攻击战斗中的对手"
    end

    test "目标已死被拒" do
      target = enemy(vitals: %{Vitals.new() | qi: 0}, combat: %{Combat.new() | dead: true})
      conn = build_conn(build_character(
        skills: %{"bingxin-jue" => 150, "force" => 150},
        mapped: %{"force" => "bingxin-jue"},
        performs: MapSet.new(["bingxin-jue/freeze"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "freeze"})
      assert output_text(conn) =~ "已经这样了"
    end

    test "成功放招投递目标侧事件" do
      target = enemy()
      conn = build_conn(build_character(
        skills: %{"bingxin-jue" => 150, "force" => 150},
        mapped: %{"force" => "bingxin-jue"},
        performs: MapSet.new(["bingxin-jue/freeze"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "freeze"})
      assert published_text(conn) =~ "寒气迎面扑向"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "bingxin-jue/freeze", level: 150, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "freeze（寒气，目标侧结算）" do
    test "命中：目标 qi/max_qi/neili 减少，busy 1" do
      target = enemy(vitals: %{Vitals.new() | qi: 500, max_qi: 500, neili: 500})
      target_conn = build_conn(target)
      data = %{perform_id: "bingxin-jue/freeze", level: 150, ap: 150, rng: fn n -> n end}

      conn = incoming(target_conn, data)

      updated = conn.private.update_character
      assert updated.meta.vitals.qi < 500
      assert updated.meta.vitals.max_qi < 500
      assert updated.meta.vitals.neili < 500
      assert updated.meta.combat.busy >= 1
      assert published_text(conn) =~ "融雪般消失"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 2}}
    end

    test "失手：目标不动，仅文案" do
      target = enemy(vitals: %{Vitals.new() | qi: 500, max_qi: 500, neili: 500}, skills: %{"force" => 500})
      target_conn = build_conn(target)
      data = %{perform_id: "bingxin-jue/freeze", level: 150, ap: 0, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.qi == 500
      assert conn.private.update_character.meta.vitals.max_qi == 500
      assert published_text(conn) =~ "堪勘无事"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 2}}
    end

    test "目标已死则忽略" do
      target = enemy(vitals: %{Vitals.new() | qi: 0}, combat: %{Combat.new() | dead: true})
      target_conn = build_conn(target)
      data = %{perform_id: "bingxin-jue/freeze", level: 150, ap: 150, rng: fn _ -> 500 end}

      assert incoming(target_conn, data).private.update_character == nil
    end
  end
end