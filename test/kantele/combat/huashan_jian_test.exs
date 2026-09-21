defmodule Kantele.Combat.HuashanJianTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HuashanJian
  alias Kantele.Combat.Skills.Performs.HuashanJian.Jie

  @vitals Vitals.new()
  @room "huashan:yuntai"

  defp build_character(stats_overrides) do
    stats = struct(Stats.new(), stats_overrides)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: @vitals,
        stats: stats,
        combat: Combat.new()
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "野猪", room_id: @room}

  defp fighter(stats_overrides) do
    character = build_character(stats_overrides)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, %{name: "长剑", skill_type: "sword"})
      |> Map.put(:enemies, [enemy()])

    %{character | meta: %{character.meta | combat: combat}}
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

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "华山剑法（技能表）" do
    test "已注册且可 enable sword/parry" do
      assert Skills.known?("huashan-jian")
      assert Skills.get("huashan-jian") == HuashanJian
      assert HuashanJian.valid_enable("sword")
      assert HuashanJian.valid_enable("parry")
      refute HuashanJian.valid_enable("force")
    end

    test "perform_list 含截手式" do
      assert HuashanJian.perform_list() == %{
               "jie" => Jie,
               "lian" => Kantele.Combat.Skills.Performs.HuashanJian.Lian,
               "long" => Kantele.Combat.Skills.Performs.HuashanJian.Long,
               "xian" => Kantele.Combat.Skills.Performs.HuashanJian.Xian
             }
    end

    test "query_action 按等级取式且不超过上限" do
      assert HuashanJian.query_action(0, fn _ -> 1 end)["skill_name"] == "有凤来仪"

      action = HuashanJian.query_action(100, fn _ -> 1 end)
      assert action["lvl"] <= 100
      assert action["damage_type"] == "刺伤"
    end
  end

  describe "截手式（攻击方门槛）" do
    test "未学会被拒" do
      character = fighter(skills: %{"huashan-jian" => 60})

      conn =
        PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "不在战斗中/无目标被拒" do
      character =
        build_character(
          skills: %{"huashan-jian" => 60},
          performs: MapSet.new(["huashan-jian/jie"])
        )

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})
      assert output_text(conn) =~ "只能对战斗中的对手使用"
    end

    test "武器不对被拒" do
      character =
        build_character(
          skills: %{"huashan-jian" => 60},
          performs: MapSet.new(["huashan-jian/jie"])
        )

      combat =
        character.meta.combat
        |> Combat.equip(:weapon, %{name: "木棍", skill_type: "staff"})
        |> Map.put(:enemies, [enemy()])

      character = %{character | meta: %{character.meta | combat: combat}}

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})
      assert output_text(conn) =~ "武器不对"
    end

    test "等级不足被拒" do
      character = fighter(skills: %{"huashan-jian" => 29}, performs: MapSet.new(["huashan-jian/jie"]))

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})
      assert output_text(conn) =~ "不够娴熟"
    end

    test "未激发华山剑法被拒" do
      character = fighter(skills: %{"huashan-jian" => 60}, performs: MapSet.new(["huashan-jian/jie"]))

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})
      assert output_text(conn) =~ "没有激发华山剑法"
    end

    test "内力不足被拒" do
      character =
        fighter(
          skills: %{"huashan-jian" => 60},
          mapped: %{"sword" => "huashan-jian"},
          performs: MapSet.new(["huashan-jian/jie"])
        )

      character = put_in(character.meta.vitals.neili, 59)

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})
      assert output_text(conn) =~ "真气不够"
    end

    test "成功放招：扣 50 内力、放出主文案、投递目标侧事件" do
      character =
        fighter(
          skills: %{"huashan-jian" => 66},
          mapped: %{"sword" => "huashan-jian"},
          performs: MapSet.new(["huashan-jian/jie"])
        )

      conn = PerformCommand.run(build_conn(character), %{"action" => "huashan-jian.jie"})

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == @vitals.neili - 50
      assert published_text(conn) =~ "截手式"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "huashan-jian/jie", level: 66, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "截手式（目标侧结算）" do
    defp target(stats_overrides, combat_overrides \\ %{}) do
      character = build_character(stats_overrides)
      combat = struct(Combat.new(), combat_overrides)
      %{character | meta: %{character.meta | combat: %{combat | enemies: [enemy()]}}}
    end

    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "命中：目标忙乱 level/22+2 并出受击文案" do
      character = target(%{"parry" => 0})

      data = %{perform_id: "huashan-jian/jie", level: 220, rng: fn _ -> 220 end}

      conn = incoming(build_conn(character), data)

      updated = conn.private.update_character
      assert updated.meta.combat.busy == div(220, 22) + 2
      assert published_text(conn) =~ "瘁不及防"
    end

    test "失手（无兵器）：目标不忙乱，文案为拨打" do
      character = target(%{"parry" => 400})

      data = %{perform_id: "huashan-jian/jie", level: 220, rng: fn _ -> 1 end}

      conn = incoming(build_conn(character), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "双手戳点刺拍"
    end

    test "失手（有兵器）：文案指向目标兵器并可被招架" do
      character =
        target(%{"parry" => 400}, %{equipped: %{weapon: %{name: "钢刀", skill_type: "blade"}}})

      data = %{perform_id: "huashan-jian/jie", level: 220, rng: fn _ -> 1 end}

      conn = incoming(build_conn(character), data)

      assert published_text(conn) =~ "钢刀"
      assert published_text(conn) =~ "识破了"
    end

    test "死亡目标忽略" do
      character = target(%{"parry" => 0}, %{dead: true})
      data = %{perform_id: "huashan-jian/jie", level: 220, rng: fn _ -> 220 end}

      assert incoming(build_conn(character), data).private.update_character == nil
    end

    test "未知绝招忽略" do
      character = target(%{"parry" => 0})
      data = %{perform_id: "unknown/x", level: 220, rng: fn _ -> 220 end}

      assert incoming(build_conn(character), data).private.update_character == nil
    end
  end
end
