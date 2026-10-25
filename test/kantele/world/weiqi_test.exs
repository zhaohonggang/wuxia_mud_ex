defmodule Kantele.World.WeiqiTest do
  @moduledoc """
  P5-9 #9 一次性场景：棋苑围棋/五子棋**纯逻辑**单测（`Kantele.World.Weiqi`）。

  覆盖 LPC `d/city/qiyuan/qiyuan2.c` 的棋盘算法：开盘/让子、坐标解析、
  落子、提子、禁入点、打劫标记、五子连珠、悔棋、渲染。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Weiqi

  # ---- 开盘 / 让子 ----------------------------------------------------------

  describe "new_game/3" do
    test "19 路围棋：全空、黑先、状态 playing" do
      s = Weiqi.new_game()

      assert s.bsize == 19
      assert s.status == Weiqi.status_playing()
      assert s.turn == "black"
      assert s.handicap == 0
      assert length(s.board) == 19 * 19
      assert Enum.all?(s.board, &(&1 == Weiqi.blank()))
    end

    test "五子棋：状态 wuzi" do
      assert Weiqi.new_game(19, true).status == Weiqi.status_wuzi()
    end

    test "让 2 子（偶数）：h_list 前两点落黑，白先" do
      s = Weiqi.new_game(19, false, 2)

      assert s.handicap == 2
      assert s.turn == "white"
      # h_list = [3*19+3, 15*19+15, ...]
      assert Enum.at(s.board, 3 * 19 + 3) == Weiqi.black()
      assert Enum.at(s.board, 15 * 19 + 15) == Weiqi.black()
      assert Enum.count(s.board, &(&1 == Weiqi.black())) == 2
    end

    test "让 9 子（奇数）：天元 + h_list 八点，共 9 黑，白先" do
      s = Weiqi.new_game(19, false, 9)

      assert s.handicap == 9
      assert s.turn == "white"
      assert Enum.at(s.board, 9 * 19 + 9) == Weiqi.black()
      assert Enum.count(s.board, &(&1 == Weiqi.black())) == 9
    end

    test "让子仅在 19 路围棋生效（五子棋/非 19 路清零）" do
      assert Weiqi.new_game(19, true, 9).handicap == 0
      assert Weiqi.new_game(15, false, 9).handicap == 0
    end
  end

  # ---- 坐标解析 -------------------------------------------------------------

  describe "translate/2" do
    test "ASCII 字母 + 数字，0-based" do
      assert Weiqi.translate("a1", 19) == {:ok, 0, 0}
      assert Weiqi.translate("d4", 19) == {:ok, 3, 3}
      assert Weiqi.translate("S19", 19) == {:ok, 18, 18}
      assert Weiqi.translate("b10", 19) == {:ok, 1, 9}
    end

    test "非法坐标" do
      assert Weiqi.translate("z1", 19) == :error
      assert Weiqi.translate("a0", 19) == :error
      assert Weiqi.translate("a20", 19) == :error
      assert Weiqi.translate("abc", 19) == :error
      assert Weiqi.translate("1a", 19) == :error
      assert Weiqi.translate("a", 19) == :error
    end

    test "棋盘大小限制字母/数字范围" do
      assert Weiqi.translate("i9", 9) == {:ok, 8, 8}
      assert Weiqi.translate("j1", 9) == :error
      assert Weiqi.translate("a10", 9) == :error
    end
  end

  # ---- 落子 / 提子 / 禁入 --------------------------------------------------

  describe "play/2（围棋）" do
    test "正常落子：落子、换手、started=1" do
      s = Weiqi.new_game()
      assert {:ok, s2, false} = Weiqi.play(s, "d4")

      assert Enum.at(s2.board, 3 * 19 + 3) == Weiqi.black()
      assert s2.turn == "white"
      assert s2.started == 1
      assert s2.lastmove == "d4"
    end

    test "占位 → :occupied" do
      s = Weiqi.new_game()
      {:ok, s2, _} = Weiqi.play(s, "d4")
      assert Weiqi.play(s2, "d4") == {:error, :occupied}
    end

    test "非法坐标 → :bad_coord" do
      assert Weiqi.play(Weiqi.new_game(), "zz") == {:error, :bad_coord}
    end

    test "提子：四面包围后最后一手提掉白子" do
      # 白(1,1) 三面黑(0,1)(1,0)(2,1)，黑再下 (1,2) 提掉白
      board = set_cells(19, [{1, 1, Weiqi.white()}, {0, 1, Weiqi.black()}, {1, 0, Weiqi.black()}, {2, 1, Weiqi.black()}])
      s = state_with(board, 19, "black", Weiqi.status_playing())

      # b3 → x=1,y=2
      assert {:ok, s2, false} = Weiqi.play(s, "b3")
      assert Enum.at(s2.board, 1 * 19 + 1) == Weiqi.blank()
      assert Enum.at(s2.board, 1 * 19 + 2) == Weiqi.black()
    end

    test "禁入点（自杀）→ :no_qi_banned" do
      # 白四面围住 (1,1)，黑下 (1,1) 无气
      board =
        set_cells(19, [
          {0, 1, Weiqi.white()},
          {1, 0, Weiqi.white()},
          {1, 2, Weiqi.white()},
          {2, 1, Weiqi.white()}
        ])

      s = state_with(board, 19, "black", Weiqi.status_playing())
      assert Weiqi.play(s, "b2") == {:error, :no_qi_banned}
    end
  end

  # ---- 五子棋 ---------------------------------------------------------------

  describe "play/2（五子棋）" do
    test "五连 → winning，状态置 not_playing" do
      board = set_cells(19, [{0, 0, Weiqi.black()}, {0, 1, Weiqi.black()}, {0, 2, Weiqi.black()}, {0, 3, Weiqi.black()}])
      s = state_with(board, 19, "black", Weiqi.status_wuzi())

      # a5 → x=0,y=4 → 连成 5
      assert {:ok, s2, true} = Weiqi.play(s, "a5")
      assert s2.status == Weiqi.status_not_playing()
    end

    test "未成五连 → 正常换手" do
      s = Weiqi.new_game(19, true)
      assert {:ok, s2, false} = Weiqi.play(s, "a1")
      assert s2.turn == "white"
    end
  end

  # ---- 悔棋 -----------------------------------------------------------------

  describe "undo/1（五子棋）" do
    test "悔一步：清掉最后一子、换回手" do
      s = Weiqi.new_game(19, true)
      {:ok, s2, false} = Weiqi.play(s, "a1")

      assert {:ok, s3} = Weiqi.undo(s2)
      assert Enum.at(s3.board, 0) == Weiqi.blank()
      assert s3.turn == "black"
      assert s3.lastmove == ""
      assert s3.undoed == 1
    end

    test "非五子棋 → :not_wuzi" do
      {:ok, s, _} = Weiqi.play(Weiqi.new_game(), "d4")
      assert Weiqi.undo(s) == {:error, :not_wuzi}
    end

    test "一步没走 → :not_started" do
      assert Weiqi.undo(Weiqi.new_game(19, true)) == {:error, :not_started}
    end

    test "一次只能悔一步 → :undoed（需先走两手，悔一步后 started 仍为 1）" do
      s = Weiqi.new_game(19, true)
      {:ok, s1, false} = Weiqi.play(s, "a1")
      {:ok, s2, false} = Weiqi.play(s1, "b1")
      {:ok, s3} = Weiqi.undo(s2)
      # 悔掉 b1 后 lastmove 回退到 a1，started 仍为 1 → 再悔命中 WQ_Undoed
      assert Weiqi.undo(s3) == {:error, :undoed}
    end
  end

  # ---- 渲染 -----------------------------------------------------------------

  describe "render/1" do
    test "19 路空盘含框线与全角坐标" do
      out = Weiqi.render(Weiqi.new_game())

      assert out =~ "┌"
      assert out =~ "┐"
      assert out =~ "└"
      assert out =~ "┘"
      assert out =~ "┼"
      assert out =~ "Ａ"
      assert out =~ "⑴"
    end

    test "落子后显示 ● / ○" do
      s = Weiqi.new_game(19, true)
      {:ok, s2, false} = Weiqi.play(s, "a1")
      assert Weiqi.render(s2) =~ "●"
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp state_with(board, bsize, turn, status) do
    %{
      bsize: bsize,
      board: board,
      status: status,
      turn: turn,
      handicap: 0,
      jie_flag: 6,
      jie_x_ban: nil,
      jie_y_ban: nil,
      started: 0,
      undoed: 0,
      lastmove: "",
      lastlastmove: ""
    }
  end

  defp set_cells(bsize, cells) do
    Enum.reduce(cells, List.duplicate(0, bsize * bsize), fn {x, y, v}, b ->
      List.replace_at(b, x * bsize + y, v)
    end)
  end
end
