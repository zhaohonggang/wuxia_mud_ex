defmodule Kantele.World.InquiryHandlers.XuedaoMidaoTest do
  @moduledoc """
  血刀派 #792：血刀老祖 ask_midao（密道/秘道）定向测试。
  LPC 依据：`kungfu/class/xuedao/laozu.c:681-695`。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Loader}

  setup_all do
    %{world: Loader.load()}
  end

  defp conn(overrides \\ []) do
    family = Keyword.get(overrides, :family, %{name: "血刀门"})

    meta = %PlayerMeta{
      stats: %Stats{},
      vitals: %Vitals{qi: 100, max_qi: 100},
      env: %{},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xuedao:laozu",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp out_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} when is_binary(data) -> data
      %Conn.EventText{text: %Conn.Text{data: iodata}} -> IO.iodata_to_binary(iodata)
      _ -> ""
    end)
    |> Enum.join()
  end

  describe "UCL 数据落地" do
    test "密道/秘道两键均指向 xuedao_midao", %{world: world} do
      laozu = Enum.find(world.characters, &(&1.name == "血刀老祖"))

      for key <- ["密道", "秘道"] do
        inquiry = laozu.meta.inquiries[key]
        assert inquiry["kind"] == "xuedao_midao"
      end
    end

    test "xuedao_midao kind 已注册" do
      assert InquiryHandlers.lookup("xuedao_midao") ==
               Kantele.World.InquiryHandlers.XuedaoMidao
    end
  end

  describe "run/3 门控与文案" do
    test "非血刀门弟子 → 你他奶奶的，嘀嘀咕咕到底要说什么？，不吐露密道" do
      conn2 =
        Kantele.World.InquiryHandlers.XuedaoMidao.run(conn(family: %{}), %{}, %{})

      assert out_text(conn2) =~ "你他奶奶的，嘀嘀咕咕到底要说什么？"
      refute out_text(conn2) =~ "enter mash"
      refute out_text(conn2) =~ "血海无边"
      refute out_text(conn2) =~ "中原扬州"
    end

    test "血刀门弟子 → 密语原文 + 返回文案" do
      conn2 = Kantele.World.InquiryHandlers.XuedaoMidao.run(conn(), %{}, %{})

      text = out_text(conn2)

      # LPC command("whisper ...") 密语逐字：入我门来、血刀先辈、enter mash、中原扬州、铁匠、血海无边。
      assert text =~ "你既然已经入我门来"
      assert text =~ "血刀先辈们留下的密道"
      assert text =~ "enter mash"
      assert text =~ "中原扬州"
      assert text =~ "伏在中原的铁匠"
      assert text =~ "血海无边"
      # LPC return 文案。
      assert text =~ "此秘密不可泄露于他人，否则天诛地灭！"
    end

    test "密语私密：不广播房间频道" do
      conn2 = Kantele.World.InquiryHandlers.XuedaoMidao.run(conn(), %{}, %{})
      assert conn2.private.channel_changes == []
    end

    test "非 map data → 返回 conn 不变" do
      c = conn()
      assert c == Kantele.World.InquiryHandlers.XuedaoMidao.run(c, %{}, "not a map")
    end
  end
end
