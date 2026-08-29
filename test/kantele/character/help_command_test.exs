defmodule Kantele.Character.HelpCommandTest do
  # Help 缓存为全局共享进程，播种需串行
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Help
  alias Kalevala.Help.HelpTopic
  alias Kantele.Character.HelpCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  setup do
    Help.put(%HelpTopic{
      key: "say",
      title: "说话",
      tagline: "房间内交流",
      keywords: ["说", "聊天"],
      content: "say <内容> 与同一房间其他角色交流。"
    })

    Help.put(%HelpTopic{
      key: "bank",
      title: "钱庄",
      keywords: ["银行", "存钱"],
      content: "bank 存/取钱。"
    })

    :ok
  end

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
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

  test "index 列出全部主题（key + 标题）" do
    output = HelpCommand.index(build_conn(player()), %{}) |> output_text()

    assert output =~ "可用帮助主题"
    assert output =~ "say"
    assert output =~ "说话"
    assert output =~ "bank"
    assert output =~ "钱庄"
  end

  test "show 按 key 精确查找" do
    output =
      build_conn(player())
      |> HelpCommand.show(%{"topic" => "say"})
      |> output_text()

    assert output =~ "说话"
    assert output =~ "say <内容>"
  end

  test "show 按 keyword（中文别名）查找" do
    output =
      build_conn(player())
      |> HelpCommand.show(%{"topic" => "说"})
      |> output_text()

    assert output =~ "说话"
    assert output =~ "say <内容>"
  end

  test "unknown 主题提示" do
    output =
      build_conn(player())
      |> HelpCommand.show(%{"topic" => "不存在"})
      |> output_text()

    assert output =~ "Unknown topic"
    assert output =~ "不存在"
  end

  test "help/帮助 路由解析" do
    {:ok, p} = Kantele.Character.Commands.parse("help")
    assert p.module == HelpCommand
    assert p.function == :index

    {:ok, p} = Kantele.Character.Commands.parse("帮助")
    assert p.module == HelpCommand
    assert p.function == :index

    {:ok, p} = Kantele.Character.Commands.parse("help say")
    assert p.module == HelpCommand
    assert p.function == :show

    {:ok, p} = Kantele.Character.Commands.parse("帮助 说")
    assert p.module == HelpCommand
    assert p.function == :show
  end
end
