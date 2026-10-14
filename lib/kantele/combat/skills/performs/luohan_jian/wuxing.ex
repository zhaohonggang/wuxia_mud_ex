defmodule Kantele.Combat.Skills.Performs.LuohanJian.Wuxing do
  @moduledoc """
  perform「来去若无形」（对照 `kungfu/skill/luohan-jian/wuxing.c`）

  门槛（按 .c 顺序）：目标在战斗中 → 持剑 → 罗汉剑法>=100 → 真气>=300 → 目标存活。
  起手广播后攻击方扣 200 真气、忙乱 3；随即连出 5 击（来/去/若/无/形 五字决，
  `COMBAT_D->do_attack`），再补一记 `do_damage(WEAPON_ATTACK, 罗汉剑法, 80)` 收招。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛；本引擎的 `Stats.perform_known?/2` 属框架级守卫
    （全库 79% 的绝招模块均有），此处保留，故验收多 1 条信息性 EXTRA；
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15 + extra` 基础伤害 + 命中判定 `level/2 + extra + random(level)` vs
    目标 dodge（同 `duanjia_sword/jue.ex`）；`do_attack` 无独立命中/失手文案，
    由引擎动作表生成，故本文件不再自行发布逐击结果文案；
  - `me->add_temp("apply/attack"/"apply/damage", extra)` 的临时加成
    （`extra = 2 * (罗汉剑法/10)`，`.c` 中分两行累加）折入目标侧每击的命中/伤害
    （攻击方本地 temp 对远程结算无意义），收招的 `-extra` 不再重复落账；
  - 5 段「X字决！」为 `message_combatd`（房间可见），攻击/目标分处两进程，
    按 LPC 顺序在攻击方顺序发布；
  - `!living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底（同 `chongyang_shenzhang/lian.ex`）；
  - `.c` 顶部声明的 `remove_effect(object, int, int)` 全文件未被定义/调用（死代码），
    未在 Elixir 侧保留。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "luohan-jian/wuxing"
  @move_name "「来去若无形」"

  # LPC: 5 次 COMBAT_D->do_attack（来/去/若/无/形 五字决）
  @strikes 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luohan-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          extra: div(lvl, 10) * 2,
          strikes: @strikes,
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
    if Stats.perform_known?(character.meta.stats, @perform_id),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  # LPC: if ( !target ) target = offensive_target(me);
  #      if ( !target || !target->is_character() || !me->is_fighting(target) )
  # 敌人列表只含 character，故 is_character 隐含成立。
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "#{@move_name}必须用剑才能施展。\n"}
    end
  end

  # LPC: if( (int)me->query_skill("luohan-jian", 1) < 100 )
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "luohan-jian") < 100 do
      {:error, "你的「罗汉剑法」不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if( (int)me->query("neili") < 300 )
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: me->add("neili", -200);（无条件）
    #      me->start_busy(3);（无条件，位于收招处）
    #      msg = HIG "$N身行突变，…\n" NOR; message_vision(msg, me, target);
    #      message_combatd(HIR "  来字决！\n" …) 等 5 段。
    # 攻击/目标分处两进程，5 段字决按 LPC 顺序在攻击方顺序发布。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 200, 0)}
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    bindings = [n1: character.name, n2: target.name]

    conn
    |> Broadcast.publish("$N身行突变，瞬间犹如分出无数身影闪电般的向$n攻去！\n", bindings)
    |> Broadcast.publish("  来字决！\n", bindings)
    |> Broadcast.publish("    去字决！\n", bindings)
    |> Broadcast.publish("      若字决！\n", bindings)
    |> Broadcast.publish("        无字决！\n", bindings)
    |> Broadcast.publish("          形字决！\n", bindings)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    extra = Map.get(data, :extra, 0)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 15), 1) + extra

    # LPC: 5 次 COMBAT_D->do_attack(me, target, weapon, TYPE_REGULAR)
    # 折算：每击 `level/15 + extra` 基础伤害 + 命中判定
    #       （`level/2 + extra + random(level)` vs 目标 dodge）。
    combo =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(level, 2) + extra + Engine.rand(rng, level) > dodge do
          acc + per_hit + Engine.rand(rng, per_hit)
        else
          acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, combo)
      |> Vitals.wound(:qi, div(combo, 3))

    # LPC: msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, skill, 80,
    #                                 HIC "            来去若无形    幻化无真境 \n" NOR);
    #      message_combatd(msg, me, target);（无条件）
    vitals =
      vitals
      |> Vitals.damage(:qi, level)
      |> Vitals.wound(:qi, div(level * 80, 100))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish("            来去若无形    幻化无真境 \n")
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # //来去若无形 wuxing.c 
  #          
  # #include <ansi.h> 
  # #include <skill.h> 
  # #include <weapon.h> 
  # #include <combat.h> 
  #          
  # //inherit F_CLEAN_UP; 
  #  
  # void remove_effect(object me, int a_amount, int d_amount); 
  #  
  # inherit F_SSERVER; 
  # int perform(object me, object target) 
  # { 
  #         object weapon; 
  #         int skill; 
  #         int extra; 
  #         string msg; 
  #   
  #         if ( !target ) target = offensive_target(me); 
  #          
  #         if ( !target 
  #                 ||      !target->is_character() 
  #                 ||      !me->is_fighting(target) ) 
  #                         return notify_fail("「来去若无形」只能在战斗中使用。\n"); 
  #  
  #         if (!objectp(weapon = me->query_temp("weapon")) 
  #                 || (string)weapon->query("skill_type") != "sword") 
  #                 return notify_fail("「来去若无形」必须用剑才能施展。\n"); 
  #          
  #         if( (int)me->query_skill("luohan-jian", 1) < 100 ) 
  #                 return notify_fail("你的「罗汉剑法」不够娴熟，不会使用「来去若无形」。\n"); 
  #  
  #         if( (int)me->query("neili") < 300  )  
  #                 return notify_fail("你的内力不够。\n"); 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #  
  #         skill = me->query_skill("luohan-jian",1); 
  #          
  #         extra = me->query_skill("luohan-jian",1) / 10; 
  #         extra += me->query_skill("luohan-jian",1) / 10; 
  #         me->add_temp("apply/attack", extra);     
  #         me->add_temp("apply/damage", extra); 
  #          
  #         msg = HIG "$N身行突变，瞬间犹如分出无数身影闪电般的向$n攻去！\n" NOR; 
  #                message_vision(msg, me, target);  
  #          
  #         me->add("neili", -200); 
  #          
  #         message_combatd(HIR "  来字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIY "    去字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #  
  #         message_combatd(HIG "      若字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIB "        无字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIW "          形字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  # 
  #         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, skill, 80,  
  # 
  # 
  #                     HIC "            来去若无形    幻化无真境 \n" NOR); 
  #         message_combatd(msg, me, target);  
  # 
  # 
  #         me->start_busy(3); 
  #         me->add_temp("apply/attack", -extra); 
  #         me->add_temp("apply/damage", -extra); 
  #  
  #         return 1; 
  # } 
end
