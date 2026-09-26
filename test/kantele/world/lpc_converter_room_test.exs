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

  describe "文件类型判定（determine_object_type，技能继承名大小写不敏感）" do
    test "大写 SKILL 继承 → skill" do
      {:ok, ucl} =
        LPCConverter.convert_string("inherit SKILL;\n\nvoid create() { set(\"name\", \"x\"); }",
          base_path: "."
        )

      assert ucl =~ "# Skill file:"
    end

    test "小写路径继承含 skill（/adm/skills/...）→ skill，不再落 generic" do
      {:ok, ucl} =
        LPCConverter.convert_string("inherit \"/adm/skills/sword\";\n\nvoid create() { }",
          base_path: "."
        )

      assert ucl =~ "# Skill file:"
    end

    test "小写 force 继承（心法）→ skill" do
      {:ok, ucl} =
        LPCConverter.convert_string("inherit \"/adm/skills/force\";\n\nvoid create() { }",
          base_path: "."
        )

      assert ucl =~ "# Skill file:"
    end

    test "回归：仅技能判定改为大小写不敏感，房间/物品判定不受影响" do
      # 小写房间继承路径不含 skill/force：仍按原标准落 generic（非 rooms）
      {:ok, ucl} =
        LPCConverter.convert_string("inherit \"/d/city/entry\";\n\nvoid create() { }",
          base_path: "."
        )

      refute ucl =~ "rooms \""
      assert ucl =~ "# Generic LPC file"
    end
  end

  describe "继承链 / 宏继承（inherit __DIR__...，子类属性优先）" do
    @liandan1_path "test_minimal_world_v2_modified/special/liandan_lin1.c"
    @liandan_path "test_minimal_world_v2_modified/special/liandan_lin.c"

    test "liandan_lin1：宏继承 LIANDAN_LIN（→liandan_lin.c→ROOM）判为 room，非 generic" do
      {:ok, ucl} = LPCConverter.convert_file(@liandan1_path)

      assert ucl =~ ~s(rooms "liandan_lin1")
      refute ucl =~ "# Generic LPC file"
    end

    test "liandan_lin1：合并父类与子类 create 属性（子类优先）" do
      {:ok, ucl} = LPCConverter.convert_file(@liandan1_path)

      assert ucl =~ ~s(name = "城西后林")
      assert ucl =~ "这是一片茂密的树林"
      assert ucl =~ "琼天大"
      assert ucl =~ "遮蔽得暗然无光"
    end

    test "liandan_lin1：exits 原样写入 UCL（悬挂目标由 loader 丢弃）" do
      {:ok, ucl} = LPCConverter.convert_file(@liandan1_path)

      assert ucl =~ ~s(room_exits "liandan_lin1")
      assert ucl =~ "south = rooms.ximenwai"
      assert ucl =~ "north = rooms.liandan_lin3"
      assert ucl =~ "east = rooms.liandan_lin5"
      assert ucl =~ "west = rooms.liandan_lin4"
    end

    test "liandan_lin（父）自身仍按继承 ROOM 判为 room" do
      {:ok, ucl} = LPCConverter.convert_file(@liandan_path)
      assert ucl =~ ~s(rooms "liandan_lin")
    end

    test "合成链：子类 set 覆盖父类，父类独有属性透传" do
      dir =
        Path.join(System.tmp_dir!(), "lpc_inherit_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)

      parent =
        "#define OTHER __DIR__\"template\"\ninherit OTHER;\nvoid create() {\n" <>
          "  set(\"short\", \"父房间\");\n  set(\"long\", @LONG\n父描述\nLONG );\n}\n"

      template =
        "#define ROOM_DIR __DIR__\"parent\"\ninherit ROOM_DIR;\ninherit ROOM;\nvoid create() {\n" <>
          "  set(\"short\", \"模板房间\");\n  set(\"item_desc\", ([\"paizi\":\"模板牌子\"]));\n}\n"

      child =
        "inherit \"/parent\";\nvoid create() {\n  set(\"short\", \"子房间\");\n}\n"

      File.write!(Path.join(dir, "parent.c"), parent)
      File.write!(Path.join(dir, "template.c"), template)
      File.write!(Path.join(dir, "child.c"), child)

      try do
        {:ok, ucl} = LPCConverter.convert_file(Path.join(dir, "child.c"))

        # 子类 short 覆盖父类；父类独有 long 透传
        assert ucl =~ ~s(name = "子房间")
        refute ucl =~ ~s(name = "父房间")
        assert ucl =~ "父描述"

        # 链上模板（父的父）的属性并入，仍判为 room
        assert ucl =~ ~s(rooms "child")
        assert ucl =~ "模板牌子"
      after
        File.rm_rf!(dir)
      end
    end

    test "互指循环继承（twoc→twin→twoc）不无限递归，仍判为 room" do
      dir =
        Path.join(System.tmp_dir!(), "lpc_cycle_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)

      twoc =
        "#define TWIN __DIR__\"twin\"\ninherit TWIN;\nvoid create() {\n" <>
          "  set(\"short\", \"双子\");\n}\n"

      twin =
        "#define OTHER __DIR__\"twoc\"\ninherit OTHER;\ninherit ROOM;\nvoid create() { }\n"

      File.write!(Path.join(dir, "twoc.c"), twoc)
      File.write!(Path.join(dir, "twin.c"), twin)

      try do
        {:ok, ucl} = LPCConverter.convert_file(Path.join(dir, "twoc.c"))
        assert ucl =~ ~s(rooms "twoc")
        assert ucl =~ ~s(name = "双子")
      after
        File.rm_rf!(dir)
      end
    end
  end
end