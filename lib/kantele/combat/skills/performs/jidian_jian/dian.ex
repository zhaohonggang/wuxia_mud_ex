defmodule Kantele.Combat.Skills.Performs.JidianJian.Dian do
  @moduledoc """
  电光四射「dian」（对照 `kungfu/skill/jidian-jian/dian.c`，inherit F_SSERVER）

  疾电剑法单体攻击：要求持剑（sword）、force >= 150、jidian-jian >= 100、
  真气 >= 250；消耗 180 内力（落空 60），剑光如电，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - 清单与 LPC 均未检查 mapped，本版保持一致；
  - 命中判定：LPC 以 sword 对 parry，本版以 `rand(level) > parry/2` 代理；
  - 忙乱：命中 2 轮、落空 3 轮。
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

  @perform_id "jidian-jian/dian"
  @move_name "「电光四射」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         {:ok, level} <- check_skill_level(stats),
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
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器无法施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功的修为不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jidian-jian")

    if level < 100 do
      {:error, "你的疾电剑法修为不够，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够，无法施展#{@move_name}。\n"}
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

    # LPC: msg = HIY "$N" HIY "冷哼一声，手中" + weapon->name() + NOR + HIY
    #           "一抖，运剑如飞，霎时之间，四处都是电光，耀人眼目。\n" NOR;
    a1 = "$N冷哼一声，手中"
    a2 = "一抖，运剑如飞，霎时之间，四处都是电光，耀人眼目。\n"
    start_msg = a1 <> weapon_name <> a2

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 180}
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
    combat = character.meta.combat
    parry = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(level, 1)) > div(parry, 2) do
      damage = div(level, 2) + Engine.rand(rng, max(div(level, 2), 1))
      combat = Combat.start_busy(combat, 2)
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += COMBAT_D->do_damage(..., HIR "只听“唰唰唰”几声，$n" HIR "无法"
      #       "看透招中虚实，连续被削中数剑，一声惨" "叫，血如泉涌！\n" NOR);
      hit_msg = "只听“唰唰唰”几声，$n无法看透招中虚实，连续被削中数剑，一声惨叫，血如泉涌！\n"

      conn
      |> Broadcast.publish(hit_msg, bindings)
      |> put_character(put_combat(character, combat))
    else
      # LPC: msg += CYN "可是$p" CYN "奋力格挡，$P" CYN "只"
      #       "觉得对手防守严密，手中剑光渐缓。 \n" NOR;
      miss_msg = "可是$p奋力格挡，$P只觉得对手防守严密，手中剑光渐缓。\n"
      Broadcast.publish(conn, miss_msg, bindings)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jidian-jian/dian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
