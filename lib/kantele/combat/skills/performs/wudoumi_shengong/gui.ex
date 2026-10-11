defmodule Kantele.Combat.Skills.Performs.WudoumiShengong.Gui do
  @moduledoc """
  perform「归去来兮」（source wudoumi-shengong/gui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "wudoumi-shengong/gui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wudoumi-shengong")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "wudoumi-shengong") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "wudoumi-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "wudoumi-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 500}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 500, 1)
    result = Messages.interpolate("$N一声断喝，双掌施出五斗米神功「归去来兮」绝技，顿时掌劲澎湃，涌向$n。
$p急忙奋力格挡，可只一瞬间，$P的掌劲已透体而入，接连震断数根肋骨！

紧接着只见$N双手陡然回圈，竟使已袭出的掌劲倒回，从$n身后再度席卷而归。
$p大惊之下，竟然僵直而立，$P澎湃的掌劲顿时穿透胸膛，尽伤五脏六腑！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-500"}], "assign_refs": [{"ap", "force"}, {"damage", "wudoumi-shengong"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "200"}, {"wudoumi-shengong", "140"}], "map_gates": [{"force", "wudoumi-shengong"}, {"unarmed", "wudoumi-shengong"}], "prepared_gates": [{"unarmed", "wudoumi-shengong"}], "remote_damage": true, "resource_gates": [{"neili", "800"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GUI "「" HIR "归去来兮" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  # //      string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/wudoumi-shengong/gui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(GUI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" GUI "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功修为不够，难以施展" GUI "。\n");
  # 
  #         if ((int)me->query_skill("wudoumi-shengong", 1) < 140)
  #                 return notify_fail("你的五斗米神功不够娴熟，难以施展" GUI "。\n");
  # 
  #         if ((int)me->query("neili") < 800)
  #                 return notify_fail("你现在真气不够，难以施展" GUI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "wudoumi-shengong")
  #                 return notify_fail("你没有激发五斗米神功为内功，难以施展" GUI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "wudoumi-shengong")
  #                 return notify_fail("你没有激发五斗米神功为拳脚，难以施展" GUI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "wudoumi-shengong")
  #                 return notify_fail("你现在没有准备使用五斗米神功，难以施展" GUI "。\n");
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你未将全身功力尽数提起，难以施展" GUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         
  # 
  #         ap = me->query_skill("force") + me->query("con") * 10;
  #         dp = target->query_skill("dodge") + target->query("dex") * 10;
  #         
  #         damage = (int)me->query_skill("wudoumi-shengong", 1);
  #         damage += random(damage);
  # 
  #         msg = HIR "$N" HIR "一声断喝，双掌施出五斗米神功「归去来兮」绝技，顿时掌"
  #               "劲澎湃，涌向$n" HIR "。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "$p" HIR "急忙奋力格挡，可只一瞬间"
  #                                            "，$P" HIR "的掌劲已透体而入，接连震断"
  #                                            "数根肋骨！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见$P" CYN "来势汹涌，不敢硬接"
  #                        "，只得小巧腾挪，躲闪开来。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("force") + me->query("con") * 10;
  #         dp = target->query_skill("dodge") + target->query("dex") * 10;
  # 
  #         msg += "\n" HIR "紧接着只见$N" HIR "双手陡然回圈，竟使已袭出的掌劲倒回"
  #                "，从$n" HIR "身后再度席卷而归。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            HIR "$p" HIR "大惊之下，竟然僵直而立，$P"
  #                                            HIR "澎湃的掌劲顿时穿透胸膛，尽伤五脏六"
  #                                            "腑！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "大惊之下急忙飞身跃起，终于躲开"
  #                        "了这神鬼莫测的一击。\n" NOR;
  #         }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -500);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
