defmodule Kantele.Character.MudinfoCommand do
  @moduledoc """
  系统资讯命令：`mudinfo`

  对应 LPC cmds/usr/mudinfo.c。
  显示当前 Mud 的系统资讯（驱动、CPU、内存、线上/注册玩家数、uptime 等）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence
  alias ExVenture.Characters

  @mud_name "武林外传"
  @mud_zone "中国"
  @version "ExVenture/Kalevala (Elixir)"

  def run(conn, _params) do
    text = build_info()
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp build_info do
    uptime = :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    mem = formatted_memory(total_memory_bytes())

    """
                .__________ 系 统 资 讯 __________.
    -------------------------------------------------------------
        Mud 中文名称：  #{@mud_name}（#{@mud_zone}）
        Mud 驱动版本：  #{@version}
        Mud 系统版本：  YH Mudlib Ver UTF-8（Elixir 移植）
        线上玩家数量：  #{online_count()} 个人在线上
        注册玩家总数：  #{registered_count()} 个人在本 Mud 注册
        载入对象总数：  #{loaded_objects_count()} 个
        游戏占用内存：  #{mem}
        连续执行时间：  #{duration_text(uptime)}
        Mud 现在状态：  运行中

    """
  end

  defp online_count, do: length(Presence.characters())

  defp registered_count do
    try do
      Characters.count_all()
    rescue
      _ -> 0
    catch
      _, _ -> 0
    end
  end

  defp loaded_objects_count do
    # Elixir 中用进程数近似 LPC objects() 数量
    :erlang.system_info(:process_count)
  end

  defp total_memory_bytes, do: :erlang.memory(:total)

  defp formatted_memory(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} bytes"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} K"
      true -> "#{Float.round(bytes / (1024 * 1024), 3)} M"
    end
  end

  defp duration_text(seconds) do
    d = div(seconds, 86_400)
    h = div(rem(seconds, 86_400), 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    parts = if d > 0, do: ["#{d}天"], else: []
    parts = if h > 0, do: parts ++ ["#{h}小时"], else: parts
    parts = if m > 0, do: parts ++ ["#{m}分"], else: parts
    Enum.join(parts, "") <> "#{s}秒"
  end
end
