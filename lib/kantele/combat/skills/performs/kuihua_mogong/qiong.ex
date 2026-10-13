defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Qiong do
  @moduledoc """
  perform「无穷无尽」（source kuihua-mogong/qiong.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 葵花魔功>=250 →
  内力上限>=3800 → 内力>=200 → 武器须为剑/针（空手则须准备 unarmed 为
  葵花魔功）→ 有武器则激发 sword、空手则准备 unarmed 为葵花魔功 → 目标存活。
  施法即扣 60 内力、忙乱 1+random(2)。
  dp = 目标战斗经验/10000，三分支：
    dp>=100：对百万经验以上仍造成伤害——ap1=葵花魔功+轻功 对
      dp1=目标闪避+目标武学修养（ap1*2/3+random(ap1)>dp1 命中），
      命中伤害 ap/2+random(ap)、95+random(5)% 外伤、扣 80 内力；
    否则 random(ap)>dp：一击必杀（target->die），扣 120 内力；
    否则：仅躲闪文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "kuihua-mogong/qiong"
  @move_name "「无穷无尽」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    ap = Stats.skill(stats, "kuihua-mogong")
    ap1 = Stats.skill(stats, "kuihua-mogong") + Stats.skill(stats, "dodge")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon_type(combat, character),
         :ok <- check_weapon_mapped(combat, character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          ap1: ap1,
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
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("kuihua-mogong", 1) < 250)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuihua-mogong") < 250 do
      {:error, "你的葵花魔功还不够娴熟，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 3800) / if (me->query("neili") < 200)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3800 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 200 -> {:error, "你的真气不够，无法施展#{@move_name}\n"}
      true -> :ok
    end
  end

  # LPC: if (weapon = me->query_temp("weapon"))
  #          { 若武器非剑/针则「你手里拿的不是剑，怎么施展…？」 }
  #          else { 若未准备 unarmed 为葵花魔功则「你并没有准备使用葵花魔功，如何施展…？」 }
  defp check_weapon_type(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你并没有准备使用葵花魔功，如何施展#{@move_name}？\n"}
        else
          :ok
        end

      %{skill_type: st} when st == "sword" or st == "pin" ->
        :ok

      _ ->
        {:error, "你手里拿的不是剑，怎么施展#{@move_name}？\n"}
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  #     if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #          return notify_fail("你没有准备使用葵花魔功，难以施展…。\n");
  defp check_weapon_mapped(combat, character) do
    case Combat.weapon(combat) do
      nil ->
        prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

        if prepared == nil or hd(String.split(prepared, "/")) != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end

      _ ->
        if Stats.mapped(character.meta.stats, "sword") != "kuihua-mogong" do
          {:error, "你没有准备使用葵花魔功，难以施展#{@move_name}。\n"}
        else
          :ok
        end
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIR "\n$N" HIR "尖啸一声，猛然进步欺前，一招竟直袭$n" …
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  # LPC: me->add("neili", -60); me->start_busy(1 + random(2));（命中与否都扣）
  defp apply_effect(conn, character, target) do
    msg = "\n$N尖啸一声，猛然进步欺前，一招竟直袭$n要害，速度之快，令人见所未见，闻所未闻。\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 60}
    combat = Combat.start_busy(character.meta.combat, 1 + :rand.uniform(2) - 1)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
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
    ap = max(Map.get(data, :ap, 0), 1)
    ap1 = max(Map.get(data, :ap1, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query("combat_exp") / 10000;
    dp = div(stats.combat_exp, 10000)

    cond do
      # LPC: if (dp >= 100) // 对百万经验以上无效，但是仍然受到伤害
      dp >= 100 ->
        # LPC: dp1 = target->query_skill("dodge", 1) + target->query_skill("martial-cognize", 1);
        dp1 = Stats.skill(stats, "dodge") + Stats.skill(stats, "martial-cognize")

        if div(ap1 * 2, 3) + Engine.rand(rng, ap1) > dp1 do
          # LPC: damage = ap / 2 + random(ap);
          #          do_damage(me, target, REMOTE_ATTACK, damage, 95 + random(5), …);
          #          me->add("neili", -80);
          damage = div(ap, 2) + Engine.rand(rng, ap)
          percent = 95 + Engine.rand(rng, 5)
          character = apply_damage(character, damage, percent)
          Performs.feedback(attacker, 80, 0)

          conn
          |> Broadcast.publish(
            Messages.interpolate(
              "这一招速度之快完全超出了$n的想象，$n慌忙回缩招架，但是此招之快，已无从躲闪，$n尖叫一声，已然中招。\n",
              bindings
            )
          )
          |> put_character(character)
        else
          conn
          |> Broadcast.publish(
            Messages.interpolate("$n知道来招不善，急忙闪避，没出一点差错。\n", bindings)
          )
          |> put_character(character)
        end

      # LPC: if (random(ap) > dp) → target->die(me)
      Engine.rand(rng, ap) > dp ->
        vitals = %{character.meta.vitals | qi: 0}
        combat = %{character.meta.combat | dead: true}
        character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
        # LPC: me->add("neili", -120);
        Performs.feedback(attacker, 120, 0)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "这一招速度之快完全超出了$n的想象，被$N这一招正好击中了丹田要害，浑身真气登时涣散！\n",
            bindings
          )
        )
        |> put_character(character)

      true ->
        conn
        |> Broadcast.publish(
          Messages.interpolate("$n大吃一惊，连忙退后，居然侥幸躲开着这一招！\n", bindings)
        )
        |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // qiong 无穷无尽
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define QIONG "「" HIR "无穷无尽" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp, ap1, dp1, damage;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/qiong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(QIONG "只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_skill("kuihua-mogong", 1) < 250)
  #         return notify_fail("你的葵花魔功还不够娴熟，不能使用" QIONG "！\n");
  # 
  #         if ((int)me->query("max_neili") < 3800)
  #                 return notify_fail("你的内力修为不足，难以施展" QIONG "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展" QIONG "\n");
  # 
  #         if (weapon = me->query_temp("weapon"))
  #         {
  #                 if (weapon->query("skill_type") != "sword" &&
  #                     weapon->query("skill_type") != "pin")
  #                         return notify_fail("你手里拿的不是剑，怎么施"
  #                                            "展" QIONG "？\n");
  #         } else
  #         {
  #                 if (me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                         return notify_fail("你并没有准备使用葵"
  #                                            "花魔功，如何施展" QIONG "？\n");
  #         }
  #         if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" QIONG "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" QIONG "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "\n$N" HIR "尖啸一声，猛然进步欺前，一招竟直袭$n" HIR "要害，速度之快，令"
  #               "人见所未见，闻所未闻。\n" NOR;
  # 
  #     me->want_kill(target);
  #         ap = me->query_skill("kuihua-mogong", 1);
  #         dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(2));
  # 
  #         if (dp >= 100) // 对百万经验以上无效，但是仍然受到伤害
  #         {
  #                 ap1 = me->query_skill("kuihua-mogong", 1) + me->query_skill("dodge", 1);
  #                 dp1 = target->query_skill("dodge", 1) + target->query_skill("martial-cognize", 1);
  #                 if (ap1 * 2 / 3 + random(ap1) > dp1)
  #                 {
  #                      damage = ap / 2 + random(ap);
  #                      msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 95 + random(5),
  #                                                 HIR "这一招速度之快完全超出了$n" HIR "的想象，$n" HIR
  #                                                 "慌忙回缩招架，但是此招之快，已无从躲闪，$n" HIR "尖叫"
  #                                                 "一声，已然中招。\n" NOR);
  #                      me->add("neili", -80);
  #                 }
  #                 else
  #                 {
  #                      msg += HIC "$n" HIC "知道来招不善，急忙闪避，没出一点差错。\n" NOR;
  #                 }
  #                 message_sort(msg, me, target);
  #                 return 1;
  #         } else
  #         if (random(ap) > dp)
  #         {
  #                 msg += HIR "这一招速度之快完全超出了$n" HIR "的想象，被$N"
  #                        HIR "这一招正好击中了丹田要害，浑身真气登时涣散！\n" NOR;
  #                 message_combatd(msg, me, target);
  #                 me->add("neili", -120);
  #                 target->die(me);
  #                 return 1;
  #         } else
  #         {
  #                 msg += HIM "$n" HIM "大吃一惊，连忙退后，居然"
  #                       "侥幸躲开着这一招！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
