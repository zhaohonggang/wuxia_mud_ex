defmodule Kantele.Combat.SankuShengongTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SankuShengong
  alias Kantele.Combat.Skills.SankuShengong.Dispel
  alias Kantele.Combat.Skills.SankuShengong.Powerup
  alias Kantele.Combat.Skills.SankuShengong.Roar

  @vitals %{Vitals.new() | neili: 1000, max_neili: 1000, qi: 500, max_qi: 500}
  @room "test:room"

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

  defp target_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "target-1",
      name: "李四",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
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

  defp exert(opts, move) do
    conn = build_conn(build_character(opts))
    ExertCommand.run(conn, %{"function" => move})
  end

  describe "三苦神功（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("sanku-shengong")
      assert Skills.get("sanku-shengong") == SankuShengong
      assert SankuShengong.valid_enable("force")
      refute SankuShengong.valid_enable("sword")
    end

    test "exert_list 含 powerup/dispel/roar" do
      assert SankuShengong.exert_list() == %{
        "powerup" => Powerup,
        "dispel" => Dispel,
        "roar" => Roar
      }
    end
  end

  describe "powerup（自我增益）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        exert(
          [skills: %{"force" => 120}, mapped: %{"force" => "sanku-shengong"}, vitals: %{@vitals | neili: 500}],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 40
      assert updated.meta.combat.temp.defense == 40
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "轻烟缭绕周身"
    end

    test "neili<80 被拒" do
      conn = exert([skills: %{"force" => 120}, mapped: %{"force" => "sanku-shengong"}, vitals: %{@vitals | neili: 50}], "powerup")
      assert output_text(conn) =~ "你的内力不够"
    end

    test "已在运功中则拒绝" do
      character =
        build_character(
          skills: %{"force" => 120},
          mapped: %{"force" => "sanku-shengong"},
          vitals: %{@vitals | neili: 500}
        )

      combat = %{character.meta.combat | buffs: [%Combat.Buff{key: "powerup", applies: []}]}
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = ExertCommand.run(build_conn(character), %{"function" => "powerup"})
      assert output_text(conn) =~ "已经在运功中了"
    end
  end

  describe "dispel（排除异常·自我）" do
    test "neili<100 被拒" do
      conn = exert([skills: %{"force" => 100}, mapped: %{"force" => "sanku-shengong"}, vitals: %{@vitals | neili: 50}], "dispel")
      assert output_text(conn) =~ "内力不足"
    end

    test "清除自身 conditions" do
      character = build_character(
        skills: %{"force" => 100},
        mapped: %{"force" => "sanku-shengong"},
        vitals: %{@vitals | neili: 500}
      )

      conn =
        build_conn(character, %{"conditions" => %{"poison" => %{level: 10}}, "cond_applyer" => %{}})
        |> ExertCommand.run(%{"function" => "dispel"})

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert conn.session["conditions"] == nil
      assert published_text(conn) =~ "调息完毕"
    end

    test "busy 1~2 轮" do
      conn = exert([skills: %{"force" => 100}, mapped: %{"force" => "sanku-shengong"}, vitals: %{@vitals | neili: 500}], "dispel")
      busy = conn.private.update_character.meta.combat.busy
      assert busy >= 1 and busy <= 2
    end
  end

  describe "roar（碧云神吼·全房间 AoE）" do
    test "neili<500 或 skill<50 被拒" do
      conn =
        exert(
          [
            skills: %{"sanku-shengong" => 49, "force" => 100},
            mapped: %{"force" => "sanku-shengong"},
            vitals: %{@vitals | neili: 600}
          ],
          "roar"
        )
      assert output_text(conn) =~ "吓走了几只老鼠"
    end

    test "成功放招：扣 150 内力、受损 10 qi、busy 1、发 perform-incoming" do
      target =
        %Kalevala.Character{
          id: "mob-1",
          name: "李四",
          pid: self(),
          room_id: @room,
          meta: %Kantele.Character.NonPlayerMeta{
            vitals: %{@vitals | qi: 500},
            stats: struct(Stats.new(), %{"force" => 50}),
            combat: Combat.new()
          }
        }

      character = build_character(
        skills: %{"sanku-shengong" => 60, "force" => 100},
        mapped: %{"force" => "sanku-shengong"},
        vitals: %{@vitals | neili: 600, qi: 500},
        combat: %{Combat.new() | enemies: [target]}
      )

      conn = ExertCommand.run(build_conn(character), %{"function" => "roar"})

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 450
      assert updated.meta.vitals.qi == 490
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "巨吼"

      assert_receive %Kalevala.Event{topic: "combat/perform-incoming", data: %{perform_id: "sanku-shengong/roar"}}
    end
  end

  describe "roar（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "con 对抗成功：无伤害" do
      character = target_character(skills: %{"con" => 100}, vitals: %{@vitals | max_neili: 1000})
      data = %{perform_id: "sanku-shengong/roar", skill: 100, rng: fn _ -> 1 end}

      conn = incoming(build_conn(character), data)

      assert conn.private.update_character == nil
    end

    test "con 对抗失败：受 jing 伤害" do
      character = target_character(skills: %{"con" => 10}, vitals: %{@vitals | max_neili: 100, jing: 100})
      data = %{perform_id: "sanku-shengong/roar", skill: 100, rng: fn _ -> 100 end}

      conn = incoming(build_conn(character), data)

      updated = conn.private.update_character
      assert updated.meta.vitals.jing < 100
      assert published_text(conn) =~ "金星乱冒"
    end
  end
end