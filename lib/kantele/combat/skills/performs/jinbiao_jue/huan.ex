defmodule Kantele.Combat.Skills.Performs.JinbiaoJue.Huan do
  @moduledoc """
  金莲幻生「huan」（对照 `kungfu/skill/jinbiao-jue/huan.c`，inherit F_SSERVER）

  金镖诀（暗器 throwing，持有于 handing 槽）攻击绝招：要求持暗器、
  jinbiao-jue >= 100、真气 >= 100；消耗 80 内力、暗器 1 枚，忙乱 2。命中判定
  `random(combat_exp + skill*skill/10*skill) > target_combat_exp`，
  命中后创伤 `skill/3 + random(skill/3)` 外伤。

  差异（TODO(migrate)）：
  - LPC 未检查 mapped，本版保持一致；
  - `reset_action()` 未建模。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "jinbiao-jue/huan"
  @move_name "「金莲幻生」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, level, weapon)
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

  defp check_weapon(combat) do
    weapon = Map.get(combat.equipped, :handing)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      {:ok, weapon}
    else
      {:error, "你现在手中没有拿着暗器，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jinbiao-jue")

    if level < 100 do
      {:error, "你的金镖诀不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, level, weapon) do
    weapon_name = Map.get(weapon, :name) || ""
    base_unit = Map.get(weapon, :base_unit) || Map.get(weapon, :unit) || ""

    # LPC: msg= HIY "忽然间只见$N" HIY "单袖一扬，袖底顿时窜起一道金光，径直向$n"
    #          HIY "电射而去。\n" NOR;
    start_msg = "忽然间只见$N单袖一扬，袖底顿时窜起一道金光，径直向$n电射而去。\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 80}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    #      ob_exp = target->query("combat_exp");
    #      if (random(my_exp) > ob_exp) { ... }
    my_exp = stats.combat_exp + div(level * level, 10) * level
    ob_exp = target.meta.stats.combat_exp
    rng = &:rand.uniform/1
    hit? = Engine.rand(rng, max(my_exp, 1)) > ob_exp

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        hit?: hit?,
        skill: level,
        weapon_name: weapon_name,
        base_unit: base_unit,
        rng: rng
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    hit? = Map.get(data, :hit?, false)
    skill = Map.get(data, :skill, 0)
    weapon_name = Map.get(data, :weapon_name)
    base_unit = Map.get(data, :base_unit)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    bindings = [n1: attacker.name, n2: character.name]

    if hit? do
      # LPC: target->receive_wound("qi", skill / 3 + random(skill / 3), me);
      vitals =
        Vitals.wound(
          character.meta.vitals,
          :qi,
          div(skill, 3) + Engine.rand(rng, max(div(skill, 3), 1))
        )

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += HIR "结果$p" HIR "躲闪不及，被$P" + HIR "那" +
      #            weapon->query("base_unit") + weapon->name() +
      #            HIR "射中身体，顿时鲜血四处飞溅！\n" NOR;
      # NOTE: "结果$p躲闪不及，被$P" 与 "那" 为相邻纯字面量，用 Enum.join 保段。
      head = Enum.join(["结果$p躲闪不及，被$P", "那"], "")

      hit_msg = head <> (base_unit || "") <> (weapon_name || "") <> "射中身体，顿时鲜血四处飞溅！\n"

      conn = Broadcast.publish(conn, hit_msg, bindings)

      # LPC: p = target->query("qi") * 100 / target->query("max_qi");
      #      msg += "( $n" + eff_status_msg(p) + " )\n";
      max_qi = character.meta.vitals.max_qi || character.meta.vitals.qi || 1
      p = div(character.meta.vitals.qi * 100, max(max_qi, 1))
      conn = Broadcast.publish(conn, "( $n" <> eff_status_msg(p) <> " )\n", bindings)

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "丝毫不乱，身子略倾，闪开了$P"
      #            CYN "发出的" + weapon->name() + CYN "。\n" NOR;
      miss_msg = "可是$p丝毫不乱，身子略倾，闪开了$P发出的" <> (weapon_name || "") <> "。\n"
      Broadcast.publish(conn, miss_msg, bindings)
    end
  end

  # LPC: eff_status_msg(p) —— 定义于 /kungfu/skill/eff_msg.h（状态描述按 qi 百分比）。
  # TODO: 该表位于独立头文件，逐条移植待补；当前返回空串以避免引入额外文案。
  defp eff_status_msg(_p), do: ""

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
