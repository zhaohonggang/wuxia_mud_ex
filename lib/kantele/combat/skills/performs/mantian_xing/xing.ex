defmodule Kantele.Combat.Skills.Performs.MantianXing.Xing do
  @moduledoc """
  perform「穹外飞星」（对照 `kungfu/skill/mantian-xing/xing.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 throwing 类暗器 →
  暗器余量>=15 → 满天星>=80 → 内功>=150 → 内力上限>=1200 → 真气>=150 →
  目标未中 `feixing` → 目标存活。
  攻击方扣 100 真气、消耗 15 枚暗器并发起手广播；
  目标侧以 `valid_power(combat_exp)/2 + random(exp*3/2)` 对抗目标
  `valid_power(combat_exp)`：命中后若目标 `parry < 攻击方 throwing` 则按随机链
  累加枚数 `n`（2..9），目标 qi 伤 150 + `n` 次 `jiali+100+i*10`、
  qi 上限伤 50，并挂 `feixing` 减益（attack/dodge -70、parry -20，
  `2 + random(满天星/15)` 秒后由 `back` 恢复）；否则目标 qi 伤 100、上限伤 40、
  攻击方忙乱 `1 + random(2)`；未命中则攻击方忙乱 3。

  差异（TODO(migrate)）：
  - 起手文案（含两次 `weapon->name()`）在攻击方广播；命中/未命中分支文案在目标侧
    广播（exp/parry 需双方数据，只能在目标侧判定）；`.c` 是累积到 `msg` 后一次
    `message_combatd`，此处按引擎惯例拆分（同 `guzhuo_zhang/yu.ex`）；
  - `weapon->hit_ob` 的逐次附加伤害（`clear_ahinfo`/`query_ahinfo` 钩子引擎无对应物）
    折算为附加 qi 伤害 `n` 次 `jiali + 100 + i*10`，其累积文案未建模（无固定字面量）；
  - `target->set_temp("feixing")` + `add_temp("apply/*")` + `call_out("back", …)`
    折算为 `Buff{key: "feixing", applies: %{attack: 70, dodge: 70, parry: 20}}` +
    `apply_temp(%{attack: -70, dodge: -70, parry: -20})`，到期由 `combat/buff-expire`
    回收并提示 `back` 的 `tell_object` 文案；
  - `target->query_temp("feixing")` 门槛在目标侧复验（目标 combat 远程不可得），
    故该文案渲染给目标；`tell_object(me, …)` 无跨进程私有通道，以房间广播替代
    （同 `force/dispel.ex`）；`tell_object(target, …)` 为对目标的私有渲染；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的敌对标记引擎未建模（同既有先例）；
  - `eff_status_msg(p)` 折算为 `Messages.eff_status_msg/1`；`chinese_number(n)` 以
    `@cn_digits` + 本地 `chinese_number/1` 复现（`~w` 签名不含字符串字面量）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "mantian-xing/xing"
  @move_name "「穹外飞星」"
  @feixing_key "feixing"
  @cost_amount 15

  @cn_digits ~w(零 一 二 三 四 五 六 七 八 九 十)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "mantian-xing")
    my_exp = Engine.valid_power(stats.combat_exp || 0)
    anqi = handing_anqi(character)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_anqi(character),
         :ok <- check_amount(character),
         :ok <- check_level(stats),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
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
          my_exp: my_exp,
          throwing: Stats.skill(stats, "throwing"),
          jiali: combat.jiali,
          anqi_name: anqi && anqi.name,
          anqi_unit: anqi && Map.get(anqi.meta, :base_unit),
          rng: rng
        }
      })

      apply_effect(conn, character, target, anqi)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing"))
  #         || (string)weapon->query("skill_type") != "throwing")
  defp check_anqi(character) do
    if handing_anqi(character) do
      :ok
    else
      {:error, "你现在手中没有拿着暗器，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (weapon->query_amount() < 15)
  defp check_amount(character) do
    if anqi_amount(character) < @cost_amount do
      {:error, "至少要有十五枚暗器才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("mantian-xing", 1)) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "mantian-xing") < 80 do
      {:error, "你的满天星不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 1200)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1200 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
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

  defp apply_effect(conn, character, target, anqi) do
    # LPC: me->add("neili", -100); weapon->add_amount(-15);
    #      msg = HIR "$N…施出「穹外飞星」将" "手中" + weapon->name() + HIR
    #            "尽数凌空射出。…" + weapon->name() + HIR "…笼罩" "$n" HIR "各处大穴！\n" NOR;
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}
    character = consume_anqi(character, anqi, @cost_amount)

    anqi_name = anqi && anqi.name

    conn =
      Broadcast.publish(
        conn,
        "$N蓦地飞身跃起，十指箕张，施出#{@move_name}将手中" <>
          anqi_name <> "尽数凌空射出。\n霎时破空声骤响，" <>
          anqi_name <> "便如同陨星飞坠一般，笼罩$n各处大穴！\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  # （对应 LPC `me->query_temp("handing")`）
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing"
    end)
  end

  defp anqi_amount(character) do
    case handing_anqi(character) do
      nil -> 0
      item -> Map.get(item.meta, :amount) || 1
    end
  end

  # LPC: weapon->add_amount(-15)；数量归零则移除该实例。
  defp consume_anqi(character, anqi, amount) do
    if anqi do
      inventory =
        character.inventory
        |> Enum.map(fn item ->
          if item == anqi do
            left = (Map.get(item.meta, :amount) || 1) - amount
            if left >= 1, do: %{item | meta: Map.put(item.meta, :amount, left)}, else: nil
          else
            item
          end
        end)
        |> Enum.reject(&is_nil/1)

      %{character | inventory: inventory}
    else
      character
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # LPC: if ((int)target->query_temp("feixing")) return notify_fail("对方已经中了…！\n");
    # 目标 combat 远程不可得，故此门槛在目标侧复验（文案按 .c 原样保留）。
    if character.meta.combat.dead do
      conn
    else
      if Combat.buff_active?(character.meta.combat, @feixing_key) do
        render(conn, CommandView, "text",
          text: "对方已经中了你的绝招，现在是废人一个，赶快进攻吧！\n"
        )
      else
        do_resolve_incoming(conn, character, attacker, data)
      end
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :skill, 0), 1)
    my_exp = max(Map.get(data, :my_exp, 0), 1)
    throwing = Map.get(data, :throwing, 0)
    jiali = Map.get(data, :jiali, 0)
    anqi_name = Map.get(data, :anqi_name) || ""
    anqi_unit = Map.get(data, :anqi_unit) || ""
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    ob_exp = Engine.valid_power(stats.combat_exp || 0)

    # LPC: if (my_exp / 2 + random(my_exp * 3 / 2) > ob_exp)
    if div(my_exp, 2) + Engine.rand(rng, div(my_exp * 3, 2)) > ob_exp do
      # LPC: if (target->query_skill("parry") < me->query_skill("throwing"))
      if Stats.skill(stats, "parry") < throwing do
        hit_vital(conn, character, bindings, rng, skill, my_exp, ob_exp, jiali, anqi_name, anqi_unit)
      else
        light_wound(conn, character, attacker, bindings, rng)
      end
    else
      # LPC: msg += CYN "可是$n…避开了$N铺天盖地的攻击。\n"; me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      Broadcast.publish(conn, "可是$n小巧腾挪，好不容易避开了$N铺天盖地的攻击。\n", bindings)
    end
  end

  # 命中要穴：枚数随机链 → n；qi 伤 150 + hit_ob 折算；挂 feixing 减益。
  defp hit_vital(conn, character, bindings, rng, skill, my_exp, ob_exp, jiali, anqi_name, anqi_unit) do
    # LPC: n = 2 + random(2);
    #      if (random(my_exp) > ob_exp) n += 1 + random(2);
    #      if (random(my_exp / 2) > ob_exp) n += 1 + random(2);
    #      if (random(my_exp / 4) > ob_exp) n += 1 + random(2);
    n = 2 + Engine.rand(rng, 2)
    n = if Engine.rand(rng, my_exp) > ob_exp, do: n + 1 + Engine.rand(rng, 2), else: n
    n = if Engine.rand(rng, div(my_exp, 2)) > ob_exp, do: n + 1 + Engine.rand(rng, 2), else: n
    n = if Engine.rand(rng, div(my_exp, 4)) > ob_exp, do: n + 1 + Engine.rand(rng, 2), else: n

    # LPC: while (n--) weapon->hit_ob(me, target, me->query("jiali") + 100 + n * 10);
    # 折算为附加 qi 伤害（逐次 n 已自减：n-1, n-2, …, 0）。
    extra = Enum.reduce(1..n, 0, fn i, acc -> acc + jiali + 100 + (n - i) * 10 end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, 150 + extra)
      |> Vitals.wound(:qi, 50)

    # LPC: target->set_temp("feixing", 1); add_temp("apply/attack", -70);
    #      add_temp("apply/dodge", -70); add_temp("apply/parry", -20);
    #      call_out("back", 2 + random(skill / 15), target);
    buff = %Buff{key: @feixing_key, applies: %{attack: 70, dodge: 70, parry: 20}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(%{attack: -70, dodge: -70, parry: -20})
      |> Combat.add_buff(buff)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
    schedule_expire(buff, 2 + Engine.rand(rng, div(skill, 15)))

    # LPC: p = target->query("qi") * 100 / target->query("max_qi");
    #      msg += "( $n" + eff_status_msg(p) + " )\n"; message_combatd(msg, me, target);
    p = div(vitals.qi * 100, max(vitals.max_qi, 1))
    suffix = "( $n" <> Messages.eff_status_msg(p) <> " )\n"

    text =
      "结果$n一声惨叫，同时中了$P" <>
        chinese_number(n) <>
        anqi_unit <>
        anqi_name <> "，直感两耳轰鸣，目不视物。\n" <> suffix

    conn
    |> Broadcast.publish(text, bindings)
    |> render(CommandView, "text",
      text: "你现在要穴受到重损，乃至全身乏力，提不上半点力道！\n"
    )
    |> Broadcast.publish("你心知刚才这招已打中对方要寒，不禁暗自冷笑。\n", bindings)
    |> put_character(character)
  end

  # 被拨开要害：轻伤 + 攻击方忙乱 1 + random(2)。
  defp light_wound(conn, character, attacker, bindings, rng) do
    # LPC: msg += HIR "$n集中生智…可还是受了点轻伤。\n";
    #      target->receive_damage("qi", 100); target->receive_wound("qi", 40);
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, 100)
      |> Vitals.wound(:qi, 40)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    p = div(vitals.qi * 100, max(vitals.max_qi, 1))
    suffix = "( $n" <> Messages.eff_status_msg(p) <> " )\n"

    text =
      "$n集中生智，双手画圈回旋挥舞，拨弄开了要害处的杀着，可还是受了点轻伤。\n" <> suffix

    # LPC: me->start_busy(1 + random(2));
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 2))

    conn
    |> Broadcast.publish(text, bindings)
    |> render(CommandView, "text",
      text: "你只觉全身几处一阵刺痛，知道自己虽被击中，但却是避开了要穴。\n"
    )
    |> put_character(character)
  end

  # LPC: call_out("back", …) 到期恢复 add_temp 并 tell_object。
  defp schedule_expire(buff, seconds) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(seconds, 1) * 1000
    )
  end

  # LPC back(): tell_object(target, HIY "渐渐的你觉得力气一丝丝的恢复了。\n" NOR);
  @doc false
  def expire_message, do: "渐渐的你觉得力气一丝丝的恢复了。\n"

  # LPC: chinese_number(n) —— 连中暗器枚数（n 为 2..9）。
  defp chinese_number(i) when i >= 0 and i <= 10, do: Enum.at(@cn_digits, i)
  defp chinese_number(i), do: Integer.to_string(i)
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XING "「" HIR "穹外飞星" NOR "」"
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill/*, i*/, p, n;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (playerp(me) && ! me->query("can_perform/mantian-xing/xing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XING "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中没有拿着暗器，难以施展" XING "。\n");
  # 
  #         if (weapon->query_amount() < 15)
  #                 return notify_fail("至少要有十五枚暗器才能施展" XING "。\n");
  # 
  #         if ((skill = me->query_skill("mantian-xing", 1)) < 80)
  #                 return notify_fail("你的满天星不够娴熟，难以施展" XING "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为不足，难以施展" XING "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不足，难以施展" XING "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不足，难以施展" XING "。\n");
  # 
  #         if ((int)target->query_temp("feixing"))
  #                 return notify_fail("对方已经中了你的绝招，现在是废人一个，赶快进攻吧！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  #         weapon->add_amount(-15);
  # 
  #         msg = HIR "$N" HIR "蓦地飞身跃起，十指箕张，施出「穹外飞星」将"
  #               "手中" + weapon->name() + HIR "尽数凌空射出。\n霎时破空声"
  #               "骤响，" + weapon->name() + HIR "便如同陨星飞坠一般，笼罩"
  #               "$n" HIR "各处大穴！\n" NOR;
  # 
  #         my_exp = COMBAT_D->valid_power(me->query("combat_exp"));
  #         ob_exp = COMBAT_D->valid_power(target->query("combat_exp"));
  # 
  #         me->want_kill(target);
  #         if (my_exp / 2 + random(my_exp * 3 / 2) > ob_exp)
  #         {
  #                 if (target->query_skill("parry") < me->query_skill("throwing"))
  #                 {
  #                         n = 2 + random(2);
  #                         if (random(my_exp) > ob_exp) n += 1 + random(2);
  #                         if (random(my_exp / 2) > ob_exp) n += 1 + random(2);
  #                         if (random(my_exp / 4) > ob_exp) n += 1 + random(2);
  # 
  #                         msg += HIR "结果$n" HIR "一声惨叫，同时中了$P" HIR +
  #                                chinese_number(n) + weapon->query("base_unit") +
  #                                weapon->name() + HIR "，直感两耳轰鸣，目不视"
  #                                "物。\n" NOR;
  # 
  #                         while (n--)
  #                         {
  #                                 COMBAT_D->clear_ahinfo();
  #                                 weapon->hit_ob(me, target,
  #                                                me->query("jiali") + 100 + n * 10);
  #                         }
  # 
  #                         target->set_temp("feixing", 1);
  #                         target->add_temp("apply/attack", -70);
  #                         target->add_temp("apply/dodge", -70);
  #                         target->add_temp("apply/parry", -20);
  #                         target->receive_damage("qi", 150, me);
  #                         target->receive_wound("qi", 50, me);
  # 
  #                         p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                         if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                                 msg += pmsg;
  # 
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                         message_combatd(msg, me, target);
  # 
  #                         tell_object(target, RED "你现在要穴受到重损，乃至全身"
  #                                             "乏力，提不上半点力道！\n" NOR);
  #                         tell_object(me, HIC "你心知刚才这招已打中对方要寒，不"
  #                                             "禁暗自冷笑。\n" NOR);
  # 
  #                         target->kill_ob(me);
  #                         call_out("back", 2 + random(skill / 15), target);
  #                 } else
  #                 {
  #                         msg += HIR "$n" HIR "集中生智，双手画圈回旋挥舞，拨弄"
  #                                "开了要害处的杀着，可还是受了点轻伤。\n" NOR;
  # 
  #                         target->receive_damage("qi", 100);
  #                         target->receive_wound("qi", 40);
  # 
  #                         p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                         message_combatd(msg, me, target);
  # 
  #                         tell_object(target, RED "你只觉全身几处一阵刺痛，知道"
  #                                             "自己虽被击中，但却是避开了要穴。"
  #                                             "\n" NOR);
  #                         target->kill_ob(me);
  #                         me->start_busy(1 + random(2));
  #                 }
  #         } else
  #         {
  #                  msg += CYN "可是$n" CYN "小巧腾挪，好不容易避开了"
  #                         CYN "$N" CYN "铺天盖地的攻击。\n" NOR;
  #                  me->start_busy(3);
  #                  message_combatd(msg, me, target);
  #         }
  #         return 1;
  # }
  # 
  # void back(object target)
  # {
  #         if (objectp(target))
  #         {
  #                 target->add_temp("apply/attack", 70);
  #                 target->add_temp("apply/dodge", 70);
  #                 target->add_temp("apply/parry", 20);
  #                 tell_object(target, HIY "渐渐的你觉得力气一丝丝的恢复了。\n" NOR);
  #                 target->delete_temp("feixing");
  #         }
  # }
end
