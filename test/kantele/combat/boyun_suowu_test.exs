defmodule Kantele.Combat.BoyunSuowuTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BoyunSuowu
  alias Kantele.Combat.Skills.Performs.BoyunSuowu.Dian
  alias Kantele.Combat.Skills.Performs.BoyunSuowu.Meng

  @vitals %{Vitals.new() | neili: 2000, max_neili: 2000}
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

  defp hand_fighter(opts) do
    character = build_character(opts)
    combat = %{character.meta.combat | enemies: [enemy()]}
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp armed_fighter(opts) do
    character = build_character(opts)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, %{name: "钢刀", skill_type: "blade"})
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

  defp perform(opts, move, fighter \\ &hand_fighter/1) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["boyun-suowu/#{move}"]))
    PerformCommand.run(build_conn(fighter.(opts)), %{"action" => "boyun-suowu.#{move}"})
  end

  defp target(skills) do
    combat = %{Combat.new() | enemies: [enemy()]}
    build_character(skills: skills, combat: combat)
  end

  defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  describe "拨云锁雾（技能表）" do
    test "已注册且可 enable hand/dodge/parry" do
      assert Skills.known?("boyun-suowu")
      assert Skills.get("boyun-suowu") == BoyunSuowu
      assert BoyunSuowu.valid_enable("hand")
      assert BoyunSuowu.valid_enable("dodge")
      assert BoyunSuowu.valid_enable("parry")
      refute BoyunSuowu.valid_enable("sword")
    end

    test "perform_list 含两诀" do
      assert BoyunSuowu.perform_list() == %{"dian" => Dian, "meng" => Meng}
    end
  end

  describe "云雾暗点（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"boyun-suowu" => 100, "biyun-xinfa" => 100}, performs: MapSet.new()], "dian")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "持械被拒" do
      conn = perform([skills: %{"boyun-suowu" => 100, "biyun-xinfa" => 100}], "dian", &armed_fighter/1)
      assert output_text(conn) =~ "只能空手使用"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"boyun-suowu" => 99, "biyun-xinfa" => 100}], "dian")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "碧云心法不足被拒" do
      conn = perform([skills: %{"boyun-suowu" => 100, "biyun-xinfa" => 99}], "dian")
      assert output_text(conn) =~ "碧云心法不够熟练"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"boyun-suowu" => 100, "biyun-xinfa" => 100}, vitals: %{@vitals | neili: 799}],
          "dian"
        )

      assert output_text(conn) =~ "内力不够"
    end

    test "成功放招投递目标侧事件且带 ap" do
      conn =
        perform(
          [skills: %{"boyun-suowu" => 100, "biyun-xinfa" => 100, "hand" => 100}],
          "dian"
        )

      assert published_text(conn) =~ "破空而去"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "boyun-suowu/dian", ap: 300, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "云雾暗点（目标侧结算）" do
    test "命中：目标 busy ap/100+2，攻击方回执 -500" do
      data = %{perform_id: "boyun-suowu/dian", ap: 300, rng: fn _ -> 300 end}
      conn = incoming(build_conn(target(%{"dodge" => 0})), data)

      assert conn.private.update_character.meta.combat.busy == div(300, 100) + 2
      assert published_text(conn) =~ "不能动弹"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 500, busy: 0}}
    end

    test "失手：攻击方回执 -500，目标不动" do
      data = %{perform_id: "boyun-suowu/dian", ap: 300, rng: fn _ -> 1 end}
      conn = incoming(build_conn(target(%{"dodge" => 400})), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "侧身一让"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 500, busy: 0}}
    end

    test "目标忙乱则忽略" do
      character = target(%{"dodge" => 0})
      combat = %{character.meta.combat | busy: 2}
      character = %{character | meta: %{character.meta | combat: combat}}
      data = %{perform_id: "boyun-suowu/dian", ap: 300, rng: fn _ -> 300 end}

      assert incoming(build_conn(character), data).private.update_character == nil
      refute_receive %Kalevala.Event{topic: "combat/perform-feedback"}
    end
  end

  describe "回梦（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"boyun-suowu" => 140, "biyun-xinfa" => 130}, performs: MapSet.new()], "meng")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "持械被拒" do
      conn = perform([skills: %{"boyun-suowu" => 140, "biyun-xinfa" => 130}], "meng", &armed_fighter/1)
      assert output_text(conn) =~ "空手才能使用"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"boyun-suowu" => 139, "biyun-xinfa" => 130}], "meng")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "碧云心法不足被拒" do
      conn = perform([skills: %{"boyun-suowu" => 140, "biyun-xinfa" => 129}], "meng")
      assert output_text(conn) =~ "不够高"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"boyun-suowu" => 140, "biyun-xinfa" => 130}, vitals: %{@vitals | neili: 299}],
          "meng"
        )

      assert output_text(conn) =~ "内力太弱"
    end

    test "成功放招投递目标侧事件且带 ap" do
      conn = perform([skills: %{"boyun-suowu" => 140, "biyun-xinfa" => 130, "hand" => 220}], "meng")

      assert published_text(conn) =~ "意欲以内力震晕"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "boyun-suowu/meng", ap: 220, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "回梦（目标侧结算）" do
    test "命中：造成 qi/wound 伤害并回执 -300/2" do
      data = %{perform_id: "boyun-suowu/meng", ap: 220, rng: fn _ -> 220 end}
      conn = incoming(build_conn(target(%{"force" => 0})), data)

      assert conn.private.update_character.meta.vitals.qi < Vitals.new().qi
      assert conn.private.update_character.meta.vitals.max_qi < Vitals.new().max_qi
      assert published_text(conn) =~ "眼前一黑"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 300, busy: 2}}
    end

    test "失手：攻击方回执 0/3，目标不动" do
      data = %{perform_id: "boyun-suowu/meng", ap: 220, rng: fn _ -> 1 end}
      conn = incoming(build_conn(target(%{"force" => 400})), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "并没有上当"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 3}}
    end
  end
end