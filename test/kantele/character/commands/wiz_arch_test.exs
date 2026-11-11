defmodule Kantele.Character.Commands.WizArchTest.CallTarget do
  @moduledoc false
  # 供 call 命令测试调用的目标模块（经由 W3ObjectEngine 注册）。
  def ping(args), do: "pong:#{inspect(args)}"
  def arity0, do: :ok
end

defmodule Kantele.Character.Commands.WizArchTest do
  @moduledoc """
  E5 — W3 arch 14 命令：路由 + 巫师门控 + 显式回执 + var/setsk 真化行为 +
  B2 W3 对象引擎：call/reboot/shutdown 真化行为。

  14 命令原先是静默 no-op，本测试确保它们：
  - 参数可达（`optional(spaces() |> text(:rest))`）；
  - 非巫师显式拒绝；
  - 巫师得到明确回执（build/possess/restore 未建模；call/reboot/shutdown 真化）。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.CallCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.RebootCommand
  alias Kantele.Character.ShutdownCommand
  alias Kantele.Character.Vitals
  alias Kalevala.Character.Conn.Text
  alias Kantele.World.W3ObjectEngine

  # 14 个 W3 arch 命令：命令字符串 -> 模块
  @commands [
    {"build", Kantele.Character.BuildCommand},
    {"call", Kantele.Character.CallCommand},
    {"changeuser", Kantele.Character.ChangeuserCommand},
    {"grant", Kantele.Character.GrantCommand},
    {"possess", Kantele.Character.PossessCommand},
    {"purge", Kantele.Character.PurgeCommand},
    {"reboot", Kantele.Character.RebootCommand},
    {"register", Kantele.Character.RegisterCommand},
    {"restore", Kantele.Character.RestoreCommand},
    {"shutdown", Kantele.Character.ShutdownCommand},
    {"smash", Kantele.Character.SmashCommand},
    {"throw", Kantele.Character.ThrowCommand},
    {"var", Kantele.Character.VarCommand},
    {"setsk", Kantele.Character.SetskCommand}
  ]

  # 仍「本端口未建模」的 3 个命令（call/reboot/shutdown 已在本计划真化，
  # possess/restore/build 依赖更重的世界/持久化系统，保留 not_modeled 回执）。
  @deferred ["build", "possess", "restore"]

  defp player(opts) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Kantele.Character.Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0)
    }

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: Keyword.get(opts, :room_id, "test:room"),
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  defp wizard_player(), do: player(id: "wizard-1", name: "巫师", attributes: %{"wiz_level" => 2})
  defp mortal_player(), do: player(id: "mortal-1", name: "平民", attributes: %{"wiz_level" => 0})

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由：参数可达" do
    test "裸命令与带参命令都解析到正确模块" do
      for {cmd, mod} <- @commands do
        {:ok, parsed} = Kantele.Character.Commands.parse(cmd)
        assert parsed.module == mod, "裸 #{cmd} 应解析到 #{mod}"

        {:ok, parsed2} = Kantele.Character.Commands.parse("#{cmd} some_arg")
        assert parsed2.module == mod, "带参 #{cmd} 应解析到 #{mod}"
        assert parsed2.params["rest"] == "some_arg", "#{cmd} 参数应进入 params[\"rest\"]"
      end
    end
  end

  describe "巫师门控：非巫师显式拒绝" do
    test "非巫师对任一命令都收到权限提示" do
      for {cmd, mod} <- @commands do
        conn = mod.run(build_conn(mortal_player()), %{"rest" => "anything"})
        assert output_text(conn) =~ "没有巫师的权限", "#{cmd} 非巫师应被拒绝"
      end
    end
  end

  describe "未建模命令：巫师收到明确回执（不再静默）" do
    test "巫师触发任一未建模命令得到「未建模」回执" do
      for {name, mod} <- @commands do
        if name in @deferred do
          conn = mod.run(build_conn(wizard_player()), %{"rest" => "arg"})
          text = output_text(conn)
          assert text =~ "未实现", "#{name} 巫师应收到未建模回执"
          assert text =~ "W3 对象系统", "#{name} 回执应说明原因"
          refute text =~ "没有巫师的权限", "#{name} 巫师不应被拒"
        end
      end
    end
  end

  describe "call：对象函数调用（已真化）" do
    test "巫师调用已注册对象函数并收到结果" do
      W3ObjectEngine.ensure!()
      W3ObjectEngine.register("wizarch_obj_ping", __MODULE__.CallTarget, %{}, nil)

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => "wizarch_obj_ping ping hello"})
      text = output_text(conn)

      assert text =~ "调用 ping 结果", "应返回函数调用结果"
      assert text =~ "pong:", "应返回目标模块的实际返回值"
      refute text =~ "没有巫师的权限"
    end

    test "匿名对象（无参数函数）也可调用" do
      W3ObjectEngine.ensure!()
      W3ObjectEngine.register("wizarch_obj_a0", __MODULE__.CallTarget, %{}, nil)

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => "wizarch_obj_a0 arity0"})
      assert output_text(conn) =~ "调用 arity0 结果: :ok"
    end

    test "对象不存在时返回明确错误" do
      W3ObjectEngine.ensure!()

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => "wizarch_ghost xyz"})
      assert output_text(conn) =~ "找不到对象"
    end

    test "函数不存在时返回明确错误" do
      W3ObjectEngine.ensure!()
      W3ObjectEngine.register("wizarch_obj_nf", __MODULE__.CallTarget, %{}, nil)

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => "wizarch_obj_nf nope"})
      assert output_text(conn) =~ "函数不存在"
    end

    test "非属主且非 admin 时被拒绝" do
      W3ObjectEngine.ensure!()
      W3ObjectEngine.register("wizarch_obj_owner", __MODULE__.CallTarget, %{}, "other_wizard")

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => "wizarch_obj_owner ping x"})
      assert output_text(conn) =~ "你没有权限调用该对象"
    end

    test "无参数时提示用法" do
      W3ObjectEngine.ensure!()

      conn = CallCommand.run(build_conn(wizard_player()), %{"rest" => ""})
      assert output_text(conn) =~ "用法"
    end

    test "非巫师被拒绝" do
      W3ObjectEngine.ensure!()

      conn = CallCommand.run(build_conn(mortal_player()), %{"rest" => "anything ping x"})
      assert output_text(conn) =~ "没有巫师的权限"
    end
  end

  describe "reboot：系统重启（已真化，应用层受限）" do
    test "巫师触发返回确认文案" do
      W3ObjectEngine.ensure!()

      conn = RebootCommand.run(build_conn(wizard_player()), %{"rest" => ""})
      text = output_text(conn)

      assert text =~ "正在调度系统重启", "应返回重启确认"
      assert text =~ "演练", "测试环境应处于 dry-run"
      refute text =~ "没有巫师的权限"
    end

    test "延迟参数被解析" do
      W3ObjectEngine.ensure!()

      conn = RebootCommand.run(build_conn(wizard_player()), %{"rest" => "5"})
      assert output_text(conn) =~ "延迟 5 秒后执行"
    end

    test "非巫师被拒绝" do
      W3ObjectEngine.ensure!()

      conn = RebootCommand.run(build_conn(mortal_player()), %{"rest" => ""})
      assert output_text(conn) =~ "没有巫师的权限"
    end
  end

  describe "shutdown：系统停机（已真化，应用层受限）" do
    test "巫师触发返回确认文案" do
      W3ObjectEngine.ensure!()

      conn = ShutdownCommand.run(build_conn(wizard_player()), %{"rest" => ""})
      text = output_text(conn)

      assert text =~ "正在调度系统停机", "应返回停机确认"
      assert text =~ "演练", "测试环境应处于 dry-run"
      refute text =~ "没有巫师的权限"
    end

    test "延迟参数被解析" do
      W3ObjectEngine.ensure!()

      conn = ShutdownCommand.run(build_conn(wizard_player()), %{"rest" => "10"})
      assert output_text(conn) =~ "延迟 10 秒后执行"
    end

    test "非巫师被拒绝" do
      W3ObjectEngine.ensure!()

      conn = ShutdownCommand.run(build_conn(mortal_player()), %{"rest" => ""})
      assert output_text(conn) =~ "没有巫师的权限"
    end
  end

  describe "var：私有变量（已真化）" do
    test "非巫师被拒绝" do
      conn = Kantele.Character.VarCommand.run(build_conn(mortal_player()), %{"rest" => "foo bar"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "无参数列出（空）" do
      conn = Kantele.Character.VarCommand.run(build_conn(wizard_player()), %{"rest" => ""})
      assert output_text(conn) =~ "无私有变量"
    end

    test "显示未设置的变量" do
      conn = Kantele.Character.VarCommand.run(build_conn(wizard_player()), %{"rest" => "foo"})
      assert output_text(conn) =~ "变量 foo 未设置"
    end

    test "设置变量并回写 conn.character.meta.temp" do
      conn = Kantele.Character.VarCommand.run(build_conn(wizard_player()), %{"rest" => "foo bar"})

      assert output_text(conn) =~ "已设置 foo = bar"
      assert PlayerMeta.get_temp(conn.character.meta, "foo") == "bar"
    end

    test "列出已设置的变量" do
      p = wizard_player()
      conn = Kantele.Character.VarCommand.run(build_conn(p), %{"rest" => "foo bar"})
      conn2 = Kantele.Character.VarCommand.run(conn, %{"rest" => ""})

      assert output_text(conn2) =~ "foo = \"bar\""
    end
  end

  describe "setsk：设置技能等级（已真化）" do
    test "非巫师被拒绝" do
      conn = Kantele.Character.SetskCommand.run(build_conn(mortal_player()), %{"rest" => "sword 50"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "设置技能等级并写回 stats.skills" do
      conn = Kantele.Character.SetskCommand.run(build_conn(wizard_player()), %{"rest" => "sword 50"})

      assert output_text(conn) =~ "已设置技能 sword = 50"
      assert conn.character.meta.stats.skills["sword"] == 50
    end

    test "等级为负整数时提示用法" do
      conn = Kantele.Character.SetskCommand.run(build_conn(wizard_player()), %{"rest" => "sword -5"})
      assert output_text(conn) =~ "用法"
      refute conn.character.meta.stats.skills["sword"] == -5
    end

    test "参数不完整时提示用法" do
      conn = Kantele.Character.SetskCommand.run(build_conn(wizard_player()), %{"rest" => "sword"})
      assert output_text(conn) =~ "用法"
    end
  end
end
