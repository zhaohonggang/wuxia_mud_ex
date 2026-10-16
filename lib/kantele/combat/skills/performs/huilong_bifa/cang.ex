defmodule Kantele.Combat.Skills.Performs.HuilongBifa.Cang do
  @moduledoc """
  掌藏龙「cang」（对照 `kungfu/skill/huilong-bifa/cang.c`，inherit F_SSERVER）

  回龙璧法暗器攻击：要求袖中持有暗器（handing，throwing）、huilong-bifa >= 120、
  force >= 150、真气 >= 150；消耗 100 内力，扬袖掷出暗器远程攻击，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - 命中判定：`rand(level) > parry/2`，忙乱 3 轮；
  - 回龙璧（id `huilong bi`）返手与"非回龙璧暗器销毁"效果未建模（TODO(migrate)）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "huilong-bifa/cang"
  @move_name "「掌藏龙」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, level, weapon)
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
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huilong-bifa")

    if level < 120 do
      {:error, "你的回龙璧法不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够了。\n"}
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

  defp apply_perform(conn, character, target, level, weapon) do
    weapon_name = Map.get(weapon, :name) || ""

    # LPC: msg = HIY "$N" HIY "一声轻喝，单手一扬，袖底顿时迸出一股气劲，袖中" +
    #           anqi->query("name") + NOR + HIY "便如蛟龙般射向$n" HIY "！\n" NOR;
    a1 = "$N一声轻喝，单手一扬，袖底顿时迸出一股气劲，袖中"
    a2 = "便如蛟龙般射向$n！\n"
    start_msg = a1 <> weapon_name <> a2

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    weapon_name = Map.get(data, :weapon_name, "")
    combat = character.meta.combat
    parry = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    conn =
      if Engine.rand(rng, max(level, 1)) > div(parry, 2) do
        damage = div(level, 2) + Engine.rand(rng, max(div(level, 2), 1))
        combat = Combat.start_busy(combat, 3)
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        character = %{character | meta: %{character.meta | vitals: vitals}}

        # LPC: msg += COMBAT_D->do_damage(..., HIR "$n" HIR "只觉劲风袭体，低头间，发"
        #       "现" + anqi->query("name") + NOR + HIR "正端端插在自己胸口，顿时惊怒交集，呕"
        #       "出一口鲜血。\n" NOR);
        hit_msg =
          "$n只觉劲风袭体，低头间，发现" <>
            weapon_name <> "正端端插在自己胸口，顿时惊怒交集，呕出一口鲜血。\n"

        conn
        |> Broadcast.publish(hit_msg, bindings)
        |> put_character(put_combat(character, combat))
      else
        # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，飞"
        #       "身一跃而起，躲避开来。\n" NOR;
        miss_msg = "可是$p看破了$P的企图，飞身一跃而起，躲避开来。\n"
        Broadcast.publish(conn, miss_msg, bindings)
      end

    # LPC: if (anqi->query("id") == "huilong bi") msg += HIC "霎时却见回龙璧凌空一个盘旋，
    #       又飞回到$N" HIC "手中。\n" NOR;
    Broadcast.publish(conn, "霎时却见回龙璧凌空一个盘旋，又飞回到$N手中。\n", bindings)
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "huilong-bifa/cang",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
