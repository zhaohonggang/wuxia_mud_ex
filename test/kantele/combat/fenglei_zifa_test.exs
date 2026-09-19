defmodule Kantele.Combat.FengleiZifaTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.FengleiZifa
  alias Kantele.Combat.Skills.Performs.FengleiZifa.She

  @vitals %{Vitals.new() | neili: 500, max_neili: 500}
  @room "gaibang:yard"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      inventory: Keyword.get(opts, :inventory, []),
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "恶犬", room_id: @room}

  defp dart(amount \\ 3) do
    %{name: "铁蒺藜", handing: true, meta: %{skill_type: "throwing", amount: amount, base_unit: "枚"}}
  end

  defp thrower(opts) do
    inventory = Keyword.get(opts, :inventory, [dart()])
    character = build_character(Keyword.put(opts, :inventory, inventory))
    combat = %{character.meta.combat | enemies: [enemy()]}
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

  defp perform(opts, move) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["fenglei-zifa/#{move}"]))
    PerformCommand.run(build_conn(thrower(opts)), %{"action" => "fenglei-zifa.#{move}"})
  end

  describe "风雷子法（技能表）" do
    test "已注册且可 enable throwing" do
      assert Skills.known?("fenglei-zifa")
      assert Skills.get("fenglei-zifa") == FengleiZifa
      assert FengleiZifa.valid_enable("throwing")
      refute FengleiZifa.valid_enable("sword")
    end

    test "perform_list 含射日诀" do
      assert FengleiZifa.perform_list() == %{"she" => She}
    end
  end

  describe "射日诀（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"fenglei-zifa" => 100}, performs: MapSet.new()], "she")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "未持暗器被拒" do
      conn = perform([skills: %{"fenglei-zifa" => 100}, inventory: []], "she")
      assert output_text(conn) =~ "并没有拿着暗器"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"fenglei-zifa" => 99}], "she")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"fenglei-zifa" => 100}, vitals: %{@vitals | neili: 99}],
          "she"
        )

      assert output_text(conn) =~ "内力不足"
    end

    test "成功消耗暗器并投递目标侧事件" do
      conn = perform([skills: %{"fenglei-zifa" => 100}, inventory: [dart(2)]], "she")

      [updated] = Enum.filter([conn.private.update_character], & &1)
      assert [%{name: "铁蒺藜", meta: %{amount: 1}}] = updated.inventory
      assert published_text(conn) =~ "射向"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "fenglei-zifa/she", skill: 100, attacker: %{id: "player-1"}}
      }
    end

    test "暗器耗尽后自背包移除" do
      conn = perform([skills: %{"fenglei-zifa" => 100}, inventory: [dart(1)]], "she")
      assert [updated] = Enum.filter([conn.private.update_character], & &1)
      assert updated.inventory == []
    end
  end

  describe "射日诀（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(character, data) do
      CombatEvent.perform_incoming(build_conn(character), %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "命中：造成创伤并回执 -80/2" do
      character = build_character(skills: %{"dodge" => 400})

      data = %{perform_id: "fenglei-zifa/she", skill: 100, combat_exp: 1000, rng: fn _ -> 700 end}
      conn = incoming(character, data)

      assert conn.private.update_character.meta.vitals.max_qi < Vitals.new().max_qi
      assert published_text(conn) =~ "闪避不及"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 80, busy: 2}}
    end

    test "失手：回执 -80/2，目标不动" do
      character = build_character(skills: %{"dodge" => 400})

      data = %{perform_id: "fenglei-zifa/she", skill: 1, combat_exp: 0, rng: fn _ -> 1 end}
      conn = incoming(character, data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "轻轻一纵"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 80, busy: 2}}
    end
  end
end