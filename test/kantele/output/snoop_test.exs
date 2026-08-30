defmodule Kantele.Output.SnoopTest do
  use ExUnit.Case, async: true

  alias Kantele.Output.Snoop

  describe "format snoop messages" do
    test "skip prompt messages (ESC[256D without ESC[K)" do
      # LPC: if (msg[0..5] == ESC "[256D") && (msg[6..8] != ESC "[K")
      assert Snoop.format("\e[256Dsome prompt") == []
    end

    test "do not skip if ESC[K present" do
      assert Snoop.format("\e[256D\e[Ksome text") != []
    end

    test "strip up arrow ESC[1A" do
      result = Snoop.format("normal\e[1Atext")
      # Should contain text without the up arrow
      refute result == []
      # The up arrow should be removed
      assert result |> Enum.join() |> String.contains?("\e[1A") == false
    end

    test "wrap NOR with BBLU WHT" do
      result = Snoop.format("text\e[0mend")
      joined = Enum.join(result)
      assert joined =~ "\e[44;37m"
    end

    test "wrap message with color sequences" do
      result = Snoop.format("hello world")
      joined = Enum.join(result)
      assert String.starts_with?(joined, "\e[44;37m")
      assert String.ends_with?(joined, "\e[0m \e[1D")
    end

    test "chunk long messages at 2560 chars" do
      long_text = String.pad_leading("", 3000, "x")
      result = Snoop.format(long_text)
      assert length(result) > 1
      assert byte_size(Enum.at(result, 0)) <= 2560
    end

    test "return single chunk for short messages" do
      result = Snoop.format("short message")
      assert length(result) == 1
    end

    test "empty string returns formatted result" do
      # Empty string doesn't match prompt skip pattern, gets formatted
      result = Snoop.format("")
      assert is_list(result)
      assert length(result) == 1
    end
  end
end