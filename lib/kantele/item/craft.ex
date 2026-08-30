defmodule Kantele.Item.Craft do
  @moduledoc """
  自制道具等级/属性（对应 `feature/itemmake.c`）

  纯计算部分：
  - `weapon_level/1`: 按 `owner` 累积 & `/100` clamps 到等级阈值；满级 + magic → ULTRA
  - `armor_level/1`: 防御等级（暂恒 0）
  - `is_equiped_weapon?/1` / `is_unarmed_weapon?/1`: 武器/空手判型
  - `apply_damage/1` / `apply_armor/1`: 攻/防结算
  - `chinese_s/1`: 魔力属性中文（cold/fire/magic/lighting）
  - `item_owner/2`: 由物品 id 解析主人（LPC 由文件名解析）

  等级阈值对照 itemmake.c：#define（5/10/30/100/300/1000/3000/10000/50000）。
  """
  alias Kantele.Item.Craft.Level

  @doc "是否自制道具 (is_item_make)"
  def is_item_make?(_), do: true

  @doc "攻击等级：owner 各键求和 /100，clamp 到 MAX_LEVEL；满且 magic(power/imbue_ok) → ULTRA"
  def weapon_level(owner, magic \\ %{}) do
    total = if is_map(owner), do: Enum.reduce(owner, 0, fn {_k, v}, acc -> acc + v end), else: 0
    lvl = div(total, 100)

    lvl =
      if lvl > Level.max(), do: Level.max(), else: lvl

    if lvl == Level.max() and (Map.get(magic, :power) || Map.get(magic, :imbue_ok)) do
      Level.ultra()
    else
      lvl
    end
  end

  @doc "防御等级（暂恒 0，LPC armor_level 未实现）"
  def armor_level(_), do: 0

  @doc "是否已装备武器 (is_equiped_weapon)"
  def is_equiped_weapon?(meta), do: is_binary(Map.get(meta, :skill_type))

  @doc "是否空手武器装备 (is_unarmed_weapon)"
  def is_unarmed_weapon?(meta), do: Map.get(meta, :armor_type) == "hands"

  @doc "item_long 是否走武器长描述"
  def item_long?(meta), do: is_equiped_weapon?(meta) or is_unarmed_weapon?(meta)

  @doc "apply_damage：按等级平方/81 加权 point，再加圣化 bless*2"
  def apply_damage(level, point, bless) do
    lvl = Level.rank(level)
    p = div(point, 2)
    d = trunc(Float.round(1.0 * (lvl * lvl) / (9 * 9) * p)) + bless * 2
    d + p
  end

  @doc "apply_armor：point + bless*2（LPC 简化算法）"
  def apply_armor(point, bless) do
    point + bless * 2
  end

  @doc "魔力属性中文 (chinese_s)：cold/fire/magic/lighting"
  def chinese_s(nil), do: "无"
  def chinese_s("cold"), do: "冰"
  def chinese_s("fire"), do: "火"
  def chinese_s("magic"), do: "魔"
  def chinese_s("lighting"), do: "电"
  def chinese_s(_), do: "无"

  @doc "item_owner：由物品 id 解析主人（LPC sscanf pattern: ITEM_DIR %*s/%s-%*s）"
  def item_owner(item_id) when is_binary(item_id) do
    case Regex.run(~r/^(.+)-[^-]+$/, item_id) do
      [_, owner] -> owner
      _ -> nil
    end
  end

  def item_owner(_), do: nil

  @doc """
  武器长描述（weapon_long）：根据 combat 统计生成武器描述

  - `combat` - 战斗统计映射，包含 MKS（杀怪数）、PKS（杀人次数）、WPK_GOOD/WPK_BAD（正/邪击杀）
  - `name` - 武器名称
  - `unit` - 单位（把/柄/支等）
  - `point` - 基础伤害值
  - `bless` - 圣化次数
  - `attack_lvl` - 攻击等级
  - `magic` - 魔力属性映射 %{type, power, imbue, imbue_ok, tessera, blood}
  """
  def weapon_long(meta) do
    combat = Map.get(meta, :combat) || %{}
    name = Map.get(meta, :name) || "武器"
    unit = Map.get(meta, :unit) || "把"

    mks = Map.get(combat, :MKS, 0)
    pks = Map.get(combat, :PKS, 0)
    k = mks + pks

    type =
      cond do
        Map.get(combat, :WPK_GOOD, 0) < div(k, 2) and Map.get(combat, :WPK_BAD, 0) < div(k, 2) ->
          0

        Map.get(combat, :WPK_GOOD, 0) > Map.get(combat, :WPK_BAD, 0) * 2 ->
          -1

        true ->
          1
      end

    cond do
      k < 10 ->
        "这#{unit}#{name}看来已经用过人血开祭，上面隐现血痕。\n"

      true ->
        attack_lvl = weapon_level(Map.get(meta, :owner), Map.get(meta, :magic))
        result = weapon_long_description(type, attack_lvl, name, unit, meta)
        result <> weapon_stats(meta, attack_lvl)
    end
  end

  defp weapon_long_description(type, attack_lvl, name, unit, meta) do
    _bless = Map.get(meta, :bless, 0)
    magic = Map.get(meta, :magic, %{})

    base_desc = weapon_base_description(type, attack_lvl, name, unit)

    if attack_lvl > Level.max() do
      tessera = Map.get(magic, :tessera)
      tessera_part =
        if tessera do
          "它上面镶嵌着#{tessera}，闪烁着奇异的光芒。\n"
        else
          ""
        end

      "#{tessera_part}#{base_desc}#{name}的等级：无上神品  LV10\n"
    else
      rank = Level.rank(attack_lvl)

      level_part =
        if rank > 0 and rank < 9 do
          threshold = Enum.at(Level.levels(), rank) || Level.max()
          "#{name}的等级：#{rank}/9（升级进度：#{attack_lvl}/#{threshold}）\n"
        else
          "#{name}的等级：#{rank}/9\n"
        end

      imbue = Map.get(magic, :imbue, 0)
      imbue_part =
        cond do
          Map.get(magic, :imbue_ok) ->
            "#{name}已经充分的浸入了，需要镶嵌以充分发挥威力。\n"

          imbue > 0 ->
            "#{name}已经运用灵物浸入了#{imbue}次，正在激发它的潜能。\n"

          true ->
            ""
        end

      base_desc <> level_part <> imbue_part
    end
  end

  defp weapon_base_description(type, attack_lvl, name, unit) do
    cond do
      type == 1 -> weapon_desc_good(attack_lvl, name, unit)
      type == -1 -> weapon_desc_evil(attack_lvl, name, unit)
      true -> weapon_desc_neutral(attack_lvl, name, unit)
    end
  end

  defp weapon_desc_good(attack_lvl, name, unit) do
    cond do
      attack_lvl > Level.ultra() ->
        "它看上去平平常常，没有半点特殊，只是隐隐的让人感到那不凡的气质。\n"

      attack_lvl > Level.max() ->
        "它看上去让人发自内心无限崇敬，一股皓然正气悠然长存，颇具帝王风范，君临天下，威镇诸路凶神恶煞、难道这就是传说中的诸神之#{name}？\n"

      attack_lvl >= 10_000 ->
        "一眼望去，你觉得有无数的凶灵在疯狂乱舞，哭天抢地，凄烈之极，似乎要重返人间。你忍不住要长叹一声，昔日凶魔，也难逃死劫。\n"

      attack_lvl >= 3_000 ->
        "它上面附着着不知多少凶魂，无数邪派凶魔毙命于下，一股哀气犹然不散，让你忍不住打了个冷战。\n"

      attack_lvl >= 1_000 ->
        "它看上去令人惊心动魄，这就是名动江湖的#{name}，多少凶煞就此毙命，成就人间正义。\n"

      attack_lvl >= 300 ->
        "它上面隐隐然透出一股血光，多年以来，许多江湖上闻名一时的凶魔都成了#{name}下的游魂。\n"

      attack_lvl >= 100 ->
        "这就是江湖上著名的神兵之一：#{name}，穷凶极恶之徒见此物无不心驰神摇。\n"

      attack_lvl >= 30 ->
        "这#{unit}#{name}有一股正气散发出来，看来它下面凶魂不少。\n"

      attack_lvl >= 10 ->
        "这#{unit}#{name}隐然透出一股正气，看来它杀了不少凶恶之徒。\n"

      attack_lvl >= 5 ->
        "细观之下，刃口有一丝血痕，想必是它杀人不少，殷血于此吧！\n"

      true ->
        "看得出这#{unit}#{name}曾经杀过不少凶恶之徒。\n"
    end
  end

  defp weapon_desc_evil(attack_lvl, name, unit) do
    cond do
      attack_lvl > Level.ultra() ->
        "它看上去平平常常，没有半点特殊，但是不知为何却总是让人感到有些不安。\n"

      attack_lvl > Level.max() ->
        "它看上去让人打心底泛出阵阵寒意，隐隐然上面似乎附着着无数冤魂，但是全然被这#{unit}#{name}上面的杀气所制，难道这就是传说中的邪神之#{name}？\n"

      attack_lvl >= 10_000 ->
        "一眼望去，你觉得有无数的冤魂向你扑来，哭天抢地，凄烈之极，你忍不住打了个寒战，不敢再看第二眼。\n"

      attack_lvl >= 3_000 ->
        "它上面附着着不知多少冤魂，无数高手饮恨于下，一股怨气直冲霄汉，让你忍不住打了个冷战。\n"

      attack_lvl >= 1_000 ->
        "它看上去令人惊心动魄，这就是名动江湖的#{name}，不知多少英雄就此饮恨。\n"

      attack_lvl >= 300 ->
        "它上面隐隐然透出一股血光，多年以来，许多江湖上闻名一时的高手都成了#{name}下的游魂。\n"

      attack_lvl >= 100 ->
        "这就是江湖上著名的凶器之一：#{name}，谁曾想那么多仁人义士饮恨于下。\n"

      attack_lvl >= 30 ->
        "这#{unit}#{name}有一股戾气散发出来，看来它下面游魂不少。\n"

      attack_lvl >= 10 ->
        "这#{unit}#{name}隐然透出一股戾气，看来它杀了不少人。\n"

      attack_lvl >= 5 ->
        "细观之下，刃口有一丝血痕，想必是它杀人不少，殷血于此吧！\n"

      true ->
        "看得出这#{unit}#{name}曾经杀过不少侠义之士。\n"
    end
  end

  defp weapon_desc_neutral(attack_lvl, name, unit) do
    cond do
      attack_lvl > Level.ultra() ->
        "它看上去平平常常，没有半点特殊，只是一件平凡之极的兵器而已。\n"

      attack_lvl > Level.max() ->
        "它安然畅意，似乎就要腾空而去，跳出三界，不入五行。世间万物，仿佛俱在它霸气所及之处。冤魂不舞、群邪辟易，无不被这#{unit}#{name}上古神兵的霸气所制。\n"

      attack_lvl >= 10_000 ->
        "一眼望去，你觉得有无数的游魂向你扑来，哭天抢地，凄烈之极，你顿时觉得它沉重无比，几乎拿捏不住。\n"

      attack_lvl >= 3_000 ->
        "它上面附着着不知多少游魂，无数正邪高手丧命于下，一股怨气哀愁油然不尽，让你忍不住打了个冷战。\n"

      attack_lvl >= 1_000 ->
        "它看上去令人惊心动魄，这就是名动江湖的#{name}，多少正邪高手都难逃此劫，堕入轮回。\n"

      attack_lvl >= 300 ->
        "它上面隐隐然透出一股血光，多年以来，许多江湖上闻名一时的高手都成了这#{unit}#{name}下的游魂。\n"

      attack_lvl >= 100 ->
        "这就是江湖上著名的利器之一：#{name}，谁能想到那么多高手饮恨于下。\n"

      attack_lvl >= 30 ->
        "这#{unit}#{name}有一股杀气散发出来，看来它下面游魂不少。\n"

      attack_lvl >= 10 ->
        "这#{unit}#{name}隐然透出一股杀气，看来它杀了不少人。\n"

      attack_lvl >= 5 ->
        "细观之下，刃口有一丝血痕，想必是它杀人不少，殷血于此吧！\n"

      true ->
        "看得出这#{unit}#{name}曾经杀过不少人。\n"
    end
  end

  defp weapon_stats(meta, _attack_lvl) do
    bless = Map.get(meta, :bless, 0)
    magic = Map.get(meta, :magic, %{})

    "-------------------------------------\n" <>
    "坚固修正： #{bless}\t" <>
    "攻·防修正：#{bless * 2}\n" <>
    "圣化次数： #{bless}\t" <>
    "魔力改善值：#{Map.get(magic, :power, 0)}\n" <>
    "魔力属性：#{chinese_s(Map.get(magic, :type))}\t" <>
    "人器融合度：#{Map.get(magic, :blood, 0)}\n" <>
    "-------------------------------------\n"
  end

  defmodule Level do
    @moduledoc "itemmake.c 等级阈值与换算"

    @levels [5, 10, 30, 100, 300, 1000, 3000, 10_000, 50_000]
    @max 50_000
    @ultra 50_001

    @doc "等级阈值表"
    def levels(), do: @levels

    @doc "MAX_LEVEL（满级）"
    def max(), do: @max

    @doc "ULTRA_LEVEL（无上神品）"
    def ultra(), do: @ultra

    @doc "攻击等级 → 1..9（LPC: while(--lvl) if(attack_lvl>=levels[lvl]) break; lvl++）"
    def rank(attack_lvl) when is_integer(attack_lvl) do
      # LPC 循环从 lvl=8 递减到 1 判断，levels[0]=5 永不参与 → 用 tl() 剔除之
      count = Enum.count(tl(@levels), fn threshold -> attack_lvl >= threshold end)
      count + 1
    end

    def rank(_), do: 0
  end

  @doc """
  ITEM_D 委托动作（对应 itemmake.c 的委托函数）

  这些函数处理自制武器的强化流程：
  - killer_reward: 记录击杀，更新 owner 和 combat 统计
  - do_san: 圣化（需要前置条件检查）
  - do_imbue: 浸透（需要圣化完成）
  - do_enchase: 镶嵌（需要浸透完成）

  宿主接线说明：
  - 实际 stat 消耗（jingli/neili/exp/potential）由命令层处理
  - 消息发送由命令层处理
  - 本模块仅处理物品状态数据更新
  """

  @san_per_imbue 1
  @random_imbue_ok 50

  @doc """
  killer_reward：记录击杀奖励

  更新 item meta：
  - combat/MKS 或 PKS：击杀计数
  - combat/WPK_GOOD/WPK_BAD：正邪击杀
  - combat/WPK_NOTGOOD/WPK_NOTBAD：善恶击杀
  - owner：武器归属映射（最多12人）
  """
  def killer_reward(item_meta, killer_meta, victim_meta) when is_map(item_meta) and is_map(killer_meta) and is_map(victim_meta) do
    item_meta
    |> update_combat_on_kill(victim_meta)
    |> update_owner_on_kill(killer_meta, victim_meta)
  end

  defp update_combat_on_kill(item_meta, victim_meta) do
    combat = Map.get(item_meta, :combat, %{})

    combat =
      cond do
        Map.get(victim_meta, :is_not_bad, false) ->
          Map.update(combat, :WPK_NOTBAD, 1, &(&1 + 1))

        true ->
          combat
      end
      |> cond_combat_update(:WPK_NOTGOOD, Map.get(victim_meta, :is_not_good, false))
      |> cond_combat_update(:WPK_GOOD, Map.get(victim_meta, :is_good, false))
      |> cond_combat_update(:WPK_BAD, Map.get(victim_meta, :is_bad, false))
      |> cond_combat_update(:MKS, !Map.get(victim_meta, :can_speak, false))
      |> cond_combat_update(:PKS, Map.get(victim_meta, :can_speak, false))

    Map.put(item_meta, :combat, combat)
  end

  defp cond_combat_update(combat, _key, false), do: combat
  defp cond_combat_update(combat, key, true), do: Map.update(combat, key, 1, &(&1 + 1))

  defp update_owner_on_kill(item_meta, killer_meta, victim_meta) do
    victim_exp = Map.get(victim_meta, :combat_exp, 0)
    killer_exp = Map.get(killer_meta, :combat_exp, 0)

    if victim_exp < 10_000 || killer_exp < victim_exp * 4 / 5 do
      item_meta
    else
      exp = div(victim_exp, 10_000)
      exp = if exp > 250, do: 100 + div(exp - 250, 16), else: if exp > 50, do: 50 + div(exp - 50, 4), else: exp
      exp = min(exp, 250)

      killer_id = Map.get(killer_meta, :id, "unknown")
      owner = Map.get(item_meta, :owner, %{})

      owner_size = map_size(owner)

      {owner, _} =
        if Map.has_key?(owner, killer_id) || owner_size < 12 do
          {Map.update(owner, killer_id, exp, &(&1 + exp)), :ok}
        else
          lowest_key = find_lowest_owner(owner)
          {owner |> Map.delete(lowest_key) |> Map.put(killer_id, exp), :evicted}
        end

      Map.put(item_meta, :owner, owner)
    end
  end

  defp find_lowest_owner(owner) do
    owner
    |> Map.to_list()
    |> Enum.min_by(fn {_k, v} -> v end)
    |> elem(0)
  end

  @doc """
  Do_san 前置条件检查

  返回 {:ok, reasons} 如果可以圣化，或 {:error, reason}
  """
  def can_san?(item_meta, player_meta) do
    magic = Map.get(item_meta, :magic) || %{}
    power = Map.get(magic, :power, 0)
    imbue_ok = Map.get(magic, :imbue_ok, false)
    imbue_ob = Map.get(magic, :imbue_ob)
    do_san = Map.get(magic, :do_san) || %{}

    cond do
      !is_weapon_or_hands?(item_meta) ->
        {:error, "装备现在还无法圣化"}

      power > 0 ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的威力已经得到了充分的发挥了"}

      imbue_ok ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的潜力已经充分挖掘了，现在只是需要最后一步融合"}

      imbue_ob != nil ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}已经被充分的圣化了，需要浸入神物以进一步磨练"}

      Map.has_key?(do_san, Map.get(player_meta, :id, "")) ->
        {:error, "你已经为#{Map.get(item_meta, :name, "装备")}圣化过了"}

      Map.get(player_meta, :neili, 0) < Map.get(player_meta, :max_neili, 1) * 9 / 10 ->
        {:error, "你现在内力并不充沛，怎敢贸然运用"}

      Map.get(player_meta, :jingli, 0) < Map.get(player_meta, :max_jingli, 1) * 9 / 10 ->
        {:error, "你现在精力不济，怎敢贸然运用"}

      get_skill(player_meta, "force") < 300 ->
        {:error, "你的内功根基不够扎实，不能贸然圣化"}

      Map.get(player_meta, :max_neili, 0) < 8000 ->
        {:error, "你尝试运了一下内力，无法顺利运足一个周天，难以施展你的能力"}

      Map.get(player_meta, :max_jingli, 0) < 1000 ->
        {:error, "你试图凝神运用精力，但是感觉尚有欠缺"}

      true ->
        :ok
    end
  end

  @doc """
  do_san 执行圣化（更新物品状态）

  返回更新后的 item_meta
  """
  def do_san(item_meta, player_meta) do
    player_id = Map.get(player_meta, :id, "unknown")
    player_name = Map.get(player_meta, :name, "某人")

    item_meta
    |> put_in([:magic, :do_san, player_id], player_name)
  end

  @doc """
  do_imbue 前置条件检查

  返回 {:ok, reasons} 如果可以浸透，或 {:error, reason}
  """
  def can_imbue?(item_meta, _player_meta, _imbue_item) do
    magic = Map.get(item_meta, :magic) || %{}
    power = Map.get(magic, :power, 0)
    imbue_ok = Map.get(magic, :imbue_ok, false)

    cond do
      power > 0 ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的威力已经得到了充分的发挥了"}

      imbue_ok ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的潜力已经充分挖掘了，现在只是需要最后一步融合"}

      true ->
        do_san = Map.get(magic, :do_san) || %{}
        san_count = Kernel.map_size(do_san)
        if san_count < @san_per_imbue do
          {:error, "你必须先对#{Map.get(item_meta, :name, "装备")}进行充分的圣化才行"}
        else
          :ok
        end
    end
  end

  @doc """
  do_imbue 执行浸透

  返回 {:ok, new_item_meta} 或 {:error, reason}
  """
  def do_imbue(item_meta) do
    current_imbue = get_in(item_meta, [:magic, :imbue]) || 0

    meta =
      item_meta
      |> update_in([:magic, :do_san], fn _ -> %{} end)
      |> update_in([:magic, :imbue_ob], fn _ -> nil end)
      |> update_in([:magic, :imbue], &((&1 || 0) + 1))

    if current_imbue >= @random_imbue_ok do
      {:ok, put_in(meta, [:magic, :imbue_ok], true)}
    else
      {:ok, meta}
    end
  end

  @doc """
  do_enchase 前置条件检查

  返回 {:ok, reasons} 如果可以镶嵌，或 {:error, reason}
  """
  def can_enchase?(item_meta, player_meta, tessera_meta) do
    magic = Map.get(item_meta, :magic) || %{}
    power = Map.get(magic, :power, 0)
    imbue_ok = Map.get(magic, :imbue_ok, false)

    cond do
      power > 0 ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的威力已经得到了充分的发挥了"}

      !imbue_ok ->
        {:error, "现在#{Map.get(item_meta, :name, "装备")}的潜力还没有充分的激发，未到镶嵌的时候"}

      !Map.get(tessera_meta, :can_be_enchased, false) ->
        {:error, "#{Map.get(tessera_meta, :name, "宝石")}没法用来镶嵌吧"}

      !Map.has_key?(tessera_meta, :magic) ->
        {:error, "#{Map.get(tessera_meta, :name, "宝石")}不能发挥魔力，没有必要镶嵌"}

      get_skill(player_meta, "certosina") < 200 ->
        {:error, "你觉得你的镶嵌技艺还不够娴熟，不敢贸然动手"}

      true ->
        :ok
    end
  end

  @doc """
  do_enchase 执行镶嵌

  返回更新后的 item_meta
  """
  def do_enchase(item_meta, tessera_meta) do
    magic = Map.get(tessera_meta, :magic, %{})

    item_meta
    |> put_in([:magic, :power], Map.get(magic, :power, 0))
    |> put_in([:magic, :type], Map.get(magic, :type, "magic"))
    |> put_in([:magic, :tessera], Map.get(tessera_meta, :name, "宝石"))
    |> update_in([:weight], &((&1 || 0) + Map.get(tessera_meta, :weight, 0)))
  end

  defp is_weapon_or_hands?(meta) do
    is_binary(Map.get(meta, :skill_type)) || Map.get(meta, :armor_type) == "hands"
  end

  defp get_skill(player_meta, skill_name, default \\ 0) do
    (player_meta[:skills] || %{})[skill_name] || default
  end
end
