defmodule Kantele.Character.MakeCommand do
  @moduledoc """
  炼药命令：`make [<药品>] [?]`

  对应 LPC cmds/std/make.c。
  多步炼药流程：检查技能/药材/研钵 → 10步 busy 循环 → 成功/失败判定
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  @recipes %{
    "xiaohuandan" => %{
      name: "小还丹",
      min_level: 50,
      time: 8,
      jing: 100,
      neili: 200,
      jingli: 100,
      skills: %{"medical" => 60, "force" => 60},
      herbs: %{"renshen" => 2, "danggui" => 3, "fuling" => 3}
    },
    "dahuan_dan" => %{
      name: "大还丹",
      min_level: 80,
      time: 10,
      jing: 200,
      neili: 500,
      jingli: 200,
      skills: %{"medical" => 100, "force" => 100, "alchemy" => 60},
      herbs: %{"renshen" => 5, "danggui" => 5, "fuling" => 5, "lingzhi" => 3}
    },
    "xiaoji_dan" => %{
      name: "消积丹",
      min_level: 30,
      time: 5,
      jing: 50,
      neili: 100,
      jingli: 50,
      skills: %{"medical" => 40},
      herbs: %{"dahuang" => 3, "houpo" => 2, "zhishi" => 2}
    }
  }

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    arg = String.trim(arg || "")

    cond do
      arg == "" ->
        list_known_recipes(conn, character)

      String.ends_with?(arg, " ?") ->
        show_recipe_requirements(conn, character, String.slice(arg, 0..-3))

      true ->
        start_making(conn, character, arg)
    end
  end

  def run(conn, %{}) do
    list_known_recipes(conn, conn.character)
  end

  defp list_known_recipes(conn, character) do
    known = character.attributes["can_make"] || %{}
    known = if is_binary(known), do: Jason.decode!(known), else: known

    if known == %{} do
      conn
      |> render(CommandView, "text", %{text: "你现在不会制任何药物。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      names = Map.keys(known) |> Enum.map(&@recipes[&1].name) |> Enum.join("、")
      conn
      |> render(CommandView, "text", %{text: "你现在已经会制#{names}了。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_recipe_requirements(conn, character, med_key) do
    recipe = @recipes[med_key]

    if !recipe do
      conn
      |> render(CommandView, "text", %{text: "你还不会配这种药啊！\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      lines = ["炼制#{recipe.name}需要以下这些药材："]

      Enum.each(recipe.herbs, fn {herb, count} ->
        lines = lines ++ ["#{count}#{get_herb_unit(herb)}#{get_herb_name(herb)}"]
      end)

      # 技能要求
      Enum.each(recipe.skills, fn {skill, level} ->
        lines = lines ++ ["#{get_skill_name(skill)}: #{level}级"]
      end)

      lines = lines ++ [
        "精力消耗: #{recipe.jing}",
        "内力消耗: #{recipe.neili}",
        "精力(精力值)消耗: #{recipe.jingli}",
        "最低制药等级: #{recipe.min_level}",
        "炼制时间: #{recipe.time} 步"
      ]

      conn
      |> render(CommandView, "text", %{text: Enum.join(lines, "\n") <> "\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp start_making(conn, character, med_key) do
    recipe = @recipes[med_key]

    if !recipe do
      conn
      |> render(CommandView, "text", %{text: "你还不会配这种药啊！\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 检查前置条件
      with :ok <- check_not_fighting(character),
           :ok <- check_not_busy(character),
           :ok <- check_mortar(character),
           :ok <- check_jing(character, recipe),
           :ok <- check_skills(character, recipe),
           :ok <- check_herbs(character, recipe) do

        # 消耗药材
        {new_inventory, msg} = consume_herbs(character.inventory, recipe)

        # 设置炼制状态
        new_state = character
        |> put_in([:meta, :temp, "making/medicine"], med_key)
        |> put_in([:meta, :temp, "making/step"], 0)
        |> put_in([:meta, :temp, "making/time"], recipe.time)
        |> put_in([:meta, :temp, "making/require"], recipe)
        |> put_in([:meta, :temp, "making/container"], "mortar")
        |> put_in([:meta, :temp, "pending/making"], 0)
        |> put_in([:meta, :short_desc], "正在专心致志的炼制药物。")

        # 消耗药材后的背包
        new_character = %{character | inventory: new_inventory, meta: new_state}
        new_conn = put_character(conn, new_character)

        # 显示开始炼制消息
        new_conn
        |> render(CommandView, "text", %{text: msg <> "，然后小心翼翼的把它们放到研钵里面，开始制药。\n"})
        |> assign(:prompt, false)
        |> delay_next_step()
        |> save()
      else
        {:error, reason} ->
          conn
          |> render(CommandView, "text", %{text: reason <> "\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp check_not_fighting(character) do
    if character.meta.combat.enemies != [], do: {:error, "打架的时候你还有闲工夫配药？"}, else: :ok
  end

  defp check_not_busy(character) do
    if character.meta.temp["busy"], do: {:error, "还是先把手头的事情忙完吧。"}, else: :ok
  end

  defp check_mortar(character) do
    qm = character.meta.temp["handing"]

    if qm == nil do
      {:error, "你的先把能够磨药的研钵拿(hand)在手上才行。"}
    else
      if qm.attrs["can_make_medicine"] == true do
        :ok
      else
        {:error, "#{qm.name}好像无法发挥研钵的作用吧。"}
      end
    end
  end

  defp check_jing(character, recipe) do
    max_jing = character.attributes["max_jing"] || 100
    jing = character.attributes["jing"] || 0
    if jing < max_jing * 7 / 10, do: {:error, "你现在精神难以集中，无法配药。"}, else: :ok
  end

  defp check_skills(character, recipe) do
    Enum.reduce_while(recipe.skills, :ok, fn {skill, req_level}, _ ->
      skill_level = character.skills[skill] || 0
      if skill_level < req_level do
        {:halt, {:error, "你的#{get_skill_name(skill)}水平不够，还无法调剂#{@recipes[Map.keys(@recipes) |> Enum.find(fn k -> @recipes[k].skills == recipe.skills end)].name}。"}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp check_herbs(character, recipe) do
    Enum.reduce_while(recipe.herbs, :ok, fn {herb, count}, _ ->
      inst = Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, herb)
      end)

      if inst && (inst.amount || 1) >= count do
        {:cont, :ok}
      else
        {:halt, {:error, "你点了点药材，发现#{get_herb_name(herb)}的分量还不够。"}}
      end
    end)
  end

  defp consume_herbs(inventory, recipe) do
    new_inv = inventory
    msg_parts = []

    Enum.each(recipe.herbs, fn {herb, count} ->
      new_inv = Enum.map(new_inv, fn inst ->
        item = Items.get!(inst.item_id)
        if item.callback_module.matches?(item, herb) do
          %{
            inst
            | amount: (inst.amount || 1) - count
          }
        else
          inst
        end
      end)
      msg_parts = msg_parts ++ ["#{count}#{get_herb_unit(herb)}#{get_herb_name(herb)}"]
    end)

    msg = "你选出#{Enum.join(msg_parts, "、")}"

    {new_inv, msg}
  end

  # 简化的延迟步骤 - 实际应使用 busy 回调机制
  defp delay_next_step(conn) do
    delay_event(conn, 2000, "make/step", %{})
  end

  # 占位符函数
  defp get_herb_name(herb) do
    case herb do
      "renshen" -> "人参"
      "danggui" -> "当归"
      "fuling" -> "茯苓"
      "lingzhi" -> "灵芝"
      "dahuang" -> "大黄"
      "houpo" -> "厚朴"
      "zhishi" -> "枳实"
      _ -> herb
    end
  end

  defp get_herb_unit(herb) do
    "两"
  end

  defp get_skill_name(skill) do
    case skill do
      "medical" -> "医术"
      "force" -> "内功"
      "alchemy" -> "炼丹术"
      _ -> skill
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end