defmodule Kantele.Combat.Skills.Performs.BizhenQingzhang.Pengpai do
  @moduledoc """
  澎湃「pengpai」（对照 `kungfu/skill/bizhen-qingzhang/pengpai.c`）

  碧针清掌绝招：须空手，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：已学此招 → 空手 → 目标在战斗中 →
  `bizhen-qingzhang>=180` → `mapped("strike")=="bizhen-qingzhang"` →
  `force>=300` → `max_neili>=3000` → `neili>=500` → 目标存活。

  攻击方无条件 `start_busy(3)`、扣 200 内力，并发起手广播
  （`$N一声轻哼…向$n涌来。`）；目标侧按 `ap/2 + rand(ap) < dp`
  （ap=strike，dp=parry）判定：
  - 命中（不满足上式）：额外扣 300 内力，伤害 `ap/2 + rand(ap/2)`（60% 外伤），
    文案 `只见$n无法抵挡这汹涌澎湃的气流…`；
  - 落空：文案 `只见$n不慌不忙，轻轻一闪，躲过了$N这一击！`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "bizhen-qingzhang/pengpai"
  @move_name "「澎湃」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         :ok <- check_unarmed(combat),
         {:ok, target} <- check_target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force_level(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # if (userp(me) && ! me->query("can_perform/bizhen-qingzhang/pengpai"))
  #         return notify_fail("你还不会使用这一招！\n");
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用这一招！\n"}
    end
  end

  # if (me->query_temp("weapon"))
  #         return notify_fail("你必须空手才能施展「澎湃」这一招！\n");
  defp check_unarmed(combat) do
    if Combat.weapon(combat) do
      {:error, "你必须空手才能施展#{@move_name}这一招！\n"}
    else
      :ok
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # if (me->query_skill("bizhen-qingzhang", 1) < 180)
  #         return notify_fail("你的碧针清掌还不够娴熟，还不能用掌力伤人！\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "bizhen-qingzhang") < 180 do
      {:error, "你的碧针清掌还不够娴熟，还不能用掌力伤人！\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("strike") != "bizhen-qingzhang")
  #         return notify_fail("你没有激发碧针清掌，无法使用「澎湃」这一招！");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "bizhen-qingzhang" do
      :ok
    else
      {:error, "你没有激发碧针清掌，无法使用#{@move_name}这一招！"}
    end
  end

  # if (me->query_skill("force") < 300)
  #         return notify_fail("你内功的修为不够，无法用掌力伤人！\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 300 do
      {:error, "你内功的修为不够，无法用掌力伤人！\n"}
    else
      :ok
    end
  end

  # if (me->query("max_neili") < 3000)
  #         return notify_fail("你的内力修为不够，无法用掌力伤人！\n");
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 3000 do
      {:error, "你的内力修为不够，无法用掌力伤人！\n"}
    else
      :ok
    end
  end

  # if (me->query("neili") < 500)
  #         return notify_fail("你的内力不够，无法用掌力伤人！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够，无法用掌力伤人！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target) do
    ap = Stats.skill(character.meta.stats, "strike")

    # LPC: me->start_busy(3); me->add("neili", -200);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 200, 0)}
    combat = Combat.start_busy(character.meta.combat, 3)

    meta =
      character.meta
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)

    character = %{character | meta: meta}

    # LPC: msg = HIW "$N" HIW "一声轻哼，双掌挥舞出一个大圈，"
    #      "横推而出，顿时一股汹涌澎湃的劲气如波浪一般向$n" HIW "涌来。\n" NOR;
    opening = "$N一声轻哼，双掌挥舞出一个大圈，横推而出，顿时一股汹涌澎湃的劲气如波浪一般向$n涌来。\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("strike"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) < dp)  → 落空
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < dp do
      # LPC: msg += HIY "只见$n" HIY "不慌不忙，轻轻一闪，躲过了$N" HIY "这一击！\n" NOR;
      Broadcast.publish(
        conn,
        Messages.interpolate("只见$n不慌不忙，轻轻一闪，躲过了$N这一击！\n", bindings)
      )
    else
      # LPC: me->add("neili", -300); damage = ap / 2 + random(ap / 2);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))
      Performs.feedback(attacker, 300, 0)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 60, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$n无法抵挡这汹涌澎湃的气流，喷出一大口鲜血，身子直线飞出！\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
