defmodule Kantele.Combat.T1TailTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills

  @vitals %{Vitals.new() | neili: 3000, max_neili: 3000}
  @room "test:room"

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
    vitals = Keyword.get(opts, :vitals, %{Vitals.new() | neili: 500, max_neili: 500})
    stats = struct(Stats.new(), Keyword.take(opts, [:skills]))

    %Kalevala.Character{
      id: "mob-1",
      pid: self(),
      name: "鸠摩智",
      room_id: @room,
      meta: %Kantele.Character.NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp attacker(opts \\ []) do
    %{
      id: "player-1",
      pid: self(),
      name: "段誉",
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs])),
        combat: Combat.new()
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

  defp perform(opts, move) do
    opts = Keyword.put_new(opts, :mapped, Keyword.get(opts, :mapped, %{"force" => "lingyuan-xinfa"}))

    mapped = Keyword.fetch!(opts, :mapped)["force"]
    opts = Keyword.put_new(opts, :performs, MapSet.new(["#{mapped}/#{move}"]))
    ExertCommand.run(build_conn(build_character(opts)), %{"function" => move})
  end

  defp incoming(target_conn, data) do
    CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
  end

  defp weapon_combat(_opts \\ []) do
    %{Combat.new() | equipped: %{weapon: %{name: "秋水剑", skill_type: "sword"}}}
  end

  # ============== 灵元心法 / 以柔破钢（lingyuan-xinfa/break） ==============

  describe "灵元心法（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("lingyuan-xinfa")
      lingyuan = Skills.get("lingyuan-xinfa")
      assert lingyuan.valid_enable("force")
      refute lingyuan.valid_enable("sword")
      assert Map.has_key?(lingyuan.exert_list(), "break")
      assert lingyuan.valid_learn(struct(Stats.new(), skills: %{"force" => 10})) == :ok
      assert {:error, _} = lingyuan.valid_learn(struct(Stats.new(), skills: %{"force" => 9}))
    end
  end

  describe "break（以柔破钢，攻击方门槛）" do
    test "无目标被拒" do
      conn =
        perform(
          [skills: %{"lingyuan-xinfa" => 160, "force" => 200}, mapped: %{"force" => "lingyuan-xinfa"}],
          "break"
        )

      assert output_text(conn) =~ "战斗中的对手"
    end

    test "等级不足被拒" do
      target = enemy(combat: weapon_combat())
      conn =
        perform(
          [
            skills: %{"lingyuan-xinfa" => 149, "force" => 200},
            mapped: %{"force" => "lingyuan-xinfa"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "break"
        )

      assert output_text(conn) =~ "火候不够"
    end

    test "目标忙乱被拒" do
      target = %{id: "mob-1", pid: self(), name: "鸠摩智", room_id: @room, busy: 2}
      conn =
        perform(
          [
            skills: %{"lingyuan-xinfa" => 160, "force" => 200},
            mapped: %{"force" => "lingyuan-xinfa"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "break"
        )

      assert output_text(conn) =~ "正在发愣"
    end

    test "目标已死被拒" do
      target = enemy(combat: %{Combat.new() | dead: true})
      conn =
        perform(
          [
            skills: %{"lingyuan-xinfa" => 160, "force" => 200},
            mapped: %{"force" => "lingyuan-xinfa"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "break"
        )

      assert output_text(conn) =~ "用不着这么费力"
    end

    test "目标空手被拒" do
      target = enemy()
      conn =
        perform(
          [
            skills: %{"lingyuan-xinfa" => 160, "force" => 200},
            mapped: %{"force" => "lingyuan-xinfa"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "break"
        )

      assert output_text(conn) =~ "空手"
    end

    test "成功放招：busy 2、投递目标侧事件" do
      target = enemy(combat: weapon_combat())
      conn =
        perform(
          [
            skills: %{"lingyuan-xinfa" => 160, "force" => 200},
            mapped: %{"force" => "lingyuan-xinfa"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "break"
        )

      updated = conn.private.update_character
      assert updated.meta.combat.busy == 2
      assert published_text(conn) =~ "阴柔之气"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "lingyuan-xinfa/break", skill: 160, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "break（以柔破钢，目标侧结算）" do
    test "命中：兵刃震落（卸下 weapon 槽）、目标忙乱 skill/20" do
      target = enemy(combat: weapon_combat())
      target_conn = build_conn(target)
      data = %{perform_id: "lingyuan-xinfa/break", skill: 160, combat_exp: 100_000, rng: fn _ -> 10_000 end}

      conn = incoming(target_conn, data)

      updated = conn.private.update_character
      assert Map.get(updated.meta.combat.equipped, :weapon) == nil
      assert updated.meta.combat.busy == 8
      assert published_text(conn) =~ "震落"

      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
    end

    test "失手：目标拆招闪开，兵刃保留" do
      combat = weapon_combat() |> Map.put(:equipped, %{weapon: %{name: "秋水剑", skill_type: "sword"}})
      target = enemy(combat: combat)

      # 攻击方 combat_exp 低、目标 combat_exp 高 → 判定失败
      target = %{target | meta: %{target.meta | stats: struct(Stats.new(), combat_exp: 100_000)}}
      target_conn = build_conn(target)
      data = %{perform_id: "lingyuan-xinfa/break", skill: 150, combat_exp: 100, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      assert conn.private.update_character == nil
      assert published_text(conn) =~ "急急拆招"
      refute published_text(conn) =~ "震落"
    end

    test "目标忙乱则忽略" do
      target = enemy(combat: %{Combat.new() | busy: 3})
      target_conn = build_conn(target)
      data = %{perform_id: "lingyuan-xinfa/break", skill: 150, combat_exp: 100_000, rng: fn _ -> 100 end}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil
    end
  end

  # ============== 黯然吟（surge-force/roar） ==============

  describe "roar（黯然吟，攻击方门槛）" do
    test "等级不足被拒" do
      assert Map.has_key?(Skills.get("surge-force").exert_list(), "roar")
      conn = perform([skills: %{"surge-force" => 99}, mapped: %{"force" => "surge-force"}], "roar")
      assert output_text(conn) =~ "吓跑了几只老鼠"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [
            skills: %{"surge-force" => 120, "force" => 120},
            mapped: %{"force" => "surge-force"},
            vitals: %{@vitals | neili: 99}
          ],
          "roar"
        )

      assert output_text(conn) =~ "内力不够"
    end

    test "no_fight 房间被拒" do
      room = %{Combat.new() | enemies: [enemy()]}
      character = build_character(
        skills: %{"surge-force" => 120, "force" => 120},
        mapped: %{"force" => "surge-force"},
        vitals: %{@vitals | neili: 200},
        combat: room
      )
      character = %{character | meta: Map.put(character.meta, :room, %{no_fight: true})}
      conn = ExertCommand.run(build_conn(character), %{"function" => "roar"})
      assert output_text(conn) =~ "不能攻击别人"
    end

    test "成功放招：扣 100 内力、受 qi 伤 10、busy 5、向所有敌人投递事件" do
      enemies = [
        %{enemy() | id: "mob-1", name: "恶人1"},
        %{enemy() | id: "mob-2", name: "恶人2"}
      ]
      combat = Combat.new() |> Map.put(:enemies, enemies)

      conn =
        perform(
          [
            skills: %{"surge-force" => 120, "force" => 200},
            mapped: %{"force" => "surge-force"},
            vitals: %{@vitals | neili: 1000, max_neili: 1000, qi: 150},
            combat: combat
          ],
          "roar"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 900
      assert updated.meta.vitals.qi == 140
      assert updated.meta.combat.busy == 5
      assert published_text(conn) =~ "仰天长啸"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "surge-force/roar", skill: 200}
      }
      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "surge-force/roar", skill: 200}
      }
    end
  end

  describe "roar（黯然吟，目标侧结算）" do
    test "内力对抗成功：目标受精力伤害，可昏迷" do
      target_vitals = %{Vitals.new() | jing: 120, max_jing: 120, base_jing: 120, neili: 100, max_neili: 500}
      target = enemy(vitals: target_vitals, skills: %{"con" => 10})
      target_conn = build_conn(target)
      data = %{perform_id: "surge-force/roar", skill: 200, rng: fn _ -> 100 end}

      conn = incoming(target_conn, data)

      updated = conn.private.update_character
      assert updated.meta.vitals.jing == 1
      assert updated.meta.vitals.max_jing == 1

      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
    end

    test "内力对抗失败：目标无事" do
      target = enemy(skills: %{"con" => 200})
      target_conn = build_conn(target)
      data = %{perform_id: "surge-force/roar", skill: 200, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
    end

    test "目标忙乱/官府保护则忽略" do
      target = enemy(combat: %{Combat.new() | busy: 2})
      target_conn = build_conn(target)
      data = %{perform_id: "surge-force/roar", skill: 200, rng: fn _ -> 100 end}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil

      target2 = enemy(skills: %{"con" => 10})
      target2_conn = build_conn(target2, %{"conditions" => %{"die_guard" => true}})
      data2 = %{perform_id: "surge-force/roar", skill: 200, rng: fn _ -> 100 end}

      conn2 = CombatEvent.perform_incoming(target2_conn, %{data: Map.merge(%{attacker: attacker()}, data2)})
      assert conn2.private.update_character == nil
    end
  end

  # ============== 鹤嘴劲点龙跃窍（taiji-shengong/dian） ==============

  describe "dian（疗伤，攻击方门槛）" do
    test "未习得被拒" do
      conn =
        perform(
          [skills: %{"taiji-shengong" => 120}, mapped: %{"force" => "taiji-shengong"}, performs: MapSet.new()],
          "dian"
        )

      assert output_text(conn) =~ "没有这种功能"
    end

    test "战斗中无法运功被拒" do
      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 120, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            combat: %{Combat.new() | enemies: [enemy()]}
          ],
          "dian"
        )

      assert output_text(conn) =~ "战斗中无法运功疗伤"
    end

    test "太极等级不足被拒" do
      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 99, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            vitals: %{@vitals | max_neili: 2000, neili: 1500}
          ],
          "dian"
        )

      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力/精神门槛被拒" do
      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 120, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            vitals: %{@vitals | max_neili: 1499, neili: 1500}
          ],
          "dian"
        )

      assert output_text(conn) =~ "内力修为太浅"

      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 120, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            vitals: %{@vitals | max_neili: 2000, neili: 999}
          ],
          "dian"
        )

      assert output_text(conn) =~ "真气不足"

      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 120, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            vitals: %{@vitals | max_neili: 2000, neili: 1500, jing: 99}
          ],
          "dian"
        )

      assert output_text(conn) =~ "精神状态不佳"
    end

    test "非战斗又无目标被拒（成功路径受 exert 无目标参数限制，见 moduledoc）" do
      conn =
        perform(
          [
            skills: %{"taiji-shengong" => 120, "force" => 200},
            mapped: %{"force" => "taiji-shengong"},
            performs: MapSet.new(["taiji-shengong/dian"]),
            vitals: %{@vitals | max_neili: 2000, neili: 1500, jing: 120}
          ],
          "dian"
        )

      assert output_text(conn) =~ "你要用真气为谁疗伤"
    end
  end

  describe "dian（疗伤，目标侧结算）" do
    test "命中：目标 max_qi/qi 与 max_jing/jing 回复，busy 2" do
      target_vitals = %{Vitals.new() | qi: 50, max_qi: 80, base_qi: 150, jing: 40, max_jing: 60, base_jing: 120}
      target = enemy(vitals: target_vitals)
      target_conn = build_conn(target)
      data = %{perform_id: "taiji-shengong/dian", force_lvl: 200, taiji_lvl: 120, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)

      updated = conn.private.update_character
      # cure_qi = 100 + 200 + 120*3 = 660 → max_qi 提到 base 150（当前 qi 保持 50）
      # cure_jing = 100 + 66 + 120 = 286 → max_jing 提到 base 120（当前 jing 保持 40）
      assert updated.meta.vitals.max_qi == 150
      assert updated.meta.vitals.qi == 50
      assert updated.meta.vitals.max_jing == 120
      assert updated.meta.vitals.jing == 40
      assert updated.meta.combat.busy == 2
      assert published_text(conn) =~ "吐出瘀血"

      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
    end

    test "目标无伤则忽略" do
      target_vitals = %{Vitals.new() | qi: 150, max_qi: 150, base_qi: 150, jing: 120, max_jing: 120, base_jing: 120}
      target = enemy(vitals: target_vitals)
      target_conn = build_conn(target)
      data = %{perform_id: "taiji-shengong/dian", force_lvl: 200, taiji_lvl: 120, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil
    end

    test "目标忙乱则忽略" do
      target = enemy(combat: %{Combat.new() | busy: 2})
      target_conn = build_conn(target)
      data = %{perform_id: "taiji-shengong/dian", force_lvl: 200, taiji_lvl: 120, rng: fn _ -> 1 end}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil
    end
  end

  # ============== 取毒液练药（xiuluo-yinshagong/suck） ==============

  describe "suck（取毒液，攻击方门槛）" do
    test "技能表已注册" do
      xiuluo = Skills.get("xiuluo-yinshagong")
      assert Map.has_key?(xiuluo.exert_list(), "suck")
    end

    test "五毒奇术/修罗阴煞功不足被拒" do
      conn =
        perform(
          [
            skills: %{"xiuluo-yinshagong" => 120, "force" => 150, "wudu-qishu" => 99},
            mapped: %{"force" => "xiuluo-yinshagong"}
          ],
          "suck"
        )

      assert output_text(conn) =~ "五毒奇术不够娴熟"

      conn =
        perform(
          [
            skills: %{"xiuluo-yinshagong" => 99, "force" => 150, "wudu-qishu" => 120},
            mapped: %{"force" => "xiuluo-yinshagong"}
          ],
          "suck"
        )

      assert output_text(conn) =~ "修罗阴煞功修为不够"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [
            skills: %{"xiuluo-yinshagong" => 120, "force" => 150, "wudu-qishu" => 120},
            mapped: %{"force" => "xiuluo-yinshagong"},
            vitals: %{@vitals | neili: 199}
          ],
          "suck"
        )

      assert output_text(conn) =~ "内力不足"
    end

    test "无目标被拒" do
      conn =
        perform(
          [
            skills: %{"xiuluo-yinshagong" => 120, "force" => 150, "wudu-qishu" => 120},
            mapped: %{"force" => "xiuluo-yinshagong"}
          ],
          "suck"
        )

      assert output_text(conn) =~ "哪只虫"
    end

    test "成功放招：扣 50 内力、投递目标侧事件" do
      target = enemy()
      conn =
        perform(
          [
            skills: %{"xiuluo-yinshagong" => 120, "force" => 150, "wudu-qishu" => 120},
            mapped: %{"force" => "xiuluo-yinshagong"},
            combat: %{Combat.new() | enemies: [target]}
          ],
          "suck"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 2950
      assert published_text(conn) =~ "伸出食指"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{
          perform_id: "xiuluo-yinshagong/suck",
          poison_lvl: 0,
          wudu_lvl: 120,
          xiuluo_lvl: 120,
          attacker: %{id: "player-1"}
        }
      }
    end
  end

  describe "suck（取毒液，目标侧结算）" do
    test "目标非毒虫（无 worm_poison）则放弃" do
      target = enemy()
      target_conn = build_conn(target)
      data = %{perform_id: "xiuluo-yinshagong/suck", poison_lvl: 100, wudu_lvl: 120, xiuluo_lvl: 120}

      conn = incoming(target_conn, data)
      assert conn.private.update_character == nil
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 0, busy: 0}}
    end

    test "毒虫目标：remain 扣减、上 poison-supply 条件、炼成药丸文案" do
      worm = enemy()
      meta = Map.put(worm.meta, :worm_poison, %{level: 10, remain: 100})
      worm = %{worm | meta: meta}
      target_conn = build_conn(worm)
      data = %{perform_id: "xiuluo-yinshagong/suck", poison_lvl: 100, wudu_lvl: 120, xiuluo_lvl: 120}

      conn = incoming(target_conn, data)

      updated = conn.private.update_character
      assert updated.meta.worm_poison.remain < 100
      assert conn.session["conditions"]["poison-supply"]
      assert published_text(conn) =~ "药丸"
    end

    test "毒液不足只挤出少量" do
      worm = enemy()
      meta = Map.put(worm.meta, :worm_poison, %{level: 1, remain: 1})
      worm = %{worm | meta: meta}
      target_conn = build_conn(worm)
      data = %{perform_id: "xiuluo-yinshagong/suck", poison_lvl: 100, wudu_lvl: 120, xiuluo_lvl: 120}

      conn = incoming(target_conn, data)
      assert conn.private.update_character != nil
      assert published_text(conn) =~ "挤了一点毒液"
    end
  end

  # ============== 易筋通脉（yijinjing/tong） ==============

  describe "tong（易筋通脉，门槛）" do
    test "未习得被拒" do
      conn =
        perform(
          [skills: %{"yijinjing" => 150}, mapped: %{"force" => "yijinjing"}, performs: MapSet.new()],
          "tong"
        )

      assert output_text(conn) =~ "没有这种功能"
    end

    test "易筋经等级不足被拒" do
      conn =
        perform(
          [skills: %{"yijinjing" => 99}, mapped: %{"force" => "yijinjing"}, performs: MapSet.new(["yijinjing/tong"])],
          "tong"
        )

      assert output_text(conn) =~ "易筋经等级不够"
    end

    test "max_neili 不足被拒" do
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: %{@vitals | max_neili: 499, neili: 3000}
          ],
          "tong"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "伤势很轻/太重被拒" do
      base = %{@vitals | max_neili: 1000, neili: 3000}
      # eff_qi/max_qi = 90% → 伤势很轻
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: %{base | max_qi: 135, base_qi: 150, qi: 135}
          ],
          "tong"
        )

      assert output_text(conn) =~ "伤势很轻"

      # eff_qi/max_qi = 5% → 内伤太重
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: %{base | max_qi: 7, base_qi: 150, qi: 7}
          ],
          "tong"
        )

      assert output_text(conn) =~ "内伤太重"
    end

    test "内力不足被拒" do
      # yijinjing 150 → 需 neili >= 750
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: %{@vitals | max_neili: 1000, neili: 749, max_qi: 100, base_qi: 150, qi: 100}
          ],
          "tong"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "成功：耗 skill*4 内力、扣 max_neili skill/4、eff_qi 回复 skill*8 并重置 qi" do
      base = %{@vitals | max_neili: 1000, neili: 2000, max_qi: 100, base_qi: 150, qi: 60}
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: base
          ],
          "tong"
        )

      updated = conn.private.update_character
      vitals = updated.meta.vitals
      assert vitals.neili == 2000 - 150 * 4
      assert vitals.max_neili == 1000 - div(150, 4)
      assert vitals.max_qi == min(100 + 150 * 8, 150)
      assert vitals.qi == vitals.max_qi
      assert published_text(conn) =~ "奇经八脉"
    end

    test "战斗中成功：busy 4" do
      base = %{@vitals | max_neili: 1000, neili: 2000, max_qi: 100, base_qi: 150, qi: 60}
      combat = %{Combat.new() | enemies: [enemy()]}
      conn =
        perform(
          [
            skills: %{"yijinjing" => 150},
            mapped: %{"force" => "yijinjing"},
            performs: MapSet.new(["yijinjing/tong"]),
            vitals: base,
            combat: combat
          ],
          "tong"
        )

      assert conn.private.update_character.meta.combat.busy == 4
    end
  end
end