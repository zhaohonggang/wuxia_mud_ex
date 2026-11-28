defmodule Kantele.World.InquiryHandlers.EmeiTonsureTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.EmeiTonsure

  @config %{
    "kind" => "emei_tonsure",
    "npc_say" => "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，请跪下(kneel)受戒。"
  }
  @data %{npc_room_id: "emei:qfadadian", npc_name: "静慧师太"}
  @family_deny "施主与我峨嵋派尚无渊源，贫尼不敢给你剃度。"
  @bonze_deny "阿弥陀佛！出家人不打诳语。你已经不是俗家人了。"
  @gender_deny "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，可去少林寺受戒。"
  @success "记住，既然出了家，就一心向佛，不能还俗。"

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{shen: 0}),
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100, max_qi: 100}),
      env: Keyword.get(opts, :env, %{gender: "女性"}),
      family: Keyword.get(opts, :family, %{name: "峨嵋派"}),
      temp: Keyword.get(opts, :temp, %{})
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id, "player:test"),
        name: Keyword.get(opts, :name, "张三"),
        room_id: Keyword.get(opts, :room_id, "emei:qfadadian"),
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

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  test "kind 已注册（InquiryHandlers.lookup）" do
    assert InquiryHandlers.lookup("emei_tonsure") == EmeiTonsure
  end

  test "无门派 → 原文拒绝，且不置 pending / 不广播 NPC 台词" do
    conn2 = EmeiTonsure.run(conn(family: %{}), @config, @data)

    assert out_text(conn2) =~ @family_deny
    refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
    assert vision_texts(conn2) == []
  end

  test "他派 → 原文拒绝，门派门先于 class/性别门" do
    conn2 =
      EmeiTonsure.run(
        conn(family: %{name: "少林派", class: "bonze"}, env: %{gender: "男性"}),
        @config,
        @data
      )

    assert out_text(conn2) =~ @family_deny
    refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
  end

  test "同门已出家 → 原文拒绝，class 门先于性别门" do
    conn2 =
      EmeiTonsure.run(
        conn(family: %{name: "峨嵋派", class: "bonze"}, env: %{gender: "男性"}),
        @config,
        @data
      )

    assert out_text(conn2) =~ @bonze_deny
    refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
  end

  test "同门男性 → 原文拒绝，转去少林寺受戒" do
    conn2 = EmeiTonsure.run(conn(env: %{gender: "男性"}), @config, @data)

    assert out_text(conn2) =~ @gender_deny
    refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
  end

  test "同门女性 → 置 pending，NPC 说跪拜提示，私发返回值原文" do
    conn2 = EmeiTonsure.run(conn(), @config, @data)

    assert PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze) == true
    assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "静慧师太说道：#{@config["npc_say"]}"))
    assert out_text(conn2) =~ @success
  end

  test "未配置 npc_say → 不广播，但仍置 pending 并私发返回值" do
    conn2 = EmeiTonsure.run(conn(), %{"kind" => "emei_tonsure"}, @data)

    assert vision_texts(conn2) == []
    assert PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze) == true
    assert out_text(conn2) =~ @success
  end

  test "非 map data → 返回 conn 不变" do
    assert conn() == EmeiTonsure.run(conn(), @config, "not a map")
  end
end
