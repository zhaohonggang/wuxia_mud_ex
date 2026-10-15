defmodule Kantele.Combat.Skills.Performs.BaguaBiao.Zhi do
  @moduledoc """
  乾坤一掷「zhi」（对照 `kungfu/skill/bagua-biao/zhi.c`）

  八卦镖法投掷绝技：手中须持 throwing 类暗器（≥30 枚），消耗 100 内力，
  将手中所有暗器掷出，对战斗中对手造成伤害。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 throwing 类暗器、
  暗器数量≥30、`bagua-biao>=120`、`force>=200`、`neili>=150`。

  攻击方广播起手式（`只见$N纵身一跃而起…将手中所有的<暗器>打了出去！`）、
  清空暗器、扣 100 内力、`start_busy(2)`，发 `perform-incoming`；
  目标侧判定命中（`rand(level) > parry/2`）：
  - 命中：`$p刹时只觉眼前金光万道…接连中了$P<暗器>！`，扣 qi 气血/外伤；
  - 未中：`可是$p眼明手快，躲过了$P发出的所有<暗器>。`

  差异（TODO(migrate)）：
  - LPC 以 `combat_exp` 与技能值复合判定命中及段数（`my_exp/ob_exp`、多轮
    `random` 叠加 n、逐枚 `hit_ob`），本版以 `rand(level) > parry/2` 代理并单次结算；
  - LPC 命中后 `receive_damage/receive_wound` 比例为本版 `qi` 气血+外伤近似。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "bagua-biao/zhi"
  @move_name "「乾坤一掷」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_anqi(character),
         :ok <- check_anqi_amount(character),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force_level(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level)
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # if (! objectp(weapon = me->query_temp("handing")) ||
  #     (string)weapon->query("skill_type") != "throwing")
  #         return notify_fail("你现在手中并没有拿着暗器。\n");
  defp check_anqi(character) do
    if has_throwing_anqi?(character) do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  # if (weapon->query_amount() < 30)
  #         return notify_fail("至少要有三十枚暗器你才能施展" ZHI "。\n");
  defp check_anqi_amount(character) do
    amount =
      case handing_anqi(character) do
        nil -> 0
        anqi -> Map.get(anqi.meta, :amount) || 1
      end

    if amount < 30 do
      {:error, "至少要有三十枚暗器你才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if ((skill = me->query_skill("bagua-biao", 1)) < 120)
  #         return notify_fail("你的八卦镖诀不够娴熟，难以施展" ZHI "。\n");
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "bagua-biao")

    if level < 120 do
      {:error, "你的八卦镖诀不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  # if ((int)me->query_skill("force") < 200)
  #         return notify_fail("你的内功火候不够，难以施展" ZHI "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if ((int)me->query("neili") < 150)
  #         return notify_fail("你现在真气不足，难以施展" ZHI "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    anqi = handing_anqi(character)
    weapon_name = (anqi && Map.get(anqi.meta, :name)) || ""

    # LPC: weapon->set_amount(0); me->add("neili", -100); me->start_busy(2)
    character = consume_all_anqi(character, anqi)

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    combat = Combat.start_busy(character.meta.combat, 2)

    meta =
      character.meta
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)

    character = %{character | meta: meta}

    # LPC: msg = HIY "只见$N" HIY "纵身一跃而起…将手中所有的"
    #      + weapon->name() + HIY "打了出去！\n";
    opening =
      "只见$N纵身一跃而起，一声暴喝，十指箕张，将手中所有的" <> weapon_name <> "打了出去！\n"

    conn =
      Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        weapon_name: weapon_name
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
    level = Map.get(data, :level, 0)
    weapon_name = Map.get(data, :weapon_name, "")
    rng = Map.get(data, :rng, &:rand.uniform/1)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(level, 1)) > div(parry, 2) do
      # LPC: receive_damage("qi", skill*3/2 + random(skill*3/2))
      #      receive_wound("qi", skill*2/3 + random(skill*2/3))
      dmg = div(level * 3, 2) + Engine.rand(rng, max(div(level * 3, 2), 1))
      wnd = div(level * 2, 3) + Engine.rand(rng, max(div(level * 2, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, dmg)
        |> Vitals.wound(:qi, wnd)

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += "$p" HIY "刹时只觉眼前金光万道，反应不及，接连中了$P"
      #      HIY + chinese_number(n) + weapon->query("base_unit")
      #      + weapon->name() + HIY "！\n" NOR;
      text =
        Messages.interpolate("$p刹时只觉眼前金光万道，反应不及，接连中了$P", bindings) <>
          weapon_name <> "！\n"

      conn
      |> Broadcast.publish(text)
      |> put_character(character)
    else
      # LPC: msg += NOR + CYN "可是$p" CYN "眼明手快，躲过了$P" CYN "发出"
      #      "的所有" + weapon->name() + CYN "。\n" NOR;
      text =
        Messages.interpolate("可是$p眼明手快，躲过了$P发出的所有", bindings) <>
          weapon_name <> "。\n"

      Broadcast.publish(conn, text)
    end
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  # （对应 LPC `me->query_temp("handing")`）
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  # LPC: weapon->set_amount(0)（数量归零则移除该实例）
  defp consume_all_anqi(character, anqi) do
    if anqi do
      %{character | inventory: Enum.reject(character.inventory, &(&1 == anqi))}
    else
      character
    end
  end

  defp has_throwing_anqi?(character), do: handing_anqi(character) != nil

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
