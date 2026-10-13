defmodule Kantele.Combat.Skills.Performs.LiangyiJian.Ren do
  @moduledoc """
  perform「天地同仁」（source liangyi-jian/ren.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 持剑类武器 → 两仪剑法>=120 →
  内力上限>=1500 → 激发 sword 为两仪剑法 → 真气>=200 → 目标存活。
  命中判定 `sword/2 + random(sword)` > 目标 `parry`；命中伤害
  `(sword*4/3)/2 + random(同值*2/3)`（50% 外伤）、扣 180 真气、忙乱 2；
  未命中扣 100 真气、忙乱 3。

  差异（TODO(migrate)）：LPC 的 can_perform 被注释掉（冲虚 NPC 说明），
  故无 check_perform_known；内力/忙乱由目标侧 feedback 回执。
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

  @perform_id "liangyi-jian/ren"
  @move_name "「天地同仁」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      weapon_name =
        case Combat.weapon(combat) do
          nil -> ""
          weapon -> Map.get(weapon, :name)
        end

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "liangyi-jian"),
          skill: Stats.skill(stats, "liangyi-jian"),
          # LPC: ap = me->query_skill("sword")
          ap: Stats.skill(stats, "sword"),
          weapon_name: weapon_name,
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("liangyi-jian", 1) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "liangyi-jian") < 120 do
      {:error, "你两仪剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 1500)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1500 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "liangyi-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "liangyi-jian" do
      :ok
    else
      {:error, "你没有激发两仪剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
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

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "$N" HIW "手中" + weapon->name() +
    #      HIW "剑芒跃动，剑光暴长，剑尖颤动似乎分左右刺向$n" HIW "，$n"
    #      HIW "看到剑\n光偏左，疾侧身右转，但只这一刹，剑光刹时袭" "向右首！\n";
    # 起手式两段字面量以 weapon->name() 分隔（中含 \n，逐字保留）；
    # 命中文案/伤害在目标侧结算。
    weapon_name =
      case Combat.weapon(character.meta.combat) do
        nil -> ""
        weapon -> Map.get(weapon, :name)
      end

    conn =
      Broadcast.publish(
        conn,
        "$N手中" <> weapon_name <>
          "剑芒跃动，剑光暴长，剑尖颤动似乎分左右刺向$n，$n看到剑\n光偏左，疾侧身右转，但只这一刹，剑光刹时袭向右首！\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
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
    ap = max(Map.get(data, :ap, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # me->start_busy(2);
      # damage = ap * 4 / 3; damage = damage / 2 + random(damage * 2 / 3);
      # do_damage(WEAPON_ATTACK, damage, 50, …); me->add("neili", -180);
      base = div(ap * 4, 3)
      damage = div(base, 2) + Engine.rand(rng, div(base * 2, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 2))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 180, 2)

      conn
      |> Broadcast.publish(
        "$n疾忙左转，却发现$N的" <> weapon_name <>
          "疾往左转，登时穿胸而过，血如泉涌。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    else
      # me->add("neili", -100); me->start_busy(3);
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish(
        "可是$p轻轻一笑，侧身右转，躲开了$P左转的剑式，毫发未伤。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define REN "「" HIW "天地同仁" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int ap, dp, damage;
  #         string msg;
  #         object weapon;
  # 
  # //冲虚是武当追杀npc，所以不实际增加冲虚了，两仪剑绝招改为自动可用。
  #         //if (userp(me) && ! me->query("can_perform/liangyi-jian/ren"))
  #        //         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(REN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" REN "。\n");
  # 
  #         if ((int)me->query_skill("liangyi-jian", 1) < 120)
  #                 return notify_fail("你两仪剑法不够娴熟，难以施展" REN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为不足，难以施展" REN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "liangyi-jian")
  #                 return notify_fail("你没有激发两仪剑法，难以施展" REN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，难以施展" REN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW"剑芒跃动，剑光暴长，剑尖颤动似乎分左右刺向$n"
  #               HIW "，$n" HIW "看到剑\n光偏左，疾侧身右转，但只这一刹，剑光刹时袭"
  #               "向右首！\n";
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(2);
  #                 damage = ap * 4 / 3;
  #                 damage = damage / 2 + random(damage * 2 / 3);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "疾忙左转，却发现$N" HIR
  #                                            "的" + weapon->name() + HIR "疾往左转"
  #                                            "，登时穿胸而过，血如泉涌。\n" NOR);
  #                 me->add("neili", -180);
  #         } else
  #         {
  #                   me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "轻轻一笑，侧身右转，躲开了$P"
  #                        CYN "左转的剑式，毫发未伤。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
