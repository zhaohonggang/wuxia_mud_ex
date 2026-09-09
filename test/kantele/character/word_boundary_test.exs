defmodule Kantele.Character.WordBoundaryTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Commands

  describe "命令词边界（A8）：短命令不吞长命令前缀" do
    for {input, module} <- [
          {"inventory", Kantele.Character.InventoryCommand},
          {"score", Kantele.Character.ScoreCommand},
          {"who", Kantele.Character.WhoCommand},
          {"who1", Kantele.Character.Who1Command},
          {"who2", Kantele.Character.Who2Command},
          {"who3", Kantele.Character.Who3Command},
          {"whoami", Kantele.Character.WhoamiCommand},
          {"whoride", Kantele.Character.WhorideCommand},
          {"to", Kantele.Character.ToCommand},
          {"top2", Kantele.Character.Top2Command},
          {"topp", Kantele.Character.ToppCommand},
          {"touch", Kantele.Character.TouchCommand}
        ] do
      test "`#{input}` 解析到自己的命令（不被首字母/短词前缀吞掉）" do
        {:ok, parsed} = Commands.parse(unquote(input))
        assert parsed.module == unquote(module)
      end
    end

    for input <- ["top", "score2"] do
      test "`#{input}` 裸输入需参数，返回 {:error, :unknown}（不被前缀吞掉）" do
        assert Commands.parse(unquote(input)) == {:error, :unknown}
      end
    end
  end
end