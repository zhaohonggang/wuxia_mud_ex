defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Wswd do
  @moduledoc """
  perform「无」（source kuihua-mogong/wswd.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kuihua-mogong/wswd"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    busy = 1

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
      Stats.skill(stats, "kuihua-mogong") < 400 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "kuihua-mogong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 7000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | neili: vitals.neili - 500}
    vitals = %{vitals | neili: vitals.neili - 600}
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
    Performs.feedback(attacker, 600, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}, {"neili", "-600"}], "assign_refs": [{"ap", "kuihua-mogong"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(busy);", "me->start_busy(busy);"], "level_gates": [{"kuihua-mogong", "400"}], "map_gates": [{"sword", "kuihua-mogong"}], "remote_damage": true, "resource_gates": [{"max_neili", "7000"}, {"neili", "1000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WSWD "「" HIR "无"BLU"双"HIM"无"HIW"对" NOR "」"
  # #define WS "「" HIR "无"BLU"双" NOR "」"
  # #define WD "「" HIM"无"HIW"对" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #     int damage, busy;
  # 
  #     if( !target ) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/ws"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if( !target || !me->is_fighting(target) || !living(target) )
  #         return notify_fail("无双无对只能对战斗中的对手使用。\n");
  # 
  #     if( ! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "sword"
  #         || me->query_skill_mapped("sword") != "kuihua-mogong" )
  #             return  notify_fail("你现在无法使用绝技。\n");
  # 
  #     if (me->query_skill("kuihua-mogong", 1) < 400)
  #         return notify_fail("以你目前的修为来看，还不足以运用"WS"\n");
  # 
  #     if (me->query("max_neili") < 7000)
  #         return notify_fail("你的内力修为不够运用"WSWD"所需！\n");
  # 
  #     if (me->query("neili") < 1000)
  #         return notify_fail("你的内力不够运用"WS"所需！\n");
  # 
  #     if (! living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #     ap = me->query_skill("kuihua-mogong", 1) + me->query("dex") * 20 + me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("parry",1) + target->query("dex") * 20 + target->query_skill("martial-cognize", 1);
  #     msg =HIM "$N突然身形一转眨眼间使出葵花魔功的终极绝招----"NOR""WSWD""HIM"之"NOR""WS"\n"HIW"$N眼神莹然有光，似乎进入了魔境之中。\n"
  #     "$N手中" + weapon->name() + "化做无双剑影攻向$n。\n";
  # 
  #         if (ap *3/5 + random(ap) < dp)
  #         {
  #             msg += HIG "然而$n" HIG "抵挡得法，将$N" HIG
  #             "的攻势化解。\n" NOR;
  #             busy = 2;
  #             me->add("neili", -300);
  #         } else
  #         {
  #             busy = 1;
  #             me->add("neili", -500);
  #             damage = ap + random(ap * 1 / 4) - random(100);
  #             msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #               HIY "$n" BLU "只觉得已经跌入了万劫魔域之中，"HIY"$N手中"+weapon->name()+
  #               WHT "如同地狱中的鬼火般，从各个方位刺了过来，避无可避！\n" NOR);
  # 
  #         }
  #         message_vision(msg, me, target);
  #         if(me->query("can_perform/kuihua-mogong/wd")){
  #             call_out("perform2", 0, me, target, busy);
  #         }
  #         else{
  #             //没学会无对
  #             me->start_busy(busy);
  #             call_out("check_wd", 3, me);
  #         }
  # 
  #     return 1;
  # }
  # int perform2(object me, object target,int busy)
  # {       int ap, dp;
  #         string msg;
  #         int damage;
  # 
  #         if (!me || !target) return notify_fail("对手已经不在这里了！\n");
  #         if(!living(target))
  #             return notify_fail("对手已经不能再战斗了。\n");
  #         if(me->query("neili") < 1000)
  #             return notify_fail("你待要再出"WD"，却发现自己的内力不够了！\n");
  #         ap = me->query_skill("kuihua-mogong", 1) + me->query("dex") * 20 + me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry",1) + target->query("dex") * 20 + target->query_skill("martial-cognize", 1);
  # 
  #         msg =HIM "说时迟那时快，$N身形逆转使出了"NOR""WSWD"之"WD""HIM"式，刹那间天空阴云密布，\n"NOR""HIM"$n的心脏几乎停止了跳动，呆呆的望着$N\n"NOR;
  # 
  #         if (ap / 2 + random(ap) < dp)
  #         {
  #             msg += HIG "这时$n屏住呼吸" HIG "抵挡得法，将$N" HIG"的攻势一一化解。\n" NOR;
  #               busy += 2;
  #               me->add("neili", -300);
  #         } else
  #         {
  #             busy += 1;
  #             me->add("neili",-600);
  #             damage = ap + random(ap * 1 / 2) - random(100);
  #             msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
  #               HIY "$n" BLU "只觉身上如同万剑穿心一般，"HIY"$N"
  #               WHT "如同死神一般，势必要取$n性命！\n" NOR);
  #         }
  #         me->start_busy(busy);
  #         message_vision(msg, me, target);
  #         return 1;
  # }
  # int check_wd(object me)
  # {
  #     if(me->query("int") + random(80) >= 100) {
  #         tell_object(me, HIW "\n你突然若有所悟，对刚才使用过的葵花魔功之"WS""HIW"式反复琢磨，\n对了，这样也可以耶！你学会了"WSWD""HIW"之"WD""HIW"式！\n" NOR);
  #         me->set("can_perform/kuihua-mogong/wd",1);
  #     }
  #     return 1;
  # }
end
