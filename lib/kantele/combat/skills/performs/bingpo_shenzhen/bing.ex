defmodule Kantele.Combat.Skills.Performs.BingpoShenzhen.Bing do
  @moduledoc """
  寒冰针「bing」（对照 `kungfu/skill/bingpo-shenzhen/bing.c`）

  冰魄神针投掷绝技：须持 throwing 类暗器，消耗 120 内力与 1 枚暗器。

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 throwing 类暗器 →
  暗器余量>=1 → 冰魄神针>=120 → 内功>=150 → 内力上限>=1500 → 真气>=150 →
  目标未中 `bingpo` → 目标存活。

  攻击方扣 120 真气、消耗 1 枚暗器并发起手广播（三次插入 `weapon->name()`）；
  目标侧以 `ap + random(ap/2)` 对抗目标 `dodge`（ap=攻击方 throwing）：
  - 命中且目标 `parry < 攻击方 throwing`：qi 伤 `skill+random(skill)`、qi 上限伤
    `skill+random(skill/2)`，并挂 `bingpo` 减益（attack/dodge -70、parry -20，
    `2 + random(skill/15)` 秒后由 `back` 恢复）；
  - 命中但目标 `parry >= throwing`：qi 伤 100、上限伤 40，攻击方忙乱 `1 + random(2)`；
  - 未命中：攻击方忙乱 3。

  差异（TODO(migrate)）：
  - `weapon->hit_ob` / `clear_ahinfo` / `query_ahinfo` 钩子引擎无对应物，未建模；
  - `target->set_temp("bingpo")` + `add_temp("apply/*")` + `call_out("back", …)`
    折算为 `Buff{key: "bingpo", applies: %{attack: 70, dodge: 70, parry: 20}}` +
    `apply_temp(%{attack: -70, dodge: -70, parry: -20})`，到期由 `combat/buff-expire`
    回收并提示 `back` 的 `tell_object` 文案（同 mantian_xing/xing）；
  - `target->query_temp("bingpo")` 门槛在目标侧复验（目标 combat 远程不可得），
    故该文案渲染给目标；`tell_object(me, …)` 无跨进程私有通道，以房间广播替代；
  - `eff_status_msg(p)` 折算为 `Messages.eff_status_msg/1`；`living(target)` 门槛
    在攻击方无 meta 可查，由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "bingpo-shenzhen/bing"
  @move_name "「寒冰针」"
  @bingpo_key "bingpo"
  @cost_amount 1

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bingpo-shenzhen")
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
          skill: lvl,
          throwing: Stats.skill(stats, "throwing"),
          anqi_name: anqi && anqi.name,
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

  # LPC: if (weapon->query_amount() < 1)
  defp check_amount(character) do
    if anqi_amount(character) < @cost_amount do
      {:error, "你手中没有针，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("bingpo-shenzhen", 1)) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "bingpo-shenzhen") < 120 do
      {:error, "你的冰魄神针不够娴熟，难以施展#{@move_name}。\n"}
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

  # LPC: if ((int)me->query("max_neili") < 1500)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1500 do
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
    # LPC: me->add("neili", -120); weapon->add_amount(-1);
    #      msg = HIY "只见$N" HIY "长袖微拂，手腕一转，一招「" HIW "寒冰针"
    #            HIY"」，将手中" + weapon->name() + HIY "猛地射出。刹那\n"
    #            "间，长空破响，" + weapon->name() + HIY "如同一颗流星划过，"
    #            "袭向$n！\n" NOR;
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 120, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}
    character = consume_anqi(character, anqi, @cost_amount)

    anqi_name = (anqi && anqi.name) || ""

    conn =
      Broadcast.publish(
        conn,
        "只见$N长袖微拂，手腕一转，一招#{@move_name}，将手中" <>
          anqi_name <>
          "猛地射出。刹那间，长空破响，" <>
          anqi_name <> "如同一颗流星划过，袭向$n！\n",
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

  # LPC: weapon->add_amount(-1)；数量归零则移除该实例。
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
    # LPC: if ((int)target->query_temp("bingpo")) return notify_fail("对方已经中了…！\n");
    # 目标 combat 远程不可得，故此门槛在目标侧复验（文案按 .c 原样保留）。
    if character.meta.combat.dead do
      conn
    else
      if Combat.buff_active?(character.meta.combat, @bingpo_key) do
        render(conn, CommandView, "text", text: "对方已经中了你的绝招，现在是废人一个，赶快进攻吧！\n")
      else
        do_resolve_incoming(conn, character, attacker, data)
      end
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :skill, 0), 1)
    throwing = Map.get(data, :throwing, 0)
    anqi_name = Map.get(data, :anqi_name) || ""
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    ap = throwing
    dp = Stats.skill(stats, "dodge")

    # LPC: ap = me->query_skill("throwing"); dp = target->query_skill("dodge");
    #      if (ap + random(ap / 2) > dp)
    if ap + Engine.rand(rng, max(div(ap, 2), 1)) > dp do
      # LPC: if (target->query_skill("parry") < me->query_skill("throwing"))
      if Stats.skill(stats, "parry") < throwing do
        hit_vital(conn, character, bindings, rng, skill, anqi_name)
      else
        light_wound(conn, character, attacker, bindings, rng)
      end
    else
      # LPC: msg += CYN "可是$n…避开了$N迅猛如电的攻击。\n"; me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      Broadcast.publish(
        conn,
        "可是$n身法灵巧，小心闪避，好不容易避开了$N迅猛如电的攻击。\n",
        bindings
      )
    end
  end

  # 命中要穴：qi 伤 skill+random(skill)、上限伤 skill+random(skill/2)；挂 bingpo 减益。
  defp hit_vital(conn, character, bindings, rng, skill, anqi_name) do
    # LPC: target->receive_damage("qi", skill + random(skill), me);
    #      target->receive_wound("qi", skill + random(skill / 2), me);
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, skill + Engine.rand(rng, skill))
      |> Vitals.wound(:qi, skill + Engine.rand(rng, max(div(skill, 2), 1)))

    # LPC: target->set_temp("bingpo", 1); add_temp("apply/attack", -70);
    #      add_temp("apply/dodge", -70); add_temp("apply/parry", -20);
    #      call_out("back", 2 + random(skill / 15), target);
    buff = %Buff{key: @bingpo_key, applies: %{attack: 70, dodge: 70, parry: 20}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(%{attack: -70, dodge: -70, parry: -20})
      |> Combat.add_buff(buff)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
    schedule_expire(buff, 2 + Engine.rand(rng, max(div(skill, 15), 1)))

    # LPC: p = target->query("qi") * 100 / target->query("max_qi");
    #      msg += "( $n" + eff_status_msg(p) + " )\n"; message_combatd(msg, me, target);
    p = div(vitals.qi * 100, max(vitals.max_qi, 1))
    suffix = "( $n" <> Messages.eff_status_msg(p) <> " )\n"

    # LPC: msg += HIR "只听$n" HIR "惨叫一声，" + weapon->name() + HIR
    #      "已经射中要害，只感伤口处透处阵阵寒意，顿觉全身软弱无力。\n" NOR;
    text =
      "只听$n惨叫一声，" <>
        anqi_name <> "已经射中要害，只感伤口处透处阵阵寒意，顿觉全身软弱无力。\n" <> suffix

    # LPC: me->start_busy 无（要穴命中不加攻击方忙乱）
    conn
    |> Broadcast.publish(text, bindings)
    |> render(CommandView, "text", text: "你现在要穴受到重损，乃至全身乏力，提不上半点力道！\n")
    |> Broadcast.publish("你心知刚才这招已打中对方要害，不禁暗自冷笑。\n", bindings)
    |> put_character(character)
  end

  # 被避开要害：qi 伤 100、上限伤 40 + 攻击方忙乱 1 + random(2)。
  defp light_wound(conn, character, attacker, bindings, rng) do
    # LPC: target->receive_damage("qi", 100); target->receive_wound("qi", 40);
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, 100)
      |> Vitals.wound(:qi, 40)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    p = div(vitals.qi * 100, max(vitals.max_qi, 1))
    suffix = "( $n" <> Messages.eff_status_msg(p) <> " )\n"

    # LPC: msg += HIR "$n" HIR "眼见暗器袭来，左躲右闪，但仍然受了一点轻伤。\n" NOR;
    text = "$n眼见暗器袭来，左躲右闪，但仍然受了一点轻伤。\n" <> suffix

    # LPC: me->start_busy(1 + random(2));
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 2))

    conn
    |> Broadcast.publish(text, bindings)
    |> render(CommandView, "text", text: "你只觉全身几处一阵刺痛，知道自己虽被击中，但却是避开了要害。\n")
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
end
