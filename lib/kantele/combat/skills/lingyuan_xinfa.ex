defmodule Kantele.Combat.Skills.LingyuanXinfa do
  @moduledoc """
  灵元心法（对照 `kungfu/skill/lingyuan-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_learn` 沿用 LPC `inherit FORCE` 的基础门槛（基本内功 >=10）。

  差异（TODO(migrate)）：
  - `valid_force` 未在 LPC 中声明，按基础内功通配（接受任意共存内功）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "lingyuan-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 10 do
      {:error, "你的基本内功火候不够，不能学习特殊内功。\n"}
    else
      :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"break" => Kantele.Combat.Skills.LingyuanXinfa.Break}
  end
end

defmodule Kantele.Combat.Skills.LingyuanXinfa.Break do
  @moduledoc """
  以柔破钢「break」（对照 `kungfu/skill/lingyuan-xinfa/break.c`）

  战斗中运功：灵元心法 >=150、目标非忙乱存活且有兵刃。
  以柔劲包裹对手兵刃，按 `random(攻击方 combat_exp) > 目标 combat_exp/3`
  判定：成功则兵刃震落（卸下 `:weapon` 装备槽）且目标忙乱 `lingyuan/20`
  轮；失败则对手急急拆招闪开。攻击方 busy 2。

  差异（TODO(migrate)）：
  - LPC 目标无兵器时以 `notify_fail` 打回攻击方；本引擎目标进程无法回写
    失败文案，改由攻击方预读目标快照（`enemies` 含 meta 时）在前置门槛
    拒绝；瘦引用（无 meta）时按有兵刃放行，目标侧无兵刃则直接放弃结算。
  - 兵刃震落只卸下装备槽（保留快照语义），不生成房间掉落物。
  - LPC `message_combatd` 后判定；本实现门槛前置，失败不产生开场文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "lingyuan-xinfa/break"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- find_target(combat),
         :ok <- gate_target_busy(target),
         :ok <- gate_skill_level(stats),
         :ok <- gate_target_alive(target),
         :ok <- gate_target_weapon(target) do
      conn =
        Broadcast.publish(
          conn,
          "$N沉肩滑步，自丹田中升起一股阴柔之气顺着血脉经络传至双手劳宫穴，" <>
            "接着这股阴柔之气就激射而出，喷向$n手中的兵刃！\n",
          n1: character.name,
          n2: target.name
        )

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          skill: Stats.skill(stats, "lingyuan-xinfa"),
          combat_exp: stats.combat_exp || 0,
          rng: &:rand.uniform/1
        }
      })

      vitals = character.meta.vitals
      combat = Combat.start_busy(combat, 2)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> put_character(character)
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = Map.get(data, :skill, 0)
    att_exp = Map.get(data, :combat_exp, 0)

    if character.meta.combat.busy > 0 do
      conn
    else
      do_resolve(conn, character, attacker, skill, att_exp, rng)
    end
  end

  defp do_resolve(conn, character, attacker, skill, att_exp, rng) do
    t_combat = character.meta.combat

    case Combat.weapon(t_combat) do
      nil ->
        Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
        conn

      weapon ->
        t_exp = (character.meta.stats.combat_exp || 0)

        if Engine.rand(rng, max(att_exp, 1)) > div(t_exp, 3) do
          t_combat =
            t_combat
            |> Combat.unequip(:weapon)
            |> Combat.start_busy(div(skill, 20))

          character = %{character | meta: %{character.meta | combat: t_combat}}

          conn =
            conn
            |> Broadcast.publish(
              "结果$n手中的#{weapon.name}与这股阴柔之气一碰竟被震落在地上！\n",
              n1: attacker.name,
              n2: character.name
            )
            |> put_character(character)

          Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
          conn
        else
          conn =
            Broadcast.publish(
              conn,
              "可是$n急急拆招，躲了开去，使$N的计谋没有得逞。\n",
              n1: attacker.name,
              n2: character.name
            )

          Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
          conn
        end
    end
  end

  defp find_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能对战斗中的对手使用「以柔破钢」。\n"}
    end
  end

  defp gate_target_busy(target) do
    if Map.get(target, :busy, 0) == 0 do
      :ok
    else
      {:error, "#{target.name}目前正在发愣，是进攻的好时机！\n"}
    end
  end

  defp gate_skill_level(stats) do
    if Stats.skill(stats, "lingyuan-xinfa") >= 150 do
      :ok
    else
      {:error, "你的灵元心法火候不够，还不会使用「以柔破钢」。\n"}
    end
  end

  defp gate_target_alive(target) do
    dead =
      case target do
        %{meta: %{combat: %{dead: dead}}} -> dead
        _ -> false
      end

    if dead do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp gate_target_weapon(target) do
    if is_nil(Map.get(target, :meta)) do
      :ok
    else
      case Combat.weapon(target.meta.combat) do
        nil -> {:error, "#{target.name}目前是空手，没什么必要施展「以柔破钢」。\n"}
        _weapon -> :ok
      end
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end