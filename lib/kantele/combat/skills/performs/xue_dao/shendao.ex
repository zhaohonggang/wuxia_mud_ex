defmodule Kantele.Combat.Skills.Performs.XueDao.Shendao do
  @moduledoc """
  perform「shendao」（source xue-dao/shendao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xue-dao/shendao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xue-dao")
    damage = Stats.skill(stats, "blade")

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
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xue-dao") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "xue-dao" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 350}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 350, 2)
    result = Messages.interpolate("$N右手持刀向左肩一勒，一阵血珠溅满刀面，紧接着右臂抡出，一片血光裹住刀影向$n当头劈落，
$n疾忙侧身避让，但血刀疾闪，只觉眼前一阵血红，刀刃劈面而下，鲜血飞溅，不禁惨声大嚎！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}], "assign_refs": [{"damage", "blade"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "level_gates": [{"force", "100"}, {"xue-dao", "100"}], "map_gates": [{"blade", "xue-dao"}], "remote_damage": true, "resource_gates": [{"max_neili", "1200"}, {"neili", "400"}, {"qi", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shendao.c  血刀「祭血神刀」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/xue-dao/shendao"))
  #                 return notify_fail("你还不会使用「祭血神刀」！\n");
  # 
  #         if (! target)
  #                 target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「祭血神刀」只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("装备刀才能使用「祭血神刀」！\n");
  # 
  #         if ((int)me->query_skill("xue-dao", 1) < 100)
  #                 return notify_fail("你血刀刀法不够娴熟，使不出「祭血神刀」。\n");
  # 
  #         if ((int)me->query_skill("force") < 100 )
  #                 return notify_fail("你内功火候不够，难以施展「祭血神刀」。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不足，无法运足内力。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，无法将「祭血神刀」使完！\n");
  # 
  #         if ((int)me->query("qi") < 100)
  #                 return notify_fail("你还敢使这招？找死啊！\n");
  # 
  #         if ((int)me->query("shen") > -1000)
  #                 return notify_fail("你为人不够凶残，还无法领会「祭血神刀」的奥妙。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "xue-dao")
  #                 return notify_fail("你没有激发血刀刀法，不能使用「祭血神刀」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "右手持刀向左肩一勒，一阵血珠溅满刀面，紧接着右臂抡出，一片血光"
  #               "裹住刀影向$n" HIR "当头劈落，\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > (int)target->query_skill("force") / 2)
  #         {
  #                 damage = me->query_skill("blade");
  #                 damage = damage / 2 + random(damage / 2);
  #                 if (me->query("character") == "心狠手辣")
  #                         damage += damage * 3 / 10;
  #                 me->add("neili", -350);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "疾忙侧身避让，但血刀疾闪，只觉眼"
  #                                            "前一阵血红，刀刃劈面而下，鲜血飞"
  #                                            "溅，不禁惨声大嚎！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(2);
  #                 msg += CYN "可是$n" CYN "侧身避让，不慌不忙，躲过了$N"
  #                        CYN "的必杀一刀。\n"NOR;
  #                 me->add("neili", -100);
  #         }
  #         me->receive_wound("qi", 50);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
