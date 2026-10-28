defmodule Kantele.World.NpcActions.GongxianTest do
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Gongxian

  @room_id "changan:qunyulou2"
  @stone "signature:qiankun_stone"

  defp conn(gongxian, inventory \\ []) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %Kantele.Character.PlayerMeta{stats: struct(Stats, gongxian: gongxian)},
        inventory: inventory
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(verb, trailing),
    do: %{verb: verb, trailing: trailing, room_id: @room_id, npc: %Kalevala.Character{name: "浮云"}}

  setup do
    # 测试环境不加载世界数据（Items 缓存为空）。成功路径需要真实物品定义，
    # 故注入 signature:qiankun_stone —— 与 data/world/signature.ucl 的同名定义
    # 一致。其余 15 项故意不注入，用于验证「没货」分支。
    Kantele.World.Items.put(@stone, %Kalevala.World.Item{
      id: @stone,
      name: "乾坤石 Qiankun Stone",
      meta: %Kantele.World.Item.Meta{value: 30_000, weight: 100, unit: "块"}
    })

    :ok
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp char_of(conn), do: conn.private.update_character || conn.character

  defp gongxian_of(conn), do: char_of(conn).meta.stats.gongxian

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled" do
      assert :not_handled = Gongxian.run(conn(0), params("list", "") |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled =
               Gongxian.run(conn(0), params("duihuan", "7 1") |> Map.put(:room_id, "changan:qunyulou1"))
    end

    test "未注册动词 → :not_handled" do
      assert :not_handled = Gongxian.run(conn(0), params("exchange", "7 1"))
    end
  end

  describe "list（fuyun.c do_list）" do
    test "表头与分隔线与 LPC 一致" do
      text = out_text(Gongxian.run(conn(0), params("list", "")))

      assert text =~ "浮云目前可以兑换（duihuan）以下物品：\n"
      assert text =~ "==========================================\n"
      assert text =~ "编号  门贡      物品\n"
      assert text =~ "------------------------------------------\n"
    end

    test "16 行，编号/门贡列宽逐字符对齐（含 LPC 的错位）" do
      text = out_text(Gongxian.run(conn(0), params("list", "")))
      lines = String.split(text, "\n")

      # 编号列：`"i" + "  "` 后按 `i<1000 / i<100 / i<10` 各补 1 空格 →
      #   1 位编号（1~9）补到 5 列宽，2 位编号（10~16）补到 4 列宽。
      # 门贡列：`"gx" + "  "` 后按 `gx<100000 / <10000 / <1000 / <100` 各补 1 空格 →
      #   1000/1500/3000/5000/6666/8888/9999 补到 4 列宽，99999 补到 3，999999 补到 2
      #   （LPC 原式，gongxian.ex 的 pad_number / pad_cost 逐条复刻）。
      assert "1     1000    蚩尤诛元仙丹" in lines
      # 编号 10 只有 4 列宽（LPC 的 `if (i < 10)` 不成立），比 1 位编号窄 1
      assert "10    6666    许愿无花果" in lines
      # 编号 16 同理；999999 门贡只补 2 列宽（四个 if 全不命中）
      assert "16    999999  寰宇天晶" in lines
      # 编号 7 = 乾坤石，1500 门贡（唯一的可重复来源）
      assert "7     1500    乾坤石" in lines
    end
  end

  describe "duihuan（fuyun.c do_duihuan）" do
    test "无参数 → 格式提示" do
      text = out_text(Gongxian.run(conn(9999), params("duihuan", "")))

      assert text =~ "你要兑换什么东西？指令：duihuan <编号> <数量>"
    end

    test "只给编号 → 格式提示（LPC sscanf 要求两个整数）" do
      text = out_text(Gongxian.run(conn(9999), params("duihuan", "7")))

      assert text =~ "你要兑换什么东西？"
    end

    test "编号越界（17 / 0 / 负数）→ 「看清编号」" do
      for index <- ["17", "0", "-3"] do
        text = out_text(Gongxian.run(conn(999_999), params("duihuan", "#{index} 1")))
        assert text =~ "输入（list）看清编号再来吧。", "index=#{index}"
      end
    end

    test "数量 < 1 → 「看清编号」（不复现 LPC 的负数量刷贡献漏洞）" do
      for count <- ["0", "-5"] do
        conn2 = Gongxian.run(conn(1000), params("duihuan", "7 #{count}"))
        assert out_text(conn2) =~ "输入（list）看清编号再来吧。", "count=#{count}"
        assert gongxian_of(conn2) == 1000
      end
    end

    test "门贡不足 → 「冷笑一声，没理你」，不扣不发" do
      conn2 = Gongxian.run(conn(1499), params("duihuan", "7 1"))

      assert out_text(conn2) =~ "浮云对你冷笑一声，没理你。"
      assert gongxian_of(conn2) == 1499
      assert char_of(conn2).inventory == []
    end

    test "乾坤石：扣 1500 门贡 + 入包 1 块" do
      conn2 = Gongxian.run(conn(2000), params("duihuan", "7 1"))

      assert out_text(conn2) =~ "浮云拿出一些乾坤石，笑眯眯的说：欢迎下次光临。"
      assert gongxian_of(conn2) == 500
      assert [%{item_id: @stone}] = char_of(conn2).inventory
    end

    test "数量 2 → 扣 3000，入包 2 块" do
      conn2 = Gongxian.run(conn(3000), params("duihuan", "7 2"))

      assert gongxian_of(conn2) == 0
      assert length(char_of(conn2).inventory) == 2
      assert Enum.all?(char_of(conn2).inventory, &(&1.item_id == @stone))
    end

    test "定义缺失的物品 → 「没货」，不扣门贡（LPC 侧 new() 必成功）" do
      conn2 = Gongxian.run(conn(99_999), params("duihuan", "1 1"))

      assert out_text(conn2) =~ "这东西一时没货，改日再来吧。"
      assert gongxian_of(conn2) == 99_999
      assert char_of(conn2).inventory == []
    end

    test "恰好够钱（gongxian == gx）→ 允许" do
      conn2 = Gongxian.run(conn(1500), params("duihuan", "7 1"))

      assert gongxian_of(conn2) == 0
      assert length(char_of(conn2).inventory) == 1
    end
  end
end
