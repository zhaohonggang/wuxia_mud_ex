defmodule Kantele.Character.CommandVerbsTest do
  @moduledoc """
  编译期动词表回归：确保 `commands.ex` 的每条 `parse("verb", ...)` 都被收进表，
  且 `CommandsCommand` 与路由实际行为一致。
  """
  use ExUnit.Case, async: true

  alias Kantele.Character.CommandVerbs
  alias Kantele.Character.Commands

  test "动词表覆盖路由器里的全部命令" do
    all = CommandVerbs.all()

    assert length(all) >= 400
    assert all == Enum.sort(Enum.uniq(all)), "动词表应去重且有序"

    Enum.each(["look", "get", "drop", "ask", "map", "option", "commands", "hints", "交互", "提示"],
      fn verb -> assert verb in all, "#{verb} 应出现在动词表" end
    )
  end

  test "global?/1 只认真实存在的命令" do
    assert CommandVerbs.global?("look")
    assert CommandVerbs.global?("hints")
    refute CommandVerbs.global?("definitely_not_a_command")
    refute CommandVerbs.global?("do_move")
    refute CommandVerbs.global?(nil)
    refute CommandVerbs.global?(:look)
  end

  test "表里的无参命令确实能被路由解析" do
    Enum.each(["hints", "交互", "提示", "map", "option", "commands"], fn verb ->
      assert {:ok, parsed} = Commands.parse(verb), "#{verb} 裸命令应可解析"
      assert parsed.params["command"] == verb
    end)
  end

  test "新增命令后动词表随源文件重编译（@external_resource）" do
    # 本条固定「新增动词要进表」的契约：hints 是本批新增的，
    # 若忘记 @external_resource，增量编译下这里会是旧的 427 条。
    assert CommandVerbs.global?("hints")
  end
end
