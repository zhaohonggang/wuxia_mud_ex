defmodule Kantele.Combat.Skills.Performs.MeinvQuan.You do
  @moduledoc """
  perform「古墓幽居」（source meinv-quan/you.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "meinv-quan/you"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "meinv-quan")

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
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "meinv-quan") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "meinv-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 180 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    Performs.feedback(attacker, 100, 3)
    result = Messages.interpolate("但见$N双拳袭来，柔中带刚，迅猛无比，其间仿佛蕴藏着无穷的威力，$n正迟疑间， $N却已中拳，闷哼一声，倒退几步，一口鲜血喷出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"damage", "unarmed"}], "busy_lines": ["//me->start_busy(2 + random(2));", "me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "120"}, {"meinv-quan", "80"}], "map_gates": [{"unarmed", "meinv-quan"}], "prepared_gates": [{"unarmed", "meinv-quan"}], "remote_damage": true, "resource_gates": [{"neili", "180"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YOU "「" HIG "古墓幽居" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # //      string pmsg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/meinv-quan/you"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YOU "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("你必须空手才能施展" YOU "。\n");
  # 
  #         if ((int)me->query_skill("meinv-quan", 1) < 80)
  #                 return notify_fail("你的美女拳法别不够，不会使用" YOU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功还未娴熟，不能使用" YOU "。\n");
  # 
  #         if ((int)me->query("neili") < 180)
  #                 return notify_fail("你现在真气不够，不能使用" YOU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "meinv-quan")
  #                 return notify_fail("你没有激发美女拳法，不能施展" YOU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "meinv-quan")
  #                 return notify_fail("你没有准备美女拳法，难以施展" YOU "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "右手支颐，左袖轻轻挥出，长叹一声，使"
  #               "出古墓派绝学「古墓幽居」，一脸尽现寂寥之意。\n" NOR;
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 //me->start_busy(2 + random(2));
  #                 me->start_busy(2);
  # 
  #                 damage = (int)me->query_skill("unarmed");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "但见$N" HIR "双拳袭来，柔中带刚，迅"
  #                                            "猛无比，其间仿佛蕴藏着无穷的威力，$n" HIR
  #                                            "正迟疑间， $N" HIR "却已中拳，闷哼一声，倒"
  #                                            "退几步，一口鲜血喷出。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN
  #                        "的企图，稳如泰山，抬手一架格开了$P"
  #                        CYN "这一拳。\n"NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
end
