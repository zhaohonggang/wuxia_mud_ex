defmodule Kantele.Character.ReplyCommandTest do
  use ExUnit.Case, async: true

  describe "reply 命令" do
    test "reply 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("reply 好的")
      assert parsed.module == Kantele.Character.ReplyCommand
      assert parsed.function == :run
      assert parsed.params["text"] == "好的"
    end
  end
end