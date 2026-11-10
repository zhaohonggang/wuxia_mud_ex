defmodule Kantele.Character.Commands.WizArchTest do
  @moduledoc """
  E5 — W3 arch 14 命令：路由 + 巫师门控 + 显式回执 + var/setsk 真化行为。

  14 命令原先是静默 no-op，本测试确保它们：
  - 参数可达（`optional(spaces() |> text(:rest))`）；
  - 非巫师显式拒绝；
  - 巫师得到明确回执（12 个未建模命令）或真实行为（var/setsk）。
  """
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kalevala.Character.Conn.Text

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

  # 6 个「本端口未建模」命令（排除已真化的 var/setsk，以及已落地的
  # grant / throw / purge / changeuser / register / smash —— 全部 6 个可建模命令）
  @deferred ["build", "call", "possess",
             "reboot", "restore", "shutdown"]

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

  describe "12 个未建模命令：巫师收到明确回执（不再静默）" do
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
