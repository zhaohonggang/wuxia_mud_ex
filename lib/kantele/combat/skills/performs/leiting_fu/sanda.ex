defmodule Kantele.Combat.Skills.Performs.LeitingFu.Sanda do
  @moduledoc """
  perform「sanda」（source leiting-fu/sanda.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "leiting-fu/sanda"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "leiting-fu")
    damage = Stats.skill(stats, "leiting-fu")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hammer") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hammer") != "leiting-fu" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 110}
    vitals = %{vitals | neili: vitals.neili - 140}
    vitals = %{vitals | neili: vitals.neili - 40}
    vitals = %{vitals | neili: vitals.neili - 55}
    vitals = %{vitals | neili: vitals.neili - 70}
    vitals = %{vitals | neili: vitals.neili - 80}
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
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。
$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。
$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-110"}, {"neili", "-140"}, {"neili", "-40"}, {"neili", "-55"}, {"neili", "-70"}, {"neili", "-80"}], "assign_refs": [{"ap", "hammer"}, {"damage", "leiting-fu"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3 + random(3));"], "level_gates": [{"force", "200"}, {"hammer", "180"}], "map_gates": [{"hammer", "leiting-fu"}], "remote_damage": true, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // sanda.c 三板斧
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage, count;
  #         int zhuan;
  # 
  #         zhuan = me->query("reborn/count");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! me->is_fighting())
  #             return notify_fail("「三板斧」只能在战斗中使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #                 (string)weapon->query("skill_type") != "hammer")
  #             return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "leiting-fu")
  #             return notify_fail("你没有激发雷霆斧法，不能使用「三板斧」。\n");
  # 
  #         if ((int)me->query_str() < 40)
  #             return notify_fail("你现在的臂力不够，目前不能使用「三板斧」！\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #             return notify_fail("你的内功火候不够，难以施展「三板斧」！\n");
  # 
  #         if ((int)me->query_skill("hammer", 1) < 180)
  #             return notify_fail("你的棍法修为不够，不会使用「三板斧」！\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #             return notify_fail("你的真气不足！\n");
  # 
  #         if (! living(target))
  #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         // 第一斧劈脑袋
  #         ap = me->query_skill("hammer") + me->query("str") * 2;
  #         dp = target->query_skill("force");
  #         damage = me->query_skill("leiting-fu", 1);
  #         damage += (me->query_str() - zhuan * 20) * 2;
  #         count = me->query_str() - zhuan * 20;
  # 
  #         msg = "\n" HIW "$N" HIW "喝道：劈脑袋！\n" NOR;
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -80);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -40);
  #         }
  # 
  #         // 第二斧鬼剔牙
  #         ap += me->query("dex") * 3;
  #         dp = target->query_skill("parry");
  #         damage += (me->query_dex() - zhuan * 20) * 3;
  #         count += me->query("dex") - zhuan * 20;
  #         msg += "\n" YEL "$N" YEL "喝道：鬼剔牙！\n" NOR;
  #         if (ap / 2 + random(ap * 4 / 5) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -110);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -55);
  #         }
  # 
  #         // 第三斧掏耳朵
  #         ap += me->query("con") * 5;
  #         dp = target->query_skill("dodge");
  #         damage += (me->query_con() - zhuan * 20) * 5;
  #         count += me->query("con") - zhuan * 20;
  #         msg += "\n" HIM "$N" HIM "喝道：掏耳朵！\n" NOR;
  #         if (ap / 3 + random(ap * 3 / 5) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -140);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -70);
  #         }
  # 
  #         me->start_busy(3 + random(3));
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
