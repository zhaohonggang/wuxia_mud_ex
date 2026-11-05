defmodule Kantele.Character.TopCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.TopCommand
  alias Kantele.Character.TopRanking
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
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        temp: Keyword.get(opts, :temp, %{}),
        env: Keyword.get(opts, :env, %{})
      }
    }
  end

  defp build(p, private \\ %{}) do
    conn = build_conn(p)

    private =
      Enum.reduce(private, conn.private, fn {key, value}, acc -> Map.put(acc, key, value) end)

    %{conn | private: private}
  end

  defp rows do
    [
      %{name: "张三", title: "一介布衣", value: 1_200_000},
      %{name: "李四", title: "江湖侠客", value: 900_000}
    ]
  end

  defp source(result), do: fn _category -> result end

  defp exp_result(opts \\ []) do
    %{
      title: "经验等级",
      rows: Keyword.get(opts, :rows, rows()),
      online_only?: Keyword.get(opts, :online_only?, false)
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

  describe "TopRanking 类别表（LPC member_array 白名单）" do
    test "lv/exp/hp/age/kill/die 均受支持，未知类别不受支持" do
      for category <- ~w(exp lv hp qi jing neili jingli age kill die) do
        assert TopRanking.supported?(category)
      end

      refute TopRanking.supported?("league")
      refute TopRanking.supported?("whatever")
    end

    test "lv/exp 与 hp/qi 的标题一致（LPC 的两次 arg 改写）" do
      assert TopRanking.title("lv") == TopRanking.title("exp")
      assert TopRanking.title("hp") == TopRanking.title("qi")
      assert TopRanking.title("exp") == "经验等级"
      assert TopRanking.title("qi") == "气 血 值"
    end

    test "kill/die 因无计数器返回 :unsupported" do
      assert TopRanking.ranking("kill") == :unsupported
      assert TopRanking.ranking("die") == :unsupported
    end
  end

  describe "top 命令" do
    test "无参数时显示帮助信息" do
      text = output_text(TopCommand.run(build(player()), %{}))
      assert text =~ "全服排行"
      assert text =~ "top lv"
    end

    test "未知类别显示帮助信息" do
      text = output_text(TopCommand.run(build(player()), %{"category" => "whatever"}))
      assert text =~ "目前只提供等级"
    end

    test "exp 渲染英雄榜并报出自己名次" do
      conn = build(player(), %{top_ranking: source(exp_result())})
      conn = TopCommand.run(conn, %{"category" => "exp"})
      text = output_text(conn)

      assert text =~ "英 雄 榜"
      assert text =~ "经验等级"
      assert text =~ "张三"
      assert text =~ "一介布衣"
      assert text =~ "1200000"
      assert text =~ "全服排行第 1 位。"
    end

    test "lv 与 exp 同榜（LPC arg 改写）" do
      conn = build(player(), %{top_ranking: source(exp_result())})
      text = output_text(TopCommand.run(conn, %{"category" => "lv"}))
      assert text =~ "经验等级"
      assert text =~ "全服排行第 1 位。"
    end

    test "在线口径的榜单会注明在线玩家" do
      result = %{title: "气 血 值", rows: rows(), online_only?: true}
      conn = build(player(), %{top_ranking: source(result)})

      text = output_text(TopCommand.run(conn, %{"category" => "hp"}))
      assert text =~ "气 血 值"
      assert text =~ "（在线玩家）"
    end

    test "空榜显示暂时空缺、名次为 0" do
      conn = build(player(), %{top_ranking: source(exp_result(rows: []))})
      text = output_text(TopCommand.run(conn, %{"category" => "exp"}))

      assert text =~ "暂时空缺"
      assert text =~ "全服排行第 0 位。"
    end

    test "kill/die 明确说明本服未记录，不再伪装成暂未开放" do
      conn = build(player(), %{top_ranking: source(:unsupported)})
      text = output_text(TopCommand.run(conn, %{"category" => "kill"}))

      assert text =~ "本服尚未记录『杀敌次数』数据"
      refute text =~ "暂未开放"
    end

    test "数据源异常时给出兜底提示" do
      conn = build(player(), %{top_ranking: source(:error)})
      text = output_text(TopCommand.run(conn, %{"category" => "exp"}))
      assert text =~ "排行榜暂时无法读取"
    end

    test "成功查看会记住 last_view" do
      conn = build(player(), %{top_ranking: source(exp_result())})
      conn = TopCommand.run(conn, %{"category" => "exp"})

      last_view = conn.private.update_character.meta.temp["last_view"]
      assert is_integer(last_view)
    end

    test "15 秒内重复查看被节流" do
      p = player(temp: %{"last_view" => 999_995})
      conn = build(p, %{top_now: 1_000_000, top_ranking: source(exp_result())})
      conn = TopCommand.run(conn, %{"category" => "exp"})

      assert output_text(conn) =~ "排行榜更新中"
      assert conn.private.update_character == nil
    end

    test "超过 15 秒可再次查看" do
      p = player(temp: %{"last_view" => 999_980})
      conn = build(p, %{top_now: 1_000_000, top_ranking: source(exp_result())})
      text = output_text(TopCommand.run(conn, %{"category" => "exp"}))

      assert text =~ "英 雄 榜"
    end

    test "wizard 绕过节流" do
      p = player(temp: %{"last_view" => 999_999}, env: %{"wizard" => true})
      conn = build(p, %{top_now: 1_000_000, top_ranking: source(exp_result())})

      assert output_text(TopCommand.run(conn, %{"category" => "exp"})) =~ "英 雄 榜"
    end

    test "league 仍走结义同盟排行" do
      text = output_text(TopCommand.run(build(player()), %{"category" => "league"}))
      assert text =~ "结义同盟"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("top exp")
      assert parsed.module == TopCommand
    end
  end
end
