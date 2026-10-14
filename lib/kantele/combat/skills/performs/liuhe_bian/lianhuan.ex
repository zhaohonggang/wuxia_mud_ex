defmodule Kantele.Combat.Skills.Performs.LiuheBian.Lianhuan do
  @moduledoc """
  perform「六合连环诀」（source liuhe-bian/lianhuan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 未处于连环诀运功中 → 持鞭类武器且激发
  六合鞭法（合并为一句门槛文案）→ 内功>=270 → 鞭法>=180 → 六合鞭法>=180 →
  真气>300 → 目标存活 → 轻功>=180。`.c` 的 can_perform 检查被注释掉，故无
  「已学此招」门槛。起手广播（兵刃名把文案拆成两段）；命中判定 `random(ap) > dp`
  （ap = force+六合鞭法+dodge + random(同值)，dp = 目标 parry+dodge）；
  命中则连出六击【天/地/人/神/鬼/六合】，第 i 击伤害 `hurt/i`（i 自 6 递减到 1）、
  50% 外伤比例，扣 300 真气、忙乱 2；未命中扣 200 真气、忙乱 2+random(3)。

  差异（TODO(migrate)）：
  - `.c` 的 6 次 `COMBAT_D->do_damage(WEAPON_ATTACK, hurt/i, 50, msg)` 折算为
    逐击 `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage*50, 100))`；
  - 命中后攻击方的 `set_temp("lianhuan",1)` / `add_temp("apply/damage", lvl)`
    与 `start_call_out(remove_effect)` 在跨进程 feedback 中无对应字段，暂不保留
    （remove_effect 文案保留在下面供核对）；
  - 六击文案每条都被 weapon->name() 拆成两段，E 侧按原样用 `<>` 拆分；
  - `living(target)` 门槛由目标侧 combat/perform-incoming 的死亡检查兜底。
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
  alias Kantele.Combat.Performs

  @perform_id "liuhe-bian/lianhuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: skill = force + liuhe-bian + dodge; lvl = liuhe-bian / 3;
    #      ap = skill + random(skill); hurt = skill / 3;
    skill = Stats.skill(stats, "force") + Stats.skill(stats, "liuhe-bian") + Stats.skill(stats, "dodge")
    lvl = Stats.skill(stats, "liuhe-bian")
    ap = skill + Engine.rand(rng, skill)

    with {:ok, target} <- target(combat),
         :ok <- check_state(character),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target),
         :ok <- check_dodge(character) do
      weapon_name = weapon_name(combat)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          hurt: div(skill, 3),
          weapon_name: weapon_name,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! target->is_character() || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "六合连环诀只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("lianhuan"))
  #             return notify_fail("你刚刚使用过六合连环诀，内力还未平复！\n");
  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :lianhuan) do
      {:error, "你刚刚使用过六合连环诀，内力还未平复！\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "whip"
  #             || me->query_skill_mapped("whip") != "liuhe-bian")
  #             return notify_fail("你手中无鞭，如何能够施展连环诀？\n");
  # 三个条件共用一句门槛文案，合并为一个判定。
  defp check_weapon(character) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "whip" and
         Stats.mapped(character.meta.stats, "whip") == "liuhe-bian" do
      :ok
    else
      {:error, "你手中无鞭，如何能够施展连环诀？\n"}
    end
  end

  # LPC: force < 270 / whip < 180 / liuhe-bian < 180
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 270 ->
        {:error, "你的内功火候未到，无法配合鞭法施展连环诀！\n"}

      Stats.skill(stats, "whip") < 180 ->
        {:error, "你鞭法修为不足，还不能使用连环诀！\n"}

      Stats.skill(stats, "liuhe-bian") < 180 ->
        {:error, "你六合鞭法修为不足，还不能使用连环诀！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") <= 300) return notify_fail("你的内力不够，无法施展！\n");
  defp check_resources(character) do
    if character.meta.vitals.neili <= 300 do
      {:error, "你的内力不够，无法施展！\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人引用可能不带 meta（瘦引用），此时跳过，由目标侧
  # combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: if (me->query_skill("dodge", 1) < 180) return notify_fail("你轻功修为不足，无法快速攻击！\n");
  defp check_dodge(character) do
    if Stats.skill(character.meta.stats, "dodge") < 180 do
      {:error, "你轻功修为不足，无法快速攻击！\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target, weapon_name) do
    # LPC: msg = HIR "\n$N大喝一声，口中轻轻念诵佛经，手中" + weapon->name() +
    #               HIR "霍霍，招招连环，" "快如电闪！\n\n" NOR;
    # 兵刃名把文案拆成两段（后半两段相邻字面量在 C 侧合并）。
    # 分支 neili/busy 由目标侧 feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "\n$N大喝一声，口中轻轻念诵佛经，手中" <> weapon_name <> "霍霍，招招连环，快如电闪！\n\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    # remove_effect 的收回文案（start_call_out 未建模，仅保留字面量）：
    _fighting_msg = "\n$N将内力收回丹田，手上招数也逐渐慢了下来。\n\n"
    _done_msg = "\n你的内功运行完毕，将内力缓缓收回丹田。\n\n"

    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    hurt = Map.get(data, :hurt, 0)
    weapon_name = Map.get(data, :weapon_name, "")

    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry") + target->query_skill("dodge");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")

    # LPC: if (random(ap) > dp)
    hit? = Engine.rand(rng, ap) > dp

    {vitals, neili_cost, attacker_busy} =
      if hit? do
        # LPC: i = 6..1; damage = hurt / i;
        #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50, 【X合】文案);
        # 折算为逐击 qi 伤害 + 50% 外伤。
        {v, _} =
          Enum.reduce(6..1, {character.meta.vitals, 6}, fn i, {v, _i} ->
            damage = div(hurt, i)
            v = v |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 50, 100))
            {v, i}
          end)

        # LPC: me->add("neili", -300); me->start_busy(2);
        {v, 300, 2}
      else
        # LPC: me->add("neili", -200); me->start_busy(2 + random(3));
        {character.meta.vitals, 200, 2 + Engine.rand(rng, 3)}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC 命中后攻击方的 set_temp("lianhuan",1) / add_temp("apply/damage", lvl)
    # 在跨进程 feedback 中无对应字段，暂不保留。
    Performs.feedback(attacker, neili_cost, attacker_busy)

    msg =
      if hit? do
        hit_messages(weapon_name) |> Enum.join("")
      else
        miss_message()
      end

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC 六击文案（每条被 weapon->name() 拆成两段，E 侧按原样拆分）：
  #   HIY 【天合】 / HIW 【地合】 / HIR 【人合】 / HIG 【神合】 / HIC 【鬼合】 / HIB 【六合】
  defp hit_messages(weapon_name) do
    [
      "\n【天合】，$N舞动手中" <> weapon_name <> "瞬息击向$n的额头，啪的一声轻响，顿时一条血印。\n",
      "\n【地合】，$N一个横扫打向$n的下盘，$n未能看破企图，一声惨嚎，" <> weapon_name <> "鞭端已没入小腿半寸，登时连退数步！\n",
      "\n【人合】，$N与" <> weapon_name <> "合为一体急射向$n，$n措手不急被打的吐血不止！\n",
      "\n【神合】，$N手中" <> weapon_name <> "似有灵性一般死追着$n而去。\n",
      "\n【鬼合】，$N突然面如死灰，动作僵硬，然后杀气却更胜一筹，" <> weapon_name <> "发出灵异的光芒，$n几乎看到了死亡的颜色。\n",
      "\n【六合】，$N口中高唱佛号，手中" <> weapon_name <> "连环击出，鞭影重重，$n再也支持不住，身上被拉出一条条豁口。\n"
    ]
  end

  # LPC: CYN "$n" CYN "不慌不忙，以快打快，将$N" CYN "的招式完全化去。\n" NOR
  # （相邻字面量合并为单段）
  defp miss_message do
    "$n不慌不忙，以快打快，将$N的招式完全化去。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  #          
  # #include <ansi.h> 
  # #include <combat.h> 
  #  
  # //inherit F_DBASE; 
  # inherit F_SSERVER; 
  #  
  # int perform(object me, object target) 
  # { 
  #         object weapon; 
  #         int skill, lvl, ap, dp, i; 
  #         string msg; 
  #         int damage, hurt, tm; 
  #          
  #         //if ( !userp(me) && !me->query("can_perform/liuhe-bian/lianhuan")) 
  #         //        return notify_fail("你所用的外功中没有这个功能!\n"); 
  #                  
  #         if ( !target ) target = offensive_target(me); 
  #          
  #         if ( !target 
  #                 ||   !target->is_character() 
  #                 ||   !me->is_fighting(target) ) 
  #                 return notify_fail("六合连环诀只能对战斗中的对手使用。\n"); 
  #          
  #         if ( me->query_temp("lianhuan") ) 
  #                 return notify_fail("你刚刚使用过六合连环诀，内力还未平复！\n");        
  #  
  #         weapon = me->query_temp("weapon"); 
  #  
  #         if (! objectp(weapon = me->query_temp("weapon"))  
  #                 || (string)weapon->query("skill_type") != "whip"  
  #                 || me->query_skill_mapped("whip") != "liuhe-bian" )  
  #                 return notify_fail("你手中无鞭，如何能够施展连环诀？\n");        
  #          
  #         if ( me->query_skill("force") < 270 ) 
  #                 return notify_fail("你的内功火候未到，无法配合鞭法施展连环诀！\n"); 
  #  
  #         if ( me->query_skill("whip", 1) < 180 ) 
  #                 return notify_fail("你鞭法修为不足，还不能使用连环诀！\n"); 
  #          
  #         if ( me->query_skill("liuhe-bian", 1) < 180 ) 
  #                 return notify_fail("你六合鞭法修为不足，还不能使用连环诀！\n");        
  #  
  #         if ( me->query("neili") <= 300 ) 
  #               return notify_fail("你的内力不够，无法施展！\n");        
  #                  
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n"); 
  #         if ( me->query_skill("dodge", 1) < 180 ) 
  #                 return notify_fail("你轻功修为不足，无法快速攻击！\n"); 
  #  
  #         skill = me->query_skill("force", 1) + me->query_skill("liuhe-bian", 1) + 
  #                 me->query_skill("dodge", 1); 
  #         lvl = me->query_skill("liuhe-bian", 1); 
  #         lvl = lvl / 3; 
  #          
  #         ap = skill + random(skill); 
  #  
  #         dp = target->query_skill("parry", 1) + target->query_skill("dodge", 1);     
  #          
  #         msg = HIR "\n$N大喝一声，口中轻轻念诵佛经，手中" +  
  #                        weapon->name() + "霍霍，招招连环，" 
  #                        "快如电闪！\n\n" NOR; 
  #         if (random(ap) > dp) 
  #         {     
  #              i = 6; 
  #              me->set_temp("lianhuan", 1); 
  #              me->add_temp("apply/damage", lvl); 
  #                  
  #              tm = 5 + random(5); 
  #          
  #              me->start_call_out( (: call_other, __FILE__, "remove_effect", me :), tm); 
  #              me->add("neili", -300); 
  #              me->start_busy(2);        
  #              hurt = skill / 3; 
  #               
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIY "\n【天合】，$N舞动手中" + weapon->name() +  
  #                     HIY "瞬息击向$n的额头，啪的一声轻响，顿时一条血印。\n" NOR); 
  #               
  #              i = 5; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIW "\n【地合】，$N一个横扫打向$n的下盘，$n未能看破企图，一声惨嚎，"  
  #                     + weapon->name() + HIW "鞭端已没入小腿半寸"  
  #                             "，登时连退数步！\n" NOR); 
  #               
  #              i = 4; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIR "\n【人合】，$N与" + weapon->name() + HIR"合为一体急射向$n，"  
  #                     "$n措手不急被打的吐血不止！\n" NOR); 
  #              i = 3; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIG "\n【神合】，$N手中" + weapon->name() + HIG "似有灵性一般" 
  #                     "死追着$n而去。\n" NOR); 
  #              i = 2; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIC "\n【鬼合】，$N突然面如死灰，动作僵硬，然后杀气却更胜一筹，"  
  #                     + weapon->name() + HIC "发出灵异的光芒，$n几乎看到了死亡的颜色。\n"    NOR); 
  #          
  #                 i = 1; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIB "\n【六合】，$N口中高唱佛号，手中" + weapon->name() +  
  #                     HIB "连环击出，鞭影重重，$n再也支持不住，身上被拉出一条条豁口。\n" NOR); 
  #               
  #          } else 
  #          { 
  #              msg += CYN "$n" CYN "不慌不忙，以快打快，将$N" 
  #                     CYN "的招式完全化去。\n" NOR; 
  #              me->add("neili", -200); 
  #              me->start_busy(2 + random(3));  
  #          } 
  #         message_combatd(msg, me, target);  
  #         return 1; 
  # } 
  #  
  # void remove_effect(object me, int amount) 
  # { 
  #         int lvl; 
  #         lvl = (int)me->query_skill("liuhe-bian", 1); 
  #         lvl = lvl / 3; 
  #         me->delete_temp("lianhuan"); 
  #  
  #         if ( me->is_fighting() ) { 
  #                 message_vision(HIR "\n$N将内力收回丹田，手上招数也逐渐慢了下来。\n\n" NOR, me);    
  #         } 
  #         else { 
  #                 tell_object(me, HIR "\n你的内功运行完毕，将内力缓缓收回丹田。\n\n" NOR); 
  #         } 
  #         me->add_temp("apply/damage", -lvl); 
  #  
  # } 
end
