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

  # ---- 主循环心跳 ----

  def tick(conn, _event) do
    conds = get_session(conn, "conditions")

    if is_map(conds) && map_size(conds) > 0 do
      character = conn.character
      vitals = character.meta.vitals

      # 引擎状态：attributes 由 vitals 喂入 + 特技开关（piyi 免疫判定用）
      state = %{
        conditions: conds,
        cond_applyer: get_session(conn, "cond_applyer"),
        attributes: %{
          jing: vitals.jing,
          qi: vitals.qi,
          jingli: vitals.jingli,
          neili: vitals.neili,
          special_skills: Map.get(character.attributes, "special_skills") || %{}
        }
      }

      daemon = &ConditionRegistry.daemon/1

      # 1) 生命周期（remain/duration 递减、到期清）；{:continue, new} 引擎已写回
      {state, _live?} = Conditions.update_condition(state, daemon)

      # 2) 每存活条件一跳 do_effect（Poison 扣 jing/qi；do_effect 已不递减 remain）
      #    Conditions.affect_by/4 的契约是 `{:ok, do_effect 返回值}`（结果不透明，
      #    见 test/kantele/batch6_test.exs），Poison.do_effect 返回 `{:ok, state}`，
      #    故这里要解双层；免疫 `{:immune}` 与解析失败 `:error` 保持 state。
      state =
        Enum.reduce(Map.keys(state.conditions || %{}), state, fn cnd, state ->
          case Conditions.affect_by(state, daemon, cnd, nil) do
            {:ok, {:ok, new_state}} when is_map(new_state) -> new_state
            {:ok, new_state} when is_map(new_state) -> new_state
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
