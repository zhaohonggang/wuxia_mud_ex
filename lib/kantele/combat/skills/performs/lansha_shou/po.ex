defmodule Kantele.Combat.Skills.Performs.LanshaShou.Po do
  @moduledoc """
  perform「破靛神砂」（source lansha-shou/po.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 蓝砂手>=100 →
  内功>=150 → 激发 hand 为蓝砂手 → 准备蓝砂手 → 真气>=200 → 目标存活。
  起手式后攻击方忙乱 3；命中判定 `hand/2 + random(hand)` > 目标 `force`，
  命中则扣 100 真气、伤害 `hand/2 + random(hand/3)`（20% 外伤比例），
  并附 final() 的抓伤文案；未命中仅化解文案。

  差异（TODO(migrate)）：
  - LPC 的 `target->affect_by("sha_poison", …)`（沙毒：level=jiali+random(jiali)、
    duration=lvl/50+random(lvl/30)，lvl=蓝砂手/2*3）框架未建模，仅保留 final()
    的抓伤文案（「伤口竟渗出黑血，隐隐发着磷光」）；
  - 攻击方 `me->start_busy(3)` 与命中分支的 -100 真气都走目标侧 feedback 回执
    （命中 feedback(100,3)、未命中 feedback(0,3)）。
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

  @perform_id "lansha-shou/po"
  @move_name "「破靛神砂」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lansha-shou")
    ap = Stats.skill(stats, "hand")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("lansha-shou", 1) < 100)
  #         if (me->query_skill("force") < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "lansha-shou") < 100 ->
        {:error, "你蓝砂手不够熟练，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "lansha-shou")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "lansha-shou" do
      :ok
    else
      {:error, "你没有激发蓝砂手，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "lansha-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared == nil or hd(String.split(prepared, "/")) != "lansha-shou" do
      {:error, "你没有准备蓝砂手，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIG "$N" HIG "身形急转，宛若鬼魅，悄然施出蓝砂手绝技「" NOR +
    #               HIB "破靛神砂" NOR + HIG "」，朝$n" HIG "胸前大穴抓落！\n" NOR;
    # 三段字面量被颜色宏的 + 分隔，用 list + Enum.join("") 复现（不合并）。
    # me->start_busy(3) 与命中分支的 neili 由目标侧 feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        [
          "$N身形急转，宛若鬼魅，悄然施出蓝砂手绝技「",
          "破靛神砂",
          "」，朝$n胸前大穴抓落！\n"
        ] |> Enum.join(""),
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
    dp = Stats.skill(character.meta.stats, "force")

    # LPC: me->start_busy(3); if (ap / 2 + random(ap) > dp)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp

    # LPC: damage = ap / 2 + random(ap / 3);
    #      COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20, (: final :));
    {vitals, msg, neili_cost} =
      if hit? do
        damage = div(ap, 2) + Engine.rand(rng, div(ap, 3))
        v = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage, 5))
        {v, final_message(), 100}
      else
        {character.meta.vitals, "$n见$N来势汹涌，奋力格挡，终于化解开来。\n", 0}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, 3)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: string final(object me, object target, int damage)
  #      return HIR "$n" HIR "闪避不及，登被$N" HIR "抓出五道血痕，伤口竟渗出黑血，
  #             隐隐发着磷光。\n" NOR;
  # （相邻字面量合并为单段）
  defp final_message do
    "$n闪避不及，登被$N抓出五道血痕，伤口竟渗出黑血，隐隐发着磷光。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIB "破靛神砂" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         int lvl;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lansha-shou/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(PO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("lansha-shou", 1) < 100)
  #                 return notify_fail("你蓝砂手不够熟练，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "lansha-shou")
  #                 return notify_fail("你没有激发蓝砂手，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "lansha-shou")
  #                 return notify_fail("你没有准备蓝砂手，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "身形急转，宛若鬼魅，悄然施出蓝砂手绝技「" NOR +
  #               HIB "破靛神砂" NOR + HIG "」，朝$n" HIG "胸前大穴抓落！\n" NOR;
  # 
  #         lvl = me->query_skill("lansha-shou", 1);
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("force");
  # 
  #         me->start_busy(3);
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap / 2 + random(ap / 3);
  #                 me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                           (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N"
  #                        CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("lansha-shou", 1) / 2 * 3;
  # 
  #         target->affect_by("sha_poison",
  #                 ([ "level"    : me->query("jiali") + random(me->query("jiali")),
  #                    "id"       : me->query("id"),
  #                    "duration" : lvl / 50 + random(lvl / 30) ]));
  # 
  #         return HIR "$n" HIR "闪避不及，登被$N" HIR
  #                "抓出五道血痕，伤口竟渗出黑血，隐隐"
  #                "发着磷光。\n" NOR;
  # }
end
