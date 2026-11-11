defmodule Kantele.World.SnowRegionEvent do
  @moduledoc """
  寒冷落地处理器（玩家自身进程；对应 LPC `gwxuedi.h do_cold` 的副作用部分）

  收到 `snow/cold` 事件后：
  1. 渲染寒冷文案（LPC `tell_object(me, msg)`）；
  2. `damage > 0` → `Damage.receive_damage("qi", damage)` 扣当前气；
  3. `damage > 10 && qi < 50` → 落 `ill_dongshang`，时长 = 已有 + 5 + damage/3
     （对应 LPC `apply_condition("ill_dongshang", query_condition("ill_dongshang") + 5 + damage/3)`）。

  出关 3 倍与关内 1 倍寒冷都经同一事件通道，区别仅在 `data.damage` 已结算好。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Feature.Damage

  @impl true
  def cold(conn, %{data: %{damage: damage, msg: msg}}) do
    conn = render(conn, CommandView, "text", %{text: msg})

    conn =
      if damage > 0 do
        case Damage.receive_damage(conn.character, :qi, damage) do
          {:ok, character} -> put_character(conn, character)
          _ -> conn
        end
      else
        conn
      end

    conn =
      if damage > 10 and current_qi(conn) < 50 do
        existing = existing_dongshang(conn)
        total = existing + 5 + div(damage, 3)
        ConditionEvent.grant(conn, "ill_dongshang", %{"duration" => total})
      else
        conn
      end

    conn
  end

  def cold(conn, _event), do: conn

  defp current_qi(conn) do
    get_in(conn.character, [:meta, :vitals, :qi]) || 0
  end

  defp existing_dongshang(conn) do
    conditions = get_session(conn, "conditions") || %{}

    case Map.get(conditions, "ill_dongshang") do
      %{"duration" => d} -> int(d)
      _ -> 0
    end
  end

  defp int(nil), do: 0
  defp int(n) when is_integer(n), do: n
  defp int(n) when is_float(n), do: trunc(n)

  defp int(n) when is_binary(n) do
    case Integer.parse(String.trim(n)) do
      {v, _} -> v
      _ -> 0
    end
  end

  defp int(_), do: 0
end
