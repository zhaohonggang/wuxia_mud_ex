defmodule Kantele.Character.OptionCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.OptionCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ %{}) do
    meta =
      %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
      |> Map.put(:option, Map.get(opts, :option, %{}))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: meta
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "option 列表" do
    test "空选项提示" do
      conn = OptionCommand.run(build_conn(player()), %{"rest" => ""})
      assert output_text(conn) =~ "選"
    end

    test "列出已有选项" do
      conn =
        OptionCommand.run(build_conn(player(%{option: %{"verbose" => "on"}})), %{"rest" => ""})

      assert output_text(conn) =~ "verbose"
      assert output_text(conn) =~ "on"
    end
  end

  describe "option 设置与删除" do
    test "设置选项" do
      conn = OptionCommand.run(build_conn(player()), %{"rest" => "verbose on"})
      updated = conn.private.update_character || conn.character
      assert updated.meta.option["verbose"] == "on"
      assert output_text(conn) =~ "Ok"
    end

    test "单值即删除键" do
      conn =
        OptionCommand.run(build_conn(player(%{option: %{"verbose" => "on"}})), %{
          "rest" => "verbose"
        })

      updated = conn.private.update_character || conn.character
      refute Map.has_key?(updated.meta.option, "verbose")
      assert output_text(conn) =~ "Ok"
    end

    test "设定值 0 视为删除" do
      conn =
        OptionCommand.run(build_conn(player(%{option: %{"verbose" => "on"}})), %{
          "rest" => "verbose 0"
        })

      updated = conn.private.update_character || conn.character
      refute Map.has_key?(updated.meta.option, "verbose")
    end
  end

  describe "map_hidden 开关（LPC option/map_hidden）" do
    test "设 1 隐藏，设 0 恢复（删键）" do
      conn = OptionCommand.run(build_conn(player()), %{"rest" => "map_hidden 1"})
      hidden = conn.private.update_character
      assert hidden.meta.option["map_hidden"] == 1

      conn2 = OptionCommand.run(build_conn(hidden), %{"rest" => "map_hidden 0"})
      shown = conn2.private.update_character
      refute Map.has_key?(shown.meta.option, "map_hidden")
    end
  end

  test "option 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("option verbose on")
    assert parsed.module == Kantele.Character.OptionCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("选项 verbose on")
    assert parsed.module == Kantele.Character.OptionCommand
  end
end
