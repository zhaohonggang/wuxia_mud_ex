defmodule Kantele.Character.RouterAliasesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  中文命令别名层（A8/N1）路由解析测试

  Router 先注册先匹配：单字裸命令靠词边界断言防误吞；
  带参命令靠必需空格自然分词；杀掉 必须先于 杀 注册。
  """

  alias Kantele.Character.Commands

  defp parse(text), do: Commands.parse(text)

  defp assert_command(text, module, function, params \\ nil) do
    case parse(text) do
      {:ok, command} ->
        assert command.module == module
        assert command.function == function

        if params do
          Enum.each(params, fn {key, value} ->
            assert Map.get(command.params, key) == value
          end)
        end

      other ->
        flunk("期望 #{text} 解析为 #{inspect(module)}.#{function}，实际 #{inspect(other)}")
    end
  end

  test "方向别名" do
    assert_command("北", Kantele.Character.MoveCommand, :north)
    assert_command("南", Kantele.Character.MoveCommand, :south)
    assert_command("西", Kantele.Character.MoveCommand, :west)
    assert_command("东", Kantele.Character.MoveCommand, :east)
    assert_command("上", Kantele.Character.MoveCommand, :up)
    assert_command("下", Kantele.Character.MoveCommand, :down)
  end

  test "方向别名带词边界（后随文字不误触发）" do
    assert parse("北上") == {:error, :unknown}
    assert parse("东西") == {:error, :unknown}
  end

  test "英文方向别名不回退" do
    assert_command("n", Kantele.Character.MoveCommand, :north)
    assert_command("north", Kantele.Character.MoveCommand, :north)
  end

  test "看 → look（忽略目标参数）且边界防误吞" do
    assert_command("看", Kantele.Character.LookCommand, :run)
    assert_command("看 黑虎", Kantele.Character.LookCommand, :run)
    assert parse("看书") == {:error, :unknown}
  end

  test "l 的既有边界不受影响" do
    assert_command("l", Kantele.Character.LookCommand, :run)
    assert parse("learn x y") != {:ok, %{module: Kantele.Character.LookCommand}}
  end

  test "拿/捡 → get" do
    assert_command("拿 包子", Kantele.Character.ItemCommand, :get, %{"item_name" => "包子"})
    assert_command("捡 长剑", Kantele.Character.ItemCommand, :get, %{"item_name" => "长剑"})
    assert parse("拿起包子") == {:error, :unknown}
  end

  test "穿/脱 → wear/remove" do
    assert_command("穿 布袍", Kantele.Character.WieldCommand, :wear, %{"item_name" => "布袍"})
    assert_command("脱 布袍", Kantele.Character.WieldCommand, :remove, %{"item_name" => "布袍"})
  end

  test "吃 → eat、喝 → drink、喝药 保持不变" do
    assert_command("吃 包子", Kantele.Character.EatCommand, :run, %{"item_name" => "包子"})
    assert_command("喝", Kantele.Character.DrinkCommand, :run)
    assert_command("喝药", Kantele.Character.DrinkCommand, :run)
    assert parse("喝酒") == {:error, :unknown}
  end

  test "杀/杀掉 → kill，杀掉 优先匹配" do
    assert_command("杀 黑虎", Kantele.Character.FightCommand, :run, %{"name" => "黑虎"})
    assert_command("杀掉 黑虎", Kantele.Character.FightCommand, :run, %{"name" => "黑虎"})
    assert_command("kill heihu", Kantele.Character.FightCommand, :run, %{"name" => "heihu"})
  end

  test "打坐 → exercise（带数量参数）" do
    assert_command("打坐 50", Kantele.Character.ExerciseCommand, :run, %{"arg" => "50"})
    assert_command("dazuo 30", Kantele.Character.ExerciseCommand, :run, %{"arg" => "30"})
  end

  test "学/练 → learn/practice" do
    assert_command("学 sword 王重九", Kantele.Character.LearnCommand, :run, %{
      "skill" => "sword",
      "name" => "王重九"
    })

    assert_command("练 liuxin-jian", Kantele.Character.PracticeCommand, :run, %{
      "skill" => "liuxin-jian"
    })
  end

  test "长命令不被中文单字别名干扰" do
    assert_command("look", Kantele.Character.LookCommand, :run)
    assert_command("learn sword wang", Kantele.Character.LearnCommand, :run)
  end
end
