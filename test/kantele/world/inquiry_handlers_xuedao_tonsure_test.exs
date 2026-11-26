defmodule Kantele.World.InquiryHandlers.XuedaoTonsureTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.XuedaoTonsure

  @tonsure_config %{kind: "xuedao_tonsure", config: %{}}

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
        room_id: Keyword.get(opts, :room_id, "xuedao:wangyougu"),
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
      %Conn.Text{data: data} when is_binary(data) ->
        data
      %Conn.EventText{text: %Conn.Text{data: iodata}} ->
        IO.iodata_to_binary(iodata)
      _ ->
        ""
    end)
    |> Enum.join()
  end

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert InquiryHandlers.lookup("xuedao_tonsure") == XuedaoTonsure
    end

    test "已是出家人（class=bonze）→ 阿弥陀佛！你我同是出家人…，不置 pending" do
      conn2 =
        XuedaoTonsure.run(
          conn(family: %{class: "bonze"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "阿弥陀佛！你我同是出家人，何故跟贫僧开这等玩笑？"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "女性 → 施主若真心向佛…可惜本寺不收女徒，不置 pending" do
      conn2 =
        XuedaoTonsure.run(
          conn(env: %{gender: "女性"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "施主若真心向佛，真是可喜可贺，可惜本寺不收女徒。"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "无性 → 公公别开玩笑了，还是赶快回宫去伺候皇上吧，不置 pending" do
      conn2 =
        XuedaoTonsure.run(
          conn(env: %{gender: "无性"}),
          @tonsure_config.config,
          @tonsure_config
        )

      assert out_text(conn2) =~ "公公别开玩笑了，还是赶快回宫去伺候皇上吧。"
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    end

    test "男性非出家人 → 置 pending_join_bonze，提示 kneel 受戒" do
      conn2 = XuedaoTonsure.run(conn(), @tonsure_config.config, @tonsure_config)

      assert out_text(conn2) =~ "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，请跪下(kneel)受戒。"
      assert PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze) == true
    end
  end

  test "非 map data → 返回 conn 不变" do
    assert conn() == XuedaoTonsure.run(conn(), %{}, "not a map")
  end
end
