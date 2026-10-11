defmodule Kantele.Combat.Skills.Performs.WuhuDuanmendao.Duan do
  @moduledoc """
  perform「断字诀」（source wuhu-duanmendao/duan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "wuhu-duanmendao/duan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wuhu-duanmendao")
    ap = Stats.skill(stats, "blade")
    count = 0
    num = 2
    i = 0

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
      Stats.skill(stats, "wuhu-duanmendao") < 50 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "wuhu-duanmendao" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 100, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "damage", "parry"], "assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(3));"], "level_gates": [{"wuhu-duanmendao", "50"}], "map_gates": [{"blade", "wuhu-duanmendao"}], "remote_damage": false, "resource_gates": [{"neili", "200"}], "var_gates": [{"exp", "100000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DUAN "「" HIW "断字诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon, ob;
  #     string msg;
  #     int ap, dp, count;
  #     int i, num, exp;
  # 
  #     if (userp(me) && ! me->query("can_perform/wuhu-duanmendao/duan"))
  #             return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(DUAN "只能在战斗中对对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #             return notify_fail("你使用的武器不对，难以施展" DUAN "。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #             return notify_fail("你现在的真气不足，难以施展" DUAN "。\n");
  # 
  #     if ((int)me->query_skill("wuhu-duanmendao", 1) < 50)
  #             return notify_fail("你的五虎断门刀还不到家，难以施展" DUAN "。\n");
  # 
  #     if (me->query_skill_mapped("blade") != "wuhu-duanmendao")
  #             return notify_fail("你没有激发五虎断门刀，难以施展" DUAN "。\n");
  # 
  #     if (! living(target))
  #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "猛然伏地，使出五虎断门刀「断」字决，顿时一片白光"
  #               "向前直滚而去！\n" NOR;
  #     message_combatd(msg, me);
  # 
  #     me->clean_up_enemy();
  #     ob = me->select_opponent();
  #     ap = me->query_skill("blade");
  #     dp = target->query_skill("parry");
  #     exp = me->query("combat_exp");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         count = ap / 3;
  #     else
  #         count = 0;
  #     num = 2;
  #     if (exp < 100000 && exp > 600000)
  #         num += 0;
  #     else
  #         num += 600000 / exp;
  # 
  #     me->add_temp("apply/attack", count * num);
  #     me->add_temp("apply/parry", count * num);
  #     me->add_temp("apply/damage", count * num / 2);
  #     for (i = 0;i < num;i++)
  #     {
  #         COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
  #     }
  # 
  #     me->add_temp("apply/attack", -count* num);
  #     me->add_temp("apply/parry", -count* num);
  #     me->add_temp("apply/damage", -count * num / 2);
  # /*
  #     if (random(2) == 1)
  #         {
  #             me->add_temp("apply/attack", ap / 2);
  #             me->add_temp("apply/parry", ap / 2);
  #             me->add_temp("apply/damage", ap / 2);
  #             message_combatd(HIW  "$N从左面劈出第四刀！\n" NOR, me, target);
  #             COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
  #             me->add_temp("apply/attack", -ap / 2);
  #             me->add_temp("apply/parry", -ap / 2);
  #             me->add_temp("apply/damage", -ap / 2);
  # 
  #             if (random(2) == 1)
  #             {
  #                 me->add_temp("apply/attack", ap);
  #                 me->add_temp("apply/parry", ap);
  #                 me->add_temp("apply/damage", ap);
  #                 message_combatd(RED  "$N从右面劈出第五刀！\n" NOR, me, target);
  #                 COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
  #                 me->add_temp("apply/attack", -ap);
  #                 me->add_temp("apply/parry", -ap);
  #                 me->add_temp("apply/damage", -ap);
  #             }
  # 
  #         }
  # */
  #     me->add("neili", -100);
  #     me->start_busy(1 + random(3));
  #     return 1;
  # }
end
