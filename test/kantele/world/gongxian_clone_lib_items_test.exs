defmodule Kantele.World.GongxianCloneLibItemsTest do
  @moduledoc """
  验证「门贡兑换」(gongxian.ex `@convert_list`) 里原本缺失的 12 件 fam 物品定义
  已补入 `data/world/clone_lib.ucl`，且整份 UCL 能被 Loader 正常解析、物品 id 与
  关键 meta 字段正确。

  这是 `npc_actions_gongxian_test.exs` 的互补：那个测试只注入乾坤石、不加载世界
  数据，只能验证「没货」分支与列表列宽；本测试加载真实世界，确认定义本身存在，
  让 12 件物品不再走「没货」兜底。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp find(world, id), do: Enum.find(world.items, &(&1.id == id))

  describe "12 件 fam 物品已补入 clone_lib.ucl（UCL 解析无误）" do
    test "四种仙丹：name/unit/value/aliases 正确", %{world: world} do
      for {id, name, alias0} <- [
            {"clone_lib:str3", "蚩尤诛元仙丹", "zhuyuan xiandan"},
            {"clone_lib:int3", "神恩通慧仙丹", "tonghui xiandan"},
            {"clone_lib:con3", "洗髓再造仙丹", "xisui xiandan"},
            {"clone_lib:dex3", "破阳无极仙丹", "wuji xiandan"}
          ] do
        item = find(world, id)
        assert item, "缺少 #{id}"
        assert item.name == name
        assert item.meta.unit == "颗"
        assert item.meta.value == 100_000
        assert alias0 in item.meta.aliases
      end
    end

    test "阎罗绸 / 离火玄冰玉：锻造原料字段正确", %{world: world} do
      yanluo = find(world, "clone_lib:yanluo")
      assert yanluo, "缺少 clone_lib:yanluo"
      assert yanluo.name == "阎罗绸"
      assert yanluo.meta.value == 30_000
      assert yanluo.meta.weight == 1200
      assert yanluo.meta.unit == "张"
      assert yanluo.meta.material_attrib == "stone"
      assert yanluo.meta.material_name == "阎罗绸"
      assert "战衣" in yanluo.meta.can_make
      assert yanluo.meta.power_point == 80
      assert yanluo.meta.item_origin == 1

      lihuo = find(world, "clone_lib:lihuo")
      assert lihuo, "缺少 clone_lib:lihuo"
      assert lihuo.name == "离火玄冰玉"
      assert lihuo.meta.value == 30_000
      assert lihuo.meta.weight == 3400
      assert lihuo.meta.unit == "块"
      assert "all" in lihuo.meta.can_make
      assert "战衣" in lihuo.meta.not_make
      assert lihuo.meta.power_point == 80
      assert lihuo.meta.material_attrib == "stone"
      assert lihuo.meta.material_name == "离火玄冰玉"
    end

    test "天书 / 无花果 / 灵丹 / 圣水：解析正确", %{world: world} do
      t1 = find(world, "clone_lib:tianshu1")
      assert t1.name == "「忘情天书」"
      assert t1.meta.value == 500_000
      assert t1.meta.unit == "本"

      t2 = find(world, "clone_lib:tianshu2")
      assert t2.name == "「无字天书」"
      assert t2.meta.value == 500_000

      guo = find(world, "clone_lib:guo")
      assert guo.name == "许愿无花果"
      assert guo.meta.value == 100_000
      assert guo.meta.unit == "个"
      assert guo.meta.no_sell == 1

      longjia = find(world, "clone_lib:longjia")
      assert longjia.name == "子午龙甲丹"
      assert longjia.meta.value == 100_000
      assert longjia.meta.unit == "颗"

      xuanhuang = find(world, "clone_lib:xuanhuang")
      assert xuanhuang.name == "玄黄紫箐丹"
      assert xuanhuang.meta.value == 100_000
      assert xuanhuang.meta.unit == "颗"

      water = find(world, "clone_lib:bless_water")
      assert water.name == "乾坤圣水"
      assert water.meta.value == 1
      assert water.meta.unit == "瓶"
      assert water.meta.no_sell == 1
    end

    test "门贡兑换表全部 16 项在世界中都有定义（不再走「没货」分支）", %{world: world} do
      ids = [
        "clone_lib:str3",
        "clone_lib:int3",
        "clone_lib:con3",
        "clone_lib:dex3",
        "clone_lib:yanluo",
        "clone_lib:lihuo",
        "signature:qiankun_stone",
        "clone_lib:tianshu2",
        "clone_lib:tianshu1",
        "clone_lib:guo",
        "clone_lib:longjia",
        "clone_lib:xuanhuang",
        "clone_lib:bless_water",
        "item:tiancs",
        "death:qise",
        "death:tianjing"
      ]

      for id <- ids do
        assert find(world, id), "门贡兑换项缺少定义：#{id}"
      end
    end
  end
end
