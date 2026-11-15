defmodule Kantele.Character.BareSettingsRoutesTest do
  @moduledoc """
  裸命令路由回归：这些命令都有 `run(conn, _params)` 兜底（列出/显示当前设定），
  因此路由参数必须是 optional。若写成必需的 `spaces() |> text(...)`，
  裸命令会 parse 失败，玩家只会看到 "What?"（option 曾踩过这个坑）。
  """
  use ExUnit.Case, async: true

  alias Kantele.Character.Commands

  @bare [
    {"option", Kantele.Character.OptionCommand},
    {"选项", Kantele.Character.OptionCommand},
    {"alias", Kantele.Character.AliasCommand},
    {"别名", Kantele.Character.AliasCommand},
    {"title", Kantele.Character.TitleCommand},
    {"头衔", Kantele.Character.TitleCommand},
    {"nick", Kantele.Character.NickCommand},
    {"昵称", Kantele.Character.NickCommand},
    {"team", Kantele.Character.TeamCommand},
    {"组队", Kantele.Character.TeamCommand},
    {"wimpy", Kantele.Character.WimpyCommand},
    {"自动逃跑", Kantele.Character.WimpyCommand}
  ]

  test "裸命令全部能命中，且不带 rest/arg" do
    Enum.each(@bare, fn {text, expected} ->
      assert {:ok, parsed} = Commands.parse(text), "#{text} 裸命令解析失败"
      assert parsed.module == expected, "#{text} 命中了 #{inspect(parsed.module)}"
      refute Map.has_key?(parsed.params, "rest"), "#{text} 不应带 rest"
      refute Map.has_key?(parsed.params, "arg"), "#{text} 不应带 arg"
    end)
  end

  test "带参数仍把 rest/arg 交下去" do
    assert {:ok, p} = Commands.parse("option map_hidden 1")
    assert p.params["rest"] == "map_hidden 1"

    assert {:ok, p} = Commands.parse("alias sc score")
    assert p.params["rest"] == "sc score"

    assert {:ok, p} = Commands.parse("title 天下第一")
    assert p.params["rest"] == "天下第一"

    assert {:ok, p} = Commands.parse("team with 张三")
    assert p.params["rest"] == "with 张三"

    assert {:ok, p} = Commands.parse("wimpy 30")
    assert p.params["arg"] == "30"
  end

  test "tt 仍需发言内容（不是设置类命令）" do
    assert {:error, :unknown} = Commands.parse("tt")
  end
end
