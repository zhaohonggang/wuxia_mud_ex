defmodule Kantele.Character.NewsCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.NewsCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    meta = %PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: combat
    }

    meta =
      case Keyword.get(opts, :cooldown) do
        true -> PlayerMeta.put_temp(meta, "last_news", :os.system_time(:second))
        _ -> meta
      end

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: meta
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

  describe "news 命令" do
    test "冷却期提示" do
      p = player(cooldown: true)
      conn = NewsCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)

      assert text =~ "慢慢来"
    end

    test "非法参数显示帮助" do
      p = player()
      conn = NewsCommand.run(build_conn(p), %{"arg" => "foo"})
      text = output_text(conn)

      assert text =~ "指令格式"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("news new")
      assert parsed.module == NewsCommand
    end
  end
end