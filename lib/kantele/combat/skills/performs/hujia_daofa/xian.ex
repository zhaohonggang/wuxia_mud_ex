defmodule Kantele.Combat.Skills.Performs.HujiaDaofa.Xian do
  @moduledoc """
  推天献印势「xian」（对照 `kungfu/skill/hujia-daofa/xian.c`，inherit F_SSERVER）

  胡家刀法单体攻击：要求持刀（blade）、force >= 160、hujia-daofa >= 120、
  blade 已激发胡家刀法、真气 >= 200；消耗 150 内力（落空 50），双手握刀缓缓推进，
  发起 `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - 命中判定：LPC 以 blade+force 对 force，本版以 `rand(level) > parry/2` 代理；
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

  @perform_id "hujia-daofa/xian"
  @move_name "「推天献印势」"

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
         :ok <- check_mapped(stats),
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 160 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "hujia-daofa")

    if level < 120 do
      {:error, "你的胡家刀法还不到家，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "hujia-daofa" do
      :ok
    else
      {:error, "你没有激发胡家刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIY "$N" HIY "横过手中" + weapon->name() + HIY "，施出「推天献"
    #           "印势」，双手握刀，将整个刀锋向$n" HIY "缓缓推进！\n"NOR;
    a1 = "$N横过手中"
    a2 = "，施出#{@move_name}，双手握刀，将整个刀锋向$n缓缓推进！\n"
    start_msg = a1 <> weapon_name <> a2

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 150}
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

      # LPC: msg += COMBAT_D->do_damage(..., HIR "$n" HIR "何曾见过如此高明的刀法，"
      #       "一声惨叫，刀锋已入体三分，鲜血四处喷溅！\n" NOR);
      hit_msg = "$n何曾见过如此高明的刀法，一声惨叫，刀锋已入体三分，鲜血四处喷溅！\n"

      conn
      |> Broadcast.publish(hit_msg, bindings)
      |> put_character(put_combat(character, combat))
    else
      # LPC: msg += CYN "$p" CYN "大吃一惊，也不招架，当即向后"
      #       "横移数尺，避开了$P" CYN "这一招。\n" NOR;
      miss_msg = "$p大吃一惊，也不招架，当即向后横移数尺，避开了$P这一招。\n"
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
      id: "hujia-daofa/xian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
