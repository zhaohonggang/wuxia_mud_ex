defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Wanli do
  @moduledoc """
  perform「晴空万里」（对照 `kungfu/skill/never-defeated/perform/wanli.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 不败神功>=120 → 真气>=200 →
  手持兵刃 → 目标存活。
  起手文案（含武器名）在攻击方广播；攻击方无条件扣 20 真气、忙乱 2。
  目标侧以 `ap/2 + random(ap*2)`（`ap = 不败神功*3/2 + 武学修养`）对目标
  `parry + 武学修养`：命中则攻击方再扣 180 真气，目标忙乱 `1 + random(3)`，
  qi 伤 `(ap + 内功)/2 + random((ap + 内功)/2)`、qi 上限伤 50%（命中部位取目标
  个体 `limbs`，缺失时回退「要害」）；未命中则只广播格挡文案。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - 两分支的 `me->start_busy(2)` 值相同 → 无条件，在攻击方直接结算；
    `me->add("neili",-20)` 无条件 → 攻击方；命中分支内的 `me->add("neili",-180)`
    经 `Performs.feedback/3` 回执；
  - `COMBAT_D->do_damage(...,damage,50,pmsg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*50,100))` 并广播 `pmsg`（含全角弯引号“扑哧”，逐字保留）；
  - `target->query("limbs")` 个体部位列表 → `Map.get(character.meta, :limbs)`，
    非列表/空表回退 `"要害"`（同既有先例）；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "never-defeated/wanli"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    wn = weapon_name(combat)

    # LPC: ap = me->query_skill("never-defeated", 1) * 3 / 2 +
    #             me->query_skill("martial-cognize", 1);
    ap = div(Stats.skill(stats, "never-defeated") * 3, 2) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
         :ok <- check_weapon(combat),
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
          # LPC: damage = ap + (int)me->query_skill("force");
          force: Stats.skill(stats, "force"),
          wn: wn,
          rng: rng
        }
      })

      apply_effect(conn, character, target, wn)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 本式无 can_perform 门槛，框架层统一把关（见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "晴空万里只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("never-defeated", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 120 do
      {:error, "你的不败神功还不够娴熟，不能使用晴空万里。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在内力太弱，不能使用晴空万里。\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) do
      :ok
    else
      {:error, "你必须手持兵刃才能施展晴空万里！\n"}
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

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = HIC "$N" HIC "怀抱" + weapon->name() + HIC "，一"
    #            "圈圈的划向$n" HIC "，将$p" HIC "卷在当中！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N怀抱" <> wn <> "，一圈圈的划向$n，将$p卷在当中！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -20);  me->start_busy(2);（两分支均为 2，视为无条件）
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 20}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 2)
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    ap = max(Map.get(data, :ap, 0), 1)
    force = max(Map.get(data, :force, 0), 0)
    wn = Map.get(data, :wn)

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap * 2) > dp) { … } else { … }
    if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
      # LPC: me->start_busy(2);（已在攻击方结算）
      #      me->add("neili", -180);（命中分支内，回执）
      Performs.feedback(attacker, 180, 0)

      # LPC: target->start_busy(1 + random(3));
      combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 3))

      # LPC: damage = ap + (int)me->query_skill("force");
      #      damage = damage / 2 + random(damage / 2);
      damage = ap + force
      damage = div(damage, 2) + Engine.rand(rng, div(damage, 2))

      # LPC: if (arrayp(limbs = target->query("limbs")))
      #        limb = limbs[random(sizeof(limbs))];
      #      else limb = "要害";
      limbs = Map.get(character.meta, :limbs)

      limb =
        case limbs do
          list when is_list(list) and list != [] -> Enum.at(list, Engine.rand(rng, length(list)))
          _ -> "要害"
        end

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(
        "$n连忙腾挪躲闪，然而“扑哧”一声，" <> wn <> "正好击中$p的" <> limb <> "，$p一声惨叫，连退数步。\n",
        bindings
      )
      |> put_character(character)
    else
      Broadcast.publish(
        conn,
        "可是$p看破了$P的变化，见招拆招，没有受到任何伤害。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wanli.c 晴空万里
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object  weapon;
  #     int     damage;
  #     string  msg;
  #         string  pmsg;
  #         string *limbs;
  #         string  limb;
  #         int ap, dp;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("晴空万里只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("never-defeated", 1) < 120)
  #         return notify_fail("你的不败神功还不够娴熟，不能使用晴空万里。\n");
  # 
  #         if ((int)me->query("neili", 1) < 200)
  #         return notify_fail("你现在内力太弱，不能使用晴空万里。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("你必须手持兵刃才能施展晴空万里！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "怀抱" + weapon->name() + HIC "，一"
  #               "圈圈的划向$n" HIC "，将$p" HIC "卷在当中！\n" NOR;
  #     me->add("neili", -20);
  # 
  #         ap = me->query_skill("never-defeated", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #         me->start_busy(2);
  #                 me->add("neili", -180);
  # 
  #         target->start_busy(1 + random(3));
  # 
  #         damage = ap + (int)me->query_skill("force");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 if (arrayp(limbs = target->query("limbs")))
  #                         limb = limbs[random(sizeof(limbs))];
  #                 else
  #                         limb = "要害";
  #                 pmsg = HIR "$n连忙腾挪躲闪，然而“扑哧”一声，" + weapon->name() +
  #                HIR "正好击中$p" HIR "的" + limb + "，$p"
  #                HIR "一声惨叫，连退数步。\n" NOR;
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50, pmsg);
  #     } else
  #     {
  #         me->start_busy(2);
  #         msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的变化，见招拆招，没有受到任何伤害。\n"NOR;
  #     }
  # 
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
