defmodule Kantele.Character.EngageCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.EngageCommand
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

    spouse = Keyword.get(opts, :spouse, nil)

    combat = Kantele.Character.Combat.new()
    combat = if Keyword.get(opts, :fighting, false) do
      %{combat | enemies: ["some-enemy"]}
    else
      combat
    end

    temp = Keyword.get(opts, :temp, %{})

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        spouse: spouse,
        temp: temp
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

  describe "engage 命令" do
    test "无参数时提示格式" do
      conn = EngageCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "指令格式"
    end

    test "无参数时提示格式 (空arg)" do
      conn = EngageCommand.run(build_conn(player()), %{"arg" => ""})
      assert output_text(conn) =~ "你要向谁求婚？"
    end

    test "格式错误只有名字无承诺" do
      conn = EngageCommand.run(build_conn(player()), %{"arg" => "李四"})
      assert output_text(conn) =~ "指令格式"
    end

    test "忙碌时拒绝求婚" do
      p = player(temp: %{"busy" => true})
      conn = EngageCommand.run(build_conn(p), %{"arg" => "李四 真心"})
      assert output_text(conn) =~ "好好忙你手头的事情"
    end

    test "战斗中拒绝求婚" do
      p = player(fighting: true)
      conn = EngageCommand.run(build_conn(p), %{"arg" => "李四 真心"})
      assert output_text(conn) =~ "好好忙你手头的事情"
    end

    test "已婚者拒绝求婚" do
      p = player(spouse: %{name: "李氏", id: "player-spouse"})
      conn = EngageCommand.run(build_conn(p), %{"arg" => "李四 真心"})
      assert output_text(conn) =~ "重婚者打入地狱"
    end

    test "已有求婚进行中拒绝新求婚" do
      p = player(temp: %{"pending/engage" => "李四", "pending/engage_target_id" => "player-2"})
      conn = EngageCommand.run(build_conn(p), %{"arg" => "王五 真心"})
      assert output_text(conn) =~ "你正在向人家求婚呢"
    end

    test "取消求婚成功" do
      p = player(temp: %{"pending/engage" => "李四", "pending/engage_target_id" => "player-2", "pending/engage_promise" => "真心"})
      conn = EngageCommand.run(build_conn(p), %{"arg" => "cancel"})
      assert output_text(conn) =~ "打消了求婚的念头"
    end

    test "取消求婚时没有进行中的求婚" do
      p = player()
      conn = EngageCommand.run(build_conn(p), %{"arg" => "cancel"})
      assert output_text(conn) =~ "你现在没有向任何人求婚"
    end

    test "正常求婚请求发送事件" do
      p = player()
      conn = EngageCommand.run(build_conn(p), %{"arg" => "李四 真心"})
      events = Enum.filter(conn.events, fn e -> e.topic == "engage/request" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.target_name == "李四"
      assert event.data.promise == "真心"
    end
  end
end
