defmodule Kantele.Combat.Skills.Performs.PixieJian.Duo do
  @moduledoc """
  perform「鬼影夺目」（对照 `kungfu/skill/pixie-jian/duo.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword/pin 或无武器 →
  辟邪剑法>=80 → 内力上限>=800 → 真气>=100 → 持械时激发 sword 为辟邪剑法、
  空手时准备 unarmed 为辟邪剑法 → 目标存活 → **目标未失明**。
  起手文案分空手/持剑两式（持剑式带 `weapon->name()`）；随后由目标侧判定
  `ap/2 + random(ap) > dp`（`ap = 剑法 + 轻功`、`dp = 目标招架 + 目标轻功`）：
  命中则 `damage = ap + random(ap)`、攻击方扣 80 真气并忙乱 2，目标受
  `do_damage(REMOTE_ATTACK, damage, 30)`，并陷入失明
  （`block_msg/all`，`10 + random(ap/30)` 秒后恢复）；否则攻击方扣 50 真气并
  忙乱 3，广播「情急智生」文案。

  差异（TODO(migrate)）：
  - 「目标失明」门槛（`target->query_temp("block_msg/all")`）在攻击方不可得，
    故移到目标侧 `resolve_incoming` 判定，以 `Combat.buff_active?/2` 检查本招
    造成的失明 buff 为代理（LPC 的 `block_msg/all` 是共享 temp，本仓仅由本招
    写入）；`.c` 中该门槛先于起手文案，故起手广播仍会发生（同
    `miaojia_jian/zhai.ex` 的处理）；
  - `.c` 的 `final()` 回调（`do_damage` 的 msg 参数为函数指针）返回失明文，
    折算为目标侧先广播该文案，再用 `Combat.Buff` + `combat/buff-expire`
    定时恢复（`applies` 为空映射，恢复走 `message` 通道）；
  - `.c` 的 `cimu_end()` 同时 `message_combatd`（房间）与 `tell_object`
    （本人），此处沿用 `cuixin_zhang/cui.ex` 的先例：两条文案拼接到
    buff 到期 `message` 中一次性呈现（`$N` 插值目标名）；
  - `REMOTE_ATTACK` 不影响本仓的伤害折算（`Vitals.damage/wound`，wound 30%）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "pixie-jian/duo"
  @move_name "「鬼影夺目」"

  # LPC: set_temp("block_msg/all", 1) + call_out("cimu_end", 10 + random(ap / 30), ...)
  @blind_key "pixie-jian/duo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("sword") + me->query_skill("dodge");
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "dodge")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character, combat),
         :ok <- check_prepared(character, combat),
         :ok <- check_target_alive(target) do
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

      apply_effect(conn, character, target, weapon_name(combat))
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/pixie-jian/duo"))
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (weapon && weapon->query("skill_type") != "sword"
  #           && weapon->query("skill_type") != "pin")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      nil ->
        :ok

      weapon ->
        if Map.get(weapon, :skill_type) in ["sword", "pin"] do
          :ok
        else
          {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (me->query_skill("pixie-jian", 1) < 80)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "pixie-jian") < 80 do
      {:error, "你的辟邪剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 800)
  #      if (me->query("neili") < 100)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 100 ->
        {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" DUO "。\n");
  #      （空手时该门槛不生效；文案与下一档相同，.c 中各自出现一次）
  defp check_mapped(character, combat) do
    weapon = Combat.weapon(combat)

    if weapon == nil or Stats.mapped(character.meta.stats, "sword") == "pixie-jian" do
      :ok
    else
      {:error, "你没有准备使用辟邪剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! weapon && me->query_skill_prepared("unarmed") != "pixie-jian")
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" DUO "。\n");
  #      （持械时该门槛不生效）
  defp check_prepared(character, combat) do
    weapon = Combat.weapon(combat)
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if weapon != nil or (prepared != nil and hd(String.split(prepared, "/")) == "pixie-jian") do
      :ok
    else
      {:error, "你没有准备使用辟邪剑法，难以施展#{@move_name}。\n"}
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

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  #      { msg = HIR "$N" HIR "一声阴笑，揉身而上，左手两指并拢，手臂"
  #                "暴长，迅捷异常分刺$n" HIR "的双目！\n" NOR; }
  #      else
  #      { msg = HIR "$N" HIR "一声阴笑，揉身而上，手中" + weapon->name() +
  #                HIR "一振，剑尖一点暴长，分刺$n" HIR "左右双目！\n" NOR; }
  defp apply_effect(conn, character, target, wn) do
    weapon = Combat.weapon(character.meta.combat)

    text =
      if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
        "$N一声阴笑，揉身而上，手中" <> wn <> "一振，剑尖一点暴长，分刺$n左右双目！\n"
      else
        "$N一声阴笑，揉身而上，左手两指并拢，手臂暴长，迅捷异常分刺$n的双目！\n"
      end

    Broadcast.publish(conn, text, n1: character.name, n2: target.name)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->query_temp("block_msg/all"))
  #      return notify_fail("对方现在什么也看不见，放胆攻击吧。\n");
  # 目标失明状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.buff_active?(character.meta.combat, @blind_key) ->
        Broadcast.publish(conn, "对方现在什么也看不见，放胆攻击吧。\n")

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("parry") + target->query_skill("dodge");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap + random(ap);
    #        msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 30,
    #                                  (: final, me, target, damage :));
    #        me->start_busy(2);  me->add("neili", -80); }
    #      else
    #      { msg += CYN "$n" CYN "情急智生，抬手也向$N"
    #                     CYN "的右眼刺去，迫得$P" CYN "回剑跃开。\n" NOR;
    #        me->start_busy(3);  me->add("neili", -50); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = ap + Engine.rand(rng, ap)
      vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 30, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(2);  me->add("neili", -80);
      Performs.feedback(attacker, 80, 2)

      # LPC final(): target->set_temp("block_msg/all", 1);
      #              call_out("cimu_end", 10 + random(ap / 30), me, target);
      #              return HIR "$n" HIR "只觉双目一阵剧痛，眼前一黑，就什么"
      #                     "也看不见了，顿时长声痛极而呼。\n" NOR;
      blind_duration = 10 + Engine.rand(rng, div(ap, 30))

      combat =
        character.meta.combat
        |> Combat.add_buff(%Combat.Buff{key: @blind_key, applies: %{}, duration: blind_duration})

      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC cimu_end(): message_combatd(HIC "$N" HIC "抹了抹流着的"
      #                                 HIR "鲜血" HIC "，终于能看"
      #                                 "见了。\n" NOR, target);
      #                  tell_object(target, HIR "你终于抹掉了眼前的"
      #                                      "鲜血，能看见了。\n" NOR);
      #                  target->delete_temp("block_msg/all");
      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{
            key: @blind_key,
            applies: %{},
            message:
              [
                Messages.interpolate("$N抹了抹流着的鲜血，终于能看见了。\n", n1: character.name),
                "你终于抹掉了眼前的鲜血，能看见了。\n"
              ]
              |> Enum.join("")
          }
        },
        blind_duration * 1000
      )

      conn
      |> Broadcast.publish(
        "$n只觉双目一阵剧痛，眼前一黑，就什么也看不见了，顿时长声痛极而呼。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3);  me->add("neili", -50);
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish(
        "$n情急智生，抬手也向$N的右眼刺去，迫得$P回剑跃开。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DUO "「" HIR "鬼影夺目" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         int /*lvl,*/ ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/pixie-jian/duo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUO "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (weapon && weapon->query("skill_type") != "sword"
  #            && weapon->query("skill_type") != "pin")
  #                 return notify_fail("你使用的武器不对，难以施展" DUO "。\n");
  # 
  #         if ((int)me->query_skill("pixie-jian", 1) < 80)
  #                 return notify_fail("你的辟邪剑法不够娴熟，难以施展" DUO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不足，难以施展" DUO "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不足，难以施展" DUO "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" DUO "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" DUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (target->query_temp("block_msg/all"))
  #             return notify_fail("对方现在什么也看不见，放胆攻击吧。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #     {
  #                 msg = HIR "$N" HIR "一声阴笑，揉身而上，左手两指并拢，手臂"
  #                       "暴长，迅捷异常分刺$n" HIR "的双目！\n" NOR;
  #         } else
  #     {
  #                 msg = HIR "$N" HIR "一声阴笑，揉身而上，手中" + weapon->name() +
  #                       HIR "一振，剑尖一点暴长，分刺$n" HIR "左右双目！\n" NOR;
  #     }
  # 
  #         ap = me->query_skill("sword") +
  #              me->query_skill("dodge");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 30,
  #                                           (: final, me, target, damage :));
  #                 me->start_busy(2);
  #                 me->add("neili", -80);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "情急智生，抬手也向$N"
  #                        CYN "的右眼刺去，迫得$P" CYN "回剑跃开。\n" NOR;
  #                 me->start_busy(3);
  #                 me->add("neili", -50);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int ap)
  # {
  #         target->set_temp("block_msg/all", 1);
  #         call_out("cimu_end", 10 + random(ap / 30), me, target);
  #         return HIR "$n" HIR "只觉双目一阵剧痛，眼前一黑，就什么"
  #                "也看不见了，顿时长声痛极而呼。\n" NOR;
  # }
  # 
  # void cimu_end(object me, object target)
  # {
  #         if (target && target->query_temp("block_msg/all"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "抹了抹流着的"
  #                                         HIR "鲜血" HIC "，终于能看"
  #                                         "见了。\n" NOR, target);
  # 
  #                         tell_object(target, HIR "你终于抹掉了眼前的"
  #                                             "鲜血，能看见了。\n" NOR);
  #                 }
  #                 target->delete_temp("block_msg/all");
  #     }
  #     return;
  # }
end
