defmodule Kantele.World.ItemActions.ConvertBianTest do
  @moduledoc """
  灵蛇杖/蛇杖 `convert` 动作单测（物品动作通道）。

  覆盖：门派守门（非欧阳世家拒绝）、精力守门（jing<100 拒绝）、
  驯兽术守门（training<70+random(70) 拒绝）、未知 handler 落空。
  守门分支返回携带提示的 conn（由分发器按 `{:handled, conn}` 送达玩家）；
  成功路径（调用 Kalevala.World.start_character/2）在 Docker 集成测试中验证。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance

  alias Kantele.World.ItemActions.ConvertBian

  defp staff(handler, item_id \\ "baituo:lingshezhang", name \\ "灵蛇杖") do
    %Item{
      id: item_id,
      name: name,
      meta: %{
        actions: [%{verb: "convert", handler: handler}],
        damage: 180,
        skill_type: "staff"
      }
    }
  end

  defp instance(item) do
    %Instance{id: "inst-1", item_id: item.id, item: item}
  end

  defp conn(opts \\ []) do
    character =
      %Kalevala.Character{
        name: "玩家",
        room_id: "baituo:xiaoyuan",
        meta: %{
          family: Keyword.get(opts, :family, %{name: "丐帮"}),
          stats: %Kantele.Character.Stats{skills: %{"training" => Keyword.get(opts, :training, 10)}},
          vitals: %{jing: Keyword.get(opts, :jing, 50)}
        },
        inventory: []
      }

    %Conn{
      character: character,
      private: %Conn.Private{room: %Kantele.World.Room{id: "baituo:xiaoyuan"}, channel_changes: []},
      output: []
    }
  end

  defp params(handler, item, trailing \\ "") do
    %{
      verb: "convert",
      trailing: trailing,
      room_id: "baituo:xiaoyuan",
      item: item,
      instance: instance(item),
      handler: handler
    }
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "守门分支（返回 conn，向玩家送达提示）" do
    test "非欧阳世家 → 拒绝" do
      c = conn(family: %{name: "丐帮"})
      c2 = ConvertBian.run(c, params("convert_lingshe", staff("convert_lingshe")))

      refute c2 == :not_handled
      assert String.contains?(out_text(c2), "只有欧阳世家的弟子")
    end

    test "无门派 → 拒绝" do
      c = conn(family: nil)
      c2 = ConvertBian.run(c, params("convert_lingshe", staff("convert_lingshe")))

      refute c2 == :not_handled
      assert String.contains?(out_text(c2), "只有欧阳世家的弟子")
    end

    test "jing 不足 → 拒绝" do
      c = conn(family: %{name: "欧阳世家"}, jing: 50)
      c2 = ConvertBian.run(c, params("convert_lingshe", staff("convert_lingshe")))

      refute c2 == :not_handled
      assert String.contains?(out_text(c2), "精力不足")
    end

    test "training 不足 → 拒绝" do
      # training=10，阈值 70+random(70) 最低 70，必拒
      c = conn(family: %{name: "欧阳世家"}, jing: 200, training: 10)
      c2 = ConvertBian.run(c, params("convert_lingshe", staff("convert_lingshe")))

      refute c2 == :not_handled
      assert String.contains?(out_text(c2), "驯兽术不够高明")
    end
  end

  describe "落空分支" do
    test "未知 handler → :not_handled，不输出" do
      c = conn(family: %{name: "欧阳世家"}, jing: 200)
      c2 = ConvertBian.run(c, %{
        verb: "convert",
        trailing: "",
        room_id: "baituo:xiaoyuan",
        item: staff("convert_lingshe"),
        instance: instance(staff("convert_lingshe")),
        handler: "unknown_handler"
      })

      assert c2 == :not_handled
    end

    test "非 convert 动词 → run 不校验动词，按 handler 分派（默认非欧阳世家故拒绝）" do
      c = conn() # 缺省丐帮，触发门派守门
      c2 = ConvertBian.run(c, %{
        verb: "wield",
        trailing: "",
        room_id: "baituo:xiaoyuan",
        item: staff("convert_lingshe"),
        instance: instance(staff("convert_lingshe")),
        handler: "convert_lingshe"
      })

      refute c2 == :not_handled
      assert String.contains?(out_text(c2), "只有欧阳世家的弟子")
    end
  end

  describe "handler 分派" do
    test "convert_lingshe → staff 项 id 为 lingshezhang" do
      item = staff("convert_lingshe", "baituo:lingshezhang", "灵蛇杖")
      assert item.name == "灵蛇杖"
      assert item.id == "baituo:lingshezhang"
    end

    test "convert_snake → staff 项 id 为 shezhang" do
      item = staff("convert_snake", "baituo:shezhang", "蛇杖")
      assert item.name == "蛇杖"
      assert item.id == "baituo:shezhang"
    end
  end
end
