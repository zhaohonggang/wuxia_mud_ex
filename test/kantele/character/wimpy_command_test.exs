defmodule Kantele.Character.WimpyCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.WimpyCommand

  import Kalevala.ConnTest

  describe "wimpy 显示设置" do
    test "无参数显示当前设置（默认关闭）" do
      conn = run_wimpy(player(), "")

      assert output_text(conn) =~ "没有设定自动逃跑"
    end

    test "无参数显示当前设置（已设定）" do
      conn = run_wimpy(player(wimpy: 30), "")

      assert output_text(conn) =~ "低于 30%"
    end
  end

  describe "wimpy 设置阈值" do
    test "设置合法阈值" do
      conn = run_wimpy(player(), "30")

      assert output_text(conn) =~ "Ok"
      assert output_text(conn) =~ "30%"
    end

    test "设置为 0 关闭" do
      conn = run_wimpy(player(wimpy: 30), "0")

      assert output_text(conn) =~ "取消了自动逃跑"
    end

    test "超过 80 拒绝" do
      conn = run_wimpy(player(), "90")

      assert output_text(conn) =~ "0-80"
    end

    test "负数拒绝" do
      conn = run_wimpy(player(), "-5")

      assert output_text(conn) =~ "0-80"
    end

    test "非数字拒绝" do
      conn = run_wimpy(player(), "abc")

      assert output_text(conn) =~ "0-80"
    end

    test "设置后 meta.wimpy 更新" do
      conn = run_wimpy(player(), "50")
      character = conn.private.update_character || conn.character

      assert character.meta.wimpy == 50
    end

    test "关闭后 meta.wimpy 为 0" do
      conn = run_wimpy(player(wimpy: 30), "0")
      character = conn.private.update_character || conn.character

      assert character.meta.wimpy == 0
    end
  end

  # ---- helpers ----

  defp player(opts \\ []) do
    wimpy = Keyword.get(opts, :wimpy, 0)

    meta =
      %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
      |> Map.put(:wimpy, wimpy)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: meta
    }
  end

  defp run_wimpy(character, arg) do
    WimpyCommand.run(build_conn(character), %{"arg" => arg})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
