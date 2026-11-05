defmodule Kantele.Character.TalkCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.TalkCommand
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
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      combat_exp: 0,
      score: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: Kantele.Character.Combat.new()}
    }
  end

  # 命令按 pid 排除自己， fixture 必须用与 self() 不同的 pid。
  defp other_pid, do: spawn(fn -> :ok end)

  defp npc(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "npc-libai"),
      name: Keyword.get(opts, :name, "李白"),
      pid: Keyword.get(opts, :pid, other_pid()),
      room_id: "test:room",
      attributes: %{},
      meta: %NonPlayerMeta{
        aliases: Keyword.get(opts, :aliases, []),
        inquiries: Keyword.get(opts, :inquiries, %{})
      }
    }
  end

  defp room(characters), do: %{private: %{characters: characters}}

  defp build(p, private \\ %{}) do
    conn = build_conn(p)

    private =
      Enum.reduce(private, conn.private, fn {key, value}, acc -> Map.put(acc, key, value) end)

    %{conn | private: private}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "parse/1（LPC sscanf 两种形式 + 默认话题）" do
    test "只有名字时话题为你好" do
      assert {:ok, "李白", "你好"} = TalkCommand.parse("李白")
    end

    test "名字 + 内容" do
      assert {:ok, "李白", "你会作诗吗？"} = TalkCommand.parse("李白 你会作诗吗？")
    end

    test "about 形式" do
      assert {:ok, "李白", "如何拜师？"} = TalkCommand.parse("李白 about 如何拜师？")
    end

    test "about 形式允许带空格的话题" do
      assert {:ok, "libai", "今日 天气 如何"} =
               TalkCommand.parse("libai about 今日 天气 如何")
    end

    test "空参数 / 非字符串" do
      assert {:error, :empty} = TalkCommand.parse("")
      assert {:error, :empty} = TalkCommand.parse("   ")
      assert {:error, :empty} = TalkCommand.parse(nil)
    end
  end

  describe "talk 命令" do
    test "无参数时显示指令格式" do
      conn = TalkCommand.run(build(player()), %{})
      assert output_text(conn) =~ "指令格式"
    end

    test "空 rest 也显示指令格式" do
      conn = TalkCommand.run(build(player()), %{"rest" => "   "})
      assert output_text(conn) =~ "指令格式"
    end

    test "房间里没有这个人 → LPC 原文" do
      conn = build(player(), %{room: room([])})
      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 你好"}))
      assert text =~ "这里没有李白。"
    end

    test "NPC 没有对话资源 → accept_talk 返回 0 的原文" do
      conn = build(player(), %{room: room([npc()])})
      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 你好"}))
      assert text =~ "李白似乎不想和你聊天。"
    end

    test "命中 inquiries 关键词 → 你对X说 + X说道" do
      target = npc(inquiries: %{"作诗" => "举杯邀明月，对影成三人。"})
      conn = build(player(), %{room: room([target])})

      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 你会作诗吗？"}))
      assert text =~ "你对李白说：你会作诗吗？"
      assert text =~ "李白说道：举杯邀明月，对影成三人。"
    end

    test "about 形式同样能命中问答" do
      target = npc(inquiries: %{"拜师" => "拜师需先过三关。"})
      conn = build(player(), %{room: room([target])})

      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 about 如何拜师？"}))
      assert text =~ "你对李白说：如何拜师？"
      assert text =~ "李白说道：拜师需先过三关。"
    end

    test "别名 / 前缀也能找到 NPC" do
      target = npc(aliases: ["libai"], inquiries: %{"你好" => "公子安好。"})
      conn = build(player(), %{room: room([target])})

      assert output_text(TalkCommand.run(conn, %{"rest" => "libai"})) =~
               "李白说道：公子安好。"
    end

    test "话题未命中问答表 → 不泄露内部形态的兜底" do
      target = npc(inquiries: %{"作诗" => "举杯邀明月。"})
      conn = build(player(), %{room: room([target])})

      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 今天天气"}))
      assert text =~ "你对李白说：今天天气"
      assert text =~ "李白似乎没有听明白你的意思。"
    end

    test "LPC 闭包占位回答不外泄" do
      target = npc(inquiries: %{"作诗" => "(: ask_poem :)"})
      conn = build(player(), %{room: room([target])})

      text = output_text(TalkCommand.run(conn, %{"rest" => "李白 作诗"}))
      refute text =~ "ask_poem"
      assert text =~ "似乎没有听明白"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("talk NPC")
      assert parsed.module == TalkCommand
    end
  end
end
