defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Po do
  @moduledoc """
  perform「破神诀」（source liuyang-zhang/po.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `PO`（→「破神诀」）展开；命中判定、内力比拼
  即杀、外伤比例与攻击方忙乱按原始 LPC 语义建模。

  - LPC 用 `max_neili` 二倍比拼决定「头骨拍碎」即杀，否则 `do_damage` 90% 外伤。
  - 攻击方 `ap` 的「同类武技广度加成」（valid_enable 循环）框架无法建模，取 0。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Family
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "liuyang-zhang/po"

  # LPC: #define PO "「" HIR "破神诀" NOR "」"
  @move_name "「破神诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      {ap, max_neili} = attack_power(character)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          max_neili: max_neili,
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("bahuang-gong", 1) < 220)
  #      if (me->query_skill("liuyang-zhang", 1) < 220)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bahuang-gong") < 220 ->
        {:error, "你八荒六合唯我独尊功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "liuyang-zhang") < 220 ->
        {:error, "你的天山六阳掌不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 3500)
  #      if (me->query("neili") < 800)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 800 ->
        {:error, "你现在真气不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #      if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #      if (me->query_skill_mapped("force") != "bahuang-gong")
  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "liuyang-zhang" ->
        {:error, "你没有激发天山六阳掌，难以施展#{@move_name}。\n"}

      prepared_is_not?(stats, "strike", "liuyang-zhang") ->
        {:error, "你没有准备天山六阳掌，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "force") != "bahuang-gong" ->
        {:error, "你没有激发八荒六合唯我独尊功，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC query_skill_prepared 返回绝招 ID（如 "liuyang-zhang/po"），需按技能前缀比对。
  defp prepared_is_not?(stats, skill, mapped) do
    case Stats.prepared_perform(stats, skill) do
      nil -> true
      prepared -> hd(String.split(prepared, "/")) != mapped
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: ap = me->query_skill("force") + me->query_skill("strike");
  #      ap += ap * improve;（improve 见下）
  #      if (me->query("family/family_name") == "灵鹫宫") ap += ap / 10;
  defp attack_power(character) do
    stats = character.meta.stats

    # LPC: improve =（query_skills("strike") 中可 valid_enable 者，最多 5 个，
    #      累加其等级） * 4 / 100 / lvl;  lvl = (combat_exp*10)^(1/3) * 4/5。
    # 框架战斗态只存基本技能表（stats.skills）与当前激发映射（stats.mapped），
    # 不持有「所有已学 strike 类武技」清单，该广度加成无法建模，improve 取 0
    # （即 LPC 中未多学同类武技时的取值）。
    improve = 0.0
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "strike")
    ap = ap + trunc(ap * improve)

    family = Map.get(character.meta, :family, %{})
    ap = if Family.name(family) == "灵鹫宫", do: ap + div(ap, 10), else: ap

    {ap, character.meta.vitals.max_neili}
  end

  # LPC: me->add("neili", -380);（无条件）
  defp apply_effect(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 380}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: msg = HIR "$N" HIR "将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌"
    #               "向$n" HIR "头顶猛然贯落。\n" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌向$n头顶猛然贯落。\n",
        n1: character.name,
        n2: target.name
      )

    conn
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
    attacker_max_neili = Map.get(data, :max_neili, 0)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("force") + target->query_skill("parry");
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry")

    # LPC: if (target->is_good()) ap += ap / 10;
    # is_good() = shen > 500 || shen_type == 1；框架只存 shen，shen_type 未建模。
    ap = if Map.get(stats, :shen, 0) > 500, do: ap + div(ap, 10), else: ap

    # LPC: if (ap / 2 + random(ap) > dp)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp
    bindings = [n1: attacker.name, n2: character.name]

    if hit? do
      {vitals, combat, msg} =
        if attacker_max_neili > character.meta.vitals.max_neili * 2 do
          # LPC: msg += HIR "顿时只听“噗”的一声，$N" HIR "一掌将$n" HIR "头骨拍得粉碎，
          #      脑浆四溅，当即瘫了下去。\n" NOR "( $n" RED "受伤过重，已经有如风中残烛，"
          #      "随时都可能断气。" NOR ")\n";（合并为单段）
          msg =
            "顿时只听“噗”的一声，$N一掌将$n头骨拍得粉碎，脑浆四溅，当即瘫了下去。\n( $n受伤过重，已经有如风中残烛，随时都可能断气。)\n"

          # LPC: damage = -1; ... if (damage < 0) target->die(me);
          vitals = %{character.meta.vitals | qi: 0}
          combat = %{character.meta.combat | dead: true}
          {vitals, combat, msg}
        else
          # LPC: damage = ap + random(ap / 2);
          damage = ap + Engine.rand(rng, div(ap, 2))

          vitals =
            character.meta.vitals
            |> Vitals.damage(:qi, damage)
            |> Vitals.wound(:qi, div(damage * 90, 100))

          # LPC: HIR "$n" HIR "慌忙抵挡，可已然不及，$N" HIR "掌劲如洪水般涌入体内，
          #      接连震断数根" "肋骨。\n:内伤@?"（合并为单段）
          {vitals, character.meta.combat,
           "$n慌忙抵挡，可已然不及，$N掌劲如洪水般涌入体内，接连震断数根肋骨。\n:内伤@?"}
        end

      # LPC: me->start_busy(1 + random(3));（仅命中分支）
      _ = Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 3))

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(msg, bindings)
      |> put_character(character)
    else
      # LPC: CYN "$p" CYN "见$P" CYN "掌劲澎湃，决计抵挡不" "住，当即身子向后横丈许，
      #      躲闪开来。\n" NOR;（合并为单段）
      # LPC: me->start_busy(1 + random(4));（仅失手分支）
      _ = Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 4))

      conn
      |> Broadcast.publish(
        "$p见$P掌劲澎湃，决计抵挡不住，当即身子向后横丈许，躲闪开来。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIR "破神诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //        object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         //me = this_player();
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "strike";
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(PO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("bahuang-gong", 1) < 220)
  #                 return notify_fail("你八荒六合唯我独尊功火候不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 220)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" PO "。\n");
  # 
  #         if (me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发天山六阳掌，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有准备天山六阳掌，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "bahuang-gong")
  #                 return notify_fail("你没有激发八荒六合唯我独尊功，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在真气不足，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌"
  #               "向$n" HIR "头顶猛然贯落。\n" NOR;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
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
  #         improve = improve * 4 / 100 / lvl;
  # 
  #         me->add("neili", -380);
  #         ap = me->query_skill("force") + me->query_skill("strike");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #         ap += ap * improve;
  #         if (me->query("family/family_name") == "灵鹫宫")
  #             ap += ap / 10;
  #         if (target->is_good()) ap += ap / 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "顿时只听“噗”的一声，$N" HIR "一掌将$n"
  #                                HIR "头骨拍得粉碎，脑浆四溅，当即瘫了下去。\n"
  #                                NOR "( $n" RED "受伤过重，已经有如风中残烛，"
  #                                "随时都可能断气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #             {
  #             //damage = ap * 2 / 3;
  #                     damage = ap + random(ap / 2);
  # 
  #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                                HIR "$n" HIR "慌忙抵挡，可已然不及，$N"
  #                                                    HIR "掌劲如洪水般涌入体内，接连震断数根"
  #                                                    "肋骨。\n:内伤@?");
  #             }
  #             me->start_busy(1 + random(3));
  #         } else
  #         {
  #             msg += CYN "$p" CYN "见$P" CYN "掌劲澎湃，决计抵挡不"
  #                        "住，当即身子向后横丈许，躲闪开来。\n" NOR;
  #             me->start_busy(1 + random(4));
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #     return 1;
  # }
end
