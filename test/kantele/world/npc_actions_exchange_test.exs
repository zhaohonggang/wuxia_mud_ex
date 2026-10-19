defmodule Kantele.World.NpcActions.ExchangeTest do
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Exchange

  @room_id "city:kedian"

  defp conn(jifen, inventory \\ []) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %PlayerMeta{jifen: jifen},
        inventory: inventory
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(trailing), do: %{verb: "exchange", trailing: trailing, room_id: @room_id, npc: %Kalevala.Character{name: "店小二"}}

  # 测试环境不加载世界数据（Items 缓存为空，见 yao 测试的同类处理）。
  # 成功路径需要真实物品定义，故在 setup 里向 cache 注入 clone_lib:puti1
  # （与 UCL clone_lib.ucl 的同名定义一致；Cache 无 delete 接口，注入是永久
  # 的，但该 id 仅本文件使用，不影响其他测试对空缓存的依赖）。
  setup do
    Kantele.World.Items.put("clone_lib:puti1", %Kalevala.World.Item{
      id: "clone_lib:puti1",
      name: "血菩提",
      meta: %{}
    })

    :ok
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  # put_character 只写 private.update_character；同一 handler 内的后续写读都经此
  # （见 Helpers current/1）。断言状态变更必须从 update_character 读。
  defp char_of(conn), do: conn.private.update_character || conn.character

  defp jifen_of(conn), do: PlayerMeta.jifen(char_of(conn).meta)

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Exchange.run(conn(10), params("血菩提") |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Exchange.run(conn(10), params("血菩提") |> Map.put(:room_id, "city:shuyuan"))
    end
  end

  describe "run/2（积分/参数守卫）" do
    test "jifen 为 0（未开户）→ 「您暂时没有积分」" do
      conn2 = Exchange.run(conn(0), params("血菩提"))

      assert String.contains?(out_text(conn2), "您暂时没有积分呢")
    end

    test "jifen 为 nil → 同样按 0 拒" do
      conn2 = Exchange.run(conn(nil), params("血菩提"))

      assert String.contains?(out_text(conn2), "您暂时没有积分呢")
    end

    test "无 arg → 「你要兑换什么东西？」" do
      conn2 = Exchange.run(conn(100), params(""))

      assert String.contains?(out_text(conn2), "你要兑换什么东西？(help jifen)")
    end

    test "纯空白 arg → 同样提示" do
      conn2 = Exchange.run(conn(100), params("   "))

      assert String.contains?(out_text(conn2), "你要兑换什么东西")
    end
  end

  describe "run/2（清单守卫）" do
    test "不在 32 种兑换表 → 「规定范围内」" do
      conn2 = Exchange.run(conn(100), params("千年人参"))

      assert String.contains?(out_text(conn2), "你只能兑换规定范围内的物品")
    end

    test "低积分打错物品名 → 先撞清单守卫（LPC switch 在 cost 之前）" do
      conn2 = Exchange.run(conn(1), params("不存在的东西"))

      assert String.contains?(out_text(conn2), "规定范围内")
    end
  end

  describe "run/2（cost 守卫）" do
    test "积分不足（10 < 所需 100）→ 带数字的拒绝且不扣分" do
      conn2 = Exchange.run(conn(10), params("镇狱惊天丸"))

      assert String.contains?(out_text(conn2), "您当前积分只有 10 点，兑换此物品需要 100 点积分")
      assert jifen_of(conn2) == 10
    end

    test "积分恰够（5 = 所需 5）→ 过守卫" do
      conn2 = Exchange.run(conn(5), params("血菩提"))

      refute String.contains?(out_text(conn2), "积分只有")
    end
  end

  describe "run/2（成功路径：世界数据有的物品）" do
    test "血菩提（puti1, cost 5）：扣 5 分 + 入包 + say 兑换完成" do
      conn2 = Exchange.run(conn(10), params("血菩提"))

      # 扣分
      assert jifen_of(conn2) == 5
      # 发物：背包多一件 clone_lib:puti1
      assert [%{item_id: "clone_lib:puti1"}] = char_of(conn2).inventory
      # say 广播
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "兑换完成，欢迎再次光临"))
    end

    test "duihuan 动词同一 handler（LPC 双注册）" do
      conn2 = Exchange.run(conn(10), params("血菩提") |> Map.put(:verb, "duihuan"))

      assert jifen_of(conn2) == 5
      assert [%{item_id: "clone_lib:puti1"}] = char_of(conn2).inventory
    end
  end

  describe "run/2（LPC !ob 分支：世界数据缺失的物品）" do
    test "神力丸（str1 无 UCL 定义）→ 「我的东西呢?！」且不扣分不发物" do
      conn2 = Exchange.run(conn(50), params("神力丸"))

      assert String.contains?(out_text(conn2), "咦？我的东西…我的东西呢?！")
      assert jifen_of(conn2) == 50
      assert char_of(conn2).inventory == []
    end

    test "子午龙甲丹（longjia 无定义，cost 80）→ 同样落 !ob（cost 先过）" do
      conn2 = Exchange.run(conn(100), params("子午龙甲丹"))

      assert String.contains?(out_text(conn2), "我的东西呢?！")
      assert jifen_of(conn2) == 100
    end
  end

  describe "rumor 传闻广播（LPC CHANNEL_D->do_channel(..., \"rumor\", ...)）" do
    # 本模块 async: false：rumor 是全服频道，订阅会接收全局广播，串行避免串扰。
    defp subscribe_rumor do
      :ok = Kantele.Communication.subscribe("rumor", %{}, [])
    end

    test "rumor_text/3：量词取物品 unit，缺失回落「个」" do
      assert Exchange.rumor_text("张三", "血菩提", "颗") ==
               "听说张三在店小二处兑换了一颗血菩提。"

      assert Exchange.rumor_text("张三", "秘籍", "本") ==
               "听说张三在店小二处兑换了一本秘籍。"

      assert Exchange.rumor_text("张三", "血菩提", nil) ==
               "听说张三在店小二处兑换了一个血菩提。"

      assert Exchange.rumor_text("张三", "血菩提", "") ==
               "听说张三在店小二处兑换了一个血菩提。"
    end

    test "兑换成功 → 向 rumor 频道广播「听说<玩家>在店小二处兑换了一<unit><物品>」" do
      subscribe_rumor()

      # 注入带量词「颗」的血菩提（覆盖 setup 的无量词版本）。
      # 注意：Kalevala.World.Item 无顶层 unit 字段，量词落在 meta.unit。
      Kantele.World.Items.put("clone_lib:puti1", %Kalevala.World.Item{
        id: "clone_lib:puti1",
        name: "血菩提",
        meta: %{unit: "颗"}
      })

      Exchange.run(conn(10), params("血菩提"))

      assert_receive %Kalevala.Event{
        data: %Kalevala.Event.Message{text: text, channel_name: "rumor"}
      }

      assert String.contains?(text, "听说玩家在店小二处兑换了一颗血菩提。")
    end

    test "兑换失败分支不广播传闻（积分不足）→ 收不到 rumor 事件" do
      subscribe_rumor()

      Exchange.run(conn(1), params("镇狱惊天丸"))

      refute_receive %Kalevala.Event{data: %Kalevala.Event.Message{channel_name: "rumor"}}
    end
  end
end
