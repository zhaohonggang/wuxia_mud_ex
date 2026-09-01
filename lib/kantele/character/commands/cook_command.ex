defmodule Kantele.Character.CookCommand do
  @moduledoc """
  烹饪命令：`cook [<菜肴名称>]`

  对应 LPC cmds/std/cook.c。
  需要激发 cooking 技能，有 cai_liao 食材，cooking 技能 >= 50。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"dish_name" => dish_name}) do
    character = conn.character

    if dish_name == "" do
      show_cooking_menu(conn, character)
    else
      cook_dish(conn, character, dish_name)
    end
  end

  def run(conn, %{}) do
    show_cooking_menu(conn, conn.character)
  end

  defp show_cooking_menu(conn, character) do
    cooking_skill = get_active_cooking_skill(character)

    if !cooking_skill do
      conn
      |> render(CommandView, "text", %{text: "请先激发你要使用的菜艺。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      menu = get_cooking_menu(cooking_skill, character)

      if !menu || map_size(menu) == 0 do
        conn
        |> render(CommandView, "text", %{text: "你现在使用#{to_chinese(cooking_skill)}不会做任何菜肴。\n"})
        |> prompt(CommandView, "prompt", %{})
      else
        dish_list = Map.keys(menu) |> Enum.join("、")
        msg = "你现在使用#{to_chinese(cooking_skill)}会做#{dish_list}这些菜肴。"

        conn
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp cook_dish(conn, character, dish_name) do
    cooking_skill = get_active_cooking_skill(character)

    if !cooking_skill do
      conn
      |> render(CommandView, "text", %{text: "请先激发你要使用的菜艺。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      skill_level = character.skills[cooking_skill] || 0

      if skill_level < 50 do
        conn
        |> render(CommandView, "text", %{text: "你这点#{to_chinese(cooking_skill)}还是不要浪费菜料了。\n"})
        |> prompt(CommandView, "prompt", %{})
      else
        menu = get_cooking_menu(cooking_skill, character)

        if !menu || !Map.has_key?(menu, dish_name) do
          conn
          |> render(CommandView, "text", %{text: "你现在还不知道怎么做『#{dish_name}』这味菜。\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          # 查找 cai_liao 食材
          case find_cailiao(character) do
            {:ok, cailiao_item, cailiao_instance} ->
              # 扣除食材
              new_inventory = Enum.reject(character.inventory, &(&1.id == cailiao_instance.id))

              # 创建菜肴
              dish = create_dish(dish_name, menu[dish_name], cooking_skill, skill_level, character.id, character.name)

              new_inventory = [dish | new_inventory]
              new_character = %{character | inventory: new_inventory}
              new_conn = put_character(conn, new_character)

              new_conn
              |> render(CommandView, "text", %{
                text: "#{character.name}卷起袖子，运用锅铲瓢盆、酱油茶醋，精心调制出一份#{dish_name}来。\n"
              })
              |> prompt(CommandView, "prompt", %{})
              |> save()

            {:error, reason} ->
              conn
              |> render(CommandView, "text", %{text: reason <> "\n"})
              |> prompt(CommandView, "prompt", %{})
          end
        end
      end
    end
  end

  defp get_active_cooking_skill(character) do
    character.attributes["cooking_active"] || character.attributes["cooking"]
  end

  defp get_cooking_menu(skill_name, character) do
    # 简化：根据技能返回固定菜单
    # 实际应从 SKILL_D(skill)->query_menu() 获取
    case skill_name do
      "chuan_cuisine" -> %{
        "回锅肉" => "四川",
        "麻婆豆腐" => "四川",
        "宫保鸡丁" => "四川"
      }
      "yue_cuisine" -> %{
        "白切鸡" => "广东",
        "烧鹅" => "广东",
        "虾饺" => "广东"
      }
      "lu_cuisine" -> %{
        "糖醋鲤鱼" => "山东",
        "九转大肠" => "山东",
        "葱烧海参" => "山东"
      }
      "su_cuisine" -> %{
        "松鼠鱼" => "江苏",
        "狮子头" => "江苏",
        "扬州炒饭" => "江苏"
      }
      _ -> %{
        "白切鸡" => "广东",
        "红烧肉" => "浙江",
        "蒸鱼" => "江浙"
      }
    end
  end

  defp find_cailiao(character) do
    Enum.find(character.inventory, fn inst ->
      item = Items.get!(inst.item_id)
      item.callback_module.matches?(item, "cai liao") || item.id == "cai_liao"
    end)
    |> case do
      nil -> {:error, "你现在手头没有菜料，没法做菜。"}
      inst ->
        if Map.get(inst, :amount, 1) >= 1 do
          item = Items.get!(inst.item_id)
          {:ok, item, inst}
        else
          {:error, "你现在手头没有菜料，没法做菜。"}
        end
    end
  end

  defp create_dish(name, cuisine, skill, level, by_id, by_name) do
    %{
      id: "dish_#{:rand.uniform(100000)}",
      name: name,
      type: "food",
      verb: "eat",
      weight: 100,
      value: 10,
      description: "一份由#{by_name}精心烹制的#{name}。\n",
      attrs: %{
        "skill" => skill,
        "level" => level,
        "by" => by_id,
        "cuisine" => cuisine,
        "food" => 50,
        "medicine" => %{qi: 20, jing: 10}
      },
      verbs: ["eat"]
    }
  end

  defp to_chinese(skill) do
    case skill do
      "chuan_cuisine" -> "川菜"
      "yue_cuisine" -> "粤菜"
      "lu_cuisine" -> "鲁菜"
      "su_cuisine" -> "苏菜"
      _ -> skill
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end