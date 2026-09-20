defmodule Kantele.Combat.XixingDafaTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.XixingDafa
  alias Kantele.Combat.Skills.XixingDafa.Powerup
  alias Kantele.Combat.Skills.XixingDafa.Suck
  alias Kantele.Combat.Skills.XixingDafa.Sangong

  @vitals %{Vitals.new() | neili: 500, max_neili: 500}
  @room "xingxiu:hall"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "丁春秋",
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
    vitals = Keyword.get(opts, :vitals, %{Vitals.new() | neili: 200, max_neili: 200})
    skills = Keyword.get(opts, :skills, %{"force" => 150})
    stats = struct(Stats.new(), skills: skills)
    combat = Keyword.get(opts, :combat, %{Combat.new() | enemies: [%{id: "player-1", pid: self(), name: "丁春秋", room_id: @room}]})

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "童姥",
      room_id: @room,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp attacker, do: %{id: "player-1", pid: self(), name: "丁春秋", room_id: @room}

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
    opts = Keyword.put_new(opts, :performs, MapSet.new(["xixing-dafa/#{move}"]))
    opts = Keyword.put_new(opts, :mapped, Keyword.get(opts, :mapped, %{"force" => "xixing-dafa"}))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  describe "吸星大法（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("xixing-dafa")
      assert Skills.get("xixing-dafa") == XixingDafa
      assert XixingDafa.valid_enable("force")
      refute XixingDafa.valid_enable("sword")
    end

    test "exert_list 含 powerup/suck/sangong" do
      assert Map.has_key?(XixingDafa.exert_list(), "powerup")
      assert Map.has_key?(XixingDafa.exert_list(), "suck")
      assert Map.has_key?(XixingDafa.exert_list(), "sangong")
    end
  end

  describe "powerup（运功）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        perform(
          [
            skills: %{"xixing-dafa" => 200, "force" => 150},
            mapped: %{"force" => "xixing-dafa"},
            vitals: %{@vitals | neili: 500}
          ],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 66
      assert updated.meta.combat.temp.defense == 66
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "真气蒸腾"
    end

    test "内力不足被拒" do
      conn = perform([skills: %{"xixing-dafa" => 200}, mapped: %{"force" => "xixing-dafa"}, vitals: %{@vitals | neili: 50}], "powerup")
      assert output_text(conn) =~ "内力不够"
    end
  end

  describe "suck（吸星，攻击方门槛）" do
    test "等级不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"xixing-dafa" => 199, "force" => 150},
          mapped: %{"force" => "xixing-dafa"},
          performs: MapSet.new(["xixing-dafa/suck"]),
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "尚未大成"
    end

    test "内力不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"xixing-dafa" => 200, "force" => 150},
          mapped: %{"force" => "xixing-dafa"},
          performs: MapSet.new(["xixing-dafa/suck"]),
          vitals: %{@vitals | neili: 50},
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "内力不够"
    end

    test "无战斗目标被拒" do
      conn =
        build_conn(build_character(
          skills: %{"xixing-dafa" => 200, "force" => 150},
          mapped: %{"force" => "xixing-dafa"},
          performs: MapSet.new(["xixing-dafa/suck"]),
          combat: Combat.new()
        ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "只能吸取战斗中的对手"
    end

    test "目标 max_neili 过低被拒" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 50})
      conn = build_conn(build_character(
        skills: %{"xixing-dafa" => 200, "force" => 150},
        mapped: %{"force" => "xixing-dafa"},
        performs: MapSet.new(["xixing-dafa/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "丹元涣散"
    end

    test "目标太弱被拒" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 150}, skills: %{"force" => 150})
      conn = build_conn(build_character(
        skills: %{"xixing-dafa" => 200, "force" => 150},
        mapped: %{"force" => "xixing-dafa"},
        performs: MapSet.new(["xixing-dafa/suck"]),
        vitals: %{@vitals | max_neili: 5000},
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "远不如你"
    end

    test "目标是太玄功被拒" do
      target = enemy(skills: %{"force" => 150})
      target = %{target | meta: %{target.meta | stats: Map.put(target.meta.stats, :mapped, %{"force" => "taixuan-gong"})}}
      conn = build_conn(build_character(
        skills: %{"xixing-dafa" => 200, "force" => 150},
        mapped: %{"force" => "xixing-dafa"},
        performs: MapSet.new(["xixing-dafa/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "太玄真气"
    end

    test "冷却中被拒" do
      target = enemy()
      combat = %{Combat.new() | enemies: [target], buffs: [%{key: "sucked", applies: %{}, duration: 10}]}
      conn = build_conn(build_character(
        skills: %{"xixing-dafa" => 200, "force" => 150},
        mapped: %{"force" => "xixing-dafa"},
        performs: MapSet.new(["xixing-dafa/suck"]),
        combat: combat
      ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert output_text(conn) =~ "刚刚吸取过"
    end

    test "成功放招投递目标侧事件" do
      target = enemy()
      conn = build_conn(build_character(
        skills: %{"xixing-dafa" => 200, "force" => 150},
        mapped: %{"force" => "xixing-dafa"},
        performs: MapSet.new(["xixing-dafa/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "suck"})
      assert published_text(conn) =~ "探出右手"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "xixing-dafa/suck", level: 200, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "suck（吸星，目标侧结算）" do
    test "命中：目标 max_neili 减少，攻击方回执 gain_max_neili" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300})
      target_conn = build_conn(target)
      data = %{perform_id: "xixing-dafa/suck", level: 200, attacker_force: 200, rng: fn _ -> 200 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili == 291
      assert published_text(conn) =~ "丹元自手掌"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 10, gain_max_neili: 9}}
    end

    test "失手：攻击方回执 busy 7，目标不动" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300}, skills: %{"force" => 500})
      target_conn = build_conn(target)
      data = %{perform_id: "xixing-dafa/suck", level: 200, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili == 300
      assert published_text(conn) =~ "看破了"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 10, busy: 7}}
    end

    test "目标已死则忽略" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300, qi: 0}, combat: %{Combat.new() | dead: true})
      target_conn = build_conn(target)
      data = %{perform_id: "xixing-dafa/suck", level: 200, rng: fn _ -> 200 end}

      assert incoming(target_conn, data).private.update_character == nil
    end
  end

  describe "sangong（散功，自我）" do
    test "扣 1 max_neili" do
      conn = perform([skills: %{"xixing-dafa" => 200}, mapped: %{"force" => "xixing-dafa"}, vitals: %{@vitals | max_neili: 500}], "sangong")
      updated = conn.private.update_character
      assert updated.meta.vitals.max_neili == 499
      assert published_text(conn) =~ "散入奇经八脉"
    end

    test "max_neili 已为 0 时被拒" do
      conn = perform([skills: %{"xixing-dafa" => 200}, mapped: %{"force" => "xixing-dafa"}, vitals: %{@vitals | max_neili: 0}], "sangong")
      assert output_text(conn) =~ "已经将内力散尽"
    end
  end
end