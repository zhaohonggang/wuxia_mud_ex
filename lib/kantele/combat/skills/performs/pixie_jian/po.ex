defmodule Kantele.Combat.Skills.Performs.PixieJian.Po do
  @moduledoc """
  perform「破元剑闪」（对照 `kungfu/skill/pixie-jian/po.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword/pin 或无武器 →
  辟邪剑法>=180 → 内力上限>=2600 → 真气>=300 → 持械时激发 sword 为辟邪剑法、
  空手时准备 unarmed 为辟邪剑法 → 目标存活 → **目标真气未被打散**。
  起手文案带 `name`（持械为 `"手中" + weapon->name()`，空手为
  `finger_name[random(6)]` 六指之一）；随后由目标侧判定
  `ap/2 + random(ap) > dp`（`ap = 剑法 + 轻功`、`dp = 目标招架 + 目标轻功`）：
  命中则 `damage = ap + random(ap)`、攻击方扣 200 真气并忙乱 2，目标受
  `do_damage(REMOTE_ATTACK, damage, random(15) + 80)`，且真气被打散
  （`no_perform`，`10 + random(ap/30)` 秒后恢复）；否则攻击方扣 150 真气并
  忙乱 3，广播「抽身急退数尺」文案。

  差异（TODO(migrate)）：
  - 「目标真气被打散」门槛（`target->query_temp("no_perform")`）在攻击方不可得，
    故移到目标侧 `resolve_incoming` 判定，以 `Combat.buff_active?/2` 检查本招
    造成的打散 buff 为代理（LPC 的 `no_perform` 是共享 temp）；
  - `.c` 的 `final()` 回调返回命中文案并置 `no_perform`，折算为目标侧先广播
    该文案，再用 `Combat.Buff` + `combat/buff-expire` 定时恢复（`applies` 为空
    映射，恢复走 `message` 通道，拼接 `message_combatd` 与 `tell_object`
    两条文案，同 `cuixin_zhang/cui.ex`）；
  - `do_damage` 的外伤比例 `random(15) + 80` 为随机值，按
    `div(damage * (80 + rand(15)), 100)` 折算；
  - `finger_name` 全局数组的六个指名字面量与 `"手中"` 前缀按 `.c` 原样保留；
  - 两条 mapped/prepared 门槛文案相同，在 `.c` 中各出现一次，故 E 侧同样分列
    两个门槛函数（同 `pixie_jian/duo.ex`、`pixie_jian/pi.ex`）；
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

  @perform_id "pixie-jian/po"
  @move_name "「破元剑闪」"

  # LPC: string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                              "右手中指", "右手无名指", "右手食指", });
  @finger_names [
    "左手中指",
    "左手无名指",
    "左手食指",
    "右手中指",
    "右手无名指",
    "右手食指"
  ]

  # LPC: set_temp("no_perform", 1) + call_out("poyuan_end", 10 + random(ap / 30), ...)
  @po_key "pixie-jian/po"

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

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/pixie-jian/po"))
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

  # LPC: if (me->query_skill("pixie-jian", 1) < 180)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "pixie-jian") < 180 do
      {:error, "你的辟邪剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 2600)
  #      if (me->query("neili") < 300)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2600 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 300 ->
        {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" PO "。\n");
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
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" PO "。\n");
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

  # LPC: if (me->query_temp("weapon")) name = "手中" + weapon->name();
  #      else name = finger_name[random(sizeof(finger_name))];
  #      msg = HIW "$N" HIW "一声冷哼，双眸间透出一丝寒气，" + name +
  #            HIW "化作千百根线丝，幻出死亡的色彩！\n" NOR;
  #      之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
  defp apply_effect(conn, character, target, rng) do
    weapon = Combat.weapon(character.meta.combat)

    name =
      if weapon != nil do
        "手中" <> weapon_name(character.meta.combat)
      else
        Enum.at(@finger_names, Engine.rand(rng, length(@finger_names)))
      end

    Broadcast.publish(
      conn,
      "$N一声冷哼，双眸间透出一丝寒气，" <> name <> "化作千百根线丝，幻出死亡的色彩！\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->query_temp("no_perform"))
  #      return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 目标真气打散状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.buff_active?(character.meta.combat, @po_key) ->
        Broadcast.publish(conn, "对方现在已经无法控制真气，放胆攻击吧。\n")

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
    #        msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, random(15) + 80,
    #                                  (: final, me, target, damage :));
    #        me->start_busy(2);  me->add("neili", -200); }
    #      else
    #      { msg += CYN "$n" CYN "大惊之下全然无法招架，急忙"
    #                     "抽身急退数尺，躲开了这一招。\n" NOR;
    #        me->start_busy(3);  me->add("neili", -150); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = ap + Engine.rand(rng, ap)

      # LPC: do_damage(..., random(15) + 80, ...)
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * (80 + Engine.rand(rng, 15)), 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(2);  me->add("neili", -200);
      Performs.feedback(attacker, 200, 2)

      # LPC final(): target->set_temp("no_perform", 1);
      #              call_out("poyuan_end", 10 + random(ap / 30), me, target);
      #              return HIR "$n" HIR "只觉眼前寒芒一闪而过，随即全身一阵"
      #                     "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
      #                     "竟发现周身力道竟似涣散一般，全然无法控制。\n" NOR;
      po_duration = 10 + Engine.rand(rng, div(ap, 30))

      combat =
        character.meta.combat
        |> Combat.add_buff(%Combat.Buff{key: @po_key, applies: %{}, duration: po_duration})

      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC poyuan_end(): message_combatd(HIC "$N" HIC "深深吸入一口"
      #                                 "气，脸色由白转红，看起来好"
      #                                 "多了。\n" NOR, target);
      #                  tell_object(target, HIY "你感到被扰乱的真气"
      #                                      "慢慢平静了下来。\n" NOR);
      #                  target->delete_temp("no_perform");
      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{
            key: @po_key,
            applies: %{},
            message:
              [
                Messages.interpolate("$N深深吸入一口气，脸色由白转红，看起来好多了。\n",
                  n1: character.name
                ),
                "你感到被扰乱的真气慢慢平静了下来。\n"
              ]
              |> Enum.join("")
          }
        },
        po_duration * 1000
      )

      conn
      |> Broadcast.publish(
        "$n只觉眼前寒芒一闪而过，随即全身一阵刺痛，几股血柱自身上射出。\n$p陡然间一提真气，竟发现周身力道竟似涣散一般，全然无法控制。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3);  me->add("neili", -150);
      Performs.feedback(attacker, 150, 3)

      conn
      |> Broadcast.publish(
        "$n大惊之下全然无法招架，急忙抽身急退数尺，躲开了这一招。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIW "破元剑闪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                          "右手中指", "右手无名指", "右手食指", });
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, name;
  #         object weapon;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/pixie-jian/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (weapon && weapon->query("skill_type") != "sword"
  #            && weapon->query("skill_type") != "pin")
  #                 return notify_fail("你使用的武器不对，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("pixie-jian", 1) < 180)
  #                 return notify_fail("你的辟邪剑法不够娴熟，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2600)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" PO "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" PO "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (target->query_temp("no_perform"))
  #                 return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 name = "手中" + weapon->name();
  #         else
  #                 name = finger_name[random(sizeof(finger_name))];
  # 
  #         msg = HIW "$N" HIW "一声冷哼，双眸间透出一丝寒气，" + name +
  #               HIW "化作千百根线丝，幻出死亡的色彩！\n" NOR;
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
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, random(15) + 80,
  #                                           (: final, me, target, damage :));
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "大惊之下全然无法招架，急忙"
  #                        "抽身急退数尺，躲开了这一招。\n" NOR;
  #                 me->start_busy(3);
  #                 me->add("neili", -150);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int ap)
  # {
  #         target->set_temp("no_perform", 1);
  #         call_out("poyuan_end", 10 + random(ap / 30), me, target);
  #         return HIR "$n" HIR "只觉眼前寒芒一闪而过，随即全身一阵"
  #                "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
  #                "竟发现周身力道竟似涣散一般，全然无法控制。\n" NOR;
  # }
  # 
  # void poyuan_end(object me, object target)
  # {
  #         if (target && target->query_temp("no_perform"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "深深吸入一口"
  #                                         "气，脸色由白转红，看起来好"
  #                                         "多了。\n" NOR, target);
  # 
  #                         tell_object(target, HIY "你感到被扰乱的真气"
  #                                             "慢慢平静了下来。\n" NOR);
  #                 }
  #                 target->delete_temp("no_perform");
  #     }
  #     return;
  # }
end
