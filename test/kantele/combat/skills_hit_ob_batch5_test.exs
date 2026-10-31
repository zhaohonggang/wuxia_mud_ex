defmodule Kantele.Combat.SkillsHitObBatch5Test do
  @moduledoc """
  batch5 三个攻击技能的 `hit_ob/5`（命中后回调）迁移。

  对应 LPC 源：

    - `qixian-wuxingjian.c#hit_ob` 七弦音攻 —— `start_busy(1)` + 额外创伤
    - `tanzhi-shentong.c#hit_ob`   弹指穴道 —— `start_busy(2)` + 额外创伤
    - `yiyang-zhi.c#hit_ob`        一阳指穴道 —— 空手 `start_busy(2)` + 额外创伤；
      持械支**不** `start_busy`（源内怪癖）

  `start_busy(n)` 以保留字 affect `{"busy", %{"rounds" => n}}` 表达，由
  `Kantele.Character.CombatEvent.apply_round_conditions/2` 落到防守方
  `character.meta.combat.busy`（`Combat.start_busy/2` 取 max，与 LPC 同义）。

  未建模（`hit_ob` 契约无通道）：攻击方 `neili` 自耗、对方 `neili` 削减、
  以及七弦的「无创伤气血伤害」—— 已在各模块 moduledoc 注明。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills.{QixianWuxingjian, TanzhiShentong, YiyangZhi}

  defp max_rng, do: fn n -> n end

  defp att(skills, extra) do
    Map.merge(%{skills: skills, max_neili: 0, neili: 0, weapon_name: nil}, extra)
  end

  defp vic(max_neili, extra \\ %{}) do
    Map.merge(%{skills: %{}, max_neili: max_neili, busy: 0}, extra)
  end

  # rng_max 下穴位取索引 17 = 「至阳穴」
  @last_acupoint "至阳穴"

  describe "qixian-wuxingjian hit_ob（七弦音攻）" do
    defp qx_att(extra \\ %{}),
      do: att(%{"qixian-wuxingjian" => 200}, Map.merge(%{max_neili: 3000, neili: 1000}, extra))

    test "条件齐备 → 额外创伤 skill/8 + damage/5，并附 busy 1" do
      {wound, msg, affects} = QixianWuxingjian.hit_ob(qx_att(), vic(200), 200, 0, max_rng())

      assert wound == div(200, 8) + div(200, 5)
      assert msg == "只听一阵淳厚的弦音从$N处传来，$n『#{@last_acupoint}』顿时受震，两耳轰鸣，全身真气乱窜不止！\n"
      assert affects == [{"busy", %{"rounds" => 1}}]
    end

    test "本门 < 180 不触发" do
      a = att(%{"qixian-wuxingjian" => 179}, %{max_neili: 3000, neili: 1000})
      assert QixianWuxingjian.hit_ob(a, vic(200), 200, 0, max_rng()) == {0, nil}
    end

    test "max_neili < 2500 不触发" do
      a = qx_att(%{max_neili: 2499})
      assert QixianWuxingjian.hit_ob(a, vic(200), 200, 0, max_rng()) == {0, nil}
    end

    test "neili < 500 不触发" do
      a = qx_att(%{neili: 499})
      assert QixianWuxingjian.hit_ob(a, vic(200), 200, 0, max_rng()) == {0, nil}
    end

    test "自身 max_neili 低于对方不触发" do
      a = qx_att(%{max_neili: 2500})
      assert QixianWuxingjian.hit_ob(a, vic(2501), 200, 0, max_rng()) == {0, nil}
    end

    test "对方 max_neili < 10 不触发" do
      assert QixianWuxingjian.hit_ob(qx_att(), vic(9), 200, 0, max_rng()) == {0, nil}
    end

    test "对方 busy 时不触发" do
      assert QixianWuxingjian.hit_ob(qx_att(), vic(200, %{busy: 1}), 200, 0, max_rng()) ==
               {0, nil}
    end

    test "damage_bonus < 150 不触发" do
      assert QixianWuxingjian.hit_ob(qx_att(), vic(200), 149, 0, max_rng()) == {0, nil}
    end
  end

  describe "tanzhi-shentong hit_ob（弹指穴道）" do
    defp tz_att(extra \\ %{}),
      do:
        att(
          %{"tanzhi-shentong" => 100, "jingluo-xue" => 100},
          Map.merge(%{neili: 800}, extra)
        )

    test "条件齐备 → 额外创伤 (damage-100)/4，并附 busy 2" do
      {wound, msg, affects} = TanzhiShentong.hit_ob(tz_att(), vic(0), 200, 0, max_rng())

      assert wound == div(200 - 100, 4)
      assert msg == "只听“飕”的一声，$n被$N凌空弹射出的指气点中#{@last_acupoint}，全身登时一阵酸麻。\n"
      assert affects == [{"busy", %{"rounds" => 2}}]
    end

    test "damage_bonus < 150 不触发" do
      assert TanzhiShentong.hit_ob(tz_att(), vic(0), 149, 0, max_rng()) == {0, nil}
    end

    test "neili < 800 不触发" do
      assert TanzhiShentong.hit_ob(tz_att(%{neili: 799}), vic(0), 200, 0, max_rng()) == {0, nil}
    end

    test "本门 < 100 不触发" do
      a = att(%{"tanzhi-shentong" => 99, "jingluo-xue" => 100}, %{neili: 800})
      assert TanzhiShentong.hit_ob(a, vic(0), 200, 0, max_rng()) == {0, nil}
    end

    test "jingluo-xue < 100 不触发" do
      a = att(%{"tanzhi-shentong" => 100, "jingluo-xue" => 99}, %{neili: 800})
      assert TanzhiShentong.hit_ob(a, vic(0), 200, 0, max_rng()) == {0, nil}
    end

    test "对方 busy 时不触发" do
      assert TanzhiShentong.hit_ob(tz_att(), vic(0, %{busy: 1}), 200, 0, max_rng()) == {0, nil}
    end
  end

  describe "yiyang-zhi hit_ob（一阳指穴道）" do
    defp yy_att(extra \\ %{}),
      do:
        att(
          %{"yiyang-zhi" => 101, "jingluo-xue" => 101},
          Map.merge(%{neili: 301}, extra)
        )

    test "空手支：额外创伤 (damage-100)/3，并附 busy 2" do
      {wound, msg, affects} = YiyangZhi.hit_ob(yy_att(), vic(0), 200, 0, max_rng())

      assert wound == div(200 - 100, 3)
      assert msg == "只听“嗤”的一声，$n被$N凌空一指点中#{@last_acupoint}，真气不由得一滞。\n"
      assert affects == [{"busy", %{"rounds" => 2}}]
    end

    test "空手支 + 对方已 busy：仍造成创伤，但不追加忙乱（源仅 if(!is_busy) 才 start_busy）" do
      {wound, msg, affects} = YiyangZhi.hit_ob(yy_att(), vic(0, %{busy: 1}), 200, 0, max_rng())

      assert wound == div(200 - 100, 3)
      assert is_binary(msg)
      assert affects == []
    end

    test "持械支：额外创伤 (damage-100)/4，且**不**追加忙乱（源内怪癖）" do
      # 源持械支只 return 文案（无 affect），故契约回 2 元组
      {wound, msg} = YiyangZhi.hit_ob(yy_att(%{weapon_name: "铁杖"}), vic(0), 200, 0, max_rng())

      assert wound == div(200 - 100, 4)
      assert msg == "只听“嗤”的一声，$n被$N杖端发出的气劲刺中#{@last_acupoint}，真气不由得一滞。\n"
    end

    test "持械支 + 对方已 busy：整支不生效（源把 !is_busy 写进前置条件）" do
      assert YiyangZhi.hit_ob(yy_att(%{weapon_name: "铁杖"}), vic(0, %{busy: 1}), 200, 0, max_rng()) ==
               {0, nil}
    end

    test "damage_bonus < 150 不触发（两支共用前置）" do
      assert YiyangZhi.hit_ob(yy_att(), vic(0), 149, 0, max_rng()) == {0, nil}
      assert YiyangZhi.hit_ob(yy_att(%{weapon_name: "铁杖"}), vic(0), 149, 0, max_rng()) == {0, nil}
    end

    test "neili <= 300 不触发（源为严格大于）" do
      assert YiyangZhi.hit_ob(yy_att(%{neili: 300}), vic(0), 200, 0, max_rng()) == {0, nil}
    end

    test "本门 <= 100 不触发（源为严格大于）" do
      a = att(%{"yiyang-zhi" => 100, "jingluo-xue" => 101}, %{neili: 301})
      assert YiyangZhi.hit_ob(a, vic(0), 200, 0, max_rng()) == {0, nil}
    end

    test "jingluo-xue <= 100 不触发（源为严格大于）" do
      a = att(%{"yiyang-zhi" => 101, "jingluo-xue" => 100}, %{neili: 301})
      assert YiyangZhi.hit_ob(a, vic(0), 200, 0, max_rng()) == {0, nil}
    end
  end

  describe "引擎接线：hit_ob 的 busy affect 进入 Round.conditions" do
    defp fighter(opts) do
      %Fighter{
        id: Map.get(opts, :id, "f"),
        name: Map.get(opts, :name, "某"),
        pid: self(),
        str: Map.get(opts, :str, 20),
        dex: 20,
        con: 20,
        int: 20,
        combat_exp: 0,
        skills: Map.fetch!(opts, :skills),
        mapped: Map.get(opts, :mapped, %{}),
        applies: Map.get(opts, :applies, %{}),
        busy: Map.get(opts, :busy, 0),
        jiali: 0,
        neili: Map.get(opts, :neili, 0),
        max_neili: Map.get(opts, :max_neili, 0),
        attack_skill: Map.get(opts, :attack_skill, "unarmed"),
        weapon_name: Map.get(opts, :weapon_name)
      }
    end

    test "七弦无形剑命中后 Round.conditions 带 busy 1" do
      attacker =
        fighter(%{
          skills: %{
            "qixian-wuxingjian" => 200,
            "unarmed" => 300,
            "force" => 300,
            "dodge" => 300,
            "parry" => 300
          },
          mapped: %{"unarmed" => "qixian-wuxingjian"},
          attack_skill: "unarmed",
          applies: %{unarmed_damage: 400},
          max_neili: 3000,
          neili: 1000
        })

      victim =
        fighter(%{
          id: "v",
          name: "对手",
          skills: %{"dodge" => 1, "parry" => 1, "force" => 1},
          max_neili: 200,
          applies: %{armor: 0}
        })

      round = Engine.attack_round(attacker, victim, rng: max_rng())

      assert round.outcome == :hit
      assert {"busy", %{"rounds" => 1}} in round.conditions
    end

    test "对方已 busy 时七弦不触发，Round.conditions 为空" do
      attacker =
        fighter(%{
          skills: %{
            "qixian-wuxingjian" => 200,
            "unarmed" => 300,
            "force" => 300,
            "dodge" => 300,
            "parry" => 300
          },
          mapped: %{"unarmed" => "qixian-wuxingjian"},
          attack_skill: "unarmed",
          applies: %{unarmed_damage: 400},
          max_neili: 3000,
          neili: 1000
        })

      victim =
        fighter(%{
          id: "v",
          name: "对手",
          skills: %{"dodge" => 1, "parry" => 1, "force" => 1},
          max_neili: 200,
          applies: %{armor: 0},
          busy: 1
        })

      round = Engine.attack_round(attacker, victim, rng: max_rng())

      refute Enum.any?(round.conditions, fn
               {"busy", _} -> true
               _ -> false
             end)
    end
  end
end
