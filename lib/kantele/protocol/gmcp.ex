defmodule Kantele.Protocol.GMCP do
  @moduledoc """
  GMCP 协议数据层（对应 `feature/user_gmcp.c`）

  只做纯数据组装/消息串构造；收发需宿主连接层（`has_gmcp`/`send_gmcp` 是钩子）。

  - `send_message/2`：`"Core.Hello {"json"}"` 模块点分 + JSON payload（sendGMCP）
  - `char_vitals/1` / `room_info/1`：按玩家/房间状态 map 组装 GMCP 数据
  - `log/2`：滚动日志保留最近 50 条
  """

  @gmcp_log 50

  @doc "滚动日志：保留最近 #{@gmcp_log} 条（user_gmcp.c log_gmcp）"
  def log(log, msg) when is_list(log) do
    Enum.take(log ++ [msg], -@gmcp_log)
  end

  def log(_log, msg), do: [msg]

  @doc "sendGMCP 消息串：`模块.子模块 [json]`（无 modules 或无 data 则 nil）"
  def send_message(data, modules) when is_map(data) and modules != [] do
    msg = Enum.join(modules, ".")
    msg <> " " <> Jason.encode!(data)
  end

  def send_message(_, _), do: nil

  @doc """
  Char.Vitals.Get 的数据组装（user_gmcp.c `Char.Vitals`）

  `v` 形如 `%{qi, max_qi, jing, max_jing, jingli, max_jingli, neili, max_neili,
  food, water, max_food, max_water, combat_exp, potential, learned_points}`，
  缺省按 0。**故意用 `|| 0`**（LPC 注释：0 值客户端可能误判 userdata）。
  """
  def char_vitals(v) do
    %{
      "hp" => int(v[:qi]),
      "max_hp" => int(v[:max_qi]),
      "jing" => int(v[:jing]),
      "max_jing" => int(v[:max_jing]),
      "jingli" => int(v[:jingli]),
      "max_jingli" => int(v[:max_jingli]),
      "neili" => int(v[:neili]),
      "max_neili" => int(v[:max_neili]),
      "food" => int(v[:food]),
      "max_food" => int(v[:max_food]),
      "water" => int(v[:water]),
      "max_water" => int(v[:max_water]),
      "exp" => int(v[:combat_exp]),
      "pot" => int(v[:potential]) - int(v[:learned_points])
    }
  end

  @doc """
  Room.Info.Get 的数据组装（user_gmcp.c `Room.Info`）

  `r` 形如 `%{name, exits: [...], area, file}`；缺省兜底。
  `hash` 用 file 的 SHA-1（user_gmcp.c：`sha1(base_name(ob))`）。
  """
  def room_info(r) do
    %{
      "name" => remove_ansi(r[:name] || ""),
      "exits" => r[:exits] || [],
      "area" => r[:area] || area_of(r[:file] || ""),
      "hash" => :crypto.hash(:sha, to_string(r[:file] || "")) |> Base.encode16(case: :lower)
    }
  end

  defp int(nil), do: 0
  defp int(n), do: n

  defp remove_ansi(s), do: String.replace(s, ~r/\e\[[0-9;]*m/, "")

  defp area_of(file) when is_binary(file) do
    file |> String.split("/") |> Enum.at(1, "") |> or_default("unknown")
  end

  defp area_of(_), do: "unknown"

  defp or_default("", d), do: d
  defp or_default(s, _), do: s
end