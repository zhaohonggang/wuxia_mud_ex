defmodule Kantele.Combat.Skills.Performs.QuanzhenJian.Ding do
  @moduledoc """
  定阳针「ding」（对照 `kungfu/skill/quanzhen-jian/ding.c`）

  全真剑法单体攻击：需持剑、全真剑法>=100、内功>=150、真气>=150、激发 sword 为
  全真剑法、目标存活。攻击方恒忙乱 2；命中判定
  `random(自身force) > 目标force/2`：命中造成
  `全真剑法 + force + xiantian-gong + random(该值/3)`（外伤 50%）并扣 80 真气；
  未命中扣 30 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `.c` 引子被 `+` 断为两段字面量（`…一式「定阳针` / `」斜斜刺出。`），
    本版以 `Enum.join/2` 保持分段（避免 `<>` 把两个字面量合并成一段）。
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

  @perform_id "quanzhen-jian/ding"
  @move_name "「定阳针」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats, combat)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/quanzhen-jian/ding"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("quanzhen-jian", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "quanzhen-jian") < 100 do
      {:error, "你全真剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在内力太弱，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "quanzhen-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "quanzhen-jian" do
      :ok
    else
      {:error, "你没有激发全真剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, _weapon, stats, combat) do
    # LPC: msg = HIC "$N" HIC "脚下左弓右箭，神气完足如雷霆五岳，一式「"
    #           HIR "定阳针" NOR + HIC "」斜斜刺出。\n" NOR;
    #      me->start_busy(2);
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "$N脚下左弓右箭，神气完足如雷霆五岳，一式「定阳针",
            "」斜斜刺出。\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        force: Stats.skill(stats, "force"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    my_force = max(Map.get(data, :force, 0), 1)
    dp = div(Stats.skill(stats, "force"), 2)

    if Engine.rand(rng, my_force) > dp do
      # LPC: damage = quanzhen-jian + force + xiantian-gong;
      #      damage = damage + random(damage / 3);
      #      do_damage(..., damage, 50, ...); me->add("neili", -80);
      base =
        Stats.skill(stats, "quanzhen-jian") + Stats.skill(stats, "force") +
          Stats.skill(stats, "xiantian-gong")

      damage = base + Engine.rand(rng, max(div(base, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$n看到$N这气拔千钧的一击，竟不知如何招架，登时受了重创！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 80, 0)
      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR;
      #      me->add("neili", -30);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p看破了$P的企图，斜跃避开。\n", bindings)
        )

      Performs.feedback(attacker, 30, 0)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "quanzhen-jian/ding",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DING "「" HIR "定阳针" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/quanzhen-jian/ding"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" DING "。\n");
  # 
  #         if ((int)me->query_skill("quanzhen-jian", 1) < 100)
  #                 return notify_fail("你全真剑法不够娴熟，难以施展" DING "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" DING "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在内力太弱，难以施展" DING "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "quanzhen-jian")
  #                 return notify_fail("你没有激发全真剑法，难以施展" DING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "脚下左弓右箭，神气完足如雷霆五岳，一式「"
  #               HIR "定阳针" NOR + HIC "」斜斜刺出。\n" NOR;
  # 
  #         me->start_busy(2);
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 damage = (int)me->query_skill("quanzhen-jian", 1) +
  #                  (int)me->query_skill("force", 1) +
  #              (int)me->query_skill("xiantian-gong", 1);
  # 
  #                 damage = damage + random(damage / 3);
  # 
  #                 me->add("neili", -80);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "看到$N" HIR "这气拔千钧"
  #                                            "的一击，竟不知如何招架，登时受了重创"
  #                                            "！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，斜跃避开。\n" NOR;
  #                 me->add("neili", -30);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
