defmodule Kantele.Character.DetailCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias ExVenture.Characters.Character
  alias ExVenture.Characters.Metadata
  alias ExVenture.Repo
  alias Kantele.Character.DetailCommand
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
      mapped: Keyword.get(opts, :mapped, %{}),
      performs: Keyword.get(opts, :performs, MapSet.new()),
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
      inventory: Keyword.get(opts, :inventory, []),
      attributes: %{"wiz_level" => Keyword.get(opts, :wiz_level, 0)},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        coins: Keyword.get(opts, :coins, 0)
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} ->
        [IO.iodata_to_binary(data)]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)
    :ok
  end

  describe "detail 无参数" do
    test "显示自己：气血/属性/经验/潜能/内功合并输出" do
      p = player(combat_exp: 1000, potential: 500)
      conn = DetailCommand.run(build_conn(p), %{"rest" => ""})

      out = output_text(conn)
      assert out =~ "气血"
      assert out =~ "膂力"
      assert out =~ "实战经验"
      assert out =~ "潜能"
      assert out =~ "基本内功"
    end

    test "有携带物品时合并输出包含背包清单" do
      instance = %Kalevala.World.Item.Instance{
        id: "inst-1",
        item_id: "global:potion",
        item: %Kalevala.World.Item{
          id: "global:potion",
          name: "Healing Potion",
          description: "A potion to heal what ails you."
        }
      }

      p = player(inventory: [instance])
      conn = DetailCommand.run(build_conn(p), %{"rest" => ""})

      out = output_text(conn)
      assert out =~ "携带物品"
      assert out =~ "Healing Potion"
    end

    test "路由解析：裸 detail 落 run_bare（无 rest）" do
      {:ok, parsed} = Kantele.Character.Commands.parse("detail")
      assert parsed.module == DetailCommand
      assert parsed.function == :run_bare
    end
  end

  describe "detail <玩家>" do
    test "非巫师提示权限不足" do
      p = player()
      conn = DetailCommand.run(build_conn(p), %{"rest" => "张三"})
      assert output_text(conn) =~ "你没有巫师的权限"
    end

    test "巫师查看离线玩家时展示其综合状态（读存档快照）" do
      character = Repo.insert!(%Character{name: "李四", wiz_level: 0})

      Repo.insert!(%Metadata{
        character_id: character.id,
        combat_exp: 5000,
        potential: 300,
        skills: %{"sword" => 80}
      })

      p = player(wiz_level: 3, name: "grant")
      conn = DetailCommand.run(build_conn(p), %{"rest" => "李四"})

      out = output_text(conn)
      assert out =~ "气血"
      assert out =~ "实战经验"
      assert out =~ "目标：李四"
    end

    test "巫师查看不存在的玩家时提示找不到" do
      p = player(wiz_level: 3, name: "grant")
      conn = DetailCommand.run(build_conn(p), %{"rest" => "不存在的玩家"})
      assert output_text(conn) =~ "找不到玩家 不存在的玩家"
    end

    test "路由解析：带参 detail 落到 run 且带 rest" do
      {:ok, parsed} = Kantele.Character.Commands.parse("detail grant")
      assert parsed.module == DetailCommand
      assert parsed.function == :run
      assert parsed.params["rest"] == "grant"
    end
  end
end