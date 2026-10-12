defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Yu do
  @moduledoc """
  perform「大智若愚」（source guzhuo-zhang/yu.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  内功>=260 → 内力上限>=2800 → 古拙掌法>=180 → 激发 `strike` 为古拙掌法 →
  准备古拙掌法 → 真气>=600 → 目标存活。
  攻击方无条件忙乱 3。命中判定 `ap/2 + random(ap)`（`ap = strike + str*10`）对目标
  `force + int*10`：命中则目标 qi 伤 `ap + random(ap/2)`、qi 上限伤 `damage*70/100`，
  攻击方扣 300 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., 70, "…")`（第 6 参为文案字面量）折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*70/100)` 并广播该文案；
  - `.c` 的 `me->start_busy(3)` 无条件、`me->add("neili", -300)` 在命中分支内，
    故忙乱由攻击方结算、真气由目标侧 `Performs.feedback` 回执（`busy: 0` 不改忙乱）；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "guzhuo-zhang/yu"
  @move_name "「大智若愚」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "guzhuo-zhang")
    # LPC: ap = me->query_skill("strike") + me->query("str") * 10;
    ap = Stats.skill(stats, "strike") + Stats.query_str(stats) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手使用。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 260)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 260 do
      {:error, "你内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 2800)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 2800 do
      {:error, "你内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("guzhuo-zhang", 1) < 180)
  defp check_level(stats) do
    if Stats.skill(stats, "guzhuo-zhang") < 180 do
      {:error, "你古拙掌法火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "guzhuo-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "guzhuo-zhang" do
      {:error, "你没有激发古拙掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "guzhuo-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "guzhuo-zhang" do
      :ok
    else
      {:error, "你没有准备古拙掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 600)
  defp check_neili(character) do
    if character.meta.vitals.neili < 600 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
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
    # LPC: msg = HIR "$N" HIR "体内真气迸发，大喝一声，双掌向$n" HIR "平平推"
    #            "去，招数朴实无华，毫无半点花巧可言。\n" NOR;
    #      me->start_busy(3);
    conn =
      Broadcast.publish(
        conn,
        "$N体内真气迸发，大喝一声，双掌向$n平平推去，招数朴实无华，毫无半点花巧可言。\n",
        n1: character.name,
        n2: target.name
      )

    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query("int") * 10;
    #      if (ap / 2 + random(ap) > dp) { damage = ap + random(ap / 2);
    #            msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70, "…"); }
    #      else { msg += "$n见$N这掌来势非凡，不敢轻易招架，当即飞身纵跃闪开。\n"; }
    dp = Stats.skill(stats, "force") + Stats.query_int(stats) * 10

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: me->add("neili", -300);（命中分支内，回执给攻击方；忙乱已在攻击方结算）
      damage = ap + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 70, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 300, 0)

      conn
      |> Broadcast.publish(
        "$n勘破不透掌中虚实，$N双掌正中$p前胸，“喀嚓喀嚓”接连断了数根肋骨。\n",
        bindings
      )
      |> put_character(character)
    else
      Broadcast.publish(conn, "$n见$N这掌来势非凡，不敢轻易招架，当即飞身纵跃闪开。\n", bindings)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YU "「" HIR "大智若愚" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/guzhuo-zhang/yu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YU "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YU "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 260)
  #                 return notify_fail("你内功修为不够，难以施展" YU "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2800)
  #                 return notify_fail("你内力修为不够，难以施展" YU "。\n");
  # 
  #         if ((int)me->query_skill("guzhuo-zhang", 1) < 180)
  #                 return notify_fail("你古拙掌法火候不够，难以施展" YU "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有激发古拙掌法，难以施展" YU "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "guzhuo-zhang")
  #                 return notify_fail("你没有准备古拙掌法，难以施展" YU "。\n");
  # 
  #         if ((int)me->query("neili") < 600)
  #                 return notify_fail("你现在真气不够，难以施展" YU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "体内真气迸发，大喝一声，双掌向$n" HIR "平平推"
  #               "去，招数朴实无华，毫无半点花巧可言。\n" NOR;  
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("force") + target->query("int") * 10;
  # 
  #         me->start_busy(3);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -300);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
  #                                            "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
  #                                            "连断了数根肋骨。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
  #                        "轻易招架，当即飞身纵跃闪开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
