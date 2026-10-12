defmodule Kantele.Combat.Skills.Performs.QishangQuan.Shang do
  @moduledoc """
  perform「伤字诀」（source qishang-quan/shang.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "qishang-quan/shang"
  @move_name "「伤字诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "cuff") + Stats.skill(stats, "force")
    lvl = Stats.skill(stats, "qishang-quan")
    damage = ap + Engine.rand(rng, div(ap, 3))

    recoil =
      character.meta.vitals.max_neili < 8000 and
        Stats.skill(stats, "jiuyang-shengong") == 0 and
        Stats.skill(stats, "buddhism") < 400

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
          recoil: recoil,
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
      Stats.skill(stats, "qishang-quan") < 220 -> {:error, "你的七伤拳不够娴熟，无法施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 220 -> {:error, "你的内功修为还不够，无法施展#{@move_name}\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.prepared_perform(stats, "cuff") == nil or
          String.split(Stats.prepared_perform(stats, "cuff"), "/") |> hd() != "qishang-quan" ->
        {:error, "你没有准备使用七伤拳，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    # TODO(migrate) 武器检查需人工核对（自动提取的文案仅供参考）：
    :ok
  end

  defp apply_effect(conn, character, target) do
    # 前置广播；消耗/Busy 依命中结果在 do_resolve_incoming 中反馈
    conn =
      Broadcast.publish(
        conn,
        "$N怒喝一声，施出绝招「伤字诀」，双拳迅猛无比的袭向$n。",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
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

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    recoil = Map.get(data, :recoil, false)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry")
    hit = div(ap * 2, 3) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    bindings = [n1: attacker.name, n2: character.name]

    {conn, character} =
      if hit do
        if recoil do
          # 七伤拳反噬：不加内力，自身受创（此处以受伤文案呈现）
          conn = Broadcast.publish(conn, "七伤拳的反噬愈来愈强！", bindings)
          Performs.feedback(attacker, 0, 2)
          {conn, character}
        else
          vitals = Vitals.damage(vitals, :qi, damage)
          character = %{character | meta: %{character.meta | vitals: vitals}}
          conn = Broadcast.publish(conn, "只见$P这一拳把$p飞了出去，重重的摔在地上，吐血不止！", bindings)
          Performs.feedback(attacker, 260, 2)
          {conn, character}
        end
      else
        conn = Broadcast.publish(conn, "可是$p奋力招架，硬生生的挡开了$P这一招。", bindings)
        Performs.feedback(attacker, 120, 3)
        {conn, character}
      end

    put_character(conn, character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-260"}], "assign_refs": [{"ap", "cuff"}, {"dp", "force"}, {"lvl", "qishang-quan"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"buddhism", "400"}, {"force", "220"}, {"qishang-quan", "220"}], "prepared_gates": [{"cuff", "qishang-quan"}], "remote_damage": true, "resource_gates": [{"max_neili", "8000"}, {"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 伤字诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" HIW "伤字诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  # //        object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp, lvl;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/qishang-quan/shang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #             return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("qishang-quan", 1) < 220)
  #             return notify_fail("你的七伤拳不够娴熟，无法施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 220)
  #             return notify_fail("你的内功修为还不够，无法施展" PO "\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #             return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "qishang-quan")
  #                 return notify_fail("你没有准备使用七伤拳，无法施展" PO "。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "怒喝一声，施出绝招「" HIW "伤字诀" HIY "」，双拳迅猛无比"
  #                   "的袭向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #         lvl = me->query_skill("qishang-quan", 1);
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                     damage = ap + random(ap / 3);
  # 
  #                     if (me->query("max_neili") < 8000 &&
  #                         ! me->query_skill("jiuyang-shengong", 1) &&
  #                         me->query_skill("buddhism", 1) < 400)
  #                     {
  #                         damage = lvl * 8000 / me->query("max_neili");
  #                         me->receive_wound("qi", damage, me);
  #                         tell_object(me, HIR "七伤拳的反噬愈来愈强！\n" NOR);
  #                     }
  #                     else
  #                     {
  #                         damage += random(lvl * 3);
  #                         me->add("neili", -260);
  #                         me->receive_heal("qi", random(lvl / 3));
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(lvl) / 5,
  #                                            HIR "只见$P" HIR "这一拳把$p" HIR
  #                                                    "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
  #                     }
  #                     me->start_busy(2);
  #         } else
  #         {
  #             msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                            HIC "这一招。\n"NOR;
  #             me->add("neili", -120);
  #             me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
