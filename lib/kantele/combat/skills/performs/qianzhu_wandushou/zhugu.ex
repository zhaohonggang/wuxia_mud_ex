defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Zhugu do
  @moduledoc """
  perform「蛛蛊决」（对照 `kungfu/skill/qianzhu-wandushou/zhugu.c`）

  门槛（按 .c 顺序）：已学此招 → 房间 no_fight → 目标（ offensive_target ）
  且是活体角色 → 目标未死 → 内功>=200 → 千蛛万毒手>=130 →
  激发 hand 为千蛛万毒手 → 真气>=400。
  起手广播后按 `combat_exp` 与「手」类武学前 5 项等级折算 `improve`
  （五毒教额外 +0.1），`lvl = 基本手法 + lvl*improve`，
  `poison = 基本毒技/15`；命中判定 `lvl/2 + random(lvl)` 对目标内功：
  命中则 `damage = lvl + random(lvl/2)`、外伤 `50 + poison` 比例，
  并令目标中 `qianzhu_wandushou` 毒（level/duration 见 LPC），攻击方
  扣 200 真气并忙乱 2；未命中则攻击方扣 80 真气并忙乱 4。

  差异（TODO(migrate)）：
  - `target->affect_by("qianzhu_wandushou", …)` 折算为
    `ConditionEvent.apply_poison/2`（`.c` 未给毒名，此处补 `"蛛蛊毒"`
    供显示，属信息性补充）；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的仇恨标志本引擎未建模，
    战斗关系由 `combat.enemies` 表达，故不落代码（仅在此说明）；
  - `target->query("not_living")` 未建模，目标侧
    `combat/perform-incoming` 的死亡检查兜底（同 `living(target)` 门槛）；
  - `query_skill_mapped("hand")` 直接比对 `Stats.mapped/2`（技能 ID）；
  - `environment(me)->query("no_fight")` 按 `force/roar.ex` 的约定读
    `character.meta.room` 的 `:no_fight` 标志；
  - 起手与分支文案在 `.c` 里累加进同一 `msg` 后一次 `message_combatd`，
    E 侧拆两处：起手在攻击方发布，分支文案在目标侧发布（判定需目标内功）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Family
  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "qianzhu-wandushou/zhugu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
    #      lvls = lvls * 4 / 5;
    #      ks = keys(me->query_skills("hand")); improve = 0; n = 0;
    #      for (m = 0; m < sizeof(ks); m++)
    #      {
    #              if (SKILL_D(ks[m])->valid_enable("hand"))
    #              {
    #                      n += 1; improve += (int)me->query_skill(ks[m], 1);
    #                      if (n > 4) break;
    #              }
    #      }
    #      improve = improve * 5 / 100 / lvls;
    lvls = trunc(:math.pow(max(stats.combat_exp, 1) * 10, 1 / 3) * 4 / 5)

    skill_sum =
      stats.skills
      |> Map.values()
      |> Enum.sort(:desc)
      |> Enum.take(5)
      |> Enum.sum()

    improve = skill_sum * 5 / 100 / max(lvls, 1)

    # LPC: if (me->query("family/family_name") == "五毒教") improve += 0.1;
    family = Family.name(Map.get(character.meta, :family, %{}))

    improve =
      if family == "五毒教" do
        improve + 0.1
      else
        improve
      end

    # LPC: lvl = me->query_skill("hand");
    #      poison = me->query_skill("poison");
    #      poison = (int)poison / 15;
    #      lvl += lvl * improve;
    lvl = Stats.skill(stats, "hand")
    poison = div(Stats.skill(stats, "poison"), 15)
    lvl = lvl + trunc(lvl * improve)

    with :ok <- check_perform_known(character),
         :ok <- check_no_fight(character),
         {:ok, target} <- target(combat),
         :ok <- check_target_living(target),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          lvl: lvl,
          poison: poison,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/zhugu"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (environment(me)->query("no_fight"))
  #              return notify_fail("这里不能攻击别人！\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "这里不能攻击别人！\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! target->is_character())
  #              return notify_fail("你要对谁施展蛛蛊决？\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要对谁施展蛛蛊决？\n"}
    end
  end

  # LPC: if (target->query("not_living"))
  #              return notify_fail("看清楚，那不是活人。\n");
  defp check_target_living(_target) do
    # not_living 目标未建模：敌人列表只收录战斗进程，
    # 由目标侧 combat/perform-incoming 的死亡检查兜底。
    _msg = "看清楚，那不是活人。\n"
    :ok
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  #      if ((int)me->query_skill("qianzhu-wandushou", 1) < 130)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不足以施展蛛蛊决。\n"}

      Stats.skill(stats, "qianzhu-wandushou") < 130 ->
        {:error, "你的千蛛万毒手修为不够，现在还无法施展蛛蛊决。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "qianzhu-wandushou")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "qianzhu-wandushou" do
      :ok
    else
      {:error, "你没有激发千蛛万毒手，无法施展蛛蛊决。\n"}
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，现在无法施展蛛蛊决。\n"}
    else
      :ok
    end
  end

  # LPC: msg = HIB "$N" HIB "施出蛛蛊决，只见一缕黑气从"
  #              "指尖透出，只一闪就没入了$n" HIB "的眉心！\n" NOR;
  #      …命中/失手在目标侧结算（dp 需目标内功）…
  defp apply_effect(conn, character, target) do
    conn
    |> Broadcast.publish(
      "$N施出蛛蛊决，只见一缕黑气从指尖透出，只一闪就没入了$n的眉心！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    lvl = Map.get(data, :lvl, 0)
    poison = Map.get(data, :poison, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (lvl / 2 + random(lvl) > target->query_skill("force"))
    if div(lvl, 2) + Engine.rand(rng, lvl) > Stats.skill(character.meta.stats, "force") do
      # LPC: damage = lvl + random(lvl / 2);
      damage = lvl + Engine.rand(rng, div(lvl, 2))

      # LPC: target->affect_by("qianzhu_wandushou",
      #          ([ "level" : lvl * 2 / 3 + random(poison),
      #             "id"    : me->query("id"),
      #             "duration" : lvl / 40 + random(lvl / 18) ]));
      poison_level = div(lvl * 2, 3) + Engine.rand(rng, poison)
      poison_duration = div(lvl, 40) + Engine.rand(rng, div(lvl, 18))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "蛛蛊毒"
        })

      # LPC: msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage,
      #                                50 + poison, HIR "$p" HIR "…");
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * (50 + poison), 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -200); me->start_busy(2);
      Performs.feedback(attacker, 200, 2)

      conn
      |> Broadcast.publish(
        "$p只觉得一股如山的劲力顺指尖猛攻过来，只觉得全身毒气狂窜，“哇”的一声吐出一口黑血！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -80);
      #      msg += CYN "可是$p" CYN "运足内力，以深厚的内功"
      #             "化解了这一指的毒劲。\n" NOR;
      Performs.feedback(attacker, 80, 4)

      conn
      |> Broadcast.publish("可是$p运足内力，以深厚的内功化解了这一指的毒劲。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int lvl, poison;
  #         int damage;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "hand";
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/zhugu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("这里不能攻击别人！\n");
  # 
  #     if (! target || ! target->is_character())
  #         return notify_fail("你要对谁施展蛛蛊决？\n");
  # 
  #     if (target->query("not_living"))
  #         return notify_fail("看清楚，那不是活人。\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不足以施展蛛蛊决。\n");
  # 
  #         if ((int)me->query_skill("qianzhu-wandushou", 1) < 130)
  #                 return notify_fail("你的千蛛万毒手修为不够，现在还无法施展蛛蛊决。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "qianzhu-wandushou")
  #                 return notify_fail("你没有激发千蛛万毒手，无法施展蛛蛊决。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，现在无法施展蛛蛊决。\n");
  # 
  #         msg = HIB "$N" HIB "施出蛛蛊决，只见一缕黑气从"
  #               "指尖透出，只一闪就没入了$n" HIB "的眉心！\n" NOR;
  # 
  #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvls = lvls * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvls;
  # 
  #         if (me->query("family/family_name") == "五毒教")
  #             improve += 0.1;
  # 
  #         lvl = me->query_skill("hand");
  #         poison = me->query_skill("poison");
  # 
  #         poison = (int)poison / 15;
  #         lvl += lvl * improve;
  # 
  #         if (lvl / 2 + random(lvl) > target->query_skill("force"))
  #         {
  #                 damage = lvl + random(lvl / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50 + poison,
  #                                            HIR "$p" HIR "只觉得一股如山的劲力顺指尖猛"
  #                                            "攻过来，只觉得全身毒气狂窜，“哇”的一声"
  #                                            "吐出一口黑血！\n" NOR);
  #                 target->affect_by("qianzhu_wandushou",
  #                                   ([ "level" : lvl * 2 / 3 + random(poison),
  #                                      "id"    : me->query("id"),
  #                                      "duration" : lvl / 40 + random(lvl / 18) ]));
  #                 me->add("neili", -200);
  #                 me->start_busy(2);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "运足内力，以深厚的内功"
  #                        "化解了这一指的毒劲。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -80);
  #         }
  #         message_combatd(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #         return 1;
  # }
end
