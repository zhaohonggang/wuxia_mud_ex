defmodule Kantele.Character.ConditionEvent do
  @moduledoc """
  条件宿主心跳（F1 接线，对应 LPC condition/condition.c heart_beat）

  与 combat 解耦的**独立 `condition/tick`**（1s 自投递，自宿主投递）：
  只要 `conditions` 非空就每跳驱动 `Conditions.update_condition/2` + `Poison.do_effect`，
  非战斗也能跑；`conditions` 清空即停投递（省资源）。

  自毒接线：`daub_command` 一发 `poison/apply`（target "self"）→ 这里落到宿主，
  应用混合毒并开动心跳。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CharacterView
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionRegistry
  alias Kantele.Character.Conditions
  alias Kantele.Poison

  @tick_interval 1000

  @condition_keys ["conditions", "cond_applyer"]

  # ---- self 自毒：daub 到手上 ----

  def apply(conn, event) do
    data = event.data

    if data.target == "self" && is_map(data.poison) do
      # 已有同种毒则混毒（LPC POISON_D->mixed_poison）；毒存 session.conditions
      prev = get_session(conn, "conditions")
      existing = prev && prev["poison"]
      mixed = Poison.mixed_poison(existing, data.poison)

      merged = Conditions.apply_condition(%{conditions: prev}, "poison", mixed)
      conds = merged.conditions

      conn =
        conn
        |> put_session_cond("conditions", conds)
        |> schedule_next()

      conn
      |> render(CommandView, "text", %{text: "你感觉一股腥臭钻入手心，随即整条手臂都一阵发麻！\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
    end
  end

  # ---- 通用落条件：由他人（NPC 私有动作）经事件给宿主上 condition ----
  #
  # NPC 私有动作 handler 跑在**玩家**进程里，无法直接改 NPC 的 session；于是经
  # `send(npc.pid, %Event{topic: "condition/apply", data: %{name: cnd, info: info}})`
  # 把条件落到 NPC 自身（对应 LPC `ob->apply_condition(cnd, info)`）。
  def apply_named(conn, event) do
    name = Map.get(event.data, :name)
    info = Map.get(event.data, :info) || %{}

    if is_binary(name) and name != "" do
      grant(conn, name, info)
    else
      conn
    end
  end

  @doc """
  给宿主落一个 condition 并开动心跳；供本模块事件与**同进程** handler 直接调用
  （`conn` 必须是被落条件的角色自身的 conn）。
  """
  def grant(conn, name, info) when is_binary(name) and name != "" do
    merged = Conditions.apply_condition(%{conditions: get_session(conn, "conditions")}, name, info)

    conn
    |> put_session_cond("conditions", merged.conditions)
    |> schedule_next()
  end

  # ---- 主循环心跳 ----

  def tick(conn, _event) do
    conds = get_session(conn, "conditions")

    if tickable?(conds) do
      conn
      |> tick_vitals()
      |> maybe_emit_down()
      |> render(CharacterView, "vitals", %{})
    else
      conn
    end
  end

  defp tickable?(conds), do: is_map(conds) and map_size(conds) > 0

  defp tick_vitals(conn) do
    character = conn.character
    vitals = character.meta.vitals
    conds = get_session(conn, "conditions")
    cond_applyer = get_session(conn, "cond_applyer")

    state =
      %{
        conditions: conds,
        cond_applyer: cond_applyer,
        attributes: %{
          jing: vitals.jing,
          qi: vitals.qi,
          jingli: vitals.jingli,
          neili: vitals.neili,
          special_skills: Map.get(character.attributes, "special_skills") || %{}
        }
      }
      |> update_lifecycle()
      |> apply_effects()

    vitals = %{vitals | jing: state.attributes.jing, qi: state.attributes.qi}

    conn
    |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
    |> put_session_cond("conditions", state.conditions)
    |> put_session_cond("cond_applyer", state.cond_applyer)
    |> maybe_schedule_next()
  end

  defp update_lifecycle(state) do
    daemon = &ConditionRegistry.daemon/1
    elem(Conditions.update_condition(state, daemon), 0)
  end

  defp apply_effects(state) do
    daemon = &ConditionRegistry.daemon/1

    Enum.reduce(Map.keys(state.conditions || %{}), state, fn cnd, state ->
      case Conditions.affect_by(state, daemon, cnd, nil) do
        {:ok, {:ok, new_state}} when is_map(new_state) -> new_state
        {:ok, new_state} when is_map(new_state) -> new_state
        _ -> state
      end
    end)
  end

  # NPC 气/精被条件拖到 0：发 condition/down，交 ConditionDownEvent 执行专属处决。
  defp maybe_emit_down(%{character: %{meta: %Kantele.Character.NonPlayerMeta{} = meta}} = conn) do
    vitals = meta.vitals

    if down?(vitals) do
      cause = if (vitals.jing || 0) <= 0, do: :jing, else: :qi
      send(self(), %Event{from_pid: self(), topic: "condition/down", data: %{cause: cause}})
    end

    conn
  end

  defp maybe_emit_down(conn), do: conn

  defp down?(vitals), do: (vitals.qi || 0) <= 0 or (vitals.jing || 0) <= 0

  # ---- 心跳调度：conditions 非空才续投，空则停 ----

  defp schedule_next(conn) do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "condition/tick", data: %{}},
      @tick_interval
    )

    conn
  end

  defp maybe_schedule_next(conn) do
    conds = get_session(conn, "conditions")

    if is_map(conds) && map_size(conds) > 0 do
      schedule_next(conn)
    else
      conn
    end
  end

  defp put_session_cond(conn, key, value) when key in @condition_keys do
    put_session(conn, key, value || nil)
  end

  @doc """
  套用毒药到宿主（无渲染，用于 combat 结算）：混毒后写入 session.conditions 并开启心跳。
  """
  def apply_poison(conn, poison) do
    state = get_session(conn, "conditions") || %{}
    existing = state["poison"]
    mixed = Poison.mixed_poison(existing, poison)
    merged = Conditions.apply_condition(%{conditions: state}, "poison", mixed)
    conds = merged.conditions

    conn
    |> put_session_cond("conditions", conds)
    |> schedule_next()
  end
end
