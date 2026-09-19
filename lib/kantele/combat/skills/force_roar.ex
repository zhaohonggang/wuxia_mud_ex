defmodule Kantele.Combat.Skills.Force.Roar do
  @moduledoc """
  狮子吼/龙吟（对照 `kungfu/skill/force/roar.c`）

  仅限特定内功：龙象/天寰/混天/九阳/九阴/葵花/吸星/战神/易筋/混元；
  force>=180、neili>=800、非 no_fight/skybook 房间；
  扣 neili 800，busy 5。
  对房间内所有生物：con 对抗，失败者受精力伤害、可能昏迷。
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

  @allowed_forces ~w(longxiang-gong tianhuan-shenjue huntian-qigong jiuyang-shengong
                     jiuyin-shengong kuihua-mogong xixing-dafa zhanshen-xinjing
                     yijinjing hunyuan-gong)

  @perform "force/roar"
  @name "狮子吼"

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"roar" => __MODULE__}
  end

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    force = Map.get(stats.mapped, "force")
    skill = Stats.skill(stats, "force")

    with :ok <- gate_allowed_force(force),
         :ok <- gate_force_level(skill),
         :ok <- gate_room_ok(character),
         :ok <- gate_neili(vitals) do
      message = roar_message(force)

      targets = combat.enemies

      Enum.each(targets, fn target ->
        if target.pid != character.pid and Process.alive?(target.pid) do
          send(target.pid, %Event{
            from_pid: self(),
            topic: "combat/perform-incoming",
            data: %{
              attacker: ref(character),
              perform_id: @perform,
              skill: skill,
              rng: &:rand.uniform/1
            }
          })
        end
      end)

      vitals = %{vitals | neili: vitals.neili - 800}
      combat = Combat.start_busy(combat, 5)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> Broadcast.publish(message, n1: character.name)
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
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      con = character.meta.stats.con || 20

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

          if t_vitals.neili < skill * 2 do
            new_eff_jing = max(new_eff_jing - damage, 0)
          end

new_vitals =
            if new_jing < 1 or new_eff_jing < 1 do
              %{t_vitals | jing: 1, max_jing: 1, unconscious: true}
            else
              %{t_vitals | jing: new_jing, max_jing: new_eff_jing}
            end

            character = %{character | meta: %{character.meta | vitals: new_vitals}}

           text = case :rand.uniform(3) do
             1 -> "突然只见$n两手抱头，双目凸出，嘴角泛出些许白沫，喉咙咯咯作响。\n"
             2 -> "顿时听得$n一声惨叫，两眼发直，全身不住颤抖，蓦地呕出一口鲜血。\n"
             _ -> "却见$n竟摔倒在地，发出声声哀嚎，双目双耳及鼻孔均渗出丝丝鲜血。\n"
           end
           |> Messages.interpolate(bindings)

           conn =
             Broadcast.publish(conn, text)
             |> put_character(character)

           Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
           conn
        else
          conn
        end
      end
    end
  end

  defp gate_allowed_force(force) do
    if force in @allowed_forces do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  defp gate_force_level(skill) do
    if skill >= 180 do
      :ok
    else
      {:error, "你的内功修为不够。\n"}
    end
  end

  defp gate_room_ok(character) do
    room_config = Map.get(character.meta, :room, %{})
    if Map.get(room_config, :no_fight) or Map.get(room_config, :skybook) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  defp gate_neili(vitals) do
    if vitals.neili >= 800 do
      :ok
    else
      {:error, "你的真气不够。\n"}
    end
  end

  defp roar_message(force) do
    case force do
      "longxiang-gong" -> "$N运转真气，面无表情，歌声如梵唱般贯入众人耳中。\n"
      "huntian-qigong" -> "$N深深吸入一囗气，运足内力发出一阵长啸，音传百里，慑人心神。\n"
      "jiuyang-shengong" -> "$N仰天长啸，声音绵泊不绝，众人无不听得心驰神摇。\n"
      "jiuyin-shengong" -> "$N气凝丹田，猛然一声断喝，声音远远的传了开去，激荡不止。\n"
      "kuihua-mogong" -> "$N蓦地极嘶长呼，声音凄厉之极，令人毛骨悚然。\n"
      "yijinjing" -> "$N深深吸入一囗气，运起金刚禅狮子吼，发出惊天动地的一声巨吼。\n"
      "hunyuan-gong" -> "$N深深吸入一囗气，运起金刚禅狮子吼，发出惊天动地的一声巨吼。\n"
      _ -> "$N深深吸入一囗气，体内#{to_chinese(force)}真气急剧迸发，陡然一声巨啸。\n"
    end
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      "longxiang-gong" -> "龙象般若功"
      _ -> name
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end