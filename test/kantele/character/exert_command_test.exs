defmodule Kantele.Character.ExertCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.ExertCommand

  describe "exert 命令" do
    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("exert powerup")
      assert parsed.module == ExertCommand
    end
  end
end
