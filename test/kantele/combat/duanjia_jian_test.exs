defmodule Kantele.Combat.DuanjiaJianTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DuanjiaJian
  alias Kantele.Combat.Skills.Performs.DuanjiaJian.Jing
  alias Kantele.Combat.Skills.Performs.DuanjiaJian.Lian

  @vitals %{Vitals.new() | neili: 200, max_neili: 200}
  @room "dali:longquanmiao"

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

  defp fighter(opts, skill_type) do
    character = build_character(opts)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, %{name: "长剑", skill_type: skill_type})
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

  defp perform(opts, move, skill_type \\ "sword") do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["duanjia-jian/#{move}"]))
    PerformCommand.run(build_conn(fighter(opts, skill_type)), %{"action" => "duanjia-jian.#{move}"})
  end

  describe "段家剑法（技能表）" do
    test "已注册且可 enable sword/staff" do
      assert Skills.known?("duanjia-jian")
      assert Skills.get("duanjia-jian") == DuanjiaJian
      assert DuanjiaJian.valid_enable("sword")
      assert DuanjiaJian.valid_enable("staff")
      refute DuanjiaJian.valid_enable("blade")
    end

    test "perform_list 含二绝招" do
      assert DuanjiaJian.perform_list() == %{"lian" => Lian, "jing" => Jing}
    end
  end

  describe "五绝连环（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"duanjia-jian" => 120}, performs: MapSet.new()], "lian")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "武器不对被拒" do
      conn =
        perform(
          [skills: %{"duanjia-jian" => 120}, mapped: %{"sword" => "duanjia-jian"}],
          "lian",
          "blade"
        )

      assert output_text(conn) =~ "武器不对"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"duanjia-jian" => 119}, mapped: %{"sword" => "duanjia-jian"}], "lian")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"duanjia-jian" => 120}], "lian")
      assert output_text(conn) =~ "没有激发段家剑"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [
            skills: %{"duanjia-jian" => 120, "force" => 150},
            mapped: %{"sword" => "duanjia-jian"},
            vitals: %{@vitals | neili: 299}
          ],
          "lian"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "成功放招投递目标侧事件" do
      conn =
        perform(
          [
            skills: %{"duanjia-jian" => 120, "force" => 150},
            mapped: %{"sword" => "duanjia-jian"},
            vitals: %{@vitals | neili: 500}
          ],
          "lian"
        )

      assert published_text(conn) =~ "飞龙一般"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "duanjia-jian/lian", level: 120, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "五绝连环（目标侧结算）" do
    defp target(skills) do
      combat = %{Combat.new() | enemies: [enemy()]}
      build_character(skills: skills, combat: combat)
    end

    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "命中：五击全中伤敌，目标忙乱 1，攻击方回执 -100/1" do
      conn = incoming(build_conn(target(%{"dodge" => 0})), %{
        perform_id: "duanjia-jian/lian",
        level: 120,
        rng: fn _ -> 1 end
      })

      updated = conn.private.update_character
      # per_hit = div(120,15) == 8；5 击全中，每击 8+random(8)=8
      assert updated.meta.vitals.qi == Vitals.new().qi - 40
      # 首击 random(5)==0 → 目标忙乱 1
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "节节败退"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 1}}
    end

    test "失手：目标不动，攻击方回执 -100/3" do
      conn = incoming(build_conn(target(%{"dodge" => 400})), %{
        perform_id: "duanjia-jian/lian",
        level: 120,
        rng: fn _ -> 3 end
      })

      updated = conn.private.update_character
      assert updated.meta.vitals.qi == Vitals.new().qi
      assert updated.meta.combat.busy == 0
      assert published_text(conn) =~ "左闪右避"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 3}}
    end
  end

  describe "惊天一剑（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"duanjia-jian" => 80}, performs: MapSet.new()], "jing")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "武器不对被拒" do
      conn =
        perform(
          [skills: %{"duanjia-jian" => 80}, mapped: %{"sword" => "duanjia-jian"}],
          "jing",
          "staff"
        )

      assert output_text(conn) =~ "武器不对"
    end

    test "等级不足被拒" do
      conn =
        perform(
          [skills: %{"duanjia-jian" => 79}, mapped: %{"sword" => "duanjia-jian"}],
          "jing"
        )

      assert output_text(conn) =~ "不够娴熟"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"duanjia-jian" => 80}], "jing")
      assert output_text(conn) =~ "没有激发段家剑"
    end

    test "内功不足被拒" do
      conn =
        perform(
          [
            skills: %{"duanjia-jian" => 80, "force" => 119},
            mapped: %{"sword" => "duanjia-jian"},
            vitals: %{@vitals | neili: 500}
          ],
          "jing"
        )

      assert output_text(conn) =~ "内功修为"
    end

    test "真气不足被拒" do
      conn =
        perform(
          [
            skills: %{"duanjia-jian" => 80, "force" => 120},
            mapped: %{"sword" => "duanjia-jian"},
            vitals: %{@vitals | neili: 299}
          ],
          "jing"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "成功放招投递目标侧事件并带 force/sword" do
      conn =
        perform(
          [
            skills: %{"duanjia-jian" => 80, "force" => 120, "sword" => 60},
            mapped: %{"sword" => "duanjia-jian"},
            vitals: %{@vitals | neili: 500}
          ],
          "jing"
        )

      assert published_text(conn) =~ "一跃而起"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{
          perform_id: "duanjia-jian/jing",
          level: 80,
          force: 120,
          sword: 60,
          attacker: %{id: "player-1"}
        }
      }
    end
  end

  describe "惊天一剑（目标侧结算）" do
    test "命中：造成伤害并回执扣内力" do
      conn = incoming(build_conn(target(%{"force" => 0})), %{
        perform_id: "duanjia-jian/jing",
        force: 300,
        sword: 60,
        rng: & &1
      })

      updated = conn.private.update_character
      # damage = div(360,5)=72 + random(72)=71 → 143；创伤 div(143,2)=71
      assert updated.meta.vitals.qi == max(Vitals.new().qi - 143, 0)
      assert updated.meta.vitals.max_qi < Vitals.new().max_qi
      assert published_text(conn) =~ "人剑合一"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 143, busy: 2}}
    end

    test "失手：目标不动，攻击方回执 -100/3" do
      conn = incoming(build_conn(target(%{"force" => 400})), %{
        perform_id: "duanjia-jian/jing",
        force: 300,
        sword: 60,
        rng: fn _ -> 1 end
      })

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "跳出了"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 3}}
    end
  end
end