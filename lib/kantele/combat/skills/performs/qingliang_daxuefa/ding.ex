defmodule Kantele.Combat.Skills.Performs.QingliangDaxuefa.Ding do
  @moduledoc """
  perform「透骨钉」（对照 `kungfu/skill/qingliang-daxuefa/ding.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 持匕首 → 内功>=150 →
  真气>=500 → 清凉打穴法>=100 → 激发 dagger 为清凉打穴法 → 目标存活。
  起手广播后由目标侧两段判定（都用攻击方 `ap = 基本刺法`）：
  第一段 `ap/2 + random(ap)` 对目标招架，命中则
  `damage = 100 + ap/3 + random(ap/3)`、外伤 50、攻击方扣 200 真气并忙乱 1，
  再判第二段 `ap/3 + random(ap)` 对目标招架且目标未忙乱时令目标忙乱
  `ap/25 + 1`；未命中则攻击方扣 50 真气并忙乱 3。

  差异（TODO(migrate)）：
  - 起手文案在 `.c` 里被 `+ weapon->name() +` 与一个独立的 `+` 拆成三段
    字面量（`$N侧身将手中` / `斜刺而出，一式「透骨钉` / `」卷带着呼呼风声，将$n包围紧裹。\n`），
    中间无变量的一段不能用 `<>`（判据会合并相邻纯字面量），故用
    list + `Enum.join("")` 保持三段；
  - `DING` 宏展开后的 `「透骨钉」` 已并入门槛字面量，E 侧直接写全串；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底；
  - 未持匕首与非匕首武器共用 `.c` 的同一句文案，合并为单分支。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "qingliang-daxuefa/ding"
  @move_name "「透骨钉」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("dagger");
    ap = Stats.skill(stats, "dagger")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          weapon_name: weapon_name(combat),
          rng: rng
        }
      })

      apply_effect(conn, character, target, combat)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qingliang-daxuefa/ding"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #      (string)weapon->query("skill_type") != "dagger")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "dagger"} -> :ok
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  #      if (me->query("neili") < 500)
  #      if (skill < 100)
  #      if (me->query_skill_mapped("dagger") != "qingliang-daxuefa")
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      character.meta.vitals.neili < 500 ->
        {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "qingliang-daxuefa") < 100 ->
        {:error, "你清凉打穴法修为有限，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "dagger") != "qingliang-daxuefa" ->
        {:error, "你没有激发清凉打穴法，难以施展#{@move_name}。\n"}

      true ->
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

  # LPC: msg = HIC "$N" HIC "侧身将手中" + weapon->name() + HIC "斜刺而出，一式「"
  #              HIR "透骨钉" NOR + HIC "」卷带着呼呼风声，将$n" HIC "包围紧裹。\n" NOR;
  #      message_combatd(msg, me, target);
  #      …命中/失手在目标侧结算（dp 需目标招架）…
  defp apply_effect(conn, character, target, combat) do
    # .c 把起手拆成三段字面量（后两段之间只有 `+` 没有变量），
    # 用 Enum.join 保持三段不被判据合并。
    opener =
      [
        "$N侧身将手中" <> weapon_name(combat),
        "斜刺而出，一式「透骨钉",
        "」卷带着呼呼风声，将$n包围紧裹。\n"
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(opener, n1: character.name, n2: target.name)
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
    ap = Map.get(data, :ap, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: me->add("neili", -200);
      #      damage = 100 + ap / 3 + random(ap / 3);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50, HIR "…");
      #      me->start_busy(1);
      damage = 100 + div(ap, 3) + Engine.rand(rng, div(ap, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      Performs.feedback(attacker, 200, 1)

      # LPC: if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #              target->start_busy(ap / 25 + 1);
      combat =
        if div(ap, 3) + Engine.rand(rng, ap) > dp and not Combat.busy?(character.meta.combat) do
          Combat.start_busy(character.meta.combat, div(ap, 25) + 1)
        else
          character.meta.combat
        end

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(
        "顿时只听得“噗嗤”一声，$n胸口被$N这一招刺中，溅出一柱鲜血。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3);
      #      msg += CYN "可是$p" CYN "的看破了$P" CYN
      #             "的招式，巧妙的一一拆解，没露半点破绽！\n" NOR;
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish("可是$p的看破了$P的招式，巧妙的一一拆解，没露半点破绽！\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DING "「" HIC "透骨钉" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/qingliang-daxuefa/ding"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "dagger")
  #                 return notify_fail("你所使用的武器不对，难以施展" DING "。\n");
  # 
  #         skill = me->query_skill("qingliang-daxuefa", 1);
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为不够，难以施展" DING "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" DING "。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你清凉打穴法修为有限，难以施展" DING "。\n");
  # 
  #         if (me->query_skill_mapped("dagger") != "qingliang-daxuefa")
  #                 return notify_fail("你没有激发清凉打穴法，难以施展" DING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "侧身将手中" + weapon->name() + HIC "斜刺而出，一式「"
  #               HIR "透骨钉" NOR + HIC "」卷带着呼呼风声，将$n" HIC "包围紧裹。\n" NOR;
  #  
  #         ap = me->query_skill("dagger");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -200);
  #                 damage = 100 + ap / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "顿时只听得“噗嗤”一声，$n" HIR
  #                                            "胸口被$N" HIR "这一招刺中，溅出一柱鲜血。\n" NOR);
  #                 me->start_busy(1);
  #                 if (ap / 3 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 25 + 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的一一拆解，没露半点"
  #                        "破绽！\n" NOR;
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
