defmodule Kantele.Combat.Skills.Performs.XiyangJian.Ci do
  @moduledoc """
  刺剑「ci」（对照 `kungfu/skill/xiyang-jian/ci.c`）

  西洋剑法绝技：需持剑、西洋剑术>=70、内功>=120、真气>=300、激发 sword 为
  西洋剑法、目标存活。命中判定 `ap/2 + random(ap) > 目标parry`（ap = sword）：
  命中造成 `ap/2 + random(ap*2/3)`（外伤 70%）并扣 70 真气、忙乱 2；
  未命中扣 30 真气、忙乱 3。

  差异（TODO(migrate)）：
  - 引子在攻击方广播，命中/落空在目标侧结算；
  - `.c` 无 `can_perform` 门槛，本引擎保留 `perform_known?` 守卫（多 1 条
    信息性 EXTRA）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的
    `dead` 分支兜底；
  - 门槛文案逐字对 `.c`：武器门槛句为「你使用的武器不对。」（无 move_name
    后缀）；mapped 门槛句逐字含「你没有激发西洋剑术不够娴熟，不能使用
    「刺剑」。」（.c 原文如此）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "xiyang-jian/ci"
  @move_name "「刺剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC 无 can_perform 门槛；本引擎保留已知绝招守卫（信息性 EXTRA）。
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #      return notify_fail("「刺剑」只能对战斗中的对手使用。\n");
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  #      return notify_fail("你使用的武器不对。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("xiyang-jian", 1) < 70)
  defp check_skill_level(stats) do
    if Stats.skill(stats, "xiyang-jian") < 70 do
      {:error, "你的西洋剑术不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 120)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功修为不够高，难以运用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "xiyang-jian")
  #      return notify_fail("你没有激发西洋剑术不够娴熟，不能使用「刺剑」。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "xiyang-jian" do
      :ok
    else
      {:error, "你没有激发西洋剑术不够娴熟，不能使用#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIC "\n$N" HIC "一声呼哨，手中的" + weapon->name()
    #           + HIC "犹如一道电光闪向$n" HIC "的胸前。\n"NOR;
    conn =
      Broadcast.publish(
        conn,
        "\n$N一声呼哨，手中的" <> weapon_name <> "犹如一道电光闪向$n的胸前。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        sword: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target))
      #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :sword, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap * 2 / 3); me->add("neili", -70);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #          HIR "$n" HIR "急忙招架，却是慢了一步，被这"
      #          "一剑正好刺中胸口，鲜血飞溅！\n" NOR);
      #      me->start_busy(2);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap * 2, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 70, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("$n急忙招架，却是慢了一步，被这一剑正好刺中胸口，鲜血飞溅！\n", bindings)
        )

      Performs.feedback(attacker, 70, 2)
      put_character(conn, character)
    else
      # LPC: msg += CYN "然而$p" CYN "眼明手快，不慌不忙的将$P"
      #                 CYN "的剑招架开。\n"NOR;
      #      me->add("neili", -30); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("然而$p眼明手快，不慌不忙的将$P的剑招架开。\n", bindings)
        )

      Performs.feedback(attacker, 30, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "xiyang-jian/ci",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // ci.c 刺剑
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「刺剑」只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if ((int)me->query_skill("xiyang-jian", 1) < 70)
  #         return notify_fail("你的西洋剑术不够娴熟，不会使用「刺剑」。\n");
  # 
  #     if ((int)me->query_skill("force") < 120)
  #         return notify_fail("你的内功修为不够高，难以运用「刺剑」。\n");
  # 
  #     if ((int)me->query("neili") < 300)
  #         return notify_fail("你现在真气不够，不能使用「刺剑」。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "xiyang-jian")
  #                 return notify_fail("你没有激发西洋剑术不够娴熟，不能使用「刺剑」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "\n$N" HIC "一声呼哨，手中的" +
  #               weapon->name() + HIC "犹如一道电光闪向$n" HIC "的胸前。\n"NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap / 2 + random(ap * 2 / 3);
  #                 me->add("neili", -70);
  #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "急忙招架，却是慢了一步，被这"
  #                                            "一剑正好刺中胸口，鲜血飞溅！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += CYN "然而$p" CYN "眼明手快，不慌不忙的将$P"
  #                        CYN "的剑招架开。\n"NOR;
  #         me->add("neili", -30);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
