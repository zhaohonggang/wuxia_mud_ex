defmodule Kantele.Combat.Skills.Performs.LinjiZhuang.Powerup do
  @moduledoc """
  exert「powerup」（source linji-zhuang/powerup.c，inherit F_CLEAN_UP）

  自身加力：消耗 100 内力，按临济庄等级给 attack/dodge 临时加成 skill/3、
  给 damage 临时加成 di；置 powerup 临时标记（运功中不可重复施展）；
  战斗中收招忙乱 1~3。起手式固定一句；若手持武器，再按 di 分三档
  （>=95 光华四射 / >=80 闪过一道光华 / >=30 隐隐透出光芒）播一条兵器文案。

  差异（TODO(migrate)）：
  - `di = (sex ? 0 : skill/2)`，封顶 100，再 `+ mahayana/10`。
    框架未建模 sex（`Map.get(meta, :sex)` 恒为 nil），走 else 分支 `di = skill/2`；
  - `receive_damage("qi", 0)` 是空操作；
  - `start_call_out(remove_effect, ...)` 未建模，仅保留收回文案字面量。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Engine

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_state(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用临济庄提升自己的战斗力。\n");
  defp check_target(_character) do
    # 框架内 exert 的 target 即自身
    _msg = "你只能用临济庄提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 100) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :powerup) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # remove_effect 的收回文案（start_call_out 未建模，仅保留字面量）：
    _remove_msg = "你的临济庄运行完毕，将内力收回丹田。\n"

    stats = character.meta.stats
    skill = Stats.skill(stats, "linji-zhuang")
    skill2 = Stats.skill(stats, "mahayana")
    rng = &:rand.uniform/1

    # LPC: if (me->query("sex")) di = 0; else di = skill / 2;
    #      if (di > 100) di = 100; di += skill2 / 10;
    # 框架未建模 sex，Map.get(meta, :sex) 恒为 nil → 走 else（di = skill/2）分支。
    base = if Map.get(character.meta, :sex), do: 0, else: div(skill, 2)
    di = min(base, 100) + div(skill2, 10)

    # LPC: me->add("neili", -100); me->receive_damage("qi", 0);（后者空操作）
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = character.meta.combat
    weapon_name = weapon_name(combat)

    # LPC: message_combatd(MAG "$N微一凝神，运起临济庄，一声娇喝，四周的空气仿佛都凝固了！\n", me);
    conn = Broadcast.publish(conn, "$N微一凝神，运起临济庄，一声娇喝，四周的空气仿佛都凝固了！\n", n1: character.name)
    conn = publish_weapon_msg(conn, di, weapon_name, character.name)

    # LPC: add_temp("apply/attack", skill/3) / add_temp("apply/dodge", skill/3)
    #      / add_temp("apply/damage", di); set_temp("powerup", 1);
    combat = Combat.apply_temp(combat, %{attack: div(skill, 3), dodge: div(skill, 3), damage: di})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :powerup, 1)}

    # LPC: if (me->is_fighting()) me->start_busy(1 + random(3));
    combat =
      if Combat.fighting?(combat) do
        Combat.start_busy(combat, 1 + Engine.rand(rng, 3))
      else
        combat
      end

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
  end

  # LPC 三档兵器文案（HIR，去色后 `$N` 与后文合并；weapon->name() 用 + 拼接，
  # 故每档在 E 侧仍是两段字面量）：
  #   di >= 95 光华四射，漫起无边杀意 / di >= 80 闪过一道光华，气势摄人
  #   di >= 30 隐隐透出一股光芒，闪烁不定；di < 30 不播
  defp publish_weapon_msg(conn, _di, nil, _me_name), do: conn

  defp publish_weapon_msg(conn, di, weapon_name, me_name) do
    msg =
      cond do
        di >= 95 ->
          "$N脸色一沉，运起临济庄神通，霎时间" <> weapon_name <> "光华四射，漫起无边杀意。\n"
        di >= 80 ->
          "$N潜运内力，只见" <> weapon_name <> "闪过一道光华，气势摄人，令人肃穆。\n"
        di >= 30 ->
          "$N默运内力，就见那" <> weapon_name <> "隐隐透出一股光芒，闪烁不定。\n"
        true ->
          nil
      end

    if msg, do: Broadcast.publish(conn, msg, n1: me_name), else: conn
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount, int di);
  # 
  # int exert(object me, object target)
  # {
  #         int skill, skill2;
  #         int di;
  #         object weapon;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用临济庄提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("linji-zhuang", 1);
  #         skill2 = me->query_skill("mahayana", 1);
  # 
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         if (me->query("sex")) di = 0; else di = skill / 2;
  #         if (di > 100) di = 100;
  #         di += skill2 / 10;
  # 
  #         message_combatd(MAG "$N" MAG "微一凝神，运起临济庄，一声娇喝，"
  #                         "四周的空气仿佛都凝固了！\n" NOR, me);
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #         {
  #                 if (di >= 95)
  #                         message_combatd(HIR "$N" HIR "脸色一沉，运起临济庄神通，霎时间" +
  #                                         weapon->name() + HIR "光华四射，漫起无边杀意。\n" NOR, me);
  #                 else
  #                 if (di >= 80)
  #                         message_combatd(HIR "$N" HIR "潜运内力，只见" +
  #                                         weapon->name() + HIR "闪过一道光华，气势摄人，令人肃穆。\n" NOR, me);
  #                 else
  #                 if (di >= 30)
  #                         message_combatd(HIR "$N" HIR "默运内力，就见那" +
  #                                         weapon->name() + HIR "隐隐透出一股光芒，闪烁不定。\n" NOR, me);
  #         }
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->add_temp("apply/damage", di);
  #         me->set_temp("powerup", 1);
  #         me->start_call_out((: call_other,__FILE__, "remove_effect", me, skill / 3, di :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(1 + random(3));
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount, int di)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/dodge", -amount);
  #                 me->add_temp("apply/damage", -di);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的临济庄运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
