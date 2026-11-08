defmodule Kantele.Character.ToCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ToCommand
  alias Kantele.Character.Controllers.ToEditorController
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

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

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "to 命令" do
    test "无参数时提示格式" do
      p = player()
      conn = ToCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "指令格式"
    end

    test "无效 verb 提示错误" do
      p = player()
      conn = ToCommand.run(build_conn(p), %{"rest" => "invalid_verb"})
      assert output_text(conn) =~ "不能使用这种方式发布信息"
    end

    test "tell 缺少对象提示错误" do
      p = player()
      conn = ToCommand.run(build_conn(p), %{"rest" => "tell"})
      assert output_text(conn) =~ "必须指明对象"
    end

    test "say 进入多行编辑态" do
      p = player()
      conn = ToCommand.run(build_conn(p), %{"rest" => "say"})

      assert output_text(conn) =~ "请输入say内容"
      assert output_text(conn) =~ "单独一行输入 . 结束"

      # 应该切换到编辑控制器
      assert Map.get(conn.private, :next_controller) == ToEditorController
      editor = Map.get(conn.private, :to_editor)
      assert editor == %{
        verb: "say",
        target: nil,
        lines: [],
        flags: %{
          need_opp: false,
          append_cr: true,
          std: true
        }
      }
    end

    test "tell 带对象进入多行编辑态" do
      p = player()
      conn = ToCommand.run(build_conn(p), %{"rest" => "tell 李四"})

      assert output_text(conn) =~ "对象：李四"
      editor = Map.get(conn.private, :to_editor)
      assert editor.verb == "tell"
      assert editor.target == "李四"
    end

    test "路由解析 to say hello" do
      {:ok, parsed} = Kantele.Character.Commands.parse("to say hello")
      assert parsed.module == ToCommand
      assert %{"command" => "to", "rest" => "say hello"} == parsed.params
    end

    test "路由解析 裸 to" do
      {:ok, parsed} = Kantele.Character.Commands.parse("to")
      assert parsed.module == ToCommand
      assert %{"command" => "to"} == parsed.params
    end
  end

  describe "ToEditorController" do
    test "init 无编辑态返回命令控制器" do
      p = player()
      conn = build_conn(p)

      result = ToEditorController.init(conn)

      assert Map.get(result.private, :next_controller) ==
             Kantele.Character.CommandController
    end

    test "recv 累积多行文本" do
      p = player()
      conn =
        build_conn(p)
        |> put_private(:to_editor, %{
          verb: "say",
          target: nil,
          flags: %{append_cr: true, std: true, need_opp: false},
          lines: []
        })

      result = ToEditorController.recv(conn, "第一行内容")

      assert output_text(result) =~ "> "
      editor = Map.get(result.private, :to_editor)
      assert editor.lines == ["第一行内容"]
    end

    test "recv 以 . 终止处理消息" do
      p = player()
      conn =
        build_conn(p)
        |> put_private(:to_editor, %{
          verb: "say",
          target: nil,
          flags: %{append_cr: true, std: true, need_opp: false, no_cost: false},
          lines: ["hello world"]
        })

      result = ToEditorController.recv(conn, ".")

      # 应该切回命令控制器
      assert Map.get(result.private, :next_controller) ==
             Kantele.Character.CommandController
      # neili 应该被扣除（1 个换行 × 10 = 10）
      updated_char = result.private.update_character || result.character
      assert updated_char.meta.vitals.neili < 9000
    end

    test "recv 内容过长被拒绝" do
      p = player()
      long_line = String.duplicate("a", 5000)
      conn =
        build_conn(p)
        |> put_private(:to_editor, %{
          verb: "say",
          target: nil,
          flags: %{append_cr: true, std: true, need_opp: false},
          lines: [long_line]
        })

      result = ToEditorController.recv(conn, ".")

      assert output_text(result) =~ "你弄得这么长干什么啊？"
    end

    test "internal force 不足时拒绝" do
      p = player(neili: 5, jing: 5)
      conn =
        build_conn(p)
        |> put_private(:to_editor, %{
          verb: "say",
          target: nil,
          flags: %{append_cr: true, std: true, need_opp: false},
          lines: ["hello world"]
        })

      result = ToEditorController.recv(conn, ".")

      assert output_text(result) =~ "不允许你这么做"
    end
  end

  defp put_private(conn, key, value) do
    %{conn | private: Map.put(conn.private, key, value)}
  end
end
