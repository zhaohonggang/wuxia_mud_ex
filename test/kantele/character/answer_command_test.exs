defmodule Kantele.Character.LegacyAnswerCommandTest do
  @moduledoc """
  S1 之前的 answer 占位桩回归（保留路由/空参覆盖）。

  文件名 `commands/answer_command_test.exs` 里的 B5 版本才是当前实现的主测试；
  本模块改用独立模块名，避免两文件同名 defmodule 触发
  "cannot define module ... because it is currently being defined" 编译错误。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AnswerCommand
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

  describe "answer 命令" do
    test "无参数时提示" do
      p = player()
      conn = AnswerCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "回答什么"
    end

    test "有参数但无 forge 议价会话时显示 stub 文案" do
      # S1c 之后路由把参数放进 "rest"；只有处于 Forging status=="answer_type"
      # 时才转交莫邪，否则走原 stub。S1 真化后 stub 文案由「暂未开放」改为
      # 「回答系统目前不支持该选项。」（避免被 CommandProbe 判为未实装占位）。
      p = player()
      conn = AnswerCommand.run(build_conn(p), %{"rest" => "好的"})
      assert output_text(conn) =~ "目前不支持该选项"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("answer 好的")
      assert parsed.module == AnswerCommand
    end
  end
end
