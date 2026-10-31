defmodule Kantele.Combat.SkillsPoisonHitObTest do
  @moduledoc """
  hit_ob 中毒系（C 相位 F4 长尾，Option 2：condition/中毒通道）。

  LPC 契约：这一族 `hit_ob` 在命中后 `victim->affect_by(CND, para)`，对应的
  引擎实现是把 `{cnd, para}` 放进 `Round.conditions`，再由
  `Kantele.Character.Events.CombatEvent.apply_round_conditions` 在伤害落地**之前**
  经 `ConditionEvent.apply_poison_condition/3` 落到防守方 session。

  本批只覆盖「引擎接线 + PoisonHit 公共骨架」：14 个技能（bingcan-duzhang /
  cuixin-zhang / dusha-zhang / hanbing-mianzhang / heisha-zhang / huagu-mianzhang /
  lansha-shou / ningxue-shenzhao / qianzhu-wandushou / shenzhaojing / tougu-zhen /
  xuanming-zhang / xuantian-zhi / yinfeng-dao）全部走 `Kantele.Combat.PoisonHit.strike/5`
  这一公共骨架（shenzhaojing / xuanming-zhang 为自定义变体，另行覆盖），其上毒主效果
  与 `Poison.family` 的 12 个 condition daemon 完全一致。

  `freezing-force` / `hanbing-zhenqi` 依赖 FORCE 基类 `hit_ob` + `query_temp("freezing")`
  未建模，本批跳过（见 MEMORY）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.PoisonHit
  alias Kantele.Combat.Skills.CuixinZhang

  defp max_rng, do: fn n -> n end

  defp fighter(opts) do
    %Fighter{
      id: "f",
      name: "某",
      pid: self(),
      str: Map.get(opts, :str, 20),
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      skills: Map.fetch!(opts, :skills),
      mapped: Map.get(opts, :mapped, %{}),
      applies: Map.get(opts, :applies, %{}),
      busy: 0,
      jiali: Map.get(opts, :jiali, 0),
      neili: Map.get(opts, :neili, 0),
      attack_skill: Map.get(opts, :attack_skill, "unarmed"),
      weapon_name: nil
    }
  end

  describe "PoisonHit.strike 公共骨架" do
    test "门槛齐备且随机判定通过 → 返回 {0, msg, [{cnd, para}]}" do
      a = %{skills: %{"cuixin-zhang" => 100}, jiali: 100, id: "att"}
      v = %{skills: %{"force" => 0}}

      {0, msg, [{cnd, para}]} =
        PoisonHit.strike(a, v, 999, max_rng(),
          skill: "cuixin-zhang",
          cnd: "cuixin_zhang",
          msg: "X",
          div1: 100,
          div2: 10
        )

      assert cnd == "cuixin_zhang"
      assert para["id"] == "att"
      # level = flvl + random(flvl) = 100 + (100-1) = 199
      assert para["level"] == 199
      # duration = div(lvl, div1) + random(div(lvl, div2)) = 1 + (10-1) = 10
      # （max_rng 下 Engine.rand(rng, n) = n-1，对齐 LPC random(n) ∈ [0, n-1]）
      assert para["duration"] == 10
      assert msg == "X"
    end

    test "伤害为 0 → 不触发" do
      a = %{skills: %{"cuixin-zhang" => 100}, jiali: 100, id: "att"}
      v = %{skills: %{"force" => 0}}

      assert PoisonHit.strike(a, v, 0, max_rng(),
               skill: "cuixin-zhang",
               cnd: "cuixin_zhang",
               msg: "X"
             ) == {0, nil}
    end

    test "内力加力不足门槛 → 不触发" do
      a = %{skills: %{"cuixin-zhang" => 100}, jiali: 0, id: "att"}
      v = %{skills: %{"force" => 0}}

      assert PoisonHit.strike(a, v, 999, max_rng(),
               skill: "cuixin-zhang",
               cnd: "cuixin_zhang",
               msg: "X"
             ) == {0, nil}
    end

    test "对手 force 高 → 随机判定不过 → 不触发" do
      a = %{skills: %{"cuixin-zhang" => 100}, jiali: 100, id: "att"}
      v = %{skills: %{"force" => 9999}}

      assert PoisonHit.strike(a, v, 999, max_rng(),
               skill: "cuixin-zhang",
               cnd: "cuixin_zhang",
               msg: "X"
             ) == {0, nil}
    end
  end

  describe "引擎接线：中毒 hit_ob 把条件落进 Round.conditions" do
    test "cuixin-zhang 命中后 round.conditions 含 cuixin_zhang" do
      a = fighter(%{
        attack_skill: "strike",
        mapped: %{"strike" => "cuixin-zhang"},
        skills: %{"strike" => 100, "cuixin-zhang" => 100, "force" => 100},
        jiali: 100,
        str: 300,
        applies: %{damage: 200, armor: 0}
      })

      v = fighter(%{
        skills: %{"dodge" => 1, "parry" => 1, "force" => 0},
        con: 10,
        applies: %{armor: 0}
      })

      round = Engine.attack_round(a, v, rng: max_rng())

      assert round.outcome == :hit

      assert Enum.any?(round.conditions, fn
               {"cuixin_zhang", para} ->
                 is_map(para) and para["level"] > 0 and para["duration"] > 0

               _ ->
                 false
             end)
    end

    test "未映射该技能 → 不落条件（回落 {0, nil, []}）" do
      a = fighter(%{
        attack_skill: "strike",
        mapped: %{},
        skills: %{"strike" => 100, "cuixin-zhang" => 100},
        jiali: 100,
        str: 300,
        applies: %{damage: 200, armor: 0}
      })

      v = fighter(%{skills: %{"dodge" => 1, "parry" => 1, "force" => 0}, con: 10, applies: %{armor: 0}})

      round = Engine.attack_round(a, v, rng: max_rng())
      assert round.conditions == []
    end
  end

  describe "技能级命中回调：CuixinZhang.hit_ob" do
    test "映射命中后返回 {0, msg, [{cuixin_zhang, para}]}" do
      a = %{skills: %{"cuixin-zhang" => 100}, jiali: 100, id: "att"}
      v = %{skills: %{"force" => 0}}

      {0, msg, [{cnd, para}]} = CuixinZhang.hit_ob(a, v, 999, 0, max_rng())

      assert cnd == "cuixin_zhang"
      assert para["id"] == "att"
      assert msg =~ "催心掌"
    end
  end
end
