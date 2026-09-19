defmodule Kantele.Combat.ForceSelfTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Force.Dispel
  alias Kantele.Combat.Skills.Force.Heal
  alias Kantele.Combat.Skills.Force.Inspire
  alias Kantele.Combat.Skills.Force.Recover
  alias Kantele.Combat.Skills.Force.Regenerate
  alias Kantele.Combat.Skills.Force.Tianmo
  alias Kantele.Combat.Skills.Force.Xun

  @vitals %{
    Vitals.new()
    | neili: 10000,
      max_neili: 10000,
      qi: 1000,
      max_qi: 1000,
      base_qi: 1000,
      jing: 1000,
      max_jing: 1000,
      base_jing: 1000
  }

  defp build_test_conn(opts \\ []) do
    # Accept both keyword lists and maps
    opts = if is_list(opts), do: Enum.into(opts, %{}), else: opts
    
    # Allow passing a pre-built stats struct, or build from individual params
    base_stats = Map.get(opts, :base_stats, nil)
    skills = Map.get(opts, :skills, %{"force" => 300})
    mapped = Map.get(opts, :mapped, %{"force" => "force"})
    performs = Map.get(opts, :performs, MapSet.new())
    special_skills = Map.get(opts, :special_skills, [])
    vitals = Map.get(opts, :vitals, @vitals)
    combat = Map.get(opts, :combat, Combat.new())
    temp = Map.get(opts, :temp, %{})
    meta_conditions = Map.get(opts, :conditions, %{})

    stats =
      if base_stats do
        # Merge base_stats with any overridden skills/mapped/performs
        struct(base_stats, %{
          skills: skills,
          mapped: mapped,
          performs: performs
        })
      else
        struct(Stats.new(), %{
          skills: skills,
          mapped: mapped,
          performs: performs
        })
      end

    meta = %Kantele.Character.PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: combat,
      temp: temp
    }
    meta = Map.put(meta, :conditions, meta_conditions)

    attributes = %{"special_skills" => Enum.into(special_skills, %{}, fn s -> {s, true} end)}

    character = %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: meta,
      attributes: attributes
    }

    build_conn(character)
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

  defp exert(conn, function) do
    ExertCommand.run(conn, %{"function" => function})
  end

  # Helper: base character that passes all heal gates except the one being tested
  defp heal_ready(opts \\ []) do
    base = %{
      vitals: %{@vitals | max_qi: 500, base_qi: 1000, neili: 200, qi: 400},
      skills: %{"force" => 60},
      special_skills: []
    }
    Map.merge(base, Enum.into(opts, %{}))
  end

  # Helper: base character that passes all inspire gates except the one being tested
  defp inspire_ready(opts \\ []) do
    base = %{
      vitals: %{@vitals | max_jing: 500, base_jing: 1000, neili: 300, jing: 400},
      skills: %{"force" => 300},
      special_skills: ["breakup"]
    }
    Map.merge(base, Enum.into(opts, %{}))
  end

  # Helper: base character that passes all tianmo gates except the one being tested
  defp tianmo_ready(opts \\ []) do
    base_stats = struct(Stats.new(), %{
      str: 35,
      con: 35,
      int: 30,
      dex: 30,
      shen: -20000000,
      skills: %{"force" => 400, "martial-cognize" => 400, "dodge" => 100, "parry" => 100}
    })
    base_vitals = %{@vitals | neili: 10000, qi: 1000, max_qi: 1000, jing: 1000, max_jing: 1000}
    base = %{
      base_stats: struct(base_stats, skills: base_stats.skills, mapped: %{"force" => "force"}, performs: MapSet.new()),
      vitals: base_vitals,
      skills: base_stats.skills
    }
    Map.merge(base, Enum.into(opts, %{}))
  end

  describe "force skill exert_list" do
    test "注册了全部 10 个运功" do
      force = Skills.get("force")
      assert force != nil
      list = force.exert_list()
      assert Map.has_key?(list, "dispel")
      assert Map.has_key?(list, "heal")
      assert Map.has_key?(list, "inspire")
      assert Map.has_key?(list, "recover")
      assert Map.has_key?(list, "regenerate")
      assert Map.has_key?(list, "tianmo")
      assert Map.has_key?(list, "xun")
      assert Map.has_key?(list, "power")
      assert Map.has_key?(list, "roar")
      assert Map.has_key?(list, "shot")
      assert list["dispel"] == Dispel
      assert list["heal"] == Heal
      assert list["inspire"] == Inspire
      assert list["recover"] == Recover
      assert list["regenerate"] == Regenerate
      assert list["tianmo"] == Tianmo
      assert list["xun"] == Xun
    end
  end

  describe "dispel (排除异常)" do
    test "内力不足被拒" do
      conn = exert(build_test_conn(vitals: %{@vitals | neili: 200}), "dispel")
      assert output_text(conn) =~ "内力不足"
    end

    test "成功清空 conditions 并扣内力" do
      conn = exert(build_test_conn(vitals: %{@vitals | neili: 500}, conditions: %{poison: 10, blind: 5}), "dispel")
      updated = conn.private.update_character

      assert updated.meta.vitals.neili == 400
      assert updated.meta.conditions == %{}
      assert published_text(conn) =~ "排除身体中的异常症状"
    end

    test "无 conditions 时给出提示" do
      conn = exert(build_test_conn(vitals: %{@vitals | neili: 500}), "dispel")
      updated = conn.private.update_character

      assert updated.meta.vitals.neili == 400
      # LPC: "结果你没发现自己有任何异常" + "眉角微微一动"
      assert published_text(conn) =~ "异常症状"
    end
  end

  describe "heal (疗伤)" do
    test "战斗中被拒" do
      combat = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}
      conn = exert(build_test_conn(heal_ready(combat: combat)), "heal")
      assert output_text(conn) =~ "战斗中运功疗伤"
    end

    test "忙碌时被拒" do
      combat = %{Combat.new() | busy: 1}
      conn = exert(build_test_conn(heal_ready(combat: combat)), "heal")
      assert output_text(conn) =~ "忙完了手头的事情"
    end

    test "天魔状态被拒" do
      buff = %Combat.Buff{key: "tianmo", applies: %{}}
      combat = %{Combat.new() | buffs: [buff]}
      conn = exert(build_test_conn(heal_ready(combat: combat)), "heal")
      assert output_text(conn) =~ "天魔解体状态不能运功疗伤"
    end

    test "未激发内功被拒" do
      conn = exert(build_test_conn(heal_ready(mapped: %{})), "heal")
      assert output_text(conn) =~ "先激发你的特殊内功"
    end

    test "气血充盈被拒" do
      vitals = %{@vitals | max_qi: 1000, base_qi: 1000, neili: 200}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 60}), "heal")
      assert output_text(conn) =~ "气血充盈"
    end

    test "内功等级不足被拒" do
      conn = exert(build_test_conn(heal_ready(skills: %{"force" => 10})), "heal")
      assert output_text(conn) =~ "修为还不够"
    end

    test "内力不足被拒" do
      conn = exert(build_test_conn(heal_ready(vitals: %{@vitals | max_qi: 500, base_qi: 1000, neili: 30, qi: 400})), "heal")
      assert output_text(conn) =~ "真气不够"
    end

    test "重伤且无 divine 被拒" do
      vitals = %{@vitals | max_qi: 100, base_qi: 1000, neili: 200}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 60}, special_skills: []), "heal")
      assert output_text(conn) =~ "受伤过重"
    end

    test "重伤但有 divine 可用" do
      vitals = %{@vitals | max_qi: 100, base_qi: 1000, neili: 200}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 60}, special_skills: ["divine"]), "heal")
      updated = conn.private.update_character
      assert updated.meta.vitals.max_qi > 100
      assert updated.meta.vitals.neili == 150
    end

    test "成功疗伤回复气血" do
      conn = exert(build_test_conn(heal_ready()), "heal")
      updated = conn.private.update_character

      assert updated.meta.vitals.neili == 150
      assert updated.meta.vitals.max_qi > 500
      assert updated.meta.vitals.qi > 400
      assert published_text(conn) =~ "运功疗伤"
    end
  end

  describe "inspire (振奋精神)" do
    test "战斗中被拒" do
      combat = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}
      conn = exert(build_test_conn(inspire_ready(combat: combat)), "inspire")
      assert output_text(conn) =~ "正在战斗中"
    end

    test "未激发内功被拒" do
      conn = exert(build_test_conn(inspire_ready(mapped: %{})), "inspire")
      assert output_text(conn) =~ "先激发你的特殊内功"
    end

    test "内功等级不足被拒" do
      conn = exert(build_test_conn(inspire_ready(skills: %{"force" => 100})), "inspire")
      assert output_text(conn) =~ "修为还不够"
    end

    test "精力充盈被拒" do
      vitals = %{@vitals | max_jing: 1000, base_jing: 1000, neili: 300}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 300}, special_skills: ["breakup"]), "inspire")
      assert output_text(conn) =~ "精神饱满"
    end

    test "内力不足被拒" do
      conn = exert(build_test_conn(inspire_ready(vitals: %{@vitals | max_jing: 500, base_jing: 1000, neili: 100, jing: 400})), "inspire")
      assert output_text(conn) =~ "真气不够"
    end

    test "精损伤太重被拒" do
      vitals = %{@vitals | max_jing: 200, base_jing: 1000, neili: 300}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 300}, special_skills: ["breakup"]), "inspire")
      assert output_text(conn) =~ "精损伤太重"
    end

    test "成功振奋回复精力" do
      conn = exert(build_test_conn(inspire_ready()), "inspire")
      updated = conn.private.update_character

      assert updated.meta.vitals.neili == 200
      assert updated.meta.vitals.max_jing > 500
      assert updated.meta.vitals.jing > 400
      assert published_text(conn) =~ "呼吸吐纳"
    end
  end

  describe "recover (调息)" do
    test "内力不足被拒" do
      conn = exert(build_test_conn(vitals: %{@vitals | neili: 10}), "recover")
      assert output_text(conn) =~ "内力不够"
    end

    test "气力充沛被拒" do
      vitals = %{@vitals | max_qi: 1000, qi: 995}
      conn = exert(build_test_conn(vitals: vitals), "recover")
      assert output_text(conn) =~ "气力充沛"
    end

    test "成功回气扣内力" do
      vitals = %{@vitals | max_qi: 1000, qi: 500, neili: 5000}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 200}), "recover")
      updated = conn.private.update_character

      assert updated.meta.vitals.qi == 1000
      assert updated.meta.vitals.neili < 5000
      assert published_text(conn) =~ "脸色看起来好多了"
    end

    test "战斗中 busy 1" do
      vitals = %{@vitals | max_qi: 1000, qi: 500, neili: 5000}
      combat = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 200}, combat: combat), "recover")
      updated = conn.private.update_character

      assert updated.meta.combat.busy == 1
    end

    test "非战斗不 busy" do
      vitals = %{@vitals | max_qi: 1000, qi: 500, neili: 5000}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 200}), "recover")
      updated = conn.private.update_character

      assert updated.meta.combat.busy == 0
    end
  end

  describe "regenerate (疗精)" do
    test "内力不足被拒" do
      conn = exert(build_test_conn(vitals: %{@vitals | neili: 10}), "regenerate")
      assert output_text(conn) =~ "内力不够"
    end

    test "精气旺盛被拒" do
      vitals = %{@vitals | max_jing: 1000, jing: 995}
      conn = exert(build_test_conn(vitals: vitals), "regenerate")
      assert output_text(conn) =~ "精气旺盛"
    end

    test "成功回精扣内力" do
      vitals = %{@vitals | max_jing: 1000, jing: 500, neili: 5000}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 200}), "regenerate")
      updated = conn.private.update_character

      assert updated.meta.vitals.jing == 1000
      assert updated.meta.vitals.neili < 5000
      assert published_text(conn) =~ "精神看起来好多了"
    end

    test "战斗中 busy 1" do
      vitals = %{@vitals | max_jing: 1000, jing: 500, neili: 5000}
      combat = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}
      conn = exert(build_test_conn(vitals: vitals, skills: %{"force" => 200}, combat: combat), "regenerate")
      updated = conn.private.update_character

      assert updated.meta.combat.busy == 1
    end
  end

  describe "tianmo (天魔解体大法)" do
    test "已在天魔状态被拒" do
      buff = %Combat.Buff{key: "tianmo", applies: %{}}
      combat = %{Combat.new() | buffs: [buff]}
      conn = exert(build_test_conn(tianmo_ready(combat: combat)), "tianmo")
      assert output_text(conn) =~ "已经在运功中了"
    end

    test "资质不足被拒" do
      stats = %{
        Stats.new()
        | str: 20,
        con: 20,
        shen: -20000000,
        skills: %{"force" => 400, "martial-cognize" => 400}
      }
      stats = struct(stats, skills: stats.skills, mapped: %{"force" => "force"}, performs: MapSet.new())
      vitals = %{@vitals | neili: 10000}
      conn = exert(build_test_conn(base_stats: stats, vitals: vitals), "tianmo")
      assert output_text(conn) =~ "资质不适合"
    end

    test "内力不足被拒" do
      conn = exert(build_test_conn(tianmo_ready(vitals: %{@vitals | neili: 7000, qi: 1000, max_qi: 1000, jing: 1000, max_jing: 1000})), "tianmo")
      assert output_text(conn) =~ "内力不够"
    end

    test "未入魔被拒" do
      stats = %{
        Stats.new()
        | str: 35,
        con: 35,
        shen: -100,
        skills: %{"force" => 400, "martial-cognize" => 400}
      }
      stats = struct(stats, skills: stats.skills, mapped: %{"force" => "force"}, performs: MapSet.new())
      vitals = %{@vitals | neili: 10000}
      conn = exert(build_test_conn(base_stats: stats, vitals: vitals), "tianmo")
      assert output_text(conn) =~ "还没有入魔"
    end

    test "技能等级不足被拒" do
      stats = %{
        Stats.new()
        | str: 35,
        con: 35,
        shen: -20000000,
        skills: %{"force" => 200, "martial-cognize" => 400}
      }
      stats = struct(stats, skills: stats.skills, mapped: %{"force" => "force"}, performs: MapSet.new())
      vitals = %{@vitals | neili: 10000}
      conn = exert(build_test_conn(base_stats: stats, vitals: vitals), "tianmo")
      assert output_text(conn) =~ "修行还不够"
    end

    test "成功进入天魔状态" do
      conn = exert(build_test_conn(tianmo_ready()), "tianmo")
      updated = conn.private.update_character

      assert updated != nil
      assert updated.meta.vitals.neili == 0
      assert updated.meta.vitals.qi < 1000
      assert updated.meta.vitals.max_qi < 1000
      assert updated.meta.vitals.jing < 1000
      assert updated.meta.vitals.max_jing < 1000
      assert Combat.buff_active?(updated.meta.combat, "tianmo")
      assert updated.meta.combat.temp.str == 35
      assert updated.meta.combat.temp.int == 30
      assert updated.meta.combat.temp.con == 35
      assert updated.meta.combat.temp.dex == 30
      assert updated.meta.combat.temp.attack > 0
      assert updated.meta.combat.temp.damage == 105
      assert published_text(conn) =~ "天魔解体大法"
    end
  end

  describe "xun (寻踪)" do
    test "无 wiz_test 被拒" do
      conn = exert(build_test_conn(temp: %{quest_id: "target"}), "xun")
      assert output_text(conn) =~ "没有这种功能"
    end

    test "无 quest_id 被拒" do
      conn = exert(build_test_conn(temp: %{wiz_test: true}), "xun")
      assert output_text(conn) =~ "没有这种功能"
    end

    test "有权限时运行 no-op" do
      conn = exert(build_test_conn(temp: %{wiz_test: true, quest_id: "target"}), "xun")
      updated = conn.private.update_character

      assert updated != nil
      assert published_text(conn) =~ "寻踪秘术"
    end
  end
end