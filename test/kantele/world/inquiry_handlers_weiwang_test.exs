defmodule Kantele.World.InquiryHandlers.WeiwangTest do
  @moduledoc """
  北京 NPC `ask_weiwang()`（威望/江湖威望）定向测试。

  覆盖：
    - 私有 tell 读取 `meta.stats.weiwang`
    - 两次 `say()` 广播的逐字文案（多数派变体 + 徐天川变体）
    - `asker_id` 防御
    - `beijing.ucl` 8 名 NPC / 16 个关键词全部由占位符切到 `kind = "weiwang"`
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.Weiwang
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp conn(weiwang \\ 42) do
    meta = %PlayerMeta{
      vitals: %Kantele.Character.Vitals{qi: 80, max_qi: 100},
      stats: %Stats{combat_exp: 100_000, skills: %{}, weiwang: weiwang},
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "beijing:tiandihui",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: Keyword.get(opts, :asker_id, "player:test"),
      asker_name: "测试玩家",
      npc_id: Keyword.get(opts, :npc_id, "beijing_fangang"),
      npc_name: Keyword.get(opts, :npc_name, "樊纲"),
      npc_room_id: Keyword.get(opts, :npc_room_id, "beijing:tiandihui")
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> IO.iodata_to_binary(data)
      %Conn.EventText{text: %Conn.Text{data: data}} -> IO.iodata_to_binary(data)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp channel_texts(conn) do
    # Conn.publish_message 把新事件 cons 到表头；Foreman 真正下发时再 reverse，
    # 这里同样反转，断言顺序才与玩家看到的 LPC 两次 say() 顺序一致。
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  test "kind 已注册到共享分发器" do
    assert InquiryHandlers.lookup("weiwang") == Weiwang
  end

  test "私有 tell 输出当前江湖威望" do
    result = Weiwang.run(conn(37), %{}, data())

    assert output_text(result) =~ "你现在的江湖威望是 37\n"
  end

  test "多数派：两次 say 广播逐字对齐樊纲 LPC" do
    result = Weiwang.run(conn(), %{}, data())

    assert length(result.private.channel_changes) == 2

    assert channel_texts(result) ==
             "\n樊纲说：如果你威望值很高，有些人见了你不但不会杀你，还会教你武功，送你宝贝。\n" <>
               "而且你还可以加入帮会，率领会众去攻打目标，就连去钱庄取钱也会有利息 。。。。。\n" <>
               "樊纲又说：杀某些坏人或救某些好人可以提高江湖威望。\n"
  end

  test "徐天川变体：interest_suffix 覆写为句号且无省略点" do
    config = %{"kind" => "weiwang", "interest_suffix" => "。"}

    result =
      Weiwang.run(conn(), config, data(npc_id: "beijing_xutianchuan", npc_name: "徐天川"))

    assert channel_texts(result) ==
             "\n徐天川说：如果你威望值很高，有些人见了你不但不会杀你，还会教你武功，送你宝贝。\n" <>
               "而且你还可以加入帮会，率领会众去攻打目标，就连去钱庄取钱也会有利息。\n" <>
               "徐天川又说：杀某些坏人或救某些好人可以提高江湖威望。\n"
  end

  test "asker_id 不是当前玩家 → 空操作" do
    conn0 = conn()
    result = Weiwang.run(conn0, %{}, data(asker_id: "player:other"))

    assert result == conn0
    assert output_text(result) == ""
    assert result.private.channel_changes == []
  end

  test "beijing.ucl：8 NPC 的 16 个威望问询全部回填，徐天川保留句号变体" do
    ucl = File.read!("data/world/beijing.ucl")

    assert length(Regex.scan(~r/kind = "weiwang"/, ucl)) == 16
    refute ucl =~ "inquire about weiwang (unimplemented)"
    assert ucl =~ ~s(interest_suffix = "。")

    for npc <- [
          "fangang",
          "fengjizhong",
          "guananji",
          "jialaoliu",
          "qianlaoben",
          "qibiaoqing",
          "xutianchuan",
          "zhuangyu"
        ] do
      assert ucl =~ "characters \"#{npc}\" {"
    end
  end

  test "Loader 加载后 8 NPC 的威望问询都解析为 weiwang 配置", %{world: world} do
    for {name, suffix} <- [
          {"樊纲", nil},
          {"风际中", nil},
          {"关安基", nil},
          {"贾老六", nil},
          {"钱老本", nil},
          {"祁彪清", nil},
          {"徐天川", "。"},
          {"庄允城", nil}
        ] do
      npc = Enum.find(world.characters, &(&1.name == name)) || raise("#{name} not loaded")

      for key <- ["威望", "江湖威望"] do
        config = npc.meta.inquiries[key] || raise("#{name}/#{key} inquiry not found")
        assert config["kind"] == "weiwang"
        assert Map.get(config, "interest_suffix") == suffix
      end
    end
  end
end
