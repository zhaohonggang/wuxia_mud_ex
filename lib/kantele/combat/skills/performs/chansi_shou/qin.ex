defmodule Kantele.Combat.Skills.Performs.ChansiShou.Qin do
  @moduledoc """
  perform「缠丝擒拿」（source chansi-shou/qin.c，由 translate_perform.py 生成，inherit F_SSERVER）

  命中：扣 80 真气、`damage = 50 + ap/6 + random(ap/6)`、35% 比例外伤，busy 2；
  未命中：扣 20 真气、busy 3。
  `final/3`（do_damage 回调）在目标侧追加后半段文案：2/3 概率让对方
  busy damage/15，否则鲜血狂喷。
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
  alias Kantele.Combat.Performs

  @perform_id "chansi-shou/qin"
  @move_name "「缠丝擒拿」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chansi-shou")
    ap = Stats.skill(stats, "hand")
    # LPC: damage = 50 + ap / 6 + random(ap / 6);（命中分支内才算）
    damage = 50 + div(ap, 6) + Engine.rand(rng, div(ap, 6))

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
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
          damage: damage,
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
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "chansi-shou") < 120 do
      {:error, "你缠丝擒拿手等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hand") != "chansi-shou" ->
        {:error, "你没有激发缠丝擒拿手，难以施展#{@move_name}。\n"}

      not prepared?(stats, "hand", "chansi-shou") ->
        {:error, "你没有准备缠丝擒拿手，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp prepared?(stats, usage, id) do
    case Stats.prepared_perform(stats, usage) do
      nil -> false
      value -> String.split(value, "/") |> hd() == id
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 100 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIW "$N" HIW "悄然贴近$n" HIW "，施出缠丝擒拿，双手忽"
    #              "折忽扭，或抓或甩，直琐$p" HIW "各处要脉。\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中/未命中的 neili 与 busy 由目标侧结算后经 Performs.feedback 回执
    #（hit -80/busy 2，miss -20/busy 3），因为分支判定需要目标 dp。
    conn =
      Broadcast.publish(
        conn,
        "$N悄然贴近$n，施出缠丝擒拿，双手忽折忽扭，或抓或甩，直琐$p各处要脉。\n",
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
    damage = Map.get(data, :damage, 0)
    stats = character.meta.stats
    combat = character.meta.combat
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("hand"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    hit = div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "parry")

    if hit do
      # LPC: me->add("neili", -80);
      #      COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35, final)
      #      me->start_busy(2);
      vitals = character.meta.vitals

      vitals =
        vitals
        |> Vitals.damage(:qi, damage)
        # LPC: wound = (damage - random(armor)) * percent / 100（armor 未建模）
        |> Vitals.wound(:qi, div(damage * 35, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC final(): if (random(3) >= 1 && ! target->is_busy())
      #                  target->start_busy(damage / 15); msg += "难以反击。\n";
      #              else msg += "鲜血狂喷。\n";
      {combat, tail} =
        if Engine.rand(rng, 3) >= 1 and not Combat.busy?(combat) do
          {Combat.start_busy(combat, div(damage, 15)), "难以反击。\n"}
        else
          {combat, "鲜血狂喷。\n"}
        end

      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        conn
        |> Broadcast.publish("却见$n奋力抵抗，可终究无法摆脱$N的攻势，连中数掌，", bindings)
        |> Broadcast.publish(tail, bindings)

      Performs.feedback(attacker, 80, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$n" CYN "的看破了$N"
      #              CYN "的招式，巧妙的招架拆解，没露半点破绽。\n" NOR;
      #      me->add("neili", -20); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          "可是$n的看破了$N的招式，巧妙的招架拆解，没露半点破绽。\n",
          bindings
        )

      Performs.feedback(attacker, 20, 3)

      conn
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIN "「" HIW "缠丝擒拿" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/chansi-shou/qin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(QIN "只能空手施展。\n");
  # 
  #         skill = me->query_skill("chansi-shou", 1);
  # 
  #         if (skill < 120)
  #                 return notify_fail("你缠丝擒拿手等级不够，难以施展" QIN "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "chansi-shou")
  #                 return notify_fail("你没有激发缠丝擒拿手，难以施展" QIN "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "chansi-shou")
  #                 return notify_fail("你没有准备缠丝擒拿手，难以施展" QIN "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" QIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "悄然贴近$n" HIW "，施出缠丝擒拿，双手忽"
  #               "折忽扭，或抓或甩，直琐$p" HIW "各处要脉。\n" NOR;
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -80);
  #                 damage = 50 + ap / 6 + random(ap / 6);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            (: final, me, target, damage :));
  #                 me->start_busy(2);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "的看破了$N"
  #                        CYN "的招式，巧妙的招架拆解，没露半点破绽。\n" NOR;
  #                 me->add("neili", -20);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         string msg;
  # 
  #         msg = HIR "却见$n" HIR "奋力抵抗，可终究无法"
  #               "摆脱$N" HIR "的攻势，连中数掌，";
  # 
  #         if (random(3) >= 1 && ! target->is_busy())
  #         {
  #                 target->start_busy(damage / 15);
  #                 msg += "难以反击。\n" NOR;
  #         } else
  #                 msg += "鲜血狂喷。\n" NOR;
  # 
  #         return  msg;
  # }
end
