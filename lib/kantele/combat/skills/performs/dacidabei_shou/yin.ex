defmodule Kantele.Combat.Skills.Performs.DacidabeiShou.Yin do
  @moduledoc """
  perform「大手印」（source dacidabei-shou/yin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：佛法>=200 → 目标在战斗中且存活 → 大慈大悲手>=180 →
  基本手法>=180 → 臂力>=35 → 内力上限>=2000 → 真气>=800 → 准备 hand 为大慈大悲手 →
  空手。命中判定 `attack = (exp/1000 + hand + neili/5 + random(...))/2` 对目标
  `defense = exp/1000 + dodge + neili/7`：命中则伤害 `dacidabei-shou/40 * jiali`
  （qi 伤，1/3 创伤），并可能击碎目标 cloth 护甲（armor<200 且 damage>500）；
  攻击方命中额外扣 `jiali` 真气，收招统一扣 200 真气并忙乱 `2 + random(2)`。

  差异（TODO(migrate)）：
  - LPC 的 `armor->unequip(); move(environment); set("name", …); reset_action()`
    折算为 `Combat.unequip(:cloth)`（本引擎护甲仅存于战斗快照，无地面掉落与
    物品改名模型，`"破碎的"` 前缀文案保留以免信息丢失）；
  - LPC 失手分支用 `SKILL_D(dodge_skill)->query_dodge_msg(target, 1)`（按目标
    闪避技能取文案），折算为通用 `Messages.dodge_msg/0`；
  - `.c` 的 `target->query_temp("armor/cloth")` 对应 `combat.equipped[:cloth]`；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "dacidabei-shou/yin"
  @move_name "「大手印」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    vitals = character.meta.vitals
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dacidabei-shou")
    # LPC: jiali = me->query("jiali") + 1;
    jiali = combat.jiali + 1
    # LPC: attack = me->query("combat_exp")/1000 + me->query_skill("hand") + me->query("neili")/5;
    attack = div(stats.combat_exp, 1000) + Stats.skill(stats, "hand") + div(vitals.neili, 5)
    # LPC: attack = (attack + random(attack + 1)) / 2;
    attack = div(attack + Engine.rand(rng, attack + 1), 2)
    # LPC: damage = me->query_skill("dacidabei-shou", 1) / 40 * jiali;
    damage = div(lvl, 40) * jiali

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_weapon(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          attack: attack,
          damage: damage,
          jiali: jiali,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
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

  # LPC: if (! target || ! me->is_fighting(target) || ! living(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC 顺序：buddhism < 200 → dacidabei-shou < 180 → hand < 180 →
  #           query_str() < 35 → max_neili < 2000 → neili < 800
  defp check_levels(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "buddhism") < 200 ->
        {:error, "你的佛法修为不足，无法施展该绝招！\n"}

      Stats.skill(stats, "dacidabei-shou") < 180 ->
        {:error, "你的大慈大悲手不够娴熟，不会使用#{@move_name}！\n"}

      Stats.skill(stats, "hand") < 180 ->
        {:error, "你的基本手法不够娴熟，不会使用#{@move_name}！\n"}

      Stats.query_str(stats) < 35 ->
        {:error, "你的臂力不够强，不能使用#{@move_name}！\n"}

      vitals.max_neili < 2000 ->
        {:error, "你的内力太弱，不能使用#{@move_name}！\n"}

      vitals.neili < 800 ->
        {:error, "你的内力太少了，无法使用出#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "dacidabei-shou")
  defp check_prepared(character) do
    case Stats.prepared_perform(character.meta.stats, "hand") do
      nil ->
        {:error, "你还没有准备大慈大悲手，无法施展#{@move_name}！\n"}

      value ->
        if String.split(value, "/") |> hd() == "dacidabei-shou" do
          :ok
        else
          {:error, "你还没有准备大慈大悲手，无法施展#{@move_name}！\n"}
        end
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # LPC: message_vision(HIR "\n$N突然面色通红，低声默念禅宗真言，双臂骨节一阵爆响，
    #       猛然腾空而起，伸手向$n胸前按去，好一式「大手印」！\n" NOR, me, target);
    # 命中/伤害/护甲击碎在目标侧结算（defense 需目标 combat_exp/dodge/neili）。
    conn
    |> Broadcast.publish(
      "\n$N突然面色通红，低声默念禅宗真言，双臂骨节一阵爆响，猛然腾空而起，伸手向$n胸前按去，好一式「大手印」！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    attack = Map.get(data, :attack, 0)
    damage = Map.get(data, :damage, 0)
    jiali = Map.get(data, :jiali, 1)
    stats = character.meta.stats
    vitals = character.meta.vitals

    # LPC: defense = target->query("combat_exp")/1000 + target->query_skill("dodge")
    #            + target->query("neili")/7;
    defense = div(stats.combat_exp, 1000) + Stats.skill(stats, "dodge") + div(vitals.neili, 7)

    # LPC: if (attack > defense)
    if attack > defense do
      {combat, conn} = break_cloth(conn, character, damage)

      # LPC: tell_object(target, RED "你只觉得霍的胸口一阵剧痛，已经被拍中了前胸！\n" NOR);
      conn =
        render(conn, CommandView, "text", %{
          text: "你只觉得霍的胸口一阵剧痛，已经被拍中了前胸！\n"
        })

      # LPC: target->receive_damage("qi", damage, me); target->receive_wound("qi", damage/3, me);
      vitals =
        vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # LPC: p = target->query("qi")*100/max_qi; msg = "( $n"+eff_status_msg(p)+" )\n";
      ratio = div(vitals.qi * 100, max(vitals.max_qi, 1))

      conn =
        Broadcast.publish(conn, "( $n#{Messages.eff_status_msg(ratio)} )\n", n2: character.name)

      # LPC: me->add("neili", -jiali); … me->add("neili", -200); me->start_busy(2+random(2));
      Performs.feedback(attacker, jiali + 200, 2 + Engine.rand(rng, 2))

      put_character(conn, character)
    else
      # LPC: message_vision(SKILL_D(dodge_skill)->query_dodge_msg(target, 1), me, target);
      conn =
        Broadcast.publish(conn, Messages.dodge_msg(),
          n1: attacker.name,
          n2: character.name
        )

      # LPC: me->add("neili", -200); me->start_busy(2+random(2));
      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

      put_character(conn, character)
    end
  end

  # LPC: if (objectp(armor = target->query_temp("armor/cloth"))
  #      && armor->query("armor_prop/armor") < 200 && damage > 500) { … 击碎护甲 … }
  defp break_cloth(conn, character, damage) do
    case Map.get(character.meta.combat.equipped, :cloth) do
      %{name: armor_name} = cloth when damage > 500 ->
        if (Map.get(cloth, :armor) || 0) < 200 do
          # LPC: message_vision(HIY "只见这斗大的手印正好印在$N的$n" HIY "上，越变越大，
          #      竟将它震得粉碎，裂成一块块掉在地上！\n" NOR, target, armor);
          conn =
            Broadcast.publish(
              conn,
              "只见这斗大的手印正好印在$N的$n上，越变越大，竟将它震得粉碎，裂成一块块掉在地上！\n",
              n1: character.name,
              n2: armor_name
            )

          # LPC: armor->unequip(); armor->move(environment(target));
          #      armor->set("name", "破碎的" + armor->query("name")); set value/armor 0;
          #      target->reset_action();
          # 本引擎护甲仅存于战斗快照，无地面掉落与物品改名模型：卸下 cloth 槽位即等价，
          # 破碎后的名称仅作展示，故此处保留该前缀文案以免信息丢失。
          _ = "破碎的"

          {Combat.unequip(character.meta.combat, :cloth), conn}
        else
          {character.meta.combat, conn}
        end

      _ ->
        {character.meta.combat, conn}
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # #include "/kungfu/skill/eff_msg.h";
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #       string msg, dodge_skill;                                
  #       int damage, jiali, attack, defense, p;
  #       object armor;
  # 
  # 
  #       if (me->query_skill("buddhism", 1) < 200)
  #            return notify_fail("你的佛法修为不足，无法施展该绝招！\n");
  #       
  #       if( !target ) target = offensive_target(me);
  #      
  #       if( !target || !me->is_fighting(target) || !living(target) )
  #            return notify_fail("「大手印」只能在战斗中对对手使用。\n");        
  #       
  #       if( (int)me->query_skill("dacidabei-shou",1) < 180 )
  #            return notify_fail("你的大慈大悲手不够娴熟，不会使用「大手印」！\n");
  #       
  #       if( (int)me->query_skill("hand",1) < 180 )
  #            return notify_fail("你的基本手法不够娴熟，不会使用「大手印」！\n");
  # 
  #       if( (int)me->query_str() < 35 )
  #            return notify_fail("你的臂力不够强，不能使用「大手印」！\n");
  #       
  #       if( (int)me->query("max_neili") < 2000 )
  #            return notify_fail("你的内力太弱，不能使用「大手印」！\n");
  #       
  #       if( (int)me->query("neili") < 800 )
  #            return notify_fail("你的内力太少了，无法使用出「大手印」！\n");   
  #        
  #       if (me->query_skill_prepared("hand") != "dacidabei-shou")
  #            return notify_fail("你还没有准备大慈大悲手，无法施展「大手印」！\n");   
  #           
  #       if( objectp(me->query_temp("weapon")) )
  #            return notify_fail("你必须空手使用「大手印」！\n");                                                                              
  #       jiali = me->query("jiali")+1;
  #       attack = me->query("combat_exp")/1000;
  #       attack += me->query_skill("hand");
  #       attack += me->query("neili")/5;
  #       defense = target->query("combat_exp")/1000;
  #       defense += target->query_skill("dodge");
  #       defense += target->query("neili")/7;
  #       attack = (attack+random(attack+1))/2;
  #       
  #       damage = me->query_skill("dacidabei-shou", 1)/40 * jiali;
  #       
  #       message_vision(HIR "\n$N突然面色通红，低声默念禅宗真言，双臂骨节一阵爆响，猛然"
  #                      "腾空而起，伸手向$n胸前按去，好一式「大手印」！\n"NOR,me,target);
  #  
  #       if( attack > defense ) { 
  #          if( objectp(armor = target->query_temp("armor/cloth"))
  #             && armor->query("armor_prop/armor") < 200
  #             && damage > 500){
  #                         message_vision(HIY"只见这斗大的手印正好印在$N的$n"HIY"上，越变越"
  #                                        "大，竟将它震得粉碎，裂成一块块掉在地上！\n"NOR, target, armor);
  #                         armor->unequip();
  #                         armor->move(environment(target));
  #                         armor->set("name", "破碎的" + armor->query("name"));    
  #                         armor->set("value", 0);
  #                         armor->set("armor_prop/armor", 0);
  #                         target->reset_action();
  #                         }
  #          tell_object(target, RED"你只觉得霍的胸口一阵剧痛，已经被拍中了前胸！\n"NOR);
  #          target->receive_damage("qi", damage,  me);
  #          target->receive_wound("qi", damage/3, me);
  #          p = (int)target->query("qi")*100/(int)target->query("max_qi");
  # 
  #          msg = "( $n"+eff_status_msg(p)+" )\n";
  #          message_vision(msg, me, target);
  #          me->add("neili", -jiali);
  #         }
  #       else {
  #          dodge_skill = target->query_skill_mapped("dodge");
  #          if( !dodge_skill ) dodge_skill = "dodge";
  #          message_vision(SKILL_D(dodge_skill)->query_dodge_msg(target, 1), me, target);
  #          }
  #       me->add("neili", -200);
  #       me->start_busy(2+random(2));            
  #       return 1;
  # }
end
