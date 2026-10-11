defmodule Kantele.Combat.Skills.Performs.JingangZhi.San do
  @moduledoc """
  perform「一指点三脉」（source jingang-zhi/san.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jingang-zhi/san"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jingang-zhi")
    ap = Stats.skill(stats, "finger")

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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jingang-zhi") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jingluo-xue") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "jingang-zhi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "luohan-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "yijinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 800}
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
    Performs.feedback(attacker, 800, 1)
    result = Messages.interpolate("$N凝气于指，「一指点三脉」点出，顿时一股纯阳的内力直袭$n胸口！
结果$n被$N一指点中，全身真气逆流而上，登时呕出一大口鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-800"}], "assign_refs": [{"ap", "finger"}, {"damage", "finger"}, {"dp", "parry"}, {"lvl", "jingang-zhi"}], "busy_lines": ["target->start_busy(lvl/30);", "me->start_busy(3 + random(3));"], "level_gates": [{"force", "300"}, {"jingang-zhi", "200"}, {"jingluo-xue", "200"}], "map_gates": [{"finger", "jingang-zhi"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [{"finger", "jingang-zhi"}], "remote_damage": true, "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIE "「" HIR "一指点三脉" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string *xue_name = ({
  # "劳宫穴", "膻中穴", "曲池穴", "关元穴", "曲骨穴", "中极穴",
  # "承浆穴", "天突穴", "百会穴", "幽门穴", "章门穴", "大横穴",
  # "紫宫穴", "冷渊穴", "天井穴", "极泉穴", "清灵穴", "至阳穴", });
  # 
  # int perform(object me, object target)
  # {
  #         int damage, lvl;
  #         string msg;
  #         // object weapon;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jingang-zhi/san"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  # 
  #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIE "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("jingang-zhi", 1) < 200)
  #                 return notify_fail("你大力金刚指不够娴熟，难以施展" DIE "。\n");
  # 
  #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
  #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" DIE "。\n");
  #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
  #                 return notify_fail("你对经络学了解不够，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "jingang-zhi")
  #                 return notify_fail("你没有激发大力金刚指，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "jingang-zhi")
  #                 return notify_fail("你没有准备大力金刚指，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够，难以施展" DIE "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         damage = (int)me->query_skill("finger") + (int)me->query_skill("force") + (int)me->query_skill("jinluo-xue",1);
  #         damage += random(damage);
  #         lvl = (int)me->query_skill("jingang-zhi", 1);
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIW "突然间";
  # 
  #         msg += "$N" HIW "凝气于指，「" HIR "一指点三脉" HIW "」点出，顿时一股"
  #                "纯阳的内力直袭$n" HIW "胸口！\n" NOR;
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
  #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
  #                                            HIY + xue_name[random(sizeof(xue_name))] +
  #                                            HIR "，全身真气逆流而上，登时呕出一大"
  #                                            "口鲜血。\n" NOR);
  # 
  #                 target->start_busy(lvl/30);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
  #                        CYN "这精妙的一指。\n" NOR;
  #         }
  # 
  # 
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -800);
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
