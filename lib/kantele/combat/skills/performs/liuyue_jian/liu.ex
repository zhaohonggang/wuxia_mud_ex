defmodule Kantele.Combat.Skills.Performs.LiuyueJian.Liu do
  @moduledoc """
  perform「流月剑诀」（source liuyue-jian/liu.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `LIU`（→「流月剑诀」）展开；命中判定、伤害与
  分档内力/忙乱（命中 -150/busy2，失手 -60/busy3）按原始 LPC 语义建模。
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

  @perform_id "liuyue-jian/liu"

  # LPC: #define LIU "「" HIY "流月剑诀" NOR "」"
  @move_name "「流月剑诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      # LPC: ap = me->query_skill("sword");
      ap = Stats.skill(stats, "sword")

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #       (string)weapon->query("skill_type") != "sword")
  # （两个条件共用一个 notify_fail 文案）
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 180)
  #      if (me->query_skill("liuyue-jian", 1) < 120)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "liuyue-jian") < 120 ->
        {:error, "你的流月剑舞修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 250)
  defp check_resources(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "liuyue-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "liuyue-jian" do
      {:error, "你没有激发流月剑舞，难以施展#{@move_name}。\n"}
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

  # 本式无「无条件」消耗：neili/busy 均分档（见 resolve_incoming 的 feedback）。
  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "一声清啸，剑法忽变，手中" + weapon->name() + HIY
    #               "轻轻划出，带出一条无比绚丽的剑芒，遥指$n" HIY "而去。\n" NOR;
    # （兵刃名把文案拆成两段）
    conn =
      Broadcast.publish(
        conn,
        "$N一声清啸，剑法忽变，手中" <> weapon_name(character.meta.combat) <>
          "轻轻划出，带出一条无比绚丽的剑芒，遥指$n而去。\n",
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap * 2 / 3 + random(ap);
      damage = div(ap * 2, 3) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -150); me->start_busy(2);（仅命中分支，跨进程回执）
      _ = Performs.feedback(attacker, 150, 2)

      # LPC: HIR "$n" HIR "顿时目瞪口呆，一个不慎，被$N" HIR "精妙的剑招刺中，鲜血飞溅！\n" NOR;
      # （合并为单段）
      conn
      |> Broadcast.publish("$n顿时目瞪口呆，一个不慎，被$N精妙的剑招刺中，鲜血飞溅！\n", bindings)
      |> put_character(character)
    else
      # LPC: me->add("neili", -60); me->start_busy(3);（仅失手分支，跨进程回执）
      _ = Performs.feedback(attacker, 60, 3)

      # LPC: CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P" CYN "的剑招。\n" NOR;
      # （合并为单段）
      conn
      |> Broadcast.publish("可是$p并不慌乱，收敛心神，轻轻格挡开了$P的剑招。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIU "「" HIY "流月剑诀" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyue-jian/liu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIU "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" LIU "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功的修为不够，难以施展" LIU "。\n");
  # 
  #         if (me->query_skill("liuyue-jian", 1) < 120)
  #                 return notify_fail("你的流月剑舞修为不够，难以施展" LIU "。\n");
  # 
  #         if (me->query("neili") < 250)
  #                 return notify_fail("你的真气不够，难以施展" LIU "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "liuyue-jian")
  #                 return notify_fail("你没有激发流月剑舞，难以施展" LIU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "一声清啸，剑法忽变，手中" + weapon->name() + HIY
  #               "轻轻划出，带出一条无比绚丽的剑芒，遥指$n" HIY "而去。\n" NOR;
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap * 2 / 3 + random(ap);
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
  #                                            HIR "$n" HIR "顿时目瞪口呆，一个不慎，被$N"
  #                                            HIR "精妙的剑招刺中，鲜血飞溅！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -60);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P"
  #                        CYN "的剑招。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
