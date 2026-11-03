defmodule Kantele.Character.BornPlayer do
  @moduledoc """
  新玩家「与生俱来」特技授予（对应 LPC `updated.c` 的 `born_player`，updated.c:344-445）。

  LPC 行为基线：
    - 候选池 = `/kungfu/special/` 全部技能文件；
    - 先剔除转世/特殊技能（guibian/guimai/jinshen/piyi/lighting/qinzong/wuxing/
      shenyan/tiandao/herb/wrach/trick）；
    - 性格不符再剔 wrath（仅「光明磊落」「心狠手辣」可保留）、trick（仅「狡黠多变」
      「阴险奸诈」可保留，已在上一步剔除，这里不再处理）；
    - 先天属性 < 20 剔对应技能：str→strength、int→intellect/clever、con→constitution、
      dex→dexterity、per→youth；
    - 随机赠 1–3 项（池空则 0 项）；命中 strength/intellect/constitution/dexterity
      再各 +2 对应属性。

  Ex 落点：
    - 授予形状与既有 `SpecialSkills` 宿主一致——`character.attributes["special_skills"]
      [id] = true`（与 poison.ex / room.ex 读取点对齐）。
    - 同时把授予 id 列表镜像进 `meta.env[:special_skills]`，由
      `Records.apply_to_character` 在重登时回灌进 `attributes`，避免重登即丢
      （`attributes` 当前未进 DB 列，属本仓库 SpecialSkills 子系统既有缺口；
      此处用 env 镜像做到「落盘 + 回灌」，与计划 D4 钩子占位精神一致）。
    - 真实特技效果待各技能模块接入；当前只负责「按 LPC 规则确定授予集合并落标」。
  """

  # LPC `/kungfu/special/` 全部技能文件名（updated.c:354 的 `get_dir` 等价）
  @all_specials [
    "accuracy", "agile", "clever", "constitution", "cunning", "dexterity",
    "divine", "energy", "greedy", "guibian", "guimai", "hatred", "health",
    "herb", "intellect", "ironskin", "jinshen", "lighting", "lucky", "might",
    "mystery", "piyi", "potential", "power", "qinzong", "self", "shenyan",
    "strength", "tiandao", "trick", "wrath", "wuxing", "youth"
  ]

  # 取消师门药品奖励等被剔除的技能（updated.c:364-366）
  @hard_excluded %{
    "guibian" => true, "guimai" => true, "jinshen" => true, "piyi" => true,
    "lighting" => true, "qinzong" => true, "wuxing" => true, "shenyan" => true,
    "tiandao" => true, "herb" => true, "wrach" => true, "trick" => true
  }

  # 命中后额外 +2 的属性（updated.c:425-438 只列了这四项）
  @bonus_map %{
    "strength" => :str,
    "intellect" => :int,
    "constitution" => :con,
    "dexterity" => :dex
  }

  # 显示名（LPC `SPECIAL_D(special)->name()` 等价），用于问答回显；缺失时回退到 id
  @names %{
    "accuracy" => "精准之体", "agile" => "身轻如燕", "clever" => "天赋聪颖",
    "constitution" => "镇蕴七星", "cunning" => "狡黠", "dexterity" => "玲珑玉躯",
    "divine" => "神佑", "energy" => "精力充沛", "greedy" => "贪婪",
    "hatred" => "仇恨之心", "health" => "康健", "intellect" => "罡睿神慧",
    "ironskin" => "铁布衫", "lucky" => "福星高照", "might" => "神力",
    "mystery" => "神秘", "power" => "力大无穷", "self" => "自在",
    "strength" => "麒麟血臂", "youth" => "天颜永驻", "wrath" => "愤怒之心"
  }

  @doc "显示名（回显用）"
  def display_name(id), do: Map.get(@names, id, id)

  @doc """
  计算授予候选池（纯函数，便于测试）。

  `character` 为 Kalevala `Character`；`character.meta.character` 为天性
  （新玩家恒 nil）。返回 eligible 技能 id 列表。
  """
  def candidate_pool(character) do
    character
    |> base_pool()
    |> reject_by_stats(stats_of(character))
  end

  defp stats_of(character), do: get_in(character, [Access.key(:meta), Access.key(:stats)])

  # 基础池 = 全部技能 − 硬性剔除集 − wrath（仅「光明磊落」「心狠手辣」可保留，
  # 新玩家 character 恒 nil，故 wrath 恒剔除；updated.c:364-373）
  defp base_pool(character) do
    char = get_in(character, [Access.key(:meta), Access.key(:character)])

    @all_specials
    |> Enum.reject(&Map.has_key?(@hard_excluded, &1))
    |> reject_wrath(char)
  end

  defp reject_wrath(pool, char) when char in ["光明磊落", "心狠手辣"], do: pool
  defp reject_wrath(pool, _char), do: Enum.reject(pool, &(&1 == "wrath"))

  # 属性 < 20 剔对应技能（updated.c:376-397）
  defp reject_by_stats(pool, stats) when is_map(stats) do
    pool
    |> reject_if(stats.str < 20, "strength")
    |> reject_if(stats.int < 20, "intellect")
    |> reject_if(stats.int < 20, "clever")
    |> reject_if(stats.con < 20, "constitution")
    |> reject_if(stats.dex < 20, "dexterity")
    |> reject_if(stats.per < 20, "youth")
  end

  defp reject_by_stats(pool, _stats), do: pool

  defp reject_if(pool, false, _id), do: pool
  defp reject_if(pool, true, id), do: Enum.reject(pool, &(&1 == id))

  @doc """
  授予「与生俱来」特技（updated.c:399-442）。

  返回更新后的 `character`：`attributes["special_skills"]` 已置标，
  `meta.env[:special_skills]` 镜像授予列表，`str/int/con/dex` 命中 +2。

  `picker` 可注入（默认 `&Enum.random/1`）以便测试固定选取。
  """
  def grant(character, picker \\ &Enum.random/1) do
    granted = pick_skills(candidate_pool(character), picker)

    character
    |> apply_grants(granted)
    |> apply_bonuses(granted)
    |> mirror_to_env(granted)
  end

  # 随机赠 1–3 项（updated.c 的「第一项/第二项/第三项」逻辑）
  defp pick_skills([], _picker), do: []

  defp pick_skills(pool, picker) when is_list(pool) do
    first = picker.(pool)
    rest1 = List.delete(pool, first)

    second =
      if rest1 != [] do
        picker.(rest1)
      else
        nil
      end

    rest2 = if second, do: List.delete(rest1, second), else: []

    third =
      if rest2 != [] do
        picker.(rest2)
      else
        nil
      end

    Enum.reject([first, second, third], &is_nil/1)
  end

  defp apply_grants(character, granted) do
    if granted == [] do
      character
    else
      existing = Map.get(character.attributes, "special_skills", %{})

      specials =
        Enum.reduce(granted, existing, fn id, acc ->
          Map.put(acc, id, true)
        end)

      %{character | attributes: Map.put(character.attributes, "special_skills", specials)}
    end
  end

  defp apply_bonuses(character, granted) do
    Enum.reduce(granted, character, fn id, char ->
      case Map.get(@bonus_map, id) do
        nil ->
          char

        attr ->
          stats = char.meta.stats
          updated = Map.update!(stats, attr, &(&1 + 2))
          put_in(char.meta.stats, updated)
      end
    end)
  end

  defp mirror_to_env(character, granted) do
    env = Map.get(character.meta, :env, %{}) || %{}
    put_in(character.meta.env, Map.put(env, :special_skills, granted))
  end
end
