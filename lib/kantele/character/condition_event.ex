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

  @tick_interval 1000

  @condition_keys ["conditions", "cond_applyer"]

  # ---- self 自毒：daub 到手上 ----

  def apply(conn, event) do
    data = event.data

    if data["target"] == "self" && is_map(data["poison"]) do
      character = conn.character
      prev = character.meta.temp["conditions"]

      # 混毒（若已有同种毒）后写回宿主
      merged = Conditions.apply_condition(%{conditions: prev}, "poison", data["poison"])
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

  # ---- 主循环心跳 ----

  def tick(conn, _event) do
    conds = get_session(conn, "conditions")

    if is_map(conds) && map_size(conds) > 0 do
      character = conn.character
      vitals = character.meta.vitals

      # 引擎状态：attributes 由 vitals 喂入
      state = %{
        conditions: conds,
        cond_applyer: get_session(conn, "cond_applyer"),
        attributes: %{
          jing: vitals.jing,
          qi: vitals.qi,
          jingli: vitals.jingli,
          neili: vitals.neili
        }
      }

      daemon = &ConditionRegistry.daemon/1

      # 1) 生命周期（remain/duration 递减、到期清）；{:continue, new} 引擎已写回
      {state, _live?} = Conditions.update_condition(state, daemon)

      # 2) 每存活条件一跳 do_effect（Poison 扣 jing/qi；do_effect 已不递减 remain）
      state =
        Enum.reduce(Map.keys(state.conditions || %{}), state, fn cnd, state ->
          case Conditions.affect_by(state, daemon, cnd, nil) do
            {:ok, new_state} -> new_state
            _ -> state
          end
        end)

      # 3) vitals 与 conditions 回写宿主
      vitals = %{vitals | jing: state.attributes.jing, qi: state.attributes.qi}

      conn =
        conn
        |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
        |> put_session_cond("conditions", state.conditions)
        |> put_session_cond("cond_applyer", state.cond_applyer)
        |> maybe_schedule_next()

      conn
      |> render(CharacterView, "vitals", %{})
    else
      conn
    end
  end

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
end
