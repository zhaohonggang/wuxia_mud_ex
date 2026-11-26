defmodule Kantele.World.InquiryHandlers.XueshanTonsureTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.XueshanTonsure

  @tonsure_config %{kind: "xueshan_tonsure", config: %{}}

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{shen: 0}),
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100, max_qi: 100}),
      env: Keyword.get(opts, :env, %{gender: "男性"}),
      family: Keyword.get(opts, :family, %{}),
      temp: Keyword.get(opts, :temp, %{})
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id, "player:test"),
        name: Keyword.get(opts, :name, "张三"),
        room_id: Keyword.get(opts, :room_id, "xueshan:shanmen"),
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character(conn), do: conn.private.update_character || conn.character

  defp out_text(conn) do
    conn.output
    |> Enum.map(fn
      %Kalevala.Character.Conn.Text{data: data} when is_binary(data) ->
        data
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: iodata}} ->
        IO.iodata_to_binary(iodata)
      _ ->
        ""
    end)
    |> Enum.join()
  end

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert InquiryHandlers.lookup("xueshan_tonsure") == XueshanTonsure
    end

    test "已是出家人（class=bonze）→ 拒绝，不置 pending" do
      conn2 =
        XueshanTonsure.run(
          conn(family: %{class: "bonze"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "你已经是出家人了，还跟我罗嗦些什么？"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "非男性（女性）→ 拒绝，不置 pending" do
      conn2 =
        XueshanTonsure.run(
          conn(env: %{gender: "女性"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "我们大轮寺历来只收男徒，你还是走吧。"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "非男性（无性）→ 拒绝，不置 pending" do
      conn2 =
        XueshanTonsure.run(
          conn(env: %{gender: "无性"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "我们大轮寺历来只收男徒，你还是走吧。"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "男性非出家人 → 置 pending_join_bonze，提示 kneel 受戒" do
      conn2 = XueshanTonsure.run(conn(), @tonsure_config.config, @tonsure_config)

      assert out_text(conn2) =~ "甚好，甚好！你若真心皈依我佛，请跪下(kneel)受戒。"
      assert PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze) == true
    end
  end

  test "非 map data → 返回 conn 不变" do
    assert conn() == XueshanTonsure.run(conn(), %{}, "not a map")
  end
end
