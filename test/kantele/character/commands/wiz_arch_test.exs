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
  alias Kantele.Character.PossessCommand
  alias Kantele.Character.RebootCommand
  alias Kantele.Character.RestoreCommand
  alias Kantele.Character.ShutdownCommand
  alias Kantele.Character.Vitals
  alias Kalevala.Character
  alias Kalevala.Character.Conn.Text
  alias Kantele.World.Possession
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

  # 仍「本端口未建模」的命令（call/reboot/shutdown/possess/restore 已真化；
  # build 依赖房间编辑器 / 出口系统 / 区域文件写入，保留 not_modeled 回执）。
  @deferred ["build"]

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

  # 注入 conn.private 余出点（与 BeastTaming 同款 seam）：房间角色列表、广播捕获、
  # 存档核验注入等，便于纯函数测试不依赖 Room 进程 / Ecto。
  defp wiz_conn(character, private_overrides) do
    conn = build_conn(character)
    private = Enum.reduce(private_overrides, conn.private || %{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
    %{conn | private: private}
  end

  # 房间内的 NPC/玩家结构（meta 用普通 map，避免被认成 PlayerMeta）。
  defp room_npc(id, name, opts \\ []) do
    %Character{
      id: id,
      name: name,
      pid: Keyword.get(opts, :pid, self()),
      room_id: "test:room",
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %{
        vitals: %Vitals{qi: Keyword.get(opts, :qi, 100), max_qi: 100, jing: 100, max_jing: 100},
        stats: %Kantele.Character.Stats{combat_exp: 1000, skills: %{}},
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp capture_broadcast do
    fn _room_id, text -> send(self(), {:possess_broadcast, text}) end
  end

  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
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

  describe "possess：附身（已真化，标记式）" do
    setup do
      Possession.ensure!()
      :ets.delete_all_objects(Possession.table())
      :ok
    end

    test "巫师附身房间内活物：记录关系 + 广播愿景 + 回执" do
      target = room_npc("test:huangbiaoma", "黄骠马")
      conn = wiz_conn(wizard_player(), %{beast_characters: [target], possess_broadcast: capture_broadcast()})

      conn = PossessCommand.run(conn, %{"rest" => "黄骠马"})
      text = output_text(conn)

      assert text =~ "你附身到了黄骠马"
      assert Possession.possessed?("test:huangbiaoma")
      assert Possession.target_of("wizard-1") == %{target_id: "test:huangbiaoma", target_name: "黄骠马"}
      assert_received {:possess_broadcast, broadcast_text}
      assert broadcast_text =~ "钻进了"
      assert broadcast_text =~ "黄骠马"
    end

    test "附身目标不存在时拒绝" do
      conn = wiz_conn(wizard_player(), %{beast_characters: []})
      conn = PossessCommand.run(conn, %{"rest" => "不存在的怪"})
      assert output_text(conn) =~ "没有名字叫"
      refute Possession.possessed?("anything")
    end

    test "不能附身自己" do
      me = wizard_player()
      conn = wiz_conn(me, %{beast_characters: [room_npc(me.id, me.name)]})
      conn = PossessCommand.run(conn, %{"rest" => me.name})
      assert output_text(conn) =~ "不能附身自己"
      refute Possession.possessed?(me.id)
    end

    test "附身已死亡目标被拒" do
      target = room_npc("test:corpse", "尸体", qi: 0)
      conn = wiz_conn(wizard_player(), %{beast_characters: [target]})
      conn = PossessCommand.run(conn, %{"rest" => "尸体"})
      assert output_text(conn) =~ "已经死了"
      refute Possession.possessed?("test:corpse")
    end

    test "附身已被附身的目标被拒" do
      target = room_npc("test:busy", "已被附身的怪")
      :ok = Possession.possess("other-wizard", "test:busy", "已被附身的怪")
      conn = wiz_conn(wizard_player(), %{beast_characters: [target]})
      conn = PossessCommand.run(conn, %{"rest" => "已被附身的怪"})
      assert output_text(conn) =~ "已经被附身了"
    end

    test "-r 解除附身" do
      :ok = Possession.possess("wizard-1", "test:x", "小白")
      conn = wiz_conn(wizard_player(), %{})
      conn = PossessCommand.run(conn, %{"rest" => "-r"})
      assert output_text(conn) =~ "已解除附身"
      refute Possession.possessed?("test:x")
    end

    test "无参查询当前附身状态" do
      conn = wiz_conn(wizard_player(), %{})
      conn = PossessCommand.run(conn, %{"rest" => ""})
      assert output_text(conn) =~ "没有附身任何对象"

      :ok = Possession.possess("wizard-1", "test:y", "小黑")
      conn = wiz_conn(wizard_player(), %{})
      conn = PossessCommand.run(conn, %{"rest" => ""})
      assert output_text(conn) =~ "附身于：小黑"
    end

    test "非巫师被拒绝" do
      target = room_npc("test:z", "小白")
      conn = wiz_conn(mortal_player(), %{beast_characters: [target]})
      conn = PossessCommand.run(conn, %{"rest" => "小白"})
      assert output_text(conn) =~ "没有巫师的权限"
    end
  end

  describe "restore：从存档恢复（已真化，跨进程事件）" do
    setup do
      flush_mailbox()
      :ok
    end

    test "巫师恢复自己：向自身进程发送 character/restore 事件" do
      conn = wiz_conn(wizard_player(), %{restore_save_for: fn _name -> {:ok, %{name: "巫师", saved_at: nil}} end})
      conn = RestoreCommand.run(conn, %{"rest" => ""})
      assert output_text(conn) =~ "已向巫师发送恢复指令"
      assert_received %Kalevala.Event{topic: "character/restore"}
    end

    test "巫师恢复房间内指定玩家：向目标进程发送事件" do
      target = room_npc("test:xiaobai", "小白", pid: self())
      conn = wiz_conn(wizard_player(), %{
        beast_characters: [target],
        restore_save_for: fn _name -> {:ok, %{name: "小白", saved_at: nil}} end
      })
      conn = RestoreCommand.run(conn, %{"rest" => "小白"})
      assert output_text(conn) =~ "已向小白发送恢复指令"
      assert_received %Kalevala.Event{topic: "character/restore"}
    end

    test "目标无存档时拒绝" do
      conn = wiz_conn(wizard_player(), %{restore_save_for: fn _name -> {:error, :not_found} end})
      conn = RestoreCommand.run(conn, %{"rest" => ""})
      assert output_text(conn) =~ "找不到"
      refute_received %Kalevala.Event{topic: "character/restore"}
    end

    test "目标不在房间时拒绝" do
      conn = wiz_conn(wizard_player(), %{
        beast_characters: [],
        restore_save_for: fn _name -> {:ok, %{name: "小白", saved_at: nil}} end
      })
      conn = RestoreCommand.run(conn, %{"rest" => "小白"})
      assert output_text(conn) =~ "这里没有名字叫 小白"
      refute_received %Kalevala.Event{topic: "character/restore"}
    end

    test "非巫师被拒绝" do
      conn = wiz_conn(mortal_player(), %{restore_save_for: fn _name -> {:ok, %{name: "x"}} end})
      conn = RestoreCommand.run(conn, %{"rest" => ""})
      assert output_text(conn) =~ "没有巫师的权限"
    end
  end
end
