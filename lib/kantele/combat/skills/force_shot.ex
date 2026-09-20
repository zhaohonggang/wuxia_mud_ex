defmodule Kantele.Combat.Skills.Force.Shot do
  @moduledoc """
  弹毒（对照 `kungfu/skill/force/shot.c`）

  仅限特定内功：修罗/化功/蛤蟆/神农/华血；
  force>=150、poison>=100、throwing>=100、neili>=300；
  需 hand 中毒药、目标有效、非 no_fight/skybook、非 die_guard/比武；
  内力对抗，成功施加毒药效果、busy 2。
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

  @allowed_forces ~w(xiuluo-yinshagong huagong-dafa hamagong shennong-xinjing huaxue-shengong)

  @perform "force/shot"
  @name "弹毒"

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
  def query_action(_level, _rng \\ &:rand.uniform/1) do
    %{}
  end

  @impl true
  def exert_list() do
    %{"shot" => __MODULE__}
  end

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    force = Map.get(stats.mapped, "force")
    skill = Stats.skill(stats, "force")
    poison_skill = Stats.skill(stats, "poison")
    throwing_skill = Stats.skill(stats, "throwing")

    with :ok <- gate_allowed_force(force),
         :ok <- gate_force_level(skill),
         :ok <- gate_skill_level(poison_skill, throwing_skill),
         :ok <- gate_room_ok(character),
         :ok <- gate_neili(vitals),
         {:ok, du} <- gate_handing_poison(character),
         {:ok, target} <- find_target(combat, character) do
      du_name = Map.get(du.item, :name) || Map.get(du.meta || %{}, :name) || "毒药"

      message = "$N一声冷笑，默运#{to_chinese(force)}内劲，手指粘住#{du_name}对准#{target.name}「嗖」的弹射了出去。\n"

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          force_lvl: skill,
          poison_skill: poison_skill,
          throwing_skill: throwing_skill,
          du: du,
          rng: &:rand.uniform/1
        }
      })

      busy = 1 + Engine.rand(&:rand.uniform/1, 3)
      vitals = %{vitals | neili: vitals.neili - 100}

      new_inventory =
        Enum.map(character.inventory, fn item ->
          if item == du do
            if is_integer(item.meta.amount) and item.meta.amount > 1 do
              %{item | meta: %{item.meta | amount: item.meta.amount - 1}}
            else
              nil
            end
          else
            item
          end
        end)
        |> Enum.reject(&is_nil/1)

      character = %{
        character
        | meta: %{
            character.meta
            | vitals: vitals,
            combat: Combat.start_busy(combat, busy)
          },
        inventory: new_inventory
      }

      conn
      |> Broadcast.publish(message, n1: character.name, n2: target.name)
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
    force_lvl = Map.get(data, :force_lvl, 0)
    poison_skill = Map.get(data, :poison_skill, 0)
    throwing_skill = Map.get(data, :throwing_skill, 0)
    du = Map.get(data, :du)
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      an = attacker.meta.vitals.max_neili + div(attacker.meta.vitals.neili, 2)
      dn = character.meta.vitals.max_neili + div(character.meta.vitals.neili, 2)

      if div(an, 2) + Engine.rand(rng, max(an, 1)) < dn * 2 / 3 do
        text = "然而$n全然不放在心上，轻轻一抖，已将$N射来的毒素尽数震落。\n"
               |> Messages.interpolate(bindings)

        conn = Broadcast.publish(conn, text)
        Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
        conn
      else
        ap = force_lvl + poison_skill + throwing_skill
        dp = Stats.skill(character.meta.stats, "dodge") +
             Stats.skill(character.meta.stats, "parry") +
             Stats.skill(character.meta.stats, "martial-cognize")

        if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
          poison_type = du.meta.poison_type
          poison_data = du.meta.poison

          # conditions 存 conn session（condition_event.ex 契约），非 meta
          prev = conn.session["conditions"] || %{}
          conditions = Map.put(prev, poison_type, poison_data)

          combat = character.meta.combat
          combat =
            if not Combat.busy?(combat) do
              Combat.start_busy(combat, 2)
            else
              combat
            end

          character = %{
            character
            | meta: %{
                character.meta
                | combat: combat
              }
          }

          conn = conn |> Kalevala.Character.Conn.put_session("conditions", conditions)

          text = "$n急忙飞身躲避，可已然不及，霎时绿光闪过，$p顿感一阵麻痹。\n"
                 |> Messages.interpolate(bindings)

          conn =
            Broadcast.publish(conn, text)
            |> put_character(character)

          Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
          conn
         else
           text = "可是$n见势不妙，急忙腾挪身形，终于避开了$N的弹毒攻击。\n"
                  |> Messages.interpolate(bindings)

          conn = Broadcast.publish(conn, text)
          Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
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
    if skill >= 150 do
      :ok
    else
      {:error, "你的内功修为不够。\n"}
    end
  end

  defp gate_skill_level(poison_skill, throwing_skill) do
    if poison_skill >= 100 and throwing_skill >= 100 do
      :ok
    else
      {:error, "你的基本毒技/暗器火候不够。\n"}
    end
  end

  defp gate_room_ok(character) do
    room_config = Map.get(character.meta, :room, %{})
    if Map.get(room_config, :no_fight, false) or Map.get(room_config, :skybook, false) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  defp gate_neili(vitals) do
    if vitals.neili >= 300 do
      :ok
    else
      {:error, "你的真气不够。\n"}
    end
  end

  defp gate_handing_poison(character) do
    du = character.inventory |> Enum.find(&(&1.meta && &1.meta.handing))
    if du && du.meta && du.meta.poison do
      {:ok, du}
    else
      {:error, "你得先准备(hand)好毒药再说。\n"}
    end
  end

  defp find_target(combat, character) do
    case combat.enemies do
      [target | _] when target.id != character.id ->
        # 瘦引用无 meta（enemy_ref）时视为存活；die_guard 在 session 由目标侧检查
        alive? = is_nil(Map.get(target, :meta)) || target.meta.vitals.qi > 0

        if alive? do
          {:ok, target}
        else
          {:error, "你想攻击谁？\n"}
        end
      _ ->
        {:error, "你想攻击谁？\n"}
    end
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      "longxiang-gong" -> "龙象般若功"
      "xiuluo-yinshagong" -> "修罗阴煞功"
      "huagong-dafa" -> "化功大法"
      "hamagong" -> "蛤蟆功"
      "shennong-xinjing" -> "神农心经"
      "huaxue-shengong" -> "华血神功"
      _ -> name
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end