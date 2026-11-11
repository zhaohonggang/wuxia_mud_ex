defmodule Kantele.Character.CloneCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CloneCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.ZoneCache

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
      room_id: Keyword.get(opts, :room_id, "test:room"),
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp wizard_player() do
    player(id: "wizard-1", name: "巫师", attributes: %{"wiz_level" => 1})
  end

  defp arch_player() do
    player(id: "arch-1", name: "大巫师", attributes: %{"wiz_level" => 2})
  end

  defp mortal_player() do
    player(id: "mortal-1", name: "平民", attributes: %{"wiz_level" => 0})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp setup_zone_cache() do
    case ZoneCache.start_link(id: ZoneCache, name: ZoneCache) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end

    npc = %Kalevala.Character{
      id: "testzone:clone_tong_ren",
      name: "铜人",
      description: "一个木制的铜人",
      meta: %{
        zone_id: "testzone",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }

    zone = %{
      id: "testzone",
      name: "测试区",
      characters: %{"clone_tong_ren" => npc},
      rooms: %{}
    }

    ZoneCache.put("testzone", zone)
  end

  defp cleanup_zone_cache() do
    ZoneCache.delete("testzone")
  end

  setup_all do
    setup_zone_cache()
    on_exit(fn -> cleanup_zone_cache() end)
    :ok
  end

  describe "clone 命令（arch 巫师）" do

    test "无参数时提示需要对象" do
      p = arch_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => ""})

      assert output_text(conn) =~ "你要复制什麽对象"
    end

    test "非巫师无法克隆" do
      p = mortal_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "clone_tong_ren"})

      assert output_text(conn) =~ "你不能复制物品"
    end

    test "巫师（非 arch）无法克隆" do
      p = wizard_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "clone_tong_ren"})

      assert output_text(conn) =~ "你不能复制物品"
    end

    test "找不到目标时报错" do
      p = arch_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "nonexistent_npc"})

      assert output_text(conn) =~ "找不到"
    end

    test "克隆 NPC 成功（按精确 id）" do
      p = arch_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "testzone:clone_tong_ren"})

      assert output_text(conn) =~ "只见"
      assert output_text(conn) =~ "铜人"
    end

    test "克隆 NPC 成功（按名称）" do
      p = arch_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "铜人"})

      assert output_text(conn) =~ "只见"
      assert output_text(conn) =~ "铜人"
    end

    test "克隆指定数量" do
      p = arch_player()
      conn = CloneCommand.run(build_conn(p), %{"rest" => "testzone:clone_tong_ren 3"})

      assert output_text(conn) =~ "只见"
      assert output_text(conn) =~ "铜人"
    end
  end

  describe "clone 命令（路由解析）" do
    test "裸命令可达" do
      {:ok, parsed} = Kantele.Character.Commands.parse("clone")
      assert parsed.module == CloneCommand
    end

    test "带参命令可达，参数在 rest 里" do
      {:ok, parsed} = Kantele.Character.Commands.parse("clone clone_tong_ren")
      assert parsed.module == CloneCommand
      assert parsed.params["rest"] == "clone_tong_ren"
    end

    test "带数量参数可达" do
      {:ok, parsed} = Kantele.Character.Commands.parse("clone clone_tong_ren 3")
      assert parsed.module == CloneCommand
      assert parsed.params["rest"] == "clone_tong_ren 3"
    end
  end
end
