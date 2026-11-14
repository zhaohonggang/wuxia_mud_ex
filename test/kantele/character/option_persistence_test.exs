defmodule Kantele.Character.OptionPersistenceTest do
  @moduledoc """
  `option` 的按角色隔离 + 落盘往返验证（cmds/usr/option.c 对应字段）。

  证明 `OptionCommand` 写入的 `meta.option` 经 `Records.save` → `Records.load`
  → `Records.apply_to_character` 后仍按角色独立保留，且字符串键在 jsonb
  往返中不丢失。
  """
  use ExVenture.DataCase, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.OptionCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(name, opts \\ %{}) do
    meta =
      %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new(),
        # Records.save 的 gender 列 NOT NULL，实登由 apply_to_character 写回 env
        env: %{gender: "男性"}
      }
      |> Map.put(:option, Map.get(opts, :option, %{}))

    %Kalevala.Character{
      id: "player-#{name}",
      name: name,
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: meta
    }
  end

  defp restore(name, character) do
    {:ok, metadata, wiz} = Records.load(name)
    {Records.apply_to_character(character, {:ok, metadata}, wiz), metadata}
  end

  test "option 按角色隔离：两个玩家各设各的，重登互不干扰" do
    a = "opt-a-#{System.unique_integer([:positive])}"
    b = "opt-b-#{System.unique_integer([:positive])}"

    a_conn = OptionCommand.run(build_conn(player(a)), %{"rest" => "map_hidden 1"})
    b_conn = OptionCommand.run(build_conn(player(b)), %{"rest" => "brief_room 1"})

    a_char = a_conn.private.update_character
    b_char = b_conn.private.update_character

    assert :ok = Records.save(a_char)
    assert :ok = Records.save(b_char)

    {a_restored, a_meta} = restore(a, player(a))
    {b_restored, b_meta} = restore(b, player(b))

    assert a_restored.meta.option == %{"map_hidden" => 1}
    assert b_restored.meta.option == %{"brief_room" => 1}
    refute Map.has_key?(a_restored.meta.option, "brief_room")
    refute Map.has_key?(b_restored.meta.option, "map_hidden")

    assert a_meta.option == %{"map_hidden" => 1}
    assert b_meta.option == %{"brief_room" => 1}
  end

  test "事件侧可见：Meta.trim 保留 :option（房间进程能读到开关）" do
    character = player("opt-trim-#{System.unique_integer([:positive])}")
    character = %{character | meta: %{character.meta | option: %{"map_hidden" => 1}}}

    # 实链路：Conn.Private.character/1 会把 meta 交给 Kalevala.Meta.trim
    conn = %{character: character, private: %{update_character: nil}}
    trimmed = Kalevala.Character.Conn.Private.character(conn)

    assert trimmed.meta.option == %{"map_hidden" => 1}
  end

  test "help option 主题可加载，含 map_hidden 用法与中文关键词" do
    topic = Kantele.World.Loader.load_help() |> Enum.find(&(&1.key == "option"))

    assert topic != nil
    assert "选项" in topic.keywords
    assert topic.content =~ "map_hidden"
    assert topic.content =~ "option map_hidden 1"
  end

  test "option 多键 / 字符串值 / 删除后落盘" do
    name = "opt-multi-#{System.unique_integer([:positive])}"

    conn =
      [%{"rest" => "map_hidden 1"}, %{"rest" => "brief_short yes"}]
      |> Enum.reduce(build_conn(player(name)), fn params, conn ->
        updated = conn.private.update_character || conn.character
        conn = %{conn | character: updated, private: %{conn.private | update_character: nil}}
        OptionCommand.run(conn, params)
      end)

    saved = conn.private.update_character || conn.character
    assert :ok = Records.save(saved)
    {restored, _meta} = restore(name, player(name))
    assert restored.meta.option == %{"map_hidden" => 1, "brief_short" => "yes"}

    deleted_conn = OptionCommand.run(build_conn(restored), %{"rest" => "map_hidden"})
    deleted = deleted_conn.private.update_character || deleted_conn.character
    assert :ok = Records.save(deleted)
    {restored2, _meta2} = restore(name, player(name))
    assert restored2.meta.option == %{"brief_short" => "yes"}
  end
end
