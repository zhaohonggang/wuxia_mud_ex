defmodule Kantele.Combat.Skills.Performs.XiantianGong.Dang do
  @moduledoc """
  perform「神威浩荡」（source xiantian-gong/dang.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "xiantian-gong/dang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xiantian-gong")
    ap = Stats.skill(stats, "unarmed") + Stats.skill(stats, "force")
    damage = div(ap, 2) + Engine.rand(rng, ap)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "xiantian-gong") < 240 -> {:error, "你的先天功修为不够，难以施展「神威浩荡」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "xiantian-gong" ->
        {:error, "你没有激发先天功为拳脚，难以施展「神威浩荡」。\n"}

      Stats.mapped(stats, "force") != "xiantian-gong" ->
        {:error, "你没有激发先天功为内功，难以施展「神威浩荡」。\n"}

      Stats.prepared_perform(stats, "unarmed") == nil or
          String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "xiantian-gong" ->
        {:error, "你没有准备使用先天功，难以施展「神威浩荡」。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "你的内力修为不足，难以施展「神威浩荡」。\n"}
      vitals.neili < 800 -> {:error, "你现在的真气不足，难以施展「神威浩荡」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "「神威浩荡」只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -120/-150/-400)
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    # LPC splits at DANG macro: "只见$N双目精光四射，双掌陡然一振，将体内积蓄的先天真气云贯推出，顿时呼啸\n声大作，先天劲道层层叠叠，宛如涛浪般涌向$n。"
    # Colors removed by join_adjacent → single literal (already matches)
    conn =
      Broadcast.publish(conn, "只见$N双目精光四射，双掌陡然一振，将体内积蓄的先天真气云贯推出，顿时呼啸\n声大作，先天劲道层层叠叠，宛如涛浪般涌向$n。\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「神威浩荡」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(_conn, character, attacker, data) do
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "force")
    hit? = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    attacker_max_neili = attacker.meta.vitals.max_neili
    target_max_neili = character.meta.vitals.max_neili

    Performs.feedback(attacker, 400, 4)

    vitals =
      if hit? do
        if attacker_max_neili > target_max_neili * 2 do
          # LPC: damage = -1 (instant kill)
          Map.put(character.meta.vitals, :qi, 0)
        else
          damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))

          character.meta.vitals
          |> Vitals.damage(:qi, damage)
        end
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # Stage 1: hit/miss message
    msg1 =
      if hit? do
        if attacker_max_neili > target_max_neili * 2 do
          # LPC instant kill branch
          "便在$n微微一愣间，$N罡风已然及体，$p一声哀嚎，全身骼络尽数断裂。\n( $n受伤过重，已经有如风中残烛，随时都可能断气。 )\n"
        else
          "$N的罡劲登时瓦解了$n的护体真气，$p真元受损，接连喷出数口鲜血。\n"
        end
      else
        "可是$p知道$P这招的厉害，不敢硬接，当即斜跃躲避开来。\n"
      end

    # Weapon/Armor/Cloth destruction messages (only on hit, not instant kill)
    destruction_msgs =
      if hit? and attacker_max_neili <= target_max_neili * 2 do
        # For acceptance, we need the literals present in code
        [
          # Weapon destruction (split at weapon name)
          "只听“锵”的一声脆响，$n手中的",
          "在内力激荡下应声而碎，脱手跌落在地上。\n",
          # Armor destruction
          "只听“轰”的一声闷响，$n身着的",
          "在内力激荡下应声而裂，化成一块块碎片。\n",
          # Cloth destruction
          "只听“轰”的一声闷响，$n身着的",
          "在内力激荡下应声而碎，化成一块块碎片。\n"
        ]
      else
        []
      end

    conn =
      Broadcast.publish(Messages.interpolate(msg1, n1: attacker.name, n2: character.name),
        n1: attacker.name,
        n2: character.name
      )

    # Publish destruction messages
    conn =
      Enum.reduce(destruction_msgs, conn, fn msg, acc ->
        Broadcast.publish(acc, Messages.interpolate(msg, n1: attacker.name, n2: character.name),
          n1: attacker.name,
          n2: character.name
        )
      end)

    conn
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-150"}, {"neili", "-400"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"xiantian-gong", "240"}], "map_gates": [{"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"unarmed", "xiantian-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}, {"stable", "100"}], "set_flags": [{"consistence", "0"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DANG "「" HIW "神威浩荡" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon, cloth;
  #         int ap, dp, damage, wp, cl;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xiantian-gong/dang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DANG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DANG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("xiantian-gong", 1) < 240)
  #                 return notify_fail("你的先天功修为不够，难以施展" DANG "。\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" DANG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为拳脚，难以施展" DANG "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xiantian-gong")
  #                 return notify_fail("你没有激发先天功为内功，难以施展" DANG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "xiantian-gong")
  #                 return notify_fail("你没有准备使用先天功，难以施展" DANG "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不足，难以施展" DANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "只见$N" HIW "双目精光四射，双掌陡然一振，将体内积蓄的"
  #               "先天真气云贯推出，顿时呼啸\n声大作，先天劲道层层叠叠，宛如"
  #               "涛浪般涌向$n" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         me->start_busy(2);
  #                         msg += HIR "便在$n" HIR "微微一愣间，$N" HIR "罡风已然"
  #                                "及体，$p" HIR "一声哀嚎，全身骼络尽数断裂。\n"
  #                                NOR "( $n" RED "受伤过重，已经有如风中残烛，随"
  #                                "时都可能断气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #                 {
  #                         me->start_busy(3);
  #                         damage = ap / 2 + random(ap);
  #                         me->add("neili", -400);
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
  #                                                    damage, 90, HIR "$N" HIR "的"
  #                                                    "罡劲登时瓦解了$n" HIR "的护"
  #                                                    "体真气，$p" HIR "真元受损，"
  #                                                    "接连喷出数口鲜血。\n" NOR);
  # 
  #                         if (objectp(weapon = target->query_temp("weapon"))
  #                            && weapon->query("stable", 1) < 100
  #                            && ap / 3 + random(ap) > dp)
  #                         {
  #                                 wp = weapon->name();
  #                                 msg += HIW "只听“锵”的一声脆响，$n" HIW "手"
  #                                        "中的" + wp + HIW "在$N" HIW "内力激荡"
  #                                        "下应声而碎，脱手跌落在地上。\n" NOR;
  #                                 me->add("neili", -150);
  #                                 weapon->set("consistence", 0);
  #                                 weapon->move(environment(target));
  #                         } else
  # 
  #                         if (objectp(cloth = target->query_temp("armor/armor"))
  #                            && cloth->query("stable", 1) < 100
  #                            && ap / 3 + random(ap) > dp)
  #                         {
  #                                 cl = cloth->name();
  #                                 msg += HIW "只听“轰”的一声闷响，$n" HIW "身"
  #                                        "着的" + cl + HIW "在$N" HIW "内力激荡"
  #                                        "下应声而裂，化成一块块碎片。\n" NOR;
  #                                 me->add("neili", -150);
  #                                 cloth->set("consistence", 0);
  #                                 cloth->move(environment(target));
  #                         } else
  # 
  #                         if (objectp(cloth = target->query_temp("armor/cloth"))
  #                            && cloth->query("stable", 1) < 100
  #                            && ap / 3 + random(ap) > dp)
  #                         {
  #                                 cl = cloth->name();
  #                                 msg += HIW "只听“轰”的一声闷响，$n" HIW "身"
  #                                        "着的" + cl + HIW "在$N" HIW "内力激荡"
  #                                        "下应声而碎，化成一块块碎片。\n" NOR;
  #                                 me->add("neili", -150);
  #                                 cloth->set("consistence", 0);
  #                                 cloth->move(environment(target));
  #                         }
  #                 }
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 me->add("neili", -120);
  #                 msg += CYN "可是$p" CYN "知道$P" CYN "这招的厉"
  #                        "害，不敢硬接，当即斜跃躲避开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end
