defmodule Kantele.World.InquiryHandlers.XueshanMidaoTest do
  @moduledoc """
  大轮寺 #796：金轮法王 ask_midao（密道/秘道）定向测试。
  LPC 依据：`kungfu/class/xueshan/fawang.c:757-772`。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Loader}

  setup_all do
    %{world: Loader.load()}
  end

  defp conn(overrides \\ []) do
    family = Keyword.get(overrides, :family, %{name: "大轮寺"})

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
        room_id: "xueshan:dadian",
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
    test "密道/秘道两键均指向 xueshan_midao", %{world: world} do
      fawang = Enum.find(world.characters, &(&1.name == "金轮法王"))

      for key <- ["密道", "秘道"] do
        inquiry = fawang.meta.inquiries[key]
        assert inquiry["kind"] == "xueshan_midao"
      end
    end

    test "xueshan_midao kind 已注册" do
      assert InquiryHandlers.lookup("xueshan_midao") ==
               Kantele.World.InquiryHandlers.XueshanMidao
    end
  end

  describe "run/3 门控与文案" do
    test "非大轮寺弟子 → 你找死么？，不吐露密道" do
      conn2 = Kantele.World.InquiryHandlers.XueshanMidao.run(conn(family: %{}), %{}, %{})

      assert out_text(conn2) =~ "你找死么？"
      refute out_text(conn2) =~ "turn lunpan"
      refute out_text(conn2) =~ "金轮九转"
    end

    test "大轮寺弟子 → 密语原文 + 返回文案" do
      conn2 = Kantele.World.InquiryHandlers.XueshanMidao.run(conn(), %{}, %{})

      text = out_text(conn2)

      # LPC command("whisper ...") 密语逐字：禅室 turn lunpan、密道去扬州、唐楠/金轮九转。
      assert text =~ "你既然投入我大轮寺"
      assert text =~ "直接去禅"
      assert text =~ "turn lunpan"
      assert text =~ "中原扬州"
      assert text =~ "唐楠"
      assert text =~ "金轮九转"
      # LPC return 文案。
      assert text =~ "此秘密不可泄露于他人，否则我饶不了你！"
    end

    test "密语私密：不广播房间频道" do
      conn2 = Kantele.World.InquiryHandlers.XueshanMidao.run(conn(), %{}, %{})
      assert conn2.private.channel_changes == []
    end

    test "非 map data → 返回 conn 不变" do
      c = conn()
      assert c == Kantele.World.InquiryHandlers.XueshanMidao.run(c, %{}, "not a map")
    end
  end
end
