defmodule Kantele.Character.OverrideTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.PlayerMeta

  test "set/query override" do
    meta = PlayerMeta.set_override(%PlayerMeta{}, "unconcious", :zhang_sanfeng)
    assert PlayerMeta.query_override(meta, "unconcious") == :zhang_sanfeng
  end

  test "run_override 取走并删除钩子，返回 {marker, meta}" do
    meta = PlayerMeta.set_override(%PlayerMeta{}, "die", :npc)
    {marker, meta} = PlayerMeta.run_override(meta, "die")
    assert marker == :npc
    assert PlayerMeta.query_override(meta, "die") == nil
  end

  test "run_override 无钩子返回 {false, meta}" do
    {found, meta} = PlayerMeta.run_override(%PlayerMeta{}, "die")
    assert found == false
    assert meta.override == %{}
  end

  test "set 同名覆盖" do
    meta =
      %PlayerMeta{}
      |> PlayerMeta.set_override("win", :a)
      |> PlayerMeta.set_override("win", :b)

    assert PlayerMeta.query_override(meta, "win") == :b
  end

  test "delete_override 移除" do
    meta =
      %PlayerMeta{}
      |> PlayerMeta.set_override("lost", :a)
      |> PlayerMeta.delete_override("lost")

    assert PlayerMeta.query_override(meta, "lost") == nil
  end

  test "override 不进房间视图 (Trim 只保留 vitals)" do
    meta = PlayerMeta.set_override(%PlayerMeta{}, "unconcious", :npc)
    assert Map.take(Kalevala.Meta.Trim.trim(meta), [:vitals]) == %{vitals: nil}
  end
end
