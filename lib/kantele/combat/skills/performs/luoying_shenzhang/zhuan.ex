defmodule Kantele.Combat.Skills.Performs.LuoyingShenzhang.Zhuan do
  @moduledoc """
  perform「奇门五转」（对照 `kungfu/skill/luoying-shenzhang/zhuan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手（主/副兵器皆无）→
  落英神剑掌>=120 → 奇门五行>=120 → 激发 `strike` 为落英神剑掌 → 准备落英神剑掌 →
  内功>=180 → 真气>=300 → 目标存活。
  攻击方扣 150 真气；命中判定 `ap/2 + random(ap)`
  （`ap = 落英神剑掌 + 奇门五行 + 内功 + int*10`）对
  目标 `dodge + parry + 奇门五行 + int*10`：命中则目标忙乱 `2 + random(3)`、
  攻击方忙乱 2，目标 qi 伤 `(内功+掌法)/4`（再 `+random(该值)`）、qi 上限伤 `damage*30/100`；
  未命中则攻击方忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., 30, "…")`（第 6 参为文案字面量）折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*30/100)` 并广播该文案；
  - `ap`/`dp` 判定在目标侧结算（目标 dodge/parry/奇门五行/int 只在自身进程可得），
    故命中/未命中两条分支文案由目标侧广播；`.c` 是累积到 `msg` 后一次
    `message_vision`，此处按引擎惯例拆为攻击方起手 + 目标侧分支（同
    `guzhuo_zhang/yu.ex`）；
  - `.c` 的 `me->add("neili", -150)` 无条件 → 攻击方结算；`me->start_busy(2)`（命中）
    与 `me->start_busy(3)`（未命中）在分支内 → 由目标侧 `Performs.feedback` 回执；
  - `me->query("int")` 折算为 `Stats.query_int/1`（base+tattoo+reborn+literate/10）；
  - `query_skill_prepared("strike")` 以 `Stats.prepared_perform/2` 的**技能前缀**比对
    （该接口返回绝招 ID 如 `"luoying-shenzhang/zhuan"`）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "luoying-shenzhang/zhuan"
  @move_name "「奇门五转」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: ap = luoying-shenzhang + qimen-wuxing + force + me->query("int") * 10;
    ap =
      Stats.skill(stats, "luoying-shenzhang") +
        Stats.skill(stats, "qimen-wuxing") +
        Stats.skill(stats, "force") +
        Stats.query_int(stats) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_level(stats),
         :ok <- check_qimen(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("luoying-shenzhang", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "luoying-shenzhang") < 120 do
      {:error, "你的落英神剑掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("qimen-wuxing", 1) < 120)
  defp check_qimen(stats) do
    if Stats.skill(stats, "qimen-wuxing") < 120 do
      {:error, "你对奇门五行的研究不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "luoying-shenzhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "luoying-shenzhang" do
      :ok
    else
      {:error, "你没有激发落英神剑掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "luoying-shenzhang")
  # `Stats.prepared_perform/2` 返回绝招 ID（如 "luoying-shenzhang/zhuan"），按技能前缀比对。
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "luoying-shenzhang" do
      :ok
    else
      {:error, "你没有准备落英神剑掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的内力不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "掌势陡然一变，施出落英神剑掌「奇门五转」绝技，虚虚"
    #            "实实的攻向$n" HIY "。\n" NOR;
    #      me->add("neili", -150);（无条件）
    # 命中/未命中分支与伤害在目标侧结算（见 resolve_incoming）。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "$N掌势陡然一变，施出落英神剑掌#{@move_name}绝技，虚虚实实的攻向$n。\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge") + target->query_skill("parry")
    #        + target->query_skill("qimen-wuxing", 1) + target->query("int") * 10;
    dp =
      Stats.skill(stats, "dodge") +
        Stats.skill(stats, "parry") +
        Stats.skill(stats, "qimen-wuxing") +
        Stats.query_int(stats) * 10

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: target->start_busy(2 + random(3)); me->start_busy(2);
      #      damage = (me->query_skill("force") + me->query_skill("strike")) / 4;
      #      damage += random(damage);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30, "…");
      damage = div(Stats.skill(stats, "force") + Stats.skill(stats, "strike"), 4)
      damage = damage + Engine.rand(rng, damage)

      combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish("$n大吃一惊，登时接连中掌，狂喷出一口鲜血，身子急转个不停。\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(3); msg += "可是$p看破了$P的企图，连消带打，避开了$P这一击。\n";
      Performs.feedback(attacker, 0, 3)
      Broadcast.publish(conn, "可是$p看破了$P的企图，连消带打，避开了$P这一击。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUAN "「" HIY "奇门五转" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/luoying-shenzhang/zhuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("luoying-shenzhang", 1) < 120)
  #                 return notify_fail("你的落英神剑掌不够娴熟，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query_skill("qimen-wuxing", 1) < 120)
  #                 return notify_fail("你对奇门五行的研究不够，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "luoying-shenzhang")
  #                 return notify_fail("你没有激发落英神剑掌，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "luoying-shenzhang")
  #                 return notify_fail("你没有准备落英神剑掌，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不足，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的内力不够，难以施展" ZHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "掌势陡然一变，施出落英神剑掌「奇门五转」绝技，虚虚"
  #               "实实的攻向$n" HIY "。\n" NOR;
  # 
  #         ap = (int)me->query_skill("luoying-shenzhang", 1) +
  #              (int)me->query_skill("qimen-wuxing", 1) +
  #              (int)me->query_skill("force") +
  #              (int)me->query("int") * 10;
  # 
  #         dp = (int)target->query_skill("dodge") +
  #              (int)target->query_skill("parry") +
  #              (int)target->query_skill("qimen-wuxing", 1) +
  #              (int)target->query("int") * 10;
  # 
  #         me->add("neili", -150);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 target->start_busy(2 + random(3));
  #             me->start_busy(2);
  #                 damage = (int)me->query_skill("force") + (int)me->query_skill("strike");
  #                 damage = damage / 4;
  #                 damage += random(damage);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "大吃一惊，登时接连中掌，"
  #                                            "狂喷出一口鲜血，身子急转个不停。\n" NOR);
  #         } else
  #     {
  #             me->start_busy(3);
  #                 msg += HIC "可是$p" HIC "看破了$P" HIC "的企图，连消带打，避开了$P"
  #                        HIC "这一击。\n"NOR;
  #     }
  #         message_vision(msg, me, target);
  #         return 1;
  # }
end
