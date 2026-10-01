defmodule CustomDirectionCommandTest do
  use ExUnit.Case, async: false

  alias Kalevala.Character.Command.ParsedCommand
  alias Kantele.Character.Commands
  alias Kantele.Character.LiuxiCommand
  alias Kantele.Character.MoveCommand

  # 方向名 -> 持有它的命令。liuxi 归 LiuxiCommand（另认 `柳溪` 别名，出自 LPC
  # cmds/std/liuxi.c），其余都是 MoveCommand 上的同名子句。
  @custom %{
    "leitai" => {MoveCommand, :leitai},
    "river" => {MoveCommand, :river},
    "dule" => {MoveCommand, :dule},
    "caihong" => {MoveCommand, :caihong},
    "panlong" => {MoveCommand, :panlong},
    "yangzhou" => {MoveCommand, :yangzhou},
    "liuxi" => {LiuxiCommand, :run}
  }

  describe "custom LPC direction names are routable" do
    for {dir, {mod, fun}} <- @custom do
      test "#{dir} parses to a movement request" do
        assert {:ok, %ParsedCommand{module: unquote(mod), function: unquote(fun)}} =
                 Commands.parse(unquote(dir))
      end
    end

    test "柳溪 is an alias of the liuxi direction" do
      assert {:ok, %ParsedCommand{module: LiuxiCommand, function: :run}} =
               Commands.parse("柳溪")
    end
  end

  describe "the standard directions still route" do
    for dir <- ~w(north south east west up down) do
      test "#{dir}" do
        assert {:ok, %ParsedCommand{}} = Commands.parse(unquote(dir))
      end
    end
  end

  describe "word boundaries" do
    test "a longer word starting with a direction is not swallowed" do
      assert {:ok, %ParsedCommand{function: :northwest}} = Commands.parse("northwest")
      assert {:error, :unknown} = Commands.parse("leitairoom")
    end
  end

  describe "no exit name in data/world is unroutable" do
    @tag :world_data
    test "every custom direction in the world has a command" do
      world = Kantele.World.Loader.load()
      custom = MapSet.new(Map.keys(@custom))

      missing =
        Enum.reduce(world.zones, MapSet.new(), fn zone, acc ->
          Enum.reduce(zone.rooms, acc, fn room, acc2 ->
            Enum.reduce(room.exits, acc2, fn exit, acc3 ->
              dir = to_string(exit.exit_name)

              if MapSet.member?(custom, dir) do
                case Commands.parse(dir) do
                  {:ok, _} -> acc3
                  _ -> MapSet.put(acc3, dir)
                end
              else
                acc3
              end
            end)
          end)
        end)

      assert MapSet.size(missing) == 0,
             "custom directions with no command: #{inspect(MapSet.to_list(missing))}"
    end
  end
end
