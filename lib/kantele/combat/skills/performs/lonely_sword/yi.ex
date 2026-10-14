defmodule Kantele.Combat.Skills.Performs.LonelySword.Yi do
  @moduledoc """
  perform「剑意」（source lonely-sword/yi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 持剑 → 真气>=200 →
  `lonely-sword`>=120 → 激发 `sword` 为独孤九剑 → 目标存活。
  起手文案按 `random(3)` 三选一（其中一支含手中兵器名）。

  对抗：`ap = 基本剑法`；目标 `dp = 招架 + 技击常识 + 独孤九剑`。
  - `ap/2 + random(ap) > dp`：伤害 `ap + random(ap)`（外伤 60%），
    攻击方真气 -180、忙乱 2；
  - 否则：攻击方真气 -60、忙乱 3。

  差异（TODO(migrate)）：
  - 起手文案三选一与命中结算依赖目标属性，故整体在目标侧
    `resolve_incoming/4` 完成；攻击方仅下发 `ap`/兵器名，其真气消耗与忙乱
    经 `combat/perform-feedback` 回执补记；
  - `COMBAT_D->do_damage(..., WEAPON_ATTACK, damage, 60, …)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*60/100)`；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧死亡检查兜底。
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
  alias Kantele.Combat.Performs

  @perform_id "lonely-sword/yi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: ap = me->query_skill("sword");
    ap = Stats.skill(stats, "sword")

    with {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_neili(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: ap,
          ap: ap,
          weapon_name: Map.get(weapon, :name),
          rng: rng
        }
      })

      # 起手文案与命中结算均依赖目标属性，故整体在目标侧完成。
      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能对战斗中的对手使用绝招。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("无剑如何运用剑意？\n");
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "无剑如何运用剑意？\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在的真气不够，无法使用剑意！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，无法使用剑意！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("lonely-sword", 1) < 120)
  #         return notify_fail("你的独孤九剑还不到家，无法使用剑意！\n");
  defp check_level(stats) do
    if Stats.skill(stats, "lonely-sword") < 120 do
      {:error, "你的独孤九剑还不到家，无法使用剑意！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "lonely-sword")
  #         return notify_fail("你没有激发独孤九剑，无法使用剑意！\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "lonely-sword" do
      {:error, "你没有激发独孤九剑，无法使用剑意！\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

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
    ap = max(Map.get(data, :ap, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: switch (random(3)) { case 0: …; case 1: …; default: … }
    opening =
      case Engine.rand(rng, 3) do
        0 -> "$N一剑刺出，连自已也不知道要刺往何处。\n"
        1 -> "$N随手挥洒手中的" <> weapon_name <> "，漫无目的，不成任何招式。\n"
        _ -> "$N斜斜刺出一剑，准头之差，令人匪夷所思。\n"
      end

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize",1) +
    #          target->query_skill("lonely-sword");
    dp =
      Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize") +
        Stats.skill(stats, "lonely-sword")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap); me->add("neili", -180);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60, …); me->start_busy(2);
      damage = ap + Engine.rand(rng, ap)
      vitals = character.meta.vitals
      vitals = Vitals.damage(vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 60, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 180, 2)

      conn
      |> Broadcast.publish(
        opening <> "$n全然无法领会$P这莫名其妙的招数，一个疏神，登时受创！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "淡然处之，并没有将$P" CYN "此招放在心上，随手架开，不漏半点破绽。\n" NOR;
      #      me->add("neili", -60); me->start_busy(3);
      Performs.feedback(attacker, 60, 3)

      conn
      |> Broadcast.publish(opening <> "$n淡然处之，并没有将$P此招放在心上，随手架开，不漏半点破绽。\n", bindings)
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yi.c 剑意
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("你只能对战斗中的对手使用绝招。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("无剑如何运用剑意？\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在的真气不够，无法使用剑意！\n");
  # 
  #     if ((int)me->query_skill("lonely-sword", 1) < 120)
  #         return notify_fail("你的独孤九剑还不到家，无法使用剑意！\n");
  # 
  #     if (me->query_skill_mapped("sword") != "lonely-sword")
  #         return notify_fail("你没有激发独孤九剑，无法使用剑意！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         switch (random(3))
  #         {
  #         case 0:
  #                 msg = HIM "$N" HIM "一剑刺出，连自已也不知道要刺往何处。\n" NOR;
  #                 break;
  # 
  #         case 1:
  #                 msg = HIM "$N" HIM "随手挥洒手中的" + weapon->name() +
  #                        HIM "，漫无目的，不成任何招式。\n" NOR;
  #                 break;
  # 
  #         default:
  #                 msg = HIM "$N" HIM "斜斜刺出一剑，准头之差，令人匪夷所思。\n" NOR;
  #                 break;
  #         }
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry") + target->query_skill("martial-cognize",1) +
  #              target->query_skill("lonely-sword");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap);
  #                 me->add("neili", -180);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
  #                                    HIR "$n" HIR "全然无法领会$P"
  #                                            HIR "这莫名其妙的招数，一个疏神，登时受创！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "$n" CYN "淡然处之，并没有将$P"
  #                        CYN "此招放在心上，随手架开，不漏半点破绽。\n" NOR;
  #                 me->add("neili", -60);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
