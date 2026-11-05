defmodule Kantele.Character.SecularizeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.SecularizeCommand

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        family: Keyword.get(opts, :family, nil),
        temp: Keyword.get(opts, :temp, %{})
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

  describe "secularize 命令门控" do
    test "非出家人（无门派）静默不处理，无输出" do
      p = player()
      conn = SecularizeCommand.run(build_conn(p), %{})
      assert output_text(conn) === ""
    end

    test "非出家人（class 非 bonze）静默不处理，无输出" do
      p = player(family: %{name: "柳溪派", class: "taoist"})
      conn = SecularizeCommand.run(build_conn(p), %{})
      assert output_text(conn) === ""
    end

    test "出家门派弟子（少林派）不可擅自还俗" do
      p = player(family: %{name: "少林派", class: "bonze"})
      conn = SecularizeCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "不能擅自还俗"
    end

    test "出家门派弟子（峨嵋派）不可擅自还俗" do
      p = player(family: %{name: "峨嵋派", class: "bonze"})
      conn = SecularizeCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "不能擅自还俗"
    end

    test "首次输入：设置 pending 标志并提示再次确认" do
      p = player(family: %{name: "武当派", class: "bonze"})
      conn = SecularizeCommand.run(build_conn(p), %{})

      assert output_text(conn) =~ "再输入一次这个命令"

      updated = conn.private.update_character || conn.character
      temp = Map.get(updated.meta, :temp) || %{}
      assert Map.get(temp, :pending_secularize) == true
    end

    test "确认输入：执行还俗，删除 class，清空 pending" do
      p =
        player(family: %{name: "武当派", class: "bonze"})
        |> set_pending()

      conn = SecularizeCommand.run(build_conn(p), %{})

      assert output_text(conn) =~ "决定回尘世好好享受享受"
      refute output_text(conn) =~ "暂未开放"

      updated = conn.private.update_character || conn.character
      family = Map.get(updated.meta, :family) || %{}
      assert Map.get(family, :class) == nil

      temp = Map.get(updated.meta, :temp) || %{}
      assert Map.get(temp, :pending_secularize) != true
    end

    test "确认输入后角色仍在原门派（仅 class 被删除）" do
      p =
        player(family: %{name: "武当派", class: "bonze"})
        |> set_pending()

      conn = SecularizeCommand.run(build_conn(p), %{})

      updated = conn.private.update_character || conn.character
      family = Map.get(updated.meta, :family) || %{}
      assert Map.get(family, :name) == "武当派"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("secularize")
      assert parsed.module == SecularizeCommand
    end
  end

  defp set_pending(character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_secularize, true))
    %{character | meta: meta}
  end
end
