defmodule Kantele.Combat.Skills.Performs.JinyuQuan.Man do
  @moduledoc """
  perform「金玉满堂」（source jinyu-quan/man.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 必须空手（主/副手均无武器）→
  金玉拳法>=80 → 激发 cuff 为金玉拳法 → 准备 cuff 为金玉拳法 → 真气>=200 → 目标存活。
  （`.c` 有 `can_perform`，故设「已知此招」检查。）
  起手广播后按 `random(cuff) > 目标 dodge/2` 判定命中（cuff = 金玉拳法等级）：
  命中 `damage = cuff/2 + random(cuff/2)`、qi 伤 + 45% 外伤，攻击方扣 150 真气 / 忙乱 2；
  未命中攻击方扣 50 真气 / 忙乱 3。

  差异（TODO(migrate)）：
  - 命中判定与伤害需目标 `dodge`，在目标侧结算；攻击方 `cuff` 等级经事件 data 传入
    （perform_list 指向本模块，真实实现）；
  - 起手式、命中/未命中广播均仅由颜色宏分隔，工具合并为单条字面量，故各自写单字面量；
  - 攻击方消耗/忙乱随分支不同，经 `Performs.feedback/3` 回传（起手侧不扣）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jinyu-quan/man"
  @move_name "「金玉满堂」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinyu-quan")
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinyu-quan/man"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(MAN "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail(MAN "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jinyu-quan", 1) < 80)
  #          return notify_fail("你的金玉拳法不够娴熟，难以施展" MAN "。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jinyu-quan") < 80 do
      {:error, "你的金玉拳法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("cuff") != "jinyu-quan")
  #          return notify_fail("你没有激发金玉拳法，难以施展" MAN "。\n");
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") == "jinyu-quan" do
      :ok
    else
      {:error, "你没有激发金玉拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "jinyu-quan")
  #          return notify_fail("你没有准备金玉拳法，难以施展" MAN "。\n");
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and (prepared |> String.split("/") |> hd()) == "jinyu-quan" do
      :ok
    else
      {:error, "你没有准备金玉拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  #          return notify_fail("你现在的真气不够，难以施展" MAN "。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIY "$N" HIY "双拳纷飞，气势如虹，顿时幻出一片拳影，似乎$n"
  #          HIY "的全身都被拳影所笼罩。\n" NOR;
  defp apply_effect(conn, character, target) do
    msg = "$N双拳纷飞，气势如虹，顿时幻出一片拳影，似乎$n的全身都被拳影所笼罩。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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

    # LPC: if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
    dp = div(Stats.skill(stats, "dodge"), 2)

    if Engine.rand(rng, ap) > dp do
      # LPC: damage = me->query_skill("cuff");  (ap 已为 cuff 等级)
      #      damage = damage / 2 + random(damage / 2);
      #      me->add("neili", -150); me->start_busy(2);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 45, (: final, ... :));
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 150, 2)

      # LPC final: "结果只听"砰砰砰砰"几声闷响，$p前胸被$P轰中数拳，登时呕出一口鲜血！\n"
      msg = "结果只听“砰砰砰砰”几声闷响，$p前胸被$P轰中数拳，登时呕出一口鲜血！\n"

      conn
      |> Broadcast.publish(Messages.interpolate(msg, bindings))
      |> put_character(character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3);
      #      msg += "可是$p识破了$P这一招，斜斜一跃避开。\n";
      Performs.feedback(attacker, 50, 3)

      msg = "可是$p识破了$P这一招，斜斜一跃避开。\n"

      conn
      |> Broadcast.publish(Messages.interpolate(msg, bindings))
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define MAN "「" HIY "金玉满堂" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinyu-quan/man"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(MAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(MAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("jinyu-quan", 1) < 80)
  #                 return notify_fail("你的金玉拳法不够娴熟，难以施展" MAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "jinyu-quan")
  #                 return notify_fail("你没有激发金玉拳法，难以施展" MAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "jinyu-quan")
  #                 return notify_fail("你没有准备金玉拳法，难以施展" MAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" MAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "双拳纷飞，气势如虹，顿时幻出一片拳影，似乎$n"
  #               HIY"的全身都被拳影所笼罩。\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage / 2);
  #                 me->add("neili", -150);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "结果只听“砰砰砰砰”几声闷响，$p"
  #                                            HIR "前胸被$P" HIR "轰中数拳，登时呕出"
  #                                            "一口鲜血！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
