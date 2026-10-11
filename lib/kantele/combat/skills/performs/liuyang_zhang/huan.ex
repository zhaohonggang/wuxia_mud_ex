defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Huan do
  @moduledoc """
  perform「寰阳式」（source liuyang-zhang/huan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "liuyang-zhang/huan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuyang-zhang")
    ap = Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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
      Stats.skill(stats, "liuyang-zhang") < 130 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "liuyang-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("$N双掌一振，施出天山六阳掌「寰阳式」，幻出满天掌影，团团罩住$n。
$n见躲闪不得，只能硬挡下一招，顿时被$P震得连退数步，吐血不止！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "assign_refs": [{"ap", "force"}, {"damage", "strike"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);"], "level_gates": [{"force", "200"}, {"liuyang-zhang", "130"}], "map_gates": [{"strike", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUAN "「" HIR "寰阳式" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/huan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUAN "只能空手施展。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展" HUAN "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 130)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发天山六阳掌，难以施展" HUAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有准备使用天山六阳掌，难以施展" HUAN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" HUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "双掌一振，施出天山六阳掌「寰阳式」，幻出"
  #               "满天掌影，团团罩住$n" HIR "。\n" NOR;
  # 
  #     me->add("neili", -50);
  #         ap = me->query_skill("force");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = me->query_skill("strike") + ap - dp;
  #                 damage += random(damage * 2 / 5);
  #         me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "见躲闪不得，只能硬挡下一"
  #                                            "招，顿时被$P" HIR "震得连退数步，吐血"
  #                                            "不止！\n" NOR);
  #         me->start_busy(3);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "强运内力，硬生生的挡住$P"
  #                        HIC "这一掌，没有受到任何伤害。\n"NOR;
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
