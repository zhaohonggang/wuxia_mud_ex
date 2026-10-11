defmodule Kantele.Combat.Skills.Performs.RuyingSuixingtui.Ruying do
  @moduledoc """
  perform「ruying」（source ruying-suixingtui/ruying.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "ruying-suixingtui/ruying"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "ruying-suixingtui")
    i = div(Stats.skill(stats, "ruying-suixingtui"), 4)

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
      Stats.skill(stats, "force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "ruying-suixingtui") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "ruying-suixingtui" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 700 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
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
    result = Messages.interpolate("这时$N双臂展动，带起一股强烈的旋风，双腿霎时齐并，「如影随形」一击重炮轰在$n胸膛之上！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}, {"neili", "-500"}], "apply_adds": ["attack", "damage", "dexerity", "strength"], "assign_refs": [{"i", "ruying-suixingtui"}], "busy_lines": ["me->start_busy(2+random(2));"], "level_gates": [{"force", "160"}, {"ruying-suixingtui", "160"}], "map_gates": [{"unarmed", "ruying-suixingtui"}], "prepared_gates": [{"unarmed", "ruying-suixingtui"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "700"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int i; 
  # 
  #         i = me->query_skill("ruying-suixingtui", 1) / 4;
  # 
  #         if ( userp(me) && !me->query("can_perform/ruying-suixingtui/ruying"))
  #                 return notify_fail("你所使用的外功中没有这样的功能。\n");
  #         
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target || !me->is_fighting(target) )
  #                 return notify_fail("「如影随形」只能在战斗中对对手使用。\n");
  # 
  #         if( objectp(me->query_temp("weapon")) )
  #                 return notify_fail("使用「如影随形」时双手必须空着！\n");
  # 
  #         if( (int)me->query_skill("ruying-suixingtui", 1) < 160 )
  #                 return notify_fail("你的如影随形腿不够娴熟，不会使用「如影随形」。\n");
  # 
  #         if( (int)me->query_skill("force", 1) < 160 )
  #                 return notify_fail("你的内功等级不够，不能使用「如影随形」。\n");
  # 
  #         if( (int)me->query_dex() < 30 )
  #                 return notify_fail("你的身法不够强，不能使用「如影随形」。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "ruying-suixingtui"
  #         || me->query_skill_mapped("unarmed") != "ruying-suixingtui")
  #                 return notify_fail("你现在无法使用「如影随形」进行攻击。\n");
  #  
  #         if( (int)me->query("max_neili") < 2000 ) 
  #                 return notify_fail("你的内力修为太弱，不能使用「如影随形」！\n");
  # 
  #         if( (int)me->query("neili") < 700 )
  #                 return notify_fail("你现在内力太少，不能使用「如影随形」。\n"); 
  # 
  #         me->add("neili", -500);
  #       
  #         msg = YEL "\n你猛吸一口真气，体内劲力瞬时爆发！\n" NOR;
  #         message_vision(msg, me, target); 
  #        
  #         me->add_temp("apply/strength", i);
  #         me->add_temp("apply/dexerity", i);
  #         me->add_temp("apply/attack", i);
  #         me->add_temp("apply/damage", i);
  # 
  #         if (random((int)me->query("combat_exp")) > (int)target->query("combat_exp") / 2 
  #         &&  random((int)me->query_skill("force")) > (int)target->query_skill("force") / 2)
  #        { 
  #              msg = HIY "$N忽然跃起，左脚一勾一弹，霎时之间踢出一招「如」字诀的穿心腿，直袭$n前胸！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK,msg);
  #         
  #              msg = HIY "紧接着$N左腿勾回，将腰身一扭，那右腿的一招「影」字诀便紧随而至，飞向$n！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 1,msg);
  #  
  #              msg = HIY"只见$N右脚劲力未消，便凌空一转，左腿顺势扫出一招「随」字诀，如影而至！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK,msg);
  # 
  #              msg = HIY"半空中$N脚未后撤，已经运起「形」字诀，内劲直透脚尖，在$n胸腹处连点了数十下！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK,msg);
  # 
  #              msg = HIR"这时$N双臂展动，带起一股强烈的旋风，双腿霎时齐并，「如影随形」一击重炮轰在$n胸膛之上！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK,msg);
  #         } else 
  #        {
  #              msg = HIY"$N忽然跃起，左脚一勾一弹，霎时之间踢出一招「如」字诀的穿心腿，直袭$n前胸！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK,msg);
  #         
  #              msg = HIY"紧接着$N左腿勾回，将腰身一扭，那右腿的一招「影」字诀便紧随而至，飞向$n！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 1,msg);
  #  
  #              msg = HIY"只见$N右脚劲力未消，便凌空一转，左腿顺势扫出一招「随」字诀，如影而至！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"),TYPE_QUICK,msg);
  # 
  #              msg = HIY"半空中$N脚未后撤，已经运起「形」字诀，内劲直透脚尖，在$n胸腹处连点了数十下！"NOR;
  #              COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 1,msg);
  #         }
  #  
  #              msg = YEL "\n你连环飞腿使完，全身一转，稳稳落在地上。\n" NOR;
  #                
  #              //me->add("neili", -400);
  #              me->add_temp("apply/dexerity", -i);
  #              me->add_temp("apply/damage", -i); 
  #              me->add_temp("apply/strength", -i);
  #              me->add_temp("apply/attack", -i);   
  #              me->start_busy(2+random(2));
  # 
  #         return 1;
  # }
end
