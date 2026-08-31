defmodule Kantele.NPC.Horseboss do
  @moduledoc """
  马夫 NPC（对应 lpc_example/ex/npc_horseboss/）

  功能：
  - 售卖坐骑（19 种，含马、驴、骡、骆驼等）
  - 向导流程：选择种类 -> 性别 -> ID -> 名字 -> 描述
  - 临时状态存储 (PlayerMeta.temp)
  - 售价 100 金（1,000,000 铜币）
  - 训练技能要求：30 级
  - 随机属性变异（±10%）
  """
  alias Kantele.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Item
  alias Kantele.Character.Stats
  alias Kantele.Character.Combat

  @species %{
    horse: [name: "马", suffix: "ma", unit: "匹", base: [str: 30, con: 25, dex: 20, int: 10]],
    donkey: [name: "驴", suffix: "lv", unit: "头", base: [str: 25, con: 30, dex: 15, int: 10]],
    mule: [name: "骡", suffix: "luo", unit: "头", base: [str: 35, con: 35, dex: 10, int: 10]],
    camel: [name: "骆驼", suffix: "tuo", unit: "头", base: [str: 40, con: 40, dex: 10, int: 10]],
    ox: [name: "牛", suffix: "niu", unit: "头", base: [str: 45, con: 45, dex: 5, int: 10]],
    elephant: [name: "大象", suffix: "xiang", unit: "头", base: [str: 60, con: 50, dex: 5, int: 15]],
    lion: [name: "狮子", suffix: "shi", unit: "头", base: [str: 50, con: 40, dex: 30, int: 15]],
    tiger: [name: "老虎", suffix: "hu", unit: "头", base: [str: 55, con: 40, dex: 35, int: 15]],
    leopard: [name: "豹子", suffix: "bao", unit: "头", base: [str: 45, con: 35, dex: 40, int: 15]],
    deer: [name: "鹿", suffix: "lu", unit: "头", base: [str: 25, con: 30, dex: 45, int: 15]],
    crane: [name: "仙鹤", suffix: "he", unit: "只", base: [str: 20, con: 25, dex: 50, int: 20]],
    eagle: [name: "老鹰", suffix: "diao", unit: "只", base: [str: 30, con: 25, dex: 55, int: 20]],
    goat: [name: "山羊", suffix: "yang", unit: "只", base: [str: 20, con: 25, dex: 30, int: 10]],
    monkey: [name: "猴子", suffix: "hou", unit: "只", base: [str: 25, con: 25, dex: 50, int: 25]],
    bear: [name: "黑熊", suffix: "xiong", unit: "头", base: [str: 55, con: 50, dex: 15, int: 10]],
    wolf: [name: "狼", suffix: "lang", unit: "头", base: [str: 40, con: 35, dex: 40, int: 15]],
    fox: [name: "狐狸", suffix: "hu", unit: "只", base: [str: 30, con: 30, dex: 45, int: 20]],
    marten: [name: "貂", suffix: "diao", unit: "只", base: [str: 20, con: 25, dex: 50, int: 20]],
    foal: [name: "小马驹", suffix: "ju", unit: "匹", base: [str: 15, con: 15, dex: 20, int: 10]],
    beast: [name: "异兽", suffix: "shou", unit: "头", base: [str: 50, con: 50, dex: 20, int: 10]]
  }

  @price 1_000_000
  @training_req 30

  defstruct [
    :id,
    :name,
    :room_id
  ]

  @doc "初始化马夫"
  def init_npc do
    %__MODULE__{}
  end

  @doc "问候：检查训练技能，显示价格和物种列表"
  def greet(npc, player) do
    cond do
      Stats.skill(player.meta.stats, "training") < @training_req ->
        "马夫摇了摇头：你的驯兽技艺不够（需 #{@training_req} 级），我这儿的牲口你驾驭不了。"

      true ->
        species_list =
          Enum.map_join(Map.keys(@species), "、", fn k ->
            Keyword.get(@species[k], :name)
          end)

        "马夫笑道：客官想买坐骑？我这儿有：#{species_list}。价格 #{@price} 文钱（100 金）。想买哪种？"
    end
  end

  @doc "开始购买流程：记录 species 到 temp"
  def start_purchase(npc, player, species_key) do
    species_key = String.to_atom(species_key)

    if Map.has_key?(@species, species_key) do
      player = PlayerMeta.put_temp(player.meta, "chosen_species", species_key)
      species_name = Keyword.get(@species[species_key], :name)

      "马夫点头：#{species_name} 好选择！公的还是母的？"
    else
      {:error, "没有这种牲口。"}
    end
  end

  @doc "选择性别"
  def choose_gender(npc, player, gender) do
    gender = String.downcase(gender)

    if gender in ["male", "female", "公", "母"] do
      gender = if gender in ["male", "公"], do: "male", else: "female"
      player = PlayerMeta.put_temp(player.meta, "pet_gender", gender)

      "马夫笑道：#{if gender == "male", do: "公", else: "母"}的好！给它起个 ID（英文字母下划线，3-20字符）。"
    else
      {:error, "只能选 male/female 或公/母。"}
    end
  end

  @doc "选择 ID"
  def choose_id(npc, player, id) do
    cond do
      not Regex.match?(~r/^[a-z_]{3,20}$/, id) ->
        {:error, "ID 只能用小写字母和下划线，3-20 字符。"}

      Item.item_exists?(id) ->
        {:error, "这个 ID 已被占用，换个别的。"}

      true ->
        player = PlayerMeta.put_temp(player.meta, "pet_id", id)
        "ID 合法。给它起个名字（2-12 个中文字）。"
    end
  end

  @doc "选择名字"
  def choose_name(npc, player, name) do
    cond do
      not Regex.match?(~r/^[\p{Han}]{2,12}$/, name) ->
        {:error, "名字必须是 2-12 个中文字。"}

      String.length(name) > 12 ->
        {:error, "名字太长了（最多 12 个中文字）。"}

      true ->
        player = PlayerMeta.put_temp(player.meta, "pet_name", name)
        "名字不错！最后写段描述（最多 60 字，可留空）。"
    end
  end

  @doc "选择描述，完成购买"
  def choose_desc(npc, player, desc \\ "") do
    species = PlayerMeta.get_temp(player.meta, "chosen_species")
    gender = PlayerMeta.get_temp(player.meta, "pet_gender")
    base_id = PlayerMeta.get_temp(player.meta, "pet_id")
    name = PlayerMeta.get_temp(player.meta, "pet_name")

    cond do
      is_nil(species) ->
        {:error, "流程异常，请重新开始。"}

      is_nil(gender) ->
        {:error, "流程异常，请重新开始。"}

      is_nil(base_id) ->
        {:error, "流程异常，请重新开始。"}

      is_nil(name) ->
        {:error, "流程异常，请重新开始。"}

      true ->
        species_data = @species[species]
        full_id = base_id <> "_" <> Keyword.get(species_data, :suffix)

        stats = generate_stats(Keyword.get(species_data, :base))

        mount = %{
          id: full_id,
          name: name <> "的" <> Keyword.get(species_data, :name),
          type: "mount",
          species: Keyword.get(species_data, :name),
          gender: gender,
          unit: Keyword.get(species_data, :unit),
          stats: stats,
          description: String.trim(desc) <> "\n主人：#{player.name} (#{player.id})",
          owner: player.id,
          owner_name: player.name,
          summon_id: full_id,
          rideable: true,
          trained: true
        }

        # 创建坐骑物品实例
        mount = Kantele.Mount.create_mount(mount)

        # 给予玩家
        player = Kantele.Mount.give_mount(player, mount)

        # 清理临时状态
        player = clear_temp(player)

        "马夫拍拍手：成交！您的 #{Keyword.get(species_data, :name)} 已备好，用 whistle #{full_id} 召唤。"
    end
  end

  @doc "取消购买，清理临时状态"
  def cancel(npc, player) do
    player = clear_temp(player)
    "马夫挥挥手：不买拉倒，下次再见。"
  end

  # --- 内部函数 ---

  defp generate_stats(base) do
    Enum.into(base, %{}, fn {k, v} ->
      # -10..10
      variance = :rand.uniform(21) - 11
      {k, max(1, v + variance)}
    end)
  end

  defp clear_temp(character) do
    %{
      character
      | meta:
          character.meta
          |> PlayerMeta.delete_temp("chosen_species")
          |> PlayerMeta.delete_temp("pet_gender")
          |> PlayerMeta.delete_temp("pet_id")
          |> PlayerMeta.delete_temp("pet_name")
    }
  end
end
