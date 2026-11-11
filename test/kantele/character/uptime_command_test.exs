defmodule Kantele.Character.UptimeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.UptimeCommand

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "start:room",
      attributes: %{},
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "format_uptime/1 中文时长格式化（对齐 LPC uptime.c）" do
    test "全 0" do
      assert UptimeCommand.format_uptime(0) == "零秒"
    end

    test "仅秒" do
      assert UptimeCommand.format_uptime(1) == "一秒"
      assert UptimeCommand.format_uptime(59) == "五十九秒"
    end

    test "分与秒（时、天省略；秒为 0 仍输出零秒）" do
      assert UptimeCommand.format_uptime(61) == "一分一秒"
      assert UptimeCommand.format_uptime(60) == "一分零秒"
    end

    test "仅小时（分 0 省略，秒 0 输出零秒，对齐 LPC uptime.c）" do
      assert UptimeCommand.format_uptime(3600) == "一小时零秒"
      assert UptimeCommand.format_uptime(3661) == "一小时一分一秒"
    end

    test "仅天（时、分 0 省略，秒 0 输出零秒）" do
      assert UptimeCommand.format_uptime(86_400) == "一天零秒"
      assert UptimeCommand.format_uptime(90_000) == "一天一小时零秒"
    end

    test "天+时+分+秒混合" do
      assert UptimeCommand.format_uptime(90_061) == "一天一小时一分一秒"
    end

    test "大数值中文数字拼接正确" do
      # 1 天 3 小时 46 分 40 秒
      assert UptimeCommand.format_uptime(100_000) == "一天三小时四十六分四十秒"
    end

    test "跨十边界（十一/二十四等）" do
      assert UptimeCommand.format_uptime(11) == "十一秒"
      # 1 天 10 小时 24 分 0 秒
      assert UptimeCommand.format_uptime(24 * 3600 + 10 * 3600 + 24 * 60) ==
               "一天十小时二十四分零秒"
    end
  end

  describe "run/2 真实运行时间输出" do
    test "输出武林外传已经运行了…秒。格式" do
      conn = UptimeCommand.run(build_conn(player()), %{})
      text = output_text(conn)

      assert text =~ "武林外传已经运行了"
      assert text =~ "秒"
      assert String.ends_with?(text, "。\n")
    end

    test "时长随 beam 启动至今单调递增且格式稳定" do
      first = UptimeCommand.format_uptime(:erlang.statistics(:wall_clock) |> elem(0) |> div(1000))
      # 轻微等待后再次取值，应仅追加秒数且格式保持一致
      Process.sleep(5)
      second = UptimeCommand.format_uptime(:erlang.statistics(:wall_clock) |> elem(0) |> div(1000))

      assert is_binary(first) and is_binary(second)
      assert String.ends_with?(first, "秒")
      assert String.ends_with?(second, "秒")
    end
  end
end
