defmodule Kantele.World.InquiryHandlers.CitySmithBackTest do
  @moduledoc """
  中原铁匠「血海无边」问询定向测试（LPC `d/city/npc/smith.c` `ask_back()`）。

  覆盖：
    - 非血刀门 → message_vision 拒绝「自顾自的干活」，不传送
    - 血刀门 → message_sort 长文案（提问者「你」版 / 旁观者姓名版，含 `$p`）
      + 传送 city:xdmidao4 + 两段 tell_object 文案，顺序与 LPC 一致
    - target_room 配置覆盖
    - 非提问者本人 → 空操作
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.CitySmithBack

  defp base_config do
    %{
      "kind" => "city_smith_back",
      "family" => "血刀门",
      "target_room" => "city:xdmidao4"
    }
  end

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "血刀门"})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 80, max_qi: 100},
      stats: %Stats{combat_exp: 100_000, skills: %{}},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: Keyword.get(opts, :room_id, "city:datiepu"),
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
      npc_id: "city_smith",
      npc_name: "铁匠",
      npc_room_id: "city:datiepu"
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
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  defp room_id(conn), do: (conn.private.update_character || conn.character).room_id

  describe "门控：非血刀门" do
    test "family != 血刀门 → 广播拒绝文案且不传送" do
      result = CitySmithBack.run(conn(family: %{name: "少林派"}), base_config(), data())

      # message_vision：提问者私有版「你」，旁观者广播版真实姓名
      assert output_text(result) =~ "铁匠自顾自的干活，好象没有听见你在说什么。"
      assert channel_texts(result) =~ "铁匠自顾自的干活，好象没有听见测试玩家在说什么。"
      refute output_text(result) =~ "快跟我来"
      assert room_id(result) == "city:datiepu"
    end
  end

  describe "成功：血刀门弟子" do
    test "message_sort 提问者版 + 旁观者版（$p 分别渲染为你/玩家名）" do
      result = CitySmithBack.run(conn(), base_config(), data())

      # message_sort 给提问者的私有 vision：$N=铁匠，$n/$p=你
      assert output_text(result) =~ "铁匠猛地抬起头来，瞪着双目上上下下打量了你"
      assert output_text(result) =~ "领着你朝后厅走去"

      # 旁观者版：$n/$p = 玩家真实姓名
      assert channel_texts(result) =~ "打量了测试玩家好一会儿"
      assert channel_texts(result) =~ "领着测试玩家朝后厅走去"
    end

    test "传送到 city:xdmidao4 并依次私发两段 tell_object 文案" do
      result = CitySmithBack.run(conn(), base_config(), data())

      assert room_id(result) == "city:xdmidao4"

      text = output_text(result)
      assert text =~ "铁匠说道：就是这里，你一直走南就行了。\n"
      assert text =~ "铁匠说完便急急忙忙赶了回去。\n"
      assert :binary.match(text, "就是这里") < :binary.match(text, "急急忙忙赶了回去")
    end

    test "target_room 可由 UCL 配置覆盖" do
      config = Map.put(base_config(), "target_room", "city:xdmidao3")
      result = CitySmithBack.run(conn(), config, data())

      assert room_id(result) == "city:xdmidao3"
    end
  end

  describe "防御" do
    test "asker_id 不是 conn.character.id → 空操作" do
      conn0 = conn()
      result = CitySmithBack.run(conn0, base_config(), data(asker_id: "player:other"))

      assert result == conn0
      assert room_id(result) == "city:datiepu"
    end
  end

  describe "UCL 接线（中原与苏州两份铁匠模板）" do
    for path <- ["data/world/clone_lib.ucl", "data/world/city.ucl"] do
      test "#{path}：三条 inquiry 与 init.add_actions 均已回填" do
        ucl = File.read!(unquote(path))

        assert ucl =~ ~s(kind = "smith_job")
        assert ucl =~ ~s(kind = "city_smith_back")
        assert ucl =~ ~s(target_room = "city:xdmidao4")
        assert ucl =~ ~s(add_actions = ["gu", "dapi", "cuihuo", "repair", "xiuli"])
        refute ucl =~ "血海无边\" value = \" inquire about back (unimplemented)"
      end
    end
  end
end
