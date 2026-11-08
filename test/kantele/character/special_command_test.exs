defmodule Kantele.Character.SpecialCommandTest do
  @moduledoc """
  `special` 命令 LPC 行为测试（cmds/std/special.c）。

  纯函数 harness：玩家/物品/房间/在线玩家都通过 `InteractionFixtures` 注入，
  不依赖应用监督树。特技 daemon 通过 `SpecialSkills.register/2` 注册到全局
  `persistent_term`，每个用例 `on_exit` 清理避免串扰。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Commands
  alias Kantele.Character.SpecialCommand
  alias Kantele.Character.SpecialSkill
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.InteractionFixtures, as: F

  # ---- 测试用特技 daemon ----

  defmodule TestPiyi do
    @behaviour SpecialSkill
    def name, do: "辟邪"
    def perform(conn, _skill, _arg), do: %{conn | private: Map.put(conn.private, :performed, "piyi")}
  end

  defmodule TestCast do
    @behaviour SpecialSkill
    def name, do: "施法"
    def perform(conn, _skill, arg), do: %{conn | private: Map.put(conn.private, :cast_arg, arg)}
  end

  defmodule TestNoop do
    @behaviour SpecialSkill
    def name, do: "noop"
    def perform(_conn, _skill, _arg), do: :not_handled
  end

  defp run(arg, opts \\ [], conn_opts \\ []) do
    p = F.player(opts)
    conn = F.build(p, conn_opts)
    SpecialCommand.run(conn, %{"rest" => arg})
  end

  describe "列出所会特技" do
    test "已出生且有特技时，普通特技在前、转世特技归到「转世」小节" do
      # 默认 fixture 拥有 piyi（转世）与 strength（普通），born=true
      # strength 的显示名来自 BornPlayer.display_name("strength") = "麒麟血臂"
      conn = run("")
      text = F.output_text(conn)
      assert text =~ "你现在会以下这些特技："
      assert text =~ "麒麟血臂(strength)"
      assert text =~ " 转  世"
      assert text =~ "piyi(piyi)"
      # 普通特技在转世小节之前
      assert String.split(text, " 转  世") |> List.first() =~ "麒麟血臂(strength)"
    end

    test "注册了 daemon 时显示 name() 而非 id" do
      SpecialSkills.register("piyi", TestPiyi)
      on_exit(fn -> SpecialSkills.unregister("piyi") end)

      conn = run("")
      text = F.output_text(conn)
      assert text =~ "辟邪(piyi)"
      refute text =~ "piyi(piyi)"
    end

    test "一个特技都不会则提示" do
      conn = run("", specials: %{})
      assert F.output_text(conn) == "你现在好像什么特技都不会哦。\n"
    end

    test "尚未出生则提示" do
      # 去掉 env 的 born / registered，且无 reborn
      conn = run("", env: %{}, attributes: %{"special_skills" => %{"piyi" => true}})
      assert F.output_text(conn) == "你还没有出生呐，会什么特技？\n"
    end
  end

  describe "使用特技" do
    test "busy 时拒绝" do
      conn = run("piyi", busy: true)
      assert F.output_text(conn) == "你现在忙着呢，不能使用特技。\n"
    end

    test "未拥有的特技拒绝" do
      conn = run("flying")
      assert F.output_text(conn) == "你不会这种特技啊！\n"
    end

    test "已拥有但无 daemon 拒绝" do
      # 默认拥有 piyi，但本用例不注册 daemon
      conn = run("piyi")
      assert F.output_text(conn) == "好像没有这种特技...\n"
    end

    test "已拥有且已注册则调用 daemon，并透传剩余参数" do
      SpecialSkills.register("cast", TestCast)
      on_exit(fn -> SpecialSkills.unregister("cast") end)

      conn = run("cast 张三", specials: %{"cast" => true})
      assert Map.get(conn.private, :cast_arg) == "张三"
    end

    test "daemon 返回 :not_handled 时只回提示符（无文案）" do
      SpecialSkills.register("noop", TestNoop)
      on_exit(fn -> SpecialSkills.unregister("noop") end)

      conn = run("noop", specials: %{"noop" => true})
      assert F.output_text(conn) == ""
    end
  end

  describe "巫师查看他人" do
    test "wizard 带玩家名则列出该玩家特技" do
      wizard = F.player(id: "me", wiz_level: 1)
      other = F.player(id: "li-1", name: "李四", specials: %{"guibian" => true})
      conn = F.build(wizard, players: [other])
      conn = SpecialCommand.run(conn, %{"rest" => "李四"})

      text = F.output_text(conn)
      assert text =~ "李四现在会以下这些特技："
      assert text =~ "guibian"
    end

    test "wizard 带参数但无匹配玩家则回落到对自己的 perform 路径" do
      wizard = F.player(id: "me", wiz_level: 1)
      conn = F.build(wizard, players: [])
      conn = SpecialCommand.run(conn, %{"rest" => "nobody"})

      # 命中不到在线玩家时，arg 保留为特技名，走「使用特技」分支
      assert F.output_text(conn) == "你不会这种特技啊！\n"
    end
  end

  describe "命令路由" do
    test "裸 special 命中且 rest 为空" do
      {:ok, parsed} = Commands.parse("special")
      assert parsed.module == SpecialCommand
      assert Map.get(parsed.params, "rest", "") == ""
    end

    test "special <特技> 透传整段文字为 rest" do
      {:ok, parsed} = Commands.parse("special piyi 张三")
      assert parsed.module == SpecialCommand
      assert Map.get(parsed.params, "rest") == "piyi 张三"
    end
  end

  # 避免未使用别名告警
  _ = Conn
end
