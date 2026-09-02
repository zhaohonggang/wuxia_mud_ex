defmodule Kantele.Character.CombineCommand do
  @moduledoc """
  组合命令：`combine <物品> & <物品> & ...`
  对应 LPC cmds/skill/combine.c。
  将特殊物品合并为新物品（如丹药配方、宝石合成等）。
  合并数据依赖结果物品模板存在于 Items 注册表；否则返回"似乎没有任何变化"。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kantele.Character.Vitals
  alias Kantele.World.Items

  @jingli_cost 200
  @min_jingli 300
  @min_max_jingli 300

  @combine_list %{
    # 镇狱惊天丸
    ["/clone/fam/max/xuanhuang-1", "/clone/fam/max/longjia-1"] => "/clone/fam/max/zhenyu",
    # 子午龙甲丹
    ["/clone/fam/pill/dimai-1", "/clone/fam/pill/renshen4-1", "/clone/fam/etc/lv7d-1"] => "/clone/fam/max/longjia",
    # 玄黄紫箐丹
    ["/clone/fam/pill/yulu-1", "/clone/fam/pill/lingzhi4-1", "/clone/fam/etc/lv7a-1"] => "/clone/fam/max/xuanhuang",
    # 地脉血泉
    ["/clone/fam/pill/puti2-1", "/clone/fam/pill/sheli3-1", "/clone/fam/etc/lv7b-1"] => "/clone/fam/pill/dimai",
    # 天香玉露
    ["/clone/fam/pill/sheli2-1", "/clone/fam/pill/puti3-1", "/clone/fam/etc/lv7c-1"] => "/clone/fam/pill/yulu",
    # 菩提子
    ["/clone/fam/pill/puti1-1", "/clone/fam/pill/puti2-1", "/clone/fam/pill/puti3-1"] => "/clone/fam/pill/puti4",
    # 忘情天书
    ["/clone/fam/gift/str3-1", "/clone/fam/gift/int3-1", "/clone/fam/gift/dex3-1", "/clone/fam/gift/con3-1"] => "/clone/fam/max/tianshu1",
    # 无字天书
    ["/clone/fam/gift/str1-1", "/clone/fam/gift/int1-1", "/clone/fam/gift/con1-1", "/clone/fam/gift/dex1-1"] => "/clone/fam/max/tianshu2",
    # 三个钻石碎片合并成一个钻石
    ["/clone/gift/cdiamond-1", "/clone/gift/cdiamond-2", "/clone/gift/cdiamond-3"] => "/clone/gift/diamond",
    # 三个钻石合并成一个精美钻石
    ["/clone/gift/diamond-1", "/clone/gift/diamond-2", "/clone/gift/diamond-3"] => "/clone/gift/fdiamond",
    # 三个精美钻石合并成为一个神之钻石
    ["/clone/gift/fdiamond-1", "/clone/gift/fdiamond-2", "/clone/gift/fdiamond-3"] => "/clone/gift/mdiamond",
    # 三个玛瑙碎片合并成为一个玛瑙
    ["/clone/gift/cagate-1", "/clone/gift/cagate-2", "/clone/gift/cagate-3"] => "/clone/gift/agate",
    # 三个玛瑙合并成为一个精美玛瑙
    ["/clone/gift/agate-1", "/clone/gift/agate-2", "/clone/gift/agate-3"] => "/clone/gift/fagate",
    # 三个精美玛瑙合并成为一个神之玛瑙
    ["/clone/gift/fagate-1", "/clone/gift/fagate-2", "/clone/gift/fagate-3"] => "/clone/gift/magate",
    # 三个水晶碎片合并成为一个水晶
    ["/clone/gift/ccrystal-1", "/clone/gift/ccrystal-2", "/clone/gift/ccrystal-3"] => "/clone/gift/crystal",
    # 三个水晶合并成为一个精美水晶
    ["/clone/gift/crystal-1", "/clone/gift/crystal-2", "/clone/gift/crystal-3"] => "/clone/gift/fcrystal",
    # 三个精美水晶合并成为一个神之水晶
    ["/clone/gift/fcrystal-1", "/clone/gift/fcrystal-2", "/clone/gift/fcrystal-3"] => "/clone/gift/mcrystal",
    # 三个翡翠碎片合并成为一个翡翠
    ["/clone/gift/cjade-1", "/clone/gift/cjade-2", "/clone/gift/cjade-3"] => "/clone/gift/jade",
    # 三个翡翠合并成为一个精美翡翠
    ["/clone/gift/jade-1", "/clone/gift/jade-2", "/clone/gift/jade-3"] => "/clone/gift/fjade",
    # 三个精美翡翠合并成为一个神之翡翠
    ["/clone/gift/fjade-1", "/clone/gift/fjade-2", "/clone/gift/fjade-3"] => "/clone/gift/mjade",
    # 乾坤圣水
    ["/clone/fam/gift/int3-1", "/clone/fam/etc/lv7a-1", "/clone/fam/item/stone5-1"] => "/clone/fam/item/bless_water",
    ["/clone/fam/gift/con3-1", "/clone/fam/etc/lv7a-1", "/clone/fam/item/stone5-1"] => "/clone/fam/item/bless_water",
    ["/clone/fam/gift/dex3-1", "/clone/fam/etc/lv7a-1", "/clone/fam/item/stone5-1"] => "/clone/fam/item/bless_water",
    ["/clone/fam/gift/str3-1", "/clone/fam/etc/lv7a-1", "/clone/fam/item/stone5-1"] => "/clone/fam/item/bless_water",
    # 许愿无花果
    ["/clone/fam/gift/str3-1", "/clone/fam/gift/int3-1", "/clone/fam/gift/con3-1", "/clone/fam/gift/dex3-1",
      "/clone/fam/gift/str2-1", "/clone/fam/gift/int2-1", "/clone/fam/gift/con2-1", "/clone/fam/gift/dex2-1"] => "/clone/fam/obj/guo"
  }

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    if is_nil(arg) or arg == "" do
      fail(conn, "你要合并什么物品？\n")
    else
      items = parse_item_list(arg)

      if length(items) < 2 do
        fail(conn, "合并物品需要指明至少两件不同的物品。\n")
      else
        check_and_combine(conn, character, items)
      end
    end
  end

  def run(conn, %{}) do
    fail(conn, "你要合并什么物品？\n格式：combine <物品> & <物品> & ...\n")
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_item_list(arg) do
    arg
    |> String.split("&")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp check_and_combine(conn, character, item_names) do
    vitals = character.meta.vitals

    if Combat.busy?(character.meta.combat) do
      fail(conn, "先忙完了你的事情再做这件事情吧！\n")
    else
      case find_and_validate_items(character, item_names) do
        {:error, reason} ->
          fail(conn, reason <> "\n")

        {:ok, instances, name_list} ->
          if vitals.jingli < @min_jingli do
            fail(conn, "你现在精力不济，无法合成物品。\n")
          else
            execute_combine(conn, character, instances, name_list)
          end
      end
    end
  end

  defp find_and_validate_items(character, item_names) do
    seen_ids = MapSet.new()
    instances = []
    name_list = []

    result =
      Enum.reduce_while(item_names, {:ok, [], []}, fn raw_name, {:ok, acc_inst, acc_names} ->
        name = String.trim(raw_name)

        if name == "" do
          {:halt, {:error, "物品名称不能为空"}}
        else
          inst =
            Enum.find(character.inventory, fn i ->
              item = Items.get!(i.item_id)
              item.callback_module.matches?(item, name)
            end)

          if is_nil(inst) do
            {:halt, {:error, "你身上没有 #{name} 这种物品"}}
          else
            inst_id = inst.item_id

            if MapSet.member?(seen_ids, inst_id) do
              {:halt, {:error, "合并物品需要指明不同的物品，不要重复指定一件物品"}}
            else
              seen_ids = MapSet.put(seen_ids, inst_id)
              bname = inst.item_id

              # Build name list like C: bname + "-" + same_count
              same_count =
                Enum.count(character.inventory, fn i -> i.item_id == bname end)

              name_entry = "#{bname}-#{same_count}"
              {:cont, {:ok, [inst | acc_inst], [name_entry | acc_names]}}
            end
          end
        end
      end)

    case result do
      {:ok, inst_rev, names_rev} ->
        {:ok, Enum.reverse(inst_rev), Enum.reverse(names_rev)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_combine(conn, character, instances, name_list) do
    # Consume jingli
    new_vitals = %{character.meta.vitals | jingli: character.meta.vitals.jingli - @jingli_cost}

    # Find matching recipe
    name_set = MapSet.new(name_list)

    recipe =
      Enum.find(@combine_list, fn {ingredients, _result} ->
        ingredient_set = MapSet.new(ingredients)
        MapSet.equal?(name_set, ingredient_set) and length(ingredients) == length(name_list)
      end)

    {text, new_inventory, new_max_jingli} =
      case recipe do
        {_ingredients, result_id} ->
          # Consume ingredient instances (destruct)
          new_inventory =
            character.inventory
            |> Enum.reject(fn inst -> Enum.any?(instances, &(&1.id == inst.id)) end)

          # Attempt to create result item
          if Items.known?(result_id) do
            result_item = Items.get(result_id)
            result_instance = %Kalevala.World.Item.Instance{
              id: Kalevala.World.Item.Instance.generate_id(),
              item_id: result_id,
              item: result_item
            }

            new_inventory = [result_instance | new_inventory]

            text =
              "霎时间只见万道光华疾闪而过，你急忙摊开手掌，发现掌心\n豁然出现了一#{result_item.unit || "个"}#{result_item.name}，蕴漾着七色霞光。\n"

            {text, new_inventory, -1}
          else
            {"可是过了半天，似乎没有任何变化，你不禁一声长叹。\n", character.inventory, 0}
          end

        nil ->
          {"可是过了半天，似乎没有任何变化，你不禁一声长叹。\n", character.inventory, 0}
      end

    # Update max_jingli
    new_vitals =
      if new_max_jingli < 0 do
        %{new_vitals | max_jingli: max(1, new_vitals.max_jingli + new_max_jingli)}
      else
        new_vitals
      end

    new_meta = %{character.meta | vitals: new_vitals}
    new_character = %{character | meta: new_meta, inventory: new_inventory}
    new_conn = put_character(conn, new_character)

    new_conn
    |> render(CommandView, "text", %{text: "你双目微闭，将数样物品凝于掌中，运转内劲迫\n使它们交融。\n\n" <> text})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end