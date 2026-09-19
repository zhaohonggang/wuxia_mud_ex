defmodule Kantele.Combat.FurongJinzhenTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.FurongJinzhen
  alias Kantele.Combat.Skills.Performs.FurongJinzhen.Xian

  @vitals %{Vitals.new() | neili: 500, max_neili: 500}
  @room "emei:jinding"
  @du %Kalevala.World.Item.Instance{
    id: "du-1",
    item_id: "feizhen",
    meta: %{handing: true, skill_type: "throwing", amount: 10, name: "飞针", unit: "枚"}
  }

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      inventory: Keyword.get(opts, :inventory, [@du]),
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "恶犬", room_id: @room}

  defp fighter(opts, inventory) do
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

  defp perform(opts, inventory \\ [@du]) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["furong-jinzhen/xian"]))
    PerformCommand.run(build_conn(fighter(opts, inventory)), %{"action" => "furong-jinzhen.xian"})
  end

  describe "芙蓉金针（技能表）" do
    test "已注册且可 enable throwing" do
      assert Skills.known?("furong-jinzhen")
      assert Skills.get("furong-jinzhen") == FurongJinzhen
      assert FurongJinzhen.valid_enable("throwing")
      refute FurongJinzhen.valid_enable("sword")
    end

    test "perform_list 含金针现影" do
      assert FurongJinzhen.perform_list() == %{"xian" => Xian}
    end
  end

  describe "金针现影（攻击方门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 120}, performs: MapSet.new()])
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "无目标被拒" do
      character =
        build_character(
          skills: %{"furong-jinzhen" => 80, "force" => 120},
          performs: MapSet.new(["furong-jinzhen/xian"])
        )

      conn = PerformCommand.run(build_conn(character), %{"action" => "furong-jinzhen.xian"})
      assert output_text(conn) =~ "只能在战斗中对对手使用"
    end

    test "手中没有暗器被拒" do
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 120}], [])
      assert output_text(conn) =~ "手中并没有拿着暗器"
    end

    test "暗器类型不对被拒" do
      du = %{@du | meta: %{@du.meta | skill_type: "sword"}}
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 120}], [du])
      assert output_text(conn) =~ "手中并没有拿着暗器"
    end

    test "暗器用尽被拒" do
      du = %{@du | meta: %{@du.meta | amount: 0}}
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 120}], [du])
      assert output_text(conn) =~ "手中并没有拿着暗器"
    end

    test "芙蓉金针不足被拒" do
      conn = perform([skills: %{"furong-jinzhen" => 79, "force" => 120}])
      assert output_text(conn) =~ "芙蓉金针不够娴熟"
    end

    test "内功不足被拒" do
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 119}])
      assert output_text(conn) =~ "内功火候不够"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"furong-jinzhen" => 80, "force" => 120}, vitals: %{@vitals | neili: 149}]
        )

      assert output_text(conn) =~ "内力不够"
    end

    test "成功放招投递目标侧事件并扣暗器数量" do
      conn =
        perform([
          skills: %{"furong-jinzhen" => 80, "force" => 120, "throwing" => 60, "dodge" => 40}
        ])

      assert published_text(conn) =~ "金光一闪"
      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{
          perform_id: "furong-jinzhen/xian",
          ap: 180,
          level: 80,
          weapon_name: "飞针",
          unit: "枚",
          attacker: %{id: "player-1"}
        }
      }

      du = Enum.find(conn.private.update_character.inventory, &(&1.id == @du.id))
      assert du.meta.amount == 9
    end

    test "暗器数量为 1 时施放后脱手" do
      du = %{@du | meta: %{@du.meta | amount: 1}}
      conn = perform([skills: %{"furong-jinzhen" => 80, "force" => 120}], [du])
      assert conn.private.update_character.inventory == []
    end
  end

  describe "金针现影（目标侧结算）" do
    defp target(skills) do
      combat = %{Combat.new() | enemies: [enemy()]}
      build_character(skills: skills, combat: combat)
    end

    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "命中：造成伤害与创伤、攻击方回执 -100/2" do
      data = %{perform_id: "furong-jinzhen/xian", ap: 180, rng: & &1}
      conn = incoming(build_conn(target(%{"dodge" => 0})), data)

      updated = conn.private.update_character
      # ap/2+random(ap)=90+179>0 命中；damage=div(180,5)=36+random(36)=35 → 71
      assert updated.meta.vitals.qi == Vitals.new().qi - 71
      assert updated.meta.vitals.max_qi == Vitals.new().max_qi - 35
      assert published_text(conn) =~ "正中要穴"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 2}}
    end

    test "命中文案带暗器名与量词" do
      data = %{
        perform_id: "furong-jinzhen/xian",
        ap: 180,
        rng: fn _ -> 180 end,
        weapon_name: "飞针",
        unit: "枚"
      }

      conn = incoming(build_conn(target(%{"dodge" => 0})), data)
      assert published_text(conn) =~ "那枚飞针"
    end

    test "失手：目标不动，攻击方回执 -100/2" do
      data = %{perform_id: "furong-jinzhen/xian", ap: 180, rng: fn _ -> 1 end}
      conn = incoming(build_conn(target(%{"dodge" => 400, "parry" => 400})), data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "躲闪开来"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 100, busy: 2}}
    end

    test "目标忙乱则忽略" do
      character = target(%{"dodge" => 0})
      combat = %{character.meta.combat | busy: 2}
      character = %{character | meta: %{character.meta | combat: combat}}
      data = %{perform_id: "furong-jinzhen/xian", ap: 180, rng: fn _ -> 180 end}

      assert incoming(build_conn(character), data).private.update_character == nil
    end
  end
end