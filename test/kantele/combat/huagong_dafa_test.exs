defmodule Kantele.Combat.HuagongDafaTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HuagongDafa
  alias Kantele.Combat.Skills.HuagongDafa.Powerup
  alias Kantele.Combat.Skills.HuagongDafa.Hua

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
    skills = Keyword.get(opts, :skills, %{"force" => 150, "dodge" => 100})
    stats = struct(Stats.new(), skills: skills)

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "童姥",
      room_id: @room,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: %{Combat.new() | enemies: [%{id: "player-1", pid: self(), name: "丁春秋", room_id: @room}]}
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
    opts = Keyword.put_new(opts, :performs, MapSet.new(["huagong-dafa/#{move}"]))
    opts = Keyword.put_new(opts, :mapped, Keyword.get(opts, :mapped, %{"force" => "huagong-dafa"}))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  describe "化功大法（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("huagong-dafa")
      assert Skills.get("huagong-dafa") == HuagongDafa
      assert HuagongDafa.valid_enable("force")
      refute HuagongDafa.valid_enable("sword")
    end

    test "valid_force 接受 guixi-gong" do
      assert HuagongDafa.valid_force("guixi-gong")
      refute HuagongDafa.valid_force("beiming-shengong")
    end

    test "exert_list 含 powerup/hua" do
      assert Map.has_key?(HuagongDafa.exert_list(), "powerup")
      assert Map.has_key?(HuagongDafa.exert_list(), "hua")
    end
  end

  describe "powerup（运功）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        perform(
          [
            skills: %{"huagong-dafa" => 120, "force" => 150},
            mapped: %{"force" => "huagong-dafa"},
            vitals: %{@vitals | neili: 500}
          ],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 40
      assert updated.meta.combat.temp.dodge == 40
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "萤萤绿光"
    end
  end

  describe "hua（化功，攻击方门槛）" do
    test "等级不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"huagong-dafa" => 99, "force" => 150},
          mapped: %{"force" => "huagong-dafa"},
          performs: MapSet.new(["huagong-dafa/hua"]),
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "功力不够"
    end

    test "内力不足被拒" do
      conn =
        build_conn(build_character(
          skills: %{"huagong-dafa" => 100, "force" => 150},
          mapped: %{"force" => "huagong-dafa"},
          performs: MapSet.new(["huagong-dafa/hua"]),
          vitals: %{@vitals | neili: 50},
          combat: %{Combat.new() | enemies: [enemy()]}
        ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "内力不够"
    end

    test "持武器被拒" do
      target = enemy()
      combat = %{Combat.new() | enemies: [target], equipped: %{weapon: %{name: "剑", skill_type: "sword"}}}
      conn = build_conn(build_character(
        skills: %{"huagong-dafa" => 100, "force" => 150},
        mapped: %{"force" => "huagong-dafa"},
        performs: MapSet.new(["huagong-dafa/hua"]),
        combat: combat
      ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "必须空手"
    end

    test "目标 neili 过低被拒" do
      target = enemy(vitals: %{Vitals.new() | neili: 5, max_neili: 200})
      conn = build_conn(build_character(
        skills: %{"huagong-dafa" => 100, "force" => 150},
        mapped: %{"force" => "huagong-dafa"},
        performs: MapSet.new(["huagong-dafa/hua"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "内力涣散"
    end

    test "目标 max_neili 过高被拒" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 800})
      conn = build_conn(build_character(
        skills: %{"huagong-dafa" => 100, "force" => 150},
        mapped: %{"force" => "huagong-dafa"},
        performs: MapSet.new(["huagong-dafa/hua"]),
        vitals: %{@vitals | max_neili: 500},
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "远胜于你"
    end

    test "目标是太玄功被拒" do
      target = enemy(skills: %{"force" => 150, "dodge" => 100})
      target = %{target | meta: %{target.meta | stats: Map.put(target.meta.stats, :mapped, %{"force" => "taixuan-gong"})}}
      conn = build_conn(build_character(
        skills: %{"huagong-dafa" => 100, "force" => 150},
        mapped: %{"force" => "huagong-dafa"},
        performs: MapSet.new(["huagong-dafa/hua"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert output_text(conn) =~ "太玄真气"
    end

    test "成功放招投递目标侧事件" do
      target = enemy()
      conn = build_conn(build_character(
        skills: %{"huagong-dafa" => 100, "force" => 150},
        mapped: %{"force" => "huagong-dafa"},
        performs: MapSet.new(["huagong-dafa/hua"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = ExertCommand.run(conn, %{"function" => "hua"})
      assert published_text(conn) =~ "全身骨节爆响"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "huagong-dafa/hua", level: 100, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "hua（化功，目标侧结算）" do
    test "命中：目标 max_neili 减少，攻击方回执 gain_max_neili" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300, neili: 200})
      target_conn = build_conn(target)
      data = %{perform_id: "huagong-dafa/hua", level: 100, attacker_force: 200, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili < 300
      assert published_text(conn) =~ "丹元自手掌"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, gain_max_neili: amount}} = event
      assert amount > 0
    end

    test "失手：攻击方回执 busy，目标不动" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300, neili: 200}, skills: %{"force" => 500, "dodge" => 500})
      target_conn = build_conn(target)
      data = %{perform_id: "huagong-dafa/hua", level: 100, rng: fn _ -> 500 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili == 300
      assert published_text(conn) =~ "看破了"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: busy}} = event
      assert busy >= 2
    end
  end
end