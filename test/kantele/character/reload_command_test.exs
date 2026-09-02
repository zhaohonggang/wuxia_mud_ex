defmodule Kantele.Character.ReloadCommandTest do
  use ExUnit.Case, async: true

  describe "reload 命令" do
    test "reload 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("reload")
      assert parsed.module == Kantele.Character.ReloadCommand
      assert parsed.function == :reload
    end

    test "recompile 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("recompile")
      assert parsed.module == Kantele.Character.ReloadCommand
      assert parsed.function == :recompile
    end
  end
end