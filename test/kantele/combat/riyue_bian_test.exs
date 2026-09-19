defmodule Kantele.Combat.RiyueBianTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RiyueBian
  alias Kantele.Combat.Skills.Performs.RiyueBian.Chan
  alias Kantele.Combat.Skills.Performs.RiyueBian.He
  alias Kantele.Combat.Skills.Performs.RiyueBian.Shang

  @vitals %{Vitals.new() | neili: 600, max_neili: 600}
  @room "riyue:laowang"
  @whip %{name: "软鞭", skill_type: "whip"}

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

  defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  defp fighter(opts, skill_type) do
    character = build_character(opts)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, Map.put(@whip, :skill_type, skill_type))
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

  defp perform(opts, move, skill_type \\ "whip") do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["riyue-bian/#{move}"]))
    PerformCommand.run(build_conn(fighter(opts, skill_type)), %{"action" => "riyue-bian.#{move}"})
  end

  describe "日月鞭法（技能表）" do
    test "已注册且可 enable whip/parry" do
      assert Skills.known?("riyue-bian")
      assert Skills.get("riyue-bian") == RiyueBian
      assert RiyueBian.valid_enable("whip")
      assert RiyueBian.valid_enable("parry")
      refute RiyueBian.valid_enable("sword")
    end

    test "perform_list 含三诀" do
      assert RiyueBian.perform_list() == %{"chan" => Chan, "he" => He, "shang" => Shang}
    end
  end

  describe "缠绕「chan」（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"whip" => 100, "riyue-bian" => 100}, performs: MapSet.new()], "chan")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "无目标被拒" do
      character =
        build_character(
          skills: %{"whip" => 100, "riyue-bian" => 100},
          combat: Combat.new(),
          performs: MapSet.new(["riyue-bian/chan"])
        )

      character = %{character | meta: %{character.meta | combat: Combat.equip(Combat.new(), :weapon, @whip)}}
      conn = PerformCommand.run(build_conn(character), %{"action" => "riyue-bian.chan"})
      assert output_text(conn) =~ "只能对战斗中的对手使用"
    end

    test "武器不对被拒" do
      conn = perform([skills: %{"whip" => 100, "riyue-bian" => 100}, mapped: %{"whip" => "riyue-bian"}], "chan", "sword")
      assert output_text(conn) =~ "没有拿着鞭子"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"whip" => 100, "riyue-bian" => 100}, mapped: %{"whip" => "riyue-bian"}, vitals: %{@vitals | neili: 79}],
          "chan"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"whip" => 100, "riyue-bian" => 100}], "chan")
      assert output_text(conn) =~ "没有激发日月鞭法"
    end

    test "成功放招投递目标侧事件" do
      conn = perform([skills: %{"whip" => 100, "riyue-bian" => 100}, mapped: %{"whip" => "riyue-bian"}], "chan")
      assert published_text(conn) =~ "缠绕"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "riyue-bian/chan", ap: 200, level: 100, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "缠绕「chan」（目标侧结算）" do
    defp target(skills) do
      combat = %{Combat.new() | enemies: [enemy()]}
      build_character(skills: skills, combat: combat)
    end

    test "命中：目标 busy level/20+2，攻击方回执 -0/1" do
      data = %{perform_id: "riyue-bian/chan", ap: 200, level: 100, rng: fn _ -> 200 end}
      conn = incoming(build_conn(target(%{"parry" => 0})), data)

      assert conn.private.update_character.meta.combat.busy == div(100, 20) + 2
      assert published_text(conn) =~ "措手不及"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 1}}
    end

    test "失手：攻击方回执 -0/2，目标不动" do
      data = %{perform_id: "riyue-bian/chan", ap: 60, level: 100, rng: fn _ -> 1 end}
      conn = incoming(build_conn(target(%{"parry" => 400})), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "看破了"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 2}}
    end

    test "目标忙乱则忽略" do
      character = target(%{"parry" => 0})
      combat = %{character.meta.combat | busy: 2}
      character = %{character | meta: %{character.meta | combat: combat}}
      data = %{perform_id: "riyue-bian/chan", ap: 200, level: 100, rng: fn _ -> 200 end}

      assert incoming(build_conn(character), data).private.update_character == nil
    end
  end

  describe "合字诀「he」（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"whip" => 120, "riyue-bian" => 120}, performs: MapSet.new()], "he")
      assert output_text(conn) =~ "受过高人指点"
    end

    test "武器不对被拒" do
      conn = perform([skills: %{"whip" => 120, "riyue-bian" => 120}, mapped: %{"whip" => "riyue-bian"}], "he", "sword")
      assert output_text(conn) =~ "武器不对"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"whip" => 119, "riyue-bian" => 119}, mapped: %{"whip" => "riyue-bian"}], "he")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"whip" => 120, "riyue-bian" => 120}, mapped: %{"whip" => "riyue-bian"}, vitals: %{@vitals | neili: 349}],
          "he"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"whip" => 120, "riyue-bian" => 120}], "he")
      assert output_text(conn) =~ "没有激发日月鞭法"
    end

    test "成功放招投递目标侧事件" do
      conn = perform([skills: %{"whip" => 120, "riyue-bian" => 120}, mapped: %{"whip" => "riyue-bian"}], "he")
      assert published_text(conn) =~ "漫天鞭影"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "riyue-bian/he", ap: 240, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "合字诀「he」（目标侧结算）" do
    test "命中：折算合计伤害、回执 -attack_time*20 / busy" do
      character = build_character(skills: %{"parry" => 0})
      data = %{perform_id: "riyue-bian/he", ap: 240, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      updated = conn.private.update_character
      assert updated.meta.vitals.qi < Vitals.new().qi
      assert published_text(conn) =~ "疲于奔命"
      # attack_time = 5 + random(240/45)=0 → 5*20=100，busy = 1+random(5)=1
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 1}}
    end

    test "失手：仍按 attack_time=5 折算伤害，文案凝神应付" do
      character = build_character(skills: %{"parry" => 1000})
      data = %{perform_id: "riyue-bian/he", ap: 240, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      assert conn.private.update_character.meta.vitals.qi < Vitals.new().qi
      assert published_text(conn) =~ "凝神应付"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 1}}
    end
  end

  describe "伤字诀「shang」（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"whip" => 180, "force" => 300, "riyue-bian" => 180}, performs: MapSet.new()], "shang")
      assert output_text(conn) =~ "受过高人指点"
    end

    test "武器不对被拒" do
      conn =
        perform(
          [skills: %{"whip" => 180, "force" => 300, "riyue-bian" => 180}, mapped: %{"whip" => "riyue-bian"}],
          "shang",
          "sword"
        )

      assert output_text(conn) =~ "武器不对"
    end

    test "内功不足被拒" do
      conn =
        perform(
          [skills: %{"whip" => 180, "force" => 299, "riyue-bian" => 180}, mapped: %{"whip" => "riyue-bian"}],
          "shang"
        )

      assert output_text(conn) =~ "内功的修为不够"
    end

    test "日月鞭法不足被拒" do
      conn =
        perform(
          [skills: %{"whip" => 179, "force" => 300, "riyue-bian" => 179}, mapped: %{"whip" => "riyue-bian"}],
          "shang"
        )

      assert output_text(conn) =~ "修为不够"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [
            skills: %{"whip" => 180, "force" => 300, "riyue-bian" => 180},
            mapped: %{"whip" => "riyue-bian"},
            vitals: %{@vitals | neili: 399}
          ],
          "shang"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "未激发被拒" do
      conn = perform([skills: %{"whip" => 180, "force" => 300, "riyue-bian" => 180}], "shang")
      assert output_text(conn) =~ "没有激发日月鞭法"
    end

    test "成功放招投递目标侧事件" do
      conn =
        perform(
          [skills: %{"whip" => 180, "force" => 300, "riyue-bian" => 180}, mapped: %{"whip" => "riyue-bian"}],
          "shang"
        )

      assert published_text(conn) =~ "飞刺向"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "riyue-bian/shang", ap: 660, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "伤字诀「shang」（目标侧结算）" do
    test "命中：折算合计伤害、回执 -300 / busy 1" do
      character = build_character(skills: %{"force" => 0, "parry" => 0})
      data = %{perform_id: "riyue-bian/shang", ap: 660, rng: fn _ -> 1 end, weapon_name: "软鞭"}
      conn = incoming(build_conn(character), data)

      assert conn.private.update_character.meta.vitals.qi == 0
      assert published_text(conn) =~ "鲜血飞溅"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 300, busy: 1}}
    end

    test "失手：目标不动、回执 -100 / busy 3" do
      character = build_character(skills: %{"force" => 1000, "parry" => 1000})
      data = %{perform_id: "riyue-bian/shang", ap: 660, rng: fn _ -> 1 end}
      conn = incoming(build_conn(character), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "运足内力"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 3}}
    end
  end
end