defmodule Kantele.Combat.BeimingShengongTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BeimingShengong
  alias Kantele.Combat.Skills.BeimingShengong.Powerup
  alias Kantele.Combat.Skills.BeimingShengong.Suck

  @vitals %{Vitals.new() | neili: 500, max_neili: 500}
  @room "xiaoyao:hall"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "段誉",
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

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "鸠摩智",
      room_id: @room,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: %{Combat.new() | enemies: [%{id: "player-1", pid: self(), name: "段誉", room_id: @room}]}
      }
    }
  end

  defp attacker, do: %{id: "player-1", pid: self(), name: "段誉", room_id: @room}

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
    opts = Keyword.put_new(opts, :performs, MapSet.new(["beiming-shengong/#{move}"]))
    opts = Keyword.put_new(opts, :mapped, Keyword.get(opts, :mapped, %{"force" => "beiming-shengong"}))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  describe "北冥神功（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("beiming-shengong")
      assert Skills.get("beiming-shengong") == BeimingShengong
      assert BeimingShengong.valid_enable("force")
      refute BeimingShengong.valid_enable("sword")
    end

    test "valid_force 接受 xiaoyao-xinfa/xiaowuxiang/beiming-shengong" do
      assert BeimingShengong.valid_force("xiaoyao-xinfa")
      assert BeimingShengong.valid_force("xiaowuxiang")
      assert BeimingShengong.valid_force("beiming-shengong")
      refute BeimingShengong.valid_force("taixuan-gong")
    end

    test "exert_list 含 powerup/suck" do
      assert Map.has_key?(BeimingShengong.exert_list(), "powerup")
      assert Map.has_key?(BeimingShengong.exert_list(), "suck")
    end
  end

  describe "powerup（运功）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        perform(
          [
            skills: %{"beiming-shengong" => 120, "force" => 150},
            mapped: %{"force" => "beiming-shengong"},
            vitals: %{@vitals | neili: 500}
          ],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 40
      assert updated.meta.combat.temp.defense == 40
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "北冥神功运行完毕"
    end
  end

  describe "suck（吸星，攻击方门槛）" do
    test "等级不足被拒" do
      conn = perform([skills: %{"beiming-shengong" => 89, "force" => 150}, mapped: %{"force" => "beiming-shengong"}], "suck")
      assert output_text(conn) =~ "功力不够"
    end

    test "内力不足被拒" do
      conn = perform([skills: %{"beiming-shengong" => 90, "force" => 150}, mapped: %{"force" => "beiming-shengong"}, vitals: %{@vitals | neili: 10}], "suck")
      assert output_text(conn) =~ "内力不够"
    end

    test "持武器被拒" do
      target = enemy()
      combat = %{Combat.new() | enemies: [target], equipped: %{weapon: %{name: "剑", skill_type: "sword"}}}
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        combat: combat
      ))
      conn = perform([], "suck")
      assert output_text(conn) =~ "必须空手"
    end

    test "目标 max_neili 过低被拒" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 50})
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = perform([], "suck")
      assert output_text(conn) =~ "丹元涣散"
    end

    test "目标太弱被拒" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 50})
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        vitals: %{@vitals | max_neili: 500},
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = perform([], "suck")
      assert output_text(conn) =~ "远不如你"
    end

    test "目标是太玄功被拒" do
      target = enemy(skills: %{"force" => 150})
      target = %{target | meta: Map.put(target.meta.stats, :mapped, %{force: "taixuan-gong"})}
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = perform([], "suck")
      assert output_text(conn) =~ "太玄真气"
    end

    test "冷却中被拒" do
      target = enemy()
      combat = %{Combat.new() | enemies: [target], buffs: [%{key: "sucked", applies: %{}, duration: 10}]}
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        combat: combat
      ))
      conn = perform([], "suck")
      assert output_text(conn) =~ "刚刚吸取过"
    end

    test "成功放招投递目标侧事件" do
      target = enemy()
      conn = build_conn(build_character(
        skills: %{"beiming-shengong" => 90, "force" => 150},
        mapped: %{"force" => "beiming-shengong"},
        performs: MapSet.new(["beiming-shengong/suck"]),
        combat: %{Combat.new() | enemies: [target]}
      ))
      conn = perform([], "suck")
      assert published_text(conn) =~ "轻轻握在"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "beiming-shengong/suck", level: 90, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "suck（吸星，目标侧结算）" do
    test "命中：目标 max_neili 减少，攻击方回执 gain_max_neili" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300})
      target_conn = build_conn(target)
      data = %{perform_id: "beiming-shengong/suck", level: 90, rng: fn _ -> 200 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili < 300
      assert published_text(conn) =~ "丹元自手掌"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 10, gain_max_neili: amount}} = event
      assert amount > 0
    end

    test "等级差距大时吸收量递减" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 200})
      target_conn = build_conn(target)
      # 攻击者 max_neili 远高于目标
      attacker = %{attacker() | meta: %{vitals: %{Vitals.new() | max_neili: 1000}}}
      data = %{perform_id: "beiming-shengong/suck", level: 200, rng: fn _ -> 200 end}

      conn = incoming(target_conn, Map.put(data, :attacker, attacker))

      # 由于 my_max > tg_max + 100 等级差距大，吸收量会被减半多次
      assert conn.private.update_character.meta.vitals.max_neili < 200
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{gain_max_neili: amount}} = event
      # 200级时基础 sucked = 1 + (200-90)/10 = 12，经过多次减半后变小
      assert amount >= 0
    end

    test "失手：攻击方回执 busy 6，目标不动" do
      target = enemy(vitals: %{Vitals.new() | max_neili: 300}, skills: %{"force" => 500})
      target_conn = build_conn(target)
      data = %{perform_id: "beiming-shengong/suck", level: 90, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character.meta.vitals.max_neili == 300
      assert published_text(conn) =~ "看破了"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 10, busy: 6}}
    end
  end
end