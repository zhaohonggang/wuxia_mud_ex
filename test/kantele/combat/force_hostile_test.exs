defmodule Kantele.Combat.ForceHostileTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Force.Lifeheal
  alias Kantele.Combat.Skills.Force.Roar
  alias Kantele.Combat.Skills.Force.Shot

  @vitals %{Vitals.new() | neili: 1000, max_neili: 1000}
  @room "test:room"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))
    inventory = Keyword.get(opts, :inventory, [])

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      inventory: inventory,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy(opts \\ []) do
    vitals = Keyword.get(opts, :vitals, %{Vitals.new() | qi: 150, max_qi: 150, jing: 120, max_jing: 120, neili: 500, max_neili: 500})
    stats = struct(Stats.new(), Keyword.take(opts, [:skills]))
    inventory = Keyword.get(opts, :inventory, [])

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "恶人",
      room_id: @room,
      inventory: inventory,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        combat_config: %{}
      }
    }
  end

  defp enemy_ref, do: %{id: "mob-1", pid: self(), name: "恶人", room_id: @room, busy: 0}

  defp attacker_ref(vitals \\ @vitals) do
    %{
      id: "player-1",
      pid: self(),
      name: "张三",
      room_id: @room,
      meta: %{vitals: vitals}
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
    opts = Keyword.put_new(opts, :performs, MapSet.new(["force/#{move}"]))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_opts, data) do
    session = Keyword.get(target_opts, :session, %{})
    target_conn = build_conn(build_character(target_opts), session)
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker_ref()}, data)})
  end

  # ============== 疗伤（force/lifeheal）攻击方门槛 ==============

  test "lifeheal: 未激发内功被拒" do
    conn = exert([skills: %{"force" => 60}], "lifeheal")
    assert output_text(conn) =~ "必须激发一种内功"
  end

  test "lifeheal: 内功等级不足被拒" do
    conn = exert([skills: %{"hunyuan-yiqi" => 49}, mapped: %{"force" => "hunyuan-yiqi"}], "lifeheal")
    assert output_text(conn) =~ "内功等级不够"
  end

  test "lifeheal: 内力修为不足被拒" do
    conn = exert([
      skills: %{"hunyuan-yiqi" => 60},
      mapped: %{"force" => "hunyuan-yiqi"},
      vitals: %{@vitals | max_neili: 299}
    ], "lifeheal")
    assert output_text(conn) =~ "内力修为不够"
  end

  test "lifeheal: 真气不足被拒" do
    conn = exert([
      skills: %{"hunyuan-yiqi" => 60},
      mapped: %{"force" => "hunyuan-yiqi"},
      vitals: %{@vitals | neili: 149}
    ], "lifeheal")
    assert output_text(conn) =~ "真气不够"
  end

  test "lifeheal: 战斗中被拒" do
    combat = Combat.new() |> Map.put(:enemies, [enemy_ref()])
    conn = exert([
      skills: %{"hunyuan-yiqi" => 60},
      mapped: %{"force" => "hunyuan-yiqi"},
      combat: combat
    ], "lifeheal")
    assert output_text(conn) =~ "战斗中无法运功疗伤"
  end

  test "lifeheal: 无可用目标被拒" do
    conn = exert([
      skills: %{"hunyuan-yiqi" => 60},
      mapped: %{"force" => "hunyuan-yiqi"}
    ], "lifeheal")
    assert output_text(conn) =~ "没有需要你救助的人"
  end

  # 注：LPC lifeheal 带 exert 目标参数（exert me target），可在战斗外救治房间内伤者；
  # 引擎 exert_command 不解析目标且未向 exert 暴露房间角色，故「成功放招」路径
  # 当前不可达（gate_not_fighting 与 find_target(enemies) 互斥）。目标侧结算见
  # lifeheal目标 测试；攻击方扣费待 exert 目标参数支持后补（TODO: D5）。

  # ============== 疗伤（force/lifeheal）目标侧结算 ==============

  test "lifeheal目标: 命中：目标回复气血/最大气血，攻击方回执" do
    target_vitals = %{Vitals.new() | qi: 50, max_qi: 100, base_qi: 150, jing: 120, max_jing: 120}
    data = %{perform_id: "force/lifeheal", force_lvl: 60, rng: fn _ -> 1 end}
    conn = incoming([vitals: target_vitals], data)

    updated = conn.private.update_character
    assert updated.meta.vitals.max_qi == 140
    assert updated.meta.vitals.qi == 80

    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "lifeheal目标: 目标忙乱则忽略" do
    target_vitals = %{Vitals.new() | qi: 50, max_qi: 100, base_qi: 150}
    combat = %{Combat.new() | busy: 2}
    data = %{perform_id: "force/lifeheal", force_lvl: 60, rng: fn _ -> 1 end}

    conn = incoming([vitals: target_vitals, combat: combat], data)
    assert conn.private.update_character == nil
  end

  # ============== 狮子吼（force/roar）攻击方门槛 ==============

  test "roar: 非允许内功被拒" do
    conn = exert([skills: %{"taiji-shengong" => 200}, mapped: %{"force" => "taiji-shengong"}], "roar")
    assert output_text(conn) =~ "没有这种功能"
  end

  test "roar: 内功等级不足被拒" do
    conn = exert([skills: %{"hunyuan-gong" => 179}, mapped: %{"force" => "hunyuan-gong"}], "roar")
    assert output_text(conn) =~ "内功修为不够"
  end

  test "roar: 真气不足被拒" do
    conn = exert([
      skills: %{"hunyuan-gong" => 200, "force" => 200},
      mapped: %{"force" => "hunyuan-gong"},
      vitals: %{@vitals | neili: 799}
    ], "roar")
    assert output_text(conn) =~ "真气不够"
  end

  test "roar: 成功放招：扣800内力、busy 5、向所有敌人投递事件" do
    enemies = [
      %{enemy_ref() | id: "mob-1", name: "恶人1"},
      %{enemy_ref() | id: "mob-2", name: "恶人2", pid: self()}
    ]
    combat = Combat.new() |> Map.put(:enemies, enemies)

    conn = exert([
      skills: %{"hunyuan-gong" => 200, "force" => 200},
      mapped: %{"force" => "hunyuan-gong"},
      vitals: %{@vitals | neili: 1000, max_neili: 1000},
      combat: combat
    ], "roar")

    updated = conn.private.update_character
    assert updated.meta.vitals.neili == 200
    assert updated.meta.combat.busy == 5
    assert published_text(conn) =~ "巨吼"

    assert_receive %Kalevala.Event{
      topic: "combat/perform-incoming",
      data: %{perform_id: "force/roar", skill: 200}
    }
    assert_receive %Kalevala.Event{
      topic: "combat/perform-incoming",
      data: %{perform_id: "force/roar", skill: 200}
    }
  end

  # ============== 狮子吼（force/roar）目标侧结算 ==============

  test "roar目标: 内力对抗成功：目标受精力伤害、可能昏迷" do
    target_vitals = %{Vitals.new() | jing: 120, max_jing: 120, max_neili: 500, neili: 100}
    data = %{perform_id: "force/roar", skill: 200, rng: fn _ -> 100 end}
    conn = incoming([vitals: target_vitals, skills: %{"con" => 10}], data)

    updated = conn.private.update_character
    assert updated.meta.vitals.jing == 1
    assert updated.meta.vitals.max_jing == 1

    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "roar目标: 内力对抗失败：目标无事" do
    target_vitals = %{Vitals.new() | jing: 120, max_jing: 120, max_neili: 500, neili: 500}
    data = %{perform_id: "force/roar", skill: 200, rng: fn _ -> 1 end}
    conn = incoming([vitals: target_vitals, skills: %{"con" => 200}], data)

    assert conn.private.update_character == nil
    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "roar目标: 目标忙乱则忽略" do
    target_vitals = %{Vitals.new() | jing: 120, max_jing: 120}
    combat = %{Combat.new() | busy: 2}
    data = %{perform_id: "force/roar", skill: 200, rng: fn _ -> 1 end}

    conn = incoming([vitals: target_vitals, combat: combat], data)
    assert conn.private.update_character == nil
  end

  test "roar目标: 死亡保护：die_guard 目标跳过" do
    target_vitals = %{Vitals.new() | jing: 120, max_jing: 120, max_neili: 100}
    data = %{perform_id: "force/roar", skill: 200, rng: fn _ -> 1 end}

    conn = incoming([vitals: target_vitals, session: %{"conditions" => %{"die_guard" => true}}], data)
    assert conn.private.update_character == nil
  end

  # ============== 弹毒（force/shot）攻击方门槛 ==============

  setup do
    du = %Kalevala.World.Item.Instance{
      id: "du-1",
      item_id: "poison:test",
      created_at: DateTime.utc_now(),
      meta: %{
        poison: true,
        poison_type: "snake_poison",
        poison: %{damage: 10, interval: 5},
        amount: 3,
        handing: true
      }
    }
    {:ok, du: du}
  end

  test "shot: 非允许内功被拒", %{du: du} do
    conn = exert([skills: %{"taiji-shengong" => 200}, mapped: %{"force" => "taiji-shengong"}], "shot")
    assert output_text(conn) =~ "没有这种功能"
  end

  test "shot: 内功等级不足被拒", %{du: du} do
    conn = exert([skills: %{"xiuluo-yinshagong" => 200, "force" => 149}, mapped: %{"force" => "xiuluo-yinshagong"}], "shot")
    assert output_text(conn) =~ "内功修为不够"
  end

  test "shot: 毒技/暗器不足被拒", %{du: du} do
    conn = exert([
      skills: %{"xiuluo-yinshagong" => 200, "force" => 200, "poison" => 99, "throwing" => 100},
      mapped: %{"force" => "xiuluo-yinshagong"}
    ], "shot")
    assert output_text(conn) =~ "基本毒技/暗器火候不够"
  end

  test "shot: 真气不足被拒", %{du: du} do
    conn = exert([
      skills: %{"xiuluo-yinshagong" => 200, "force" => 200, "poison" => 100, "throwing" => 100},
      mapped: %{"force" => "xiuluo-yinshagong"},
      vitals: %{@vitals | neili: 299}
    ], "shot")
    assert output_text(conn) =~ "真气不够"
  end

  test "shot: 手中无毒药被拒", %{du: du} do
    conn = exert([
      skills: %{"xiuluo-yinshagong" => 200, "force" => 200, "poison" => 100, "throwing" => 100},
      mapped: %{"force" => "xiuluo-yinshagong"}
    ], "shot")
    assert Regex.match?(~r/准备.*毒药/, output_text(conn))
  end

  test "shot: 无目标被拒", %{du: du} do
    conn = exert([
      skills: %{"xiuluo-yinshagong" => 200, "force" => 200, "poison" => 100, "throwing" => 100},
      mapped: %{"force" => "xiuluo-yinshagong"},
      inventory: [du]
    ], "shot")
    assert output_text(conn) =~ "想攻击谁"
  end

  test "shot: 成功放招：扣内力、消耗毒药、busy、投递事件", %{du: du} do
    enemies = [enemy_ref()]
    combat = Combat.new() |> Map.put(:enemies, enemies)

    conn = exert([
      skills: %{"xiuluo-yinshagong" => 200, "poison" => 120, "throwing" => 120, "force" => 200},
      mapped: %{"force" => "xiuluo-yinshagong"},
      vitals: %{@vitals | neili: 500, max_neili: 500},
      combat: combat,
      inventory: [du]
    ], "shot")

    updated = conn.private.update_character
    assert updated.meta.vitals.neili == 400
    assert updated.meta.combat.busy >= 1
    assert length(updated.inventory) == 1
    assert Enum.at(updated.inventory, 0).meta.amount == 2
    assert published_text(conn) =~ "弹射"

    assert_receive %Kalevala.Event{
      topic: "combat/perform-incoming",
      data: %{perform_id: "force/shot", force_lvl: 200, poison_skill: 120, throwing_skill: 120}
    }
  end

  # ============== 弹毒（force/shot）目标侧结算 ==============

  test "shot目标: 内力对抗失败：目标震落毒药", %{du: du} do
    target_vitals = %{Vitals.new() | max_neili: 1000, neili: 1000}
    attacker_vitals = %{Vitals.new() | max_neili: 500, neili: 100}
    data = %{
      perform_id: "force/shot",
      force_lvl: 200,
      poison_skill: 120,
      throwing_skill: 120,
      du: du,
      rng: fn n -> max(1, div(n, 2)) end
    }
    conn = incoming([vitals: target_vitals], Map.put(data, :attacker, Map.put(attacker_ref(attacker_vitals), :meta, %{vitals: attacker_vitals})))

    assert published_text(conn) =~ "震落"
    assert conn.private.update_character == nil
    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "shot目标: 内力对抗成功但招架闪避：目标避开", %{du: du} do
    target_vitals = %{Vitals.new() | max_neili: 200, neili: 100}
    attacker_vitals = %{Vitals.new() | max_neili: 500, neili: 100}
    target_stats = %{"dodge" => 500, "parry" => 500, "martial-cognize" => 500}
    data = %{
      perform_id: "force/shot",
      force_lvl: 200,
      poison_skill: 120,
      throwing_skill: 120,
      du: du,
      rng: fn _ -> 100 end
    }
    conn = incoming([vitals: target_vitals, skills: target_stats],
      Map.put(data, :attacker, Map.put(attacker_ref(attacker_vitals), :meta, %{vitals: attacker_vitals})))

    assert published_text(conn) =~ "避开"
    assert conn.private.update_character == nil
    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "shot目标: 命中：目标中毒+busy 2、攻击方回执", %{du: du} do
    target_vitals = %{Vitals.new() | max_neili: 200, neili: 100}
    attacker_vitals = %{Vitals.new() | max_neili: 500, neili: 100}
    target_stats = %{"dodge" => 0, "parry" => 0, "martial-cognize" => 0}
    data = %{
      perform_id: "force/shot",
      force_lvl: 200,
      poison_skill: 120,
      throwing_skill: 120,
      du: du,
      rng: fn _ -> 100 end
    }
    conn = incoming([vitals: target_vitals, skills: target_stats],
      Map.put(data, :attacker, Map.put(attacker_ref(attacker_vitals), :meta, %{vitals: attacker_vitals})))

    updated = conn.private.update_character
    assert Map.has_key?(conn.session["conditions"], "snake_poison")
    assert updated.meta.combat.busy == 2
    assert published_text(conn) =~ "麻痹"

    assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
  end

  test "shot目标: 目标忙乱则忽略", %{du: du} do
    target_vitals = %{Vitals.new() | max_neili: 200, neili: 100}
    attacker_vitals = %{Vitals.new() | max_neili: 500, neili: 100}
    combat = %{Combat.new() | busy: 3}
    data = %{
      perform_id: "force/shot",
      force_lvl: 200,
      poison_skill: 120,
      throwing_skill: 120,
      du: du,
      rng: fn _ -> 100 end
    }
    conn = incoming([vitals: target_vitals, combat: combat],
      Map.put(data, :attacker, %{attacker_ref() | meta: %{vitals: attacker_vitals}}))

    assert conn.private.update_character == nil
  end
end