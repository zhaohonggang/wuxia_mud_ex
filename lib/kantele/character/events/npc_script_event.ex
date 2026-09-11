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

  defp bump_gongxian(character, gongxian) when is_integer(gongxian) do
    Map.update(character.meta.stats, :gongxian, gongxian, &(&1 + gongxian))
  end

  defp bump_gongxian(character, _), do: character.meta.stats
end