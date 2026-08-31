defmodule Kantele.World.Room.WuduLiandu do
  @moduledoc """
  五毒炼毒房（对应 ExKantele.World.Room.WuduLiandu / room_wudu_liandu.ex）

  功能：
  - 炼制配方（6 种毒药，含 Wusheng San 合成）
  - 炼制状态机（检查 -> 扣材料 -> 定时 -> 结算）
  - 技能/资源校验
  - 定时回调
  """
  alias Kantele.World.Room
  alias Kantele.Scheduler
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  @min_skill 60
  @min_jing 80
  @min_qi 80
  @base_time_min 15
  @base_time_max 15
  @failure_chance 50
  @failure_roll_max 3

  @recipes %{
    "heding hong" => %{
      name: "Heding Hong",
      ingredients: ["du nang", "shexin zi", "qianri zui"],
      skill_req: 60,
      product: "hedinghong",
      duration: 15,
      level_bonus: 0
    },
    "furou gao" => %{
      name: "Furou Gao",
      ingredients: ["du nang", "fugu cao", "chuanxin lian"],
      skill_req: 60,
      product: "furougao",
      duration: 15,
      level_bonus: 0
    },
    "kongque dan" => %{
      name: "Kongque Dan",
      ingredients: ["du nang", "fugu cao", "qianri zui"],
      skill_req: 60,
      product: "kongquedan",
      duration: 15,
      level_bonus: 0
    },
    "chixie fen" => %{
      name: "Chixie Fen",
      ingredients: ["du nang", "shexin zi", "duanchang cao"],
      skill_req: 60,
      product: "chixiefen",
      duration: 15,
      level_bonus: 0
    },
    "duanchang san" => %{
      name: "Duanchang San",
      ingredients: ["du nang", "duanchang cao", "chuanxin lian"],
      skill_req: 60,
      product: "duanchangsan",
      duration: 15,
      level_bonus: 0
    },
    "wusheng san" => %{
      name: "Wusheng San",
      ingredients: [
        "du nang",
        "shexin zi",
        "qianri zui",
        "duanchang cao",
        "chuanxin lian",
        "jinshe duyu"
      ],
      skill_req: 60,
      product: "wushengsan",
      duration: 25,
      level_bonus: 20
    }
  }

  defstruct [
    :id,
    :key,
    :zone_id,
    :name,
    :description,
    :map_color,
    :map_icon,
    :x,
    :y,
    :z,
    exits: [],
    features: [],
    flags: [],
    # 炼制专用字段
    recipes: @recipes
  ]

  @doc "初始化炼毒房"
  def init_room do
    %{
      recipes: @recipes,
      exits: ["south"],
      features: ["liandu_furnace"],
      flags: []
    }
  end

  @doc "开始炼制"
  def start_crafting(room, player, recipe_name) do
    recipe = Map.fetch!(@recipes, String.downcase(recipe_name))

    cond do
      not faction_match?(player) ->
        {:error, "非五毒教弟子不可炼毒"}

      Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/recipe") ->
        {:error, "你正在炼制中，请稍候"}

      Kantele.Character.Combat.busy?(player.meta.combat) ->
        {:error, "你正忙着呢"}

      Stats.skill(player.meta.stats, "wudu-qishu") < @min_skill ->
        {:error, "你的五毒奇术火候不够"}

      player.meta.vitals.jing < @min_jing ->
        {:error, "你的精力不够"}

      player.meta.vitals.qi < @min_qi ->
        {:error, "你的气血不够"}

      not has_ingredients?(player, recipe.ingredients) ->
        {:error, "材料不足"}

      true ->
        consume_ingredients(player, recipe.ingredients)
        duration = recipe.duration + :rand.uniform(@base_time_max)

        player =
          Kantele.Character.PlayerMeta.put_temp(player.meta, "liandu/recipe", recipe.product)

        player =
          Kantele.Character.PlayerMeta.put_temp(
            player.meta,
            "liandu/level_bonus",
            recipe.level_bonus
          )

        player = Kantele.Character.PlayerMeta.put_temp(player.meta, "liandu/duration", duration)

        player = Combat.start_busy(player.meta.combat, div(duration, 2) + 1)

        # 设置定时器
        Scheduler.schedule_callback(
          {__MODULE__, :liandu_callback, [player.id]},
          duration * 1000
        )

        {:ok, "开始炼制 #{recipe.name}，约 #{duration} 秒后完成。"}
    end
  end

  @doc "炼制完成回调"
  def liandu_callback(player_id) do
    # 这里需要获取玩家进程并调用
    :ok
  end

  defp faction_match?(player) do
    Map.get(player.meta, :family) == "wudu"
  end

  defp has_ingredients?(player, ingredients) do
    Enum.all?(ingredients, fn item_name ->
      Kantele.Item.has?(player, item_name)
    end)
  end

  defp consume_ingredients(player, ingredients) do
    Enum.each(ingredients, fn item_name ->
      Kantele.Item.take(player, item_name)
    end)
  end

  # 炼制完成处理（需要在玩家进程中调用）
  def liandu_finish(player) do
    recipe = Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/recipe")
    level_bonus = Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/level_bonus") || 0

    # 清理临时状态
    player = Kantele.Character.PlayerMeta.delete_temp(player.meta, "liandu/recipe")
    player = Kantele.Character.PlayerMeta.delete_temp(player.meta, "liandu/level_bonus")
    player = Kantele.Character.PlayerMeta.delete_temp(player.meta, "liandu/duration")

    # 伤害判定
    cond do
      Stats.skill(player.meta.stats, "wudu-qishu") < @failure_chance and
          :rand.uniform(@failure_roll_max) == 1 ->
        # 失败
        dmg_jing = 50 + :rand.uniform(30)
        dmg_qi = 50 + :rand.uniform(30)

        Vitals.damage(player.meta.vitals, :jing, dmg_jing)
        Vitals.damage(player.meta.vitals, :qi, dmg_qi)

        {:error, "炼制失败！你损失了 #{dmg_jing} 点精力和 #{dmg_qi} 点气血。"}

      true ->
        # 成功
        base_level = div(Stats.skill(player.meta.stats, "wudu-qishu"), 2) + 10

        level =
          base_level +
            (Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/level_bonus") || 0)

        poison = %{
          id: Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/recipe"),
          name:
            @recipes[Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/recipe")].name,
          type: "poison",
          poison: %{
            level: level,
            id: "player_id",
            name: "Poison",
            duration: 15
          }
        }

        # 奖励
        exp_gain = 300 + :rand.uniform(300)
        score_gain = 100 + :rand.uniform(100)

        player = Kantele.Character.Stats.add_exp(player.meta.stats, exp_gain)
        player = Kantele.Character.Stats.add_score(player.meta.stats, score_gain)
        player = Kantele.Character.Stats.add_potential(player.meta.stats, 50 + :rand.uniform(50))

        Stats.improve_skill(player.meta.stats, "poison")
        Stats.improve_skill(player.meta.stats, "wudu-qishu")

        # Wusheng San 额外奖励
        if Kantele.Character.PlayerMeta.get_temp(player.meta, "liandu/recipe") == "wusheng san" do
          player = Kantele.Character.Stats.add_potential(player.meta.stats, 100)
        end

        {:ok, "炼制成功！获得 #{Kantele.Item.Item.get(recipe.product).name} (等级 #{level})"}
    end
  end
end
