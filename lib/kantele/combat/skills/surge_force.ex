defmodule Kantele.Combat.Skills.SurgeForce do
  @moduledoc """
  怒海狂涛（对照 `kungfu/skill/surge-force.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须男性）限制未实现（本模型暂无性别字段）。
  - `roar`（黯然吟）房间 AOE 简化为对敌人列表逐发（同 `force/roar`）；
    LPC 的 `want_kill`/`fight_ob` 敌对建立未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "surge-force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的基本内功火候还不够，还不能修炼怒海狂涛。\n"}

      stats.str < 45 ->
        {:error, "你的膂力不足，难以修习怒海狂涛。\n"}

      true ->
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
    %{
      "powerup" => Kantele.Combat.Skills.SurgeForce.Powerup,
      "roar" => Kantele.Combat.Skills.SurgeForce.Roar
    }
  end
end

defmodule Kantele.Combat.Skills.SurgeForce.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/surge-force/powerup.c`）

  需 500 内力，耗 200；临时提升 attack=defense=怒海*2/5、unarmed_damage=怒海/5，
  持续 怒海 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "surge-force/powerup",
      gates: [
        {:neili_min, 500, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 200},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:mul, {:skill, "surge-force"}, 2}, 5},
           defense: {:div, {:mul, {:skill, "surge-force"}, 2}, 5},
           unarmed_damage: {:div, {:skill, "surge-force"}, 5}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "surge-force"},
      expire_message: "你的怒海狂涛运行完毕，将内力收回丹田。\n",
      message: "$N一声长啸，激起一阵狂风，气浪翻翻滚滚，向两旁散开。\n霎时之间，便似长风动起，气云聚合，天地渺然，有如海浪滔滔。\n"
    }
end

defmodule Kantele.Combat.Skills.SurgeForce.Roar do
  @moduledoc """
  黯然吟「roar」（对照 `kungfu/skill/surge-force/roar.c`）

  需怒海狂涛 >=100、内力 >=100、非 no_fight 房间。
  耗内力 100、受 qi 伤 10、busy 5。
  对房间所有生物：`skill/2 + random(skill/2) < 耐力*2` 者免伤；
  否则受精力伤害 `damage*2`（damage = force - 目标max_neili/10），
  目标内力 < force*2 时追加精力内伤，可能昏迷（jing/max_jing 归 1）。
  LPC 用基本内功 force 作 skill 与伤害基准。

  差异（TODO(migrate)）：
  - 房间 AOE 简化为对敌人列表逐发（同 `force/roar`）；`want_kill`/`fight_ob`
    敌对建立未建模。
  - `die_guard` 保护在目标侧按 session 条件跳过。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "surge-force/roar"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    with :ok <- gate_skill_level(stats),
         :ok <- gate_neili(vitals),
         :ok <- gate_room_ok(character) do
      skill = Stats.skill(stats, "force")

      Enum.each(combat.enemies, fn target ->
        if target.id != character.id and Process.alive?(target.pid) do
          send(target.pid, %Event{
            from_pid: self(),
            topic: "combat/perform-incoming",
            data: %{
              attacker: ref(character),
              perform_id: @perform_id,
              skill: skill,
              rng: &:rand.uniform/1
            }
          })
        end
      end)

      vitals = vitals |> Map.put(:neili, max(vitals.neili - 100, 0)) |> Vitals.damage(:qi, 10)
      combat = Combat.start_busy(combat, 5)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(
        "$N仰天长啸，声浪一波一波的荡开去，令人发耳欲聩，意乱情迷！\n",
        n1: character.name
      )
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

    cond do
      Map.has_key?(conn.session["conditions"] || %{}, "die_guard") ->
        conn

      character.meta.combat.busy > 0 ->
        conn

      true ->
        do_resolve(conn, character, attacker, skill, rng)
    end
  end

  defp do_resolve(conn, character, attacker, skill, rng) do
    con = Stats.skill(character.meta.stats, "con") || character.meta.stats.con || 20

    if div(skill, 2) + Engine.rand(rng, max(div(skill, 2), 1)) < con * 2 do
      Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
      conn
    else
      max_neili = character.meta.vitals.max_neili
      damage = skill - div(max_neili, 10)

      if damage > 0 do
        t_vitals = character.meta.vitals
        new_jing = max(t_vitals.jing - damage * 2, 0)
        new_eff_jing = max(t_vitals.max_jing - damage, 0)

        new_eff_jing =
          if t_vitals.neili < skill * 2 do
            max(new_eff_jing - damage, 0)
          else
            new_eff_jing
          end

        new_vitals =
          if new_jing < 1 or new_eff_jing < 1 do
            # 昏迷：jing/max_jing 归 1（Vitals 无 unconscious 字段，LPC 差异记 TODO(migrate)）
            %{t_vitals | jing: 1, max_jing: 1}
          else
            %{t_vitals | jing: new_jing, max_jing: new_eff_jing}
          end

        character = %{character | meta: %{character.meta | vitals: new_vitals}}

        conn =
          conn
          |> Broadcast.publish(
            Messages.interpolate("$n听了脑子轰的一下，双耳嗡鸣不止。\n", n1: attacker.name, n2: character.name)
          )
          |> put_character(character)

        Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
        conn
      else
        conn
      end
    end
  end

  defp gate_skill_level(stats) do
    if Stats.skill(stats, "surge-force") >= 100 do
      :ok
    else
      {:error, "你黯然一声长叹，结果吓跑了几只老鼠！\n"}
    end
  end

  defp gate_neili(vitals) do
    if vitals.neili >= 100 do
      :ok
    else
      {:error, "你的内力不够。\n"}
    end
  end

  defp gate_room_ok(character) do
    room_config = Map.get(character.meta, :room, %{})
    if Map.get(room_config, :no_fight, false) do
      {:error, "这里不能攻击别人! \n"}
    else
      :ok
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
