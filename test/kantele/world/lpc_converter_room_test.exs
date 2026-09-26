defmodule Kantele.World.LPCConverterRoomTest do
  use ExUnit.Case, async: true

  alias Kantele.World.LPCConverter

  @cave_path "test_minimal_world_v2_modified/room/cave.c"
  @kedian_path "test_minimal_world_v2_modified/room/kedian.c"
  @furong_path "test_minimal_world_v2_modified/room/furong.c"
  @bet_path "test_minimal_world_v2_modified/room/bet.c"

  defp parse(path) do
    {:ok, ast} = LPCConverter.parse_ast(File.read!(path), path, path)
    ast
  end

  describe "valid_leave 出口阻挡抽取（notify_fail）" do
    test "cave：蟒蛇在场阻挡 dir=in，条件与台词都保留" do
      ast = parse(@cave_path)

      assert ast.exit_vetoes == [
               %{
                 dir: "in",
                 condition: ~s|dir == "in" && objectp(present("mang she", environment(me)))|,
                 message: "蟒蛇盘在岩洞口，将路封了个严实。"
               }
             ]
    end

    test "kedian：颜色宏包裹的两条独立阻挡（up/west）" do
      ast = parse(@kedian_path)

      assert length(ast.exit_vetoes) == 2
      veto_up = Enum.find(ast.exit_vetoes, &(&1.dir == "up"))
      veto_west = Enum.find(ast.exit_vetoes, &(&1.dir == "west"))

      assert veto_up.condition =~ ~s|! me->query_temp("rent_paid") && dir == "up"|
      assert veto_west.condition =~ ~s|me->query_temp("rent_paid") && dir == "west"|
      assert veto_up.message =~ "想白住啊"
      assert veto_west.message =~ "店小二跑到门边拦住"
      assert veto_west.message =~ "付了银子"
    end

    test "furong：兜底阻挡不绑定方向/条件（宴会进行中不得离开）" do
      ast = parse(@furong_path)

      assert ast.exit_vetoes == [
               %{dir: nil, condition: nil, message: "请先用 order end 结束宴会后才能离开。"}
             ]
    end

    test "无 notify_fail 的 valid_leave（bet 仅清理状态）不产出阻挡" do
      ast = parse(@bet_path)
      assert ast.exit_vetoes == []
    end

    test "emission：valid_leave 块进房间 UCL" do
      {:ok, ucl} =
        LPCConverter.convert_string(File.read!(@cave_path),
          base_path: "test_minimal_world_v2_modified/room"
        )

      assert ucl =~ "valid_leave = ["
      assert ucl =~ ~s(direction = "in")
      assert ucl =~ "蟒蛇盘在岩洞口，将路封了个严实。"
    end
  end

  describe "set(" <> "item_desc" <> ") 墙牌/菜单抽取" do
    test "bet：paizi 规则板完整拼接，颜色宏剥离" do
      {:ok, ucl} =
        LPCConverter.convert_string(File.read!(@bet_path),
          base_path: "test_minimal_world_v2_modified/room"
        )

      assert ucl =~ "item_desc = {"
      assert ucl =~ "paizi = "
      assert ucl =~ "赌博规则"
      assert ucl =~ "一赢三十六"
      assert ucl =~ "一赢十二"
      assert ucl =~ "一赢六"
      assert ucl =~ "一赢三"
    end

    test "furong：menu 菜单完整保留" do
      {:ok, ucl} =
        LPCConverter.convert_string(File.read!(@furong_path),
          base_path: "test_minimal_world_v2_modified/room"
        )

      assert ucl =~ "menu = "
      assert ucl =~ "承办酒席"
      assert ucl =~ "祝寿宴"
      assert ucl =~ "order end"
    end
  end
end