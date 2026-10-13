defmodule Kantele.Combat.Skills.Performs.JindingZhang.Bashi do
  @moduledoc """
  perform「八式合一」（source jinding-zhang/bashi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  真气>=200 → 基本内功>=100 → 金顶绵掌>=100 →
  激发 strike 为金顶绵掌 → 准备 strike 为金顶绵掌 → 目标存活。
  起手广播后按 `random(基本掌法) vs 目标 force/2` 判定命中：
  命中则伤害 `(临济庄 + 金顶绵掌)/3 + random(...)`（qi 伤 + 30% 外伤）、
  扣 100 真气、忙乱 2；未命中则忙乱 3（不扣真气）。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传；
  - `.c` 用 `message_combatd(msg, me, target)` 把起手式与结算文案合成一条广播，
    此处按本仓库约定拆为「攻击方发起手式 / 目标侧发结算文案」两条。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jinding-zhang/bashi"
  @move_name "「八式合一」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinding-zhang")
    # LPC: random(me->query_skill("strike"))
    ap = Stats.skill(stats, "strike")
    # LPC: damage = (query_skill("linji-zhuang",1) + query_skill("jinding-zhang",1)) / 3;
    damage_base =
      div(Stats.skill(stats, "linji-zhuang") + Stats.skill(stats, "jinding-zhang"), 3)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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
          damage_base: damage_base,
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/jinding-zhang/bashi"))
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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的内力还不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 100)
  #      / if ((int)me->query_skill("jinding-zhang", 1) < 100)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "jinding-zhang") < 100 ->
        {:error, "你的金顶绵掌的修习不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "jinding-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "jinding-zhang" do
      :ok
    else
      {:error, "你没有激发金顶绵掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "jinding-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "jinding-zhang" do
      {:error, "你现在没有准备使用金顶绵掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character) do
    # LPC: msg = HIY "$N" HIY "深深吸了一口气，提起全身的功力于"
    #            "双掌猛力拍出，只听得骨骼一阵爆响！\n" NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 force）。
    conn
    |> Broadcast.publish(
      "$N深深吸了一口气，提起全身的功力于双掌猛力拍出，只听得骨骼一阵爆响！\n",
      n1: character.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage_base = Map.get(data, :damage_base, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("strike")) > (int)target->query_skill("force") / 2)
    if Engine.rand(rng, ap) > div(Stats.skill(stats, "force"), 2) do
      # LPC: damage += random(damage);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                HIR "只见漫天掌影飘忽不定的罩向$n" HIR "全身各个部位，$n" HIR
      #                "顿时接连中了数" "掌！\n" NOR);
      #      me->add("neili", -100); me->start_busy(2);
      damage = damage_base + Engine.rand(rng, damage_base)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 100, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见漫天掌影飘忽不定的罩向$n全身各个部位，$n顿时接连中了数掌！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "猛地向后一跃，跳出了$P" CYN "的攻击范围。\n" NOR;
      #      me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p猛地向后一跃，跳出了$P的攻击范围。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BASHI "「" HIY "八式合一" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #         // int count,d_count,qi, maxqi, skill;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinding-zhang/bashi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BASHI "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(BASHI "只能空手施展。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的内力还不够，难以施展" BASHI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功的修为不够，难以施展" BASHI "。\n");
  # 
  #         if ((int)me->query_skill("jinding-zhang", 1) < 100)
  #                 return notify_fail("你的金顶绵掌的修习不够，难以施展" BASHI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "jinding-zhang")
  #                 return notify_fail("你没有激发金顶绵掌，难以施展" BASHI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jinding-zhang")
  #                 return notify_fail("你现在没有准备使用金顶绵掌，难以施展" BASHI "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "深深吸了一口气，提起全身的功力于"
  #               "双掌猛力拍出，只听得骨骼一阵爆响！\n" NOR;
  #         if (random(me->query_skill("strike")) > (int)target->query_skill("force") / 2)
  #         {
  #                 damage  = (int)me->query_skill("linji-zhuang", 1);
  #                 damage += (int)me->query_skill("jinding-zhang", 1);
  #                 damage /= 3;
  #                 damage += random(damage);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "只见漫天掌影飘忽不定的罩向$n" HIR
  #                                            "全身各个部位，$n" HIR "顿时接连中了数"
  #                                            "掌！\n" NOR);
  #                 me->add("neili", -100);
  #                 me->start_busy(2);
  #          } else
  #          {
  #                 msg += CYN "可是$p" CYN "猛地向后一跃，跳出了$P"
  #                        CYN "的攻击范围。\n" NOR;
  #                 me->start_busy(3);
  #          }
  #          message_combatd(msg, me, target);
  #          return 1;
  # }
end
