defmodule Kantele.Item.ExtraLong do
  @moduledoc """
  武器/防具 extra_long 描述系统（对应 LPC inherit/weapon/*.c 和 inherit/armor/*.c extra_long）

  生成 wield/wear 时显示的详细描述，包括：
  - 物品类型（兵器/防具）
  - 绑定类型
  - 重量
  - 伤害力/防护力
  - 镶嵌凹槽
  - 装备要求
  - 下线丢失
  """

  @doc """
  生成武器 extra_long 描述

  返回 binary 字符串或 nil。
  """
  def weapon(skill_type, meta) do
    type_name = weapon_type_name(skill_type)

    build_desc(
      "兵器(#{type_name})",
      meta
    )
  end

  @doc """
  生成防具 extra_long 描述

  返回 binary 字符串或 nil。
  """
  def armor(armor_type, meta) do
    type_name = armor_type_name(armor_type)

    build_desc(
      "防具(#{type_name})",
      meta
    )
  end

  defp build_desc(category_name, meta) do
    bindable_type = bindable_name(meta["bindable"])
    weight = meta["weight"] || 0
    damage = get_in(meta, ["weapon_prop", "damage"]) || 0
    armor_val = get_in(meta, ["armor_prop", "armor"]) || 0
    flute = get_in(meta, ["enchase", "flute"]) || 0
    need = meta["need"] || %{}
    autoload = meta["autoload"] || false

    lines = [
      "\n物品类型 : #{category_name}",
      if(bindable_type, do: "绑定类型 : #{bindable_type}"),
      "重    量 : #{weight}",
      if(damage > 0, do: "伤 害 力 : #{damage}"),
      if(armor_val > 0, do: "防 护 力 : #{armor_val}"),
      if(flute > 0, do: "镶嵌凹槽 : #{flute}"),
      build_need_lines(need),
      "下线丢失 : #{if(autoload, do: "否", else: "是")}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")

    lines
  end

  defp weapon_type_name("sword"), do: "剑"
  defp weapon_type_name("blade"), do: "刀"
  defp weapon_type_name("staff"), do: "杖"
  defp weapon_type_name("axe"), do: "斧"
  defp weapon_type_name("club"), do: "棍"
  defp weapon_type_name("dagger"), do: "匕首"
  defp weapon_type_name("fork"), do: "叉"
  defp weapon_type_name("hammer"), do: "锤"
  defp weapon_type_name("pin"), do: "针"
  defp weapon_type_name("whip"), do: "鞭"
  defp weapon_type_name("bow"), do: "弓"
  defp weapon_type_name("throwing"), do: "暗器"
  defp weapon_type_name("xsword"), do: "玄铁剑"
  defp weapon_type_name(_), do: "兵器"

  defp armor_type_name("cloth"), do: "衣服"
  defp armor_type_name("boots"), do: "靴子"
  defp armor_type_name("head"), do: "护头盔"
  defp armor_type_name("neck"), do: "护项链"
  defp armor_type_name("finger"), do: "护戒指"
  defp armor_type_name("waist"), do: "护腰带"
  defp armor_type_name("wrists"), do: "护腕"
  defp armor_type_name("hands"), do: "护手套"
  defp armor_type_name("shield"), do: "盾牌"
  defp armor_type_name("surcoat"), do: "外袍"
  defp armor_type_name("charm"), do: "护身符"
  defp armor_type_name(_), do: "防具"

  defp bindable_name(1), do: "装备绑定"
  defp bindable_name(2), do: "拾取绑定"
  defp bindable_name(3), do: "直接绑定"
  defp bindable_name(_), do: nil

  defp build_need_lines(need) when map_size(need) == 0, do: nil

  defp build_need_lines(need) do
    need
    |> Enum.map(fn {key, value} ->
      "装备要求 : #{to_chinese(key)} #{value}"
    end)
    |> Enum.join("\n")
  end

  defp to_chinese("str"), do: "臂力"
  defp to_chinese("int"), do: "悟性"
  defp to_chinese("con"), do: "根骨"
  defp to_chinese("dex"), do: "身法"
  defp to_chinese("kar"), do: "福缘"
  defp to_chinese(key), do: key
end
