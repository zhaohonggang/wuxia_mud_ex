defmodule Kantele.Character.SetupControllerTest do
  @moduledoc """
  SetupController 状态机测试（性别 → 洗点 → 投胎）。

  注意：投胎(born) 末步会 `move/4` 到出生地，需要运行中的世界（ZoneCache），
  故本单元只覆盖「不触发 move」的性别与洗点两段；投胎映射与落盘由
  SetupPersistenceTest（DataCase）覆盖。
  """
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SetupController
  alias Kantele.Character.Stats

  defp player do
    %Character{
      id: "p1",
      name: "tester",
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      meta: %PlayerMeta{stats: %Stats{}}
    }
  end

  # `put_character` 把角色暂存到 `conn.private.update_character`，由框架在下一步
  # 应用回 `conn.character`。单元测试直接调 recv 时需手动应用，方能跨步累积状态。
  defp applied(conn) do
    case conn.private do
      %{update_character: char} when not is_nil(char) -> %{conn | character: char}
      _ -> conn
    end
  end

  defp char_of(conn), do: conn.private.update_character || conn.character

  defp state(conn), do: conn.session[:setup_state]

  describe "init" do
    test "进入阎罗殿，问答首步为性别" do
      conn = SetupController.init(build_conn(player()))
      assert state(conn) == :gender
    end
  end

  describe "问答① 性别" do
    test "m / 男 → 男性，进入洗点" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "m") |> applied()
      assert state(conn) == :washto
      assert char_of(conn).meta.env[:gender] == "男性"
    end

    test "f / 女 → 女性" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "f") |> applied()
      assert char_of(conn).meta.env[:gender] == "女性"
      assert state(conn) == :washto
    end

    test "非法输入重新询问性别" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "x") |> applied()
      assert state(conn) == :gender
      assert char_of(conn).meta.env[:gender] == nil
    end
  end

  describe "问答② 洗点(washto)" do
    test "总和=80 通过，写入 stats 与 env[:washed]，进入投胎" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "m") |> applied()
      conn = SetupController.recv(conn, "20 20 20 20") |> applied()
      c = char_of(conn)

      assert c.meta.stats.str == 20
      assert c.meta.stats.int == 20
      assert c.meta.stats.con == 20
      assert c.meta.stats.dex == 20
      # per/kar 随机 5–30，落盘于 stats
      assert c.meta.stats.per in 5..30
      assert c.meta.stats.kar in 5..30
      assert c.meta.env[:washed] == true
      assert state(conn) == :born
    end

    test "各项范围 10–30（>30 被拒）" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "m") |> applied()
      conn = SetupController.recv(conn, "31 20 20 9") |> applied()

      assert state(conn) == :washto
      assert char_of(conn).meta.env[:washed] == nil
    end

    test "总和 != 80 被拒（updated.c:128）" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "m") |> applied()
      conn = SetupController.recv(conn, "20 20 20 21") |> applied()

      assert state(conn) == :washto
      assert char_of(conn).meta.env[:washed] == nil
    end

    test "非 4 整数被拒" do
      conn = SetupController.init(build_conn(player())) |> applied()
      conn = SetupController.recv(conn, "m") |> applied()
      conn = SetupController.recv(conn, "20 20 20") |> applied()

      assert state(conn) == :washto
      assert char_of(conn).meta.env[:washed] == nil
    end
  end

  describe "born 映射（公开访问器）" do
    test "扬州人氏：普通出生地无 surname" do
      spec = SetupController.birthplace("扬州人氏")
      assert spec.startroom == "city:kedian"
      assert spec.born == "扬州人氏"
      assert spec.born_family == "没有"
      assert spec.surname == nil
    end

    test "欧阳世家：西域·白驼山 + 姓欧阳" do
      spec = SetupController.birthplace("欧阳世家")
      assert spec.startroom == "baituo:dating"
      assert spec.born == "西域人氏"
      assert spec.born_family == "欧阳世家"
      assert spec.surname == "欧阳"
    end

    test "段氏皇族：大理·王府 + 姓段" do
      spec = SetupController.birthplace("段氏皇族")
      assert spec.startroom == "dali:wangfugate"
      assert spec.born == "大理人氏"
      assert spec.surname == "段"
    end

    test "未知出生地返回 nil" do
      assert SetupController.birthplace("火星人氏") == nil
    end
  end
end
