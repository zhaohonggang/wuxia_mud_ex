defmodule Kantele.Character.NpcScriptEvent do
  @moduledoc """
  数据驱动 NPC 脚本效果（Q6，玩家侧）

  NpcAskEvent 对脚本化 inquire（map 答语）分发 `npc/give` / `npc/learn` /
  `npc/faction` 事件到玩家进程；本模块在此落库并渲染回话：
  - `give`  把物品加入背包（落盘）
  - `learn` 学会技能（stats.skills，首学 1 级）
  - `faction` 拜入门派（meta.family）+ 发放门派贡献（stats.gongxian）

  与 `MirrorEvent.mirror/give` 同构；差异是物品 id 不写死，完全由数据驱动。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Items

  def give_result(conn, %{
        data: %{npc_name: npc_name, item_id: item_id, asker_id: asker_id}
      }) do
    character = conn.character

    case asker_id == character.id do
      false ->
        conn

      true ->
        case Items.get(item_id) do
          {:ok, item} ->
            instance = %Item.Instance{
              id: Item.Instance.generate_id(),
              item_id: item_id,
              created_at: DateTime.utc_now()
            }

            character = %{character | inventory: [instance | character.inventory]}
            Records.save(character)

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{
              text: "#{npc_name}取出一物，郑重递到你手中。\n"
            })
            |> prompt(CommandView, "prompt", %{})

          _ ->
            conn
        end
    end
  end

  def give_result(conn, _event), do: conn

  def learn_result(conn, %{data: %{npc_name: npc_name, skill: skill, asker_id: asker_id}}) do
    character = conn.character

    case asker_id == character.id do
      false ->
        conn

      true ->
        stats = Map.update(character.meta.stats, :skills, %{}, &Map.put_new(&1, skill, 1))
        meta = %{character.meta | stats: stats}
        character = %{character | meta: meta}
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{
          text: "#{npc_name}悉心指点，你领悟了「#{skill}」的入门要诀。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def learn_result(conn, _event), do: conn

  def faction_result(conn, %{
        data: %{npc_name: npc_name, family: family, gongxian: gongxian, asker_id: asker_id}
      }) do
    character = conn.character

    case asker_id == character.id do
      false ->
        conn

      true ->
        family_meta = %{name: family}
        meta = %{character.meta | family: family_meta, stats: bump_gongxian(character, gongxian)}
        character = %{character | meta: meta}
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{
          text: "#{npc_name}点头道：今日起你便是我#{family}门下，好生修炼。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def faction_result(conn, _event), do: conn

  def register_result(conn, %{
        data: %{npc_name: npc_name, item_id: _item_id, asker_id: asker_id, keyword: keyword}
      }) do
    character = conn.character

    case asker_id == character.id do
      false ->
        conn

      true ->
        # 从关键词提取物品名（格式：登记 <物品名>）
        target_name = keyword
          |> String.replace(~r/登记[召唤]?\s*/, "")
          |> String.trim()

        if target_name == "" do
          conn
          |> render(CommandView, "text", %{
            text: "#{npc_name}问：你要登记哪件兵器？\n"
          })
          |> prompt(CommandView, "prompt", %{})
        else
          # 查找背包中匹配的物品
          item_instance = Enum.find(character.inventory, fn inst ->
            item = Items.get!(inst.item_id)
            item.name == target_name ||
            String.contains?(item.name, target_name) ||
            String.contains?(inst.item_id, target_name)
          end)

          if is_nil(item_instance) do
            conn
            |> render(CommandView, "text", %{
              text: "#{npc_name}摇头道：「你身上并没有#{target_name}，无法为你登记召唤之法。」\n"
            })
            |> prompt(CommandView, "prompt", %{})
          else
            item = Items.get!(item_instance.item_id)
            item_path = item.id

            can_summon = Map.put(character.attributes["can_summon"] || %{}, item_instance.item_id, item_path)
            attributes = Map.put(character.attributes, "can_summon", can_summon)
            character = %{character | attributes: attributes}
            Records.save(character)

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{
              text: "#{npc_name}在#{item.name}上刻下召唤符文，对你道：「日后想唤它，只需运功呼唤即可。」\n"
            })
            |> prompt(CommandView, "prompt", %{})
          end
        end
    end
  end

  def register_result(conn, _event), do: conn

  defp bump_gongxian(character, gongxian) when is_integer(gongxian) do
    Map.update(character.meta.stats, :gongxian, gongxian, &(&1 + gongxian))
  end

  defp bump_gongxian(character, _), do: character.meta.stats
end