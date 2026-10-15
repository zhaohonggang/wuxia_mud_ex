defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Biao do
  @moduledoc """
  七子刚镖「biao」（对照 `kungfu/skill/tangmen-throwing/biao.c`）

  唐门暗器绝技：手中须持暗器（`handing` 槽 throwing 类，或「七子刚镖」本体），
  唐门暗器>=120、拨云锁雾>=120、内功>=200、max_neili>=1200、真气>=150、
  目标存活。命中判定 `ap/2 + random(ap) > 目标parry + 目标dugu-jiujian`
  （ap = throwing）。命中且非「七子刚镖」本体时掷出 7 枚、造成
  `throwing*3/4` 伤害；命中且为「七子刚镖」本体时令目标重伤；未命中则
  扣目标 1000 内力。攻击方无条件扣 100 内力，命中忙乱 2、未命中忙乱 3。

  差异（TODO(migrate)）：
  - `COMBAT_D->clear_ahinfo`/`query_ahinfo`/`eff_status_msg` 与逐枚 `hit_ob`
    的附加信息未建模，折算为单次 damage/wound 结算；
  - `weapon->query("base_unit")`、`me->query("jiali")` 未建模，省略/取 0；
  - `tell_object(target, …)` 折算为房间广播；
  - LPC 无 can_perform 门槛，保留 perform_known 守卫（多 1 条信息性 EXTRA）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "tangmen-throwing/biao"

  # LPC: string name() { return(HIR "七子刚镖" NOR); }
  defp biao_name, do: "七子刚镖"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, anqi} <- check_anqi(character),
         :ok <- check_anqi_amount(anqi),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_boyun(stats),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, anqi)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (!target || !me->is_fighting(target))
  #          return notify_fail(name() + "只能在战斗中对对手使用。\n");
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, biao_name() <> "只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("handing")) ||
  #       (weapon->query("id") != "qizi gangbiao" &&
  #        weapon->query("skill_type") != "throwing"))
  defp check_anqi(character) do
    case handing_item(character) do
      nil ->
        {:error, anqi_error()}

      item ->
        if Map.get(item, :id) == "qizi gangbiao" or
             Map.get(item.meta, :skill_type) == "throwing" do
          {:ok, item}
        else
          {:error, anqi_error()}
        end
    end
  end

  defp anqi_error, do: "你现在手中没有拿着暗器七子刚镖，难以施展" <> biao_name() <> "。\n"

  # LPC: if (weapon->query("id") != "qizigangbiao" && weapon->query_amount() < 7)
  defp check_anqi_amount(item) do
    if Map.get(item, :id) != "qizigangbiao" and (Map.get(item.meta, :amount) || 1) < 7 do
      {:error, "你现在手中没有足够的暗器，难以施展" <> biao_name() <> "。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("tangmen-throwing", 1)) < 120)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "tangmen-throwing")

    if level < 120 do
      {:error, "你的唐门暗器不够娴熟，难以施展" <> biao_name() <> "。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query_skill("boyun-suowu", 1) < 120)
  defp check_boyun(stats) do
    if Stats.skill(stats, "boyun-suowu") < 120 do
      {:error, "你的拨云锁雾不够娴熟，无法施展" <> biao_name() <> "。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功修为不足，难以施展" <> biao_name() <> "。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 1200)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1200 do
      {:error, "你的内力修为不足，难以施展" <> biao_name() <> "。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不足，难以施展" <> biao_name() <> "。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, anqi) do
    stats = character.meta.stats
    weapon_name = Map.get(anqi.meta, :name, "")

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    # LPC: msg = HIR "\n$N" HIR "突然身行一止，从怀中摸出七枚手掌大小的" + weapon->name()
    #           + HIR "，一扬手向$n掷去。\n" "只见七枚" + weapon->name()
    #           + HIR "，飞旋打出，$n" HIR "的周身飞舞着无数的光影，却听不到一丝声音。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "\n$N突然身行一止，从怀中摸出七枚手掌大小的" <>
          weapon_name <>
          "，一扬手向$n掷去。\n只见七枚" <>
          weapon_name <> "，飞旋打出，$n的周身飞舞着无数的光影，却听不到一丝声音。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        throwing: Stats.skill(stats, "throwing"),
        weapon_name: weapon_name,
        special?: Map.get(anqi, :id) == "qizi gangbiao",
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
    throwing = Map.get(data, :throwing, 0)
    weapon_name = Map.get(data, :weapon_name, "")
    special? = Map.get(data, :special?, false)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: tell_object(target, HIR "\n你急忙屏气凝神，希望能够招架这致命的一击。\n"NOR);
    conn = Broadcast.publish(conn, "你急忙屏气凝神，希望能够招架这致命的一击。\n", bindings)

    # LPC: ap = me->query_skill("throwing");
    #      dp = target->query_skill("parry") + target->query_skill("dugu-jiujian", 1);
    ap = max(throwing, 1)
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dugu-jiujian")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      do_hit(conn, character, attacker, rng, special?, throwing, weapon_name, bindings)
    else
      # LPC: tell_object(target, HIR "忽然那无数的光影一闪而没，你心中一惊急忙运内力于全身。\n" NOR);
      conn = Broadcast.publish(conn, "忽然那无数的光影一闪而没，你心中一惊急忙运内力于全身。\n", bindings)

      conn =
        Broadcast.publish(
          conn,
          "$n双臂急舞，衣袖带起破风之声。只听当的一声轻响，竟将那七枚暗器磕飞开去。\n",
          bindings
        )

      # LPC: if (target->query("neili") < 1000) target->set("neili", 0);
      #      else target->add("neili", -1000);
      vitals =
        if character.meta.vitals.neili < 1000 do
          %{character.meta.vitals | neili: 0}
        else
          %{character.meta.vitals | neili: character.meta.vitals.neili - 1000}
        end

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(3);
      Performs.feedback(attacker, 0, 3)
      put_character(conn, character)
    end
  end

  defp do_hit(conn, character, attacker, _rng, true, _throwing, _weapon_name, bindings) do
    # LPC（七子刚镖本体）：msg = HIR "忽然那无数的光影一闪而没，$n身行一顿，喷出一口鲜血，仰天而倒。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "忽然那无数的光影一闪而没，$n身行一顿，喷出一口鲜血，仰天而倒。\n",
        bindings
      )

    # LPC: tell_object(target, HIR "你只觉得胸口一阵钻心的疼痛。低头一看只见那七枚暗器已经深深的
    #      嵌在你的心口。\n" "血迹中隐约有几个小字[七子刚镖...]。\n"NOR);
    conn =
      Broadcast.publish(
        conn,
        "你只觉得胸口一阵钻心的疼痛。低头一看只见那七枚暗器已经深深的嵌在你的心口。\n" <>
          "血迹中隐约有几个小字[七子刚镖...]。\n",
        bindings
      )

    # LPC: target->receive_wound("qi", 100, me); target->unconcious(me); me->start_busy(2);
    vitals = Vitals.wound(character.meta.vitals, :qi, 100)
    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, 0, 2)
    put_character(conn, character)
  end

  defp do_hit(conn, character, attacker, _rng, false, throwing, weapon_name, bindings) do
    # LPC: damage = me->query_skill("throwing") * 3 / 4 + me->query("jiali");
    damage = div(throwing * 3, 4)

    # LPC: msg = HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的七"
    #           + weapon->query("base_unit") + weapon->name() + HIR "。\n"NOR;
    conn =
      Broadcast.publish(
        conn,
        "结果$p一声惨嚎，连中了$P发出的七" <> weapon_name <> "。\n",
        bindings
      )

    # LPC: target->receive_damage("qi", damage, me); target->receive_wound("qi", damage, me);
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, damage)

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(2);
    Performs.feedback(attacker, 0, 2)
    put_character(conn, character)
  end

  # 手持暗器：inventory 中带 handing 标记的实例（对应 LPC `me->query_temp("handing")`）
  defp handing_item(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and Map.get(item.meta, :handing)
    end)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "tangmen-throwing/biao",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
