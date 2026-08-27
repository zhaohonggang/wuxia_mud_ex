defmodule ExVenture.Characters.Metadata do
  @moduledoc """
  玩家武侠属性的持久化（combat_exp/potential/skills/neili 上限等）

  对应 LPC 玩家 dbase 中可成长字段的落盘；登录时恢复。
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias ExVenture.Characters.Character

  schema "character_metadata" do
    belongs_to(:character, Character)

    field(:str, :integer, default: 20)
    field(:dex, :integer, default: 20)
    field(:con, :integer, default: 20)
    field(:int, :integer, default: 20)
    field(:combat_exp, :integer, default: 0)
    field(:potential, :integer, default: 100)
    field(:learned_points, :integer, default: 0)
    field(:max_neili, :integer, default: 200)
    field(:max_jingli, :integer, default: 0)
    field(:coins, :integer, default: 100)
    field(:score, :integer, default: 0)
    field(:weiwang, :integer, default: 0)
    field(:gongxian, :integer, default: 0)
    field(:shen, :integer, default: 0)
    field(:family, :map, default: %{})
    field(:skills, :map, default: %{})
    field(:mapped, :map, default: %{})
    field(:performs, {:array, :string}, default: [])
    field(:inventory, {:array, :map}, default: [])
    field(:equipment, :map, default: %{})
    field(:nickname, :string)
    field(:title, :string, default: "")
    field(:option, :map, default: %{})
    field(:alias_commands, :map, default: %{})

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :character_id,
      :str,
      :dex,
      :con,
      :int,
      :combat_exp,
      :potential,
      :learned_points,
      :max_neili,
      :max_jingli,
      :coins,
      :score,
      :weiwang,
      :gongxian,
      :shen,
      :family,
      :skills,
      :mapped,
      :performs,
      :inventory,
      :equipment,
      :nickname,
      :title,
      :option,
      :alias_commands
    ])
    |> validate_required([:character_id])
    |> unique_constraint(:character_id)
  end
end

defmodule Kantele.Character.Records do
  @moduledoc """
  玩家战斗属性存取（Kantele 内存结构 <-> DB）

  - 登录：`load/1` 按角色名恢复 Stats 与 neili 上限
  - 成长：击杀奖励、learn/practice 后调用 `save/1` 落盘
  """

  require Logger

  import Ecto.Query

  alias ExVenture.Characters.Character
  alias ExVenture.Characters.Metadata
  alias ExVenture.Repo
  alias Kantele.Character.Stats

  @doc """
  按角色名加载持久化属性，无记录则返回 nil（调用方用默认值）
  """
  def load(character_name) do
    case find_character(character_name) do
      nil ->
        :error

      character ->
        case Repo.get_by(Metadata, character_id: character.id) do
          nil -> :error
          metadata -> {:ok, metadata}
        end
    end
  end

  @doc """
  保存玩家属性（仅 PlayerMeta 生效；失败只记日志，绝不影响游戏进程）
  """
  def save(%{meta: %Kantele.Character.PlayerMeta{}, name: name} = character) do
    meta = character.meta

    with {:ok, record} <- ensure_record(name) do
        metadata =
          Metadata.changeset(record, %{
            str: meta.stats.str,
            dex: meta.stats.dex,
            con: meta.stats.con,
            int: meta.stats.int,
            combat_exp: meta.stats.combat_exp,
            potential: meta.stats.potential,
            learned_points: meta.stats.learned_points || 0,
            max_neili: meta.vitals.max_neili,
            max_jingli: meta.vitals.max_jingli || 0,
            coins: meta.coins || 0,
            score: meta.stats.score || 0,
            weiwang: meta.stats.weiwang || 0,
            gongxian: meta.stats.gongxian || 0,
            shen: meta.stats.shen || 0,
            family: serialize_family(meta.family),
            skills: meta.stats.skills,
            mapped: meta.stats.mapped,
            performs: MapSet.to_list(meta.stats.performs),
            inventory: Enum.map(character.inventory, &%{item_id: &1.item_id}),
            equipment: serialized_equipment(meta.combat.equipped),
            nickname: meta.nickname,
            title: meta.title || "",
            option: meta.option || %{},
            alias_commands: meta.alias_commands || %{}
          })

      case Repo.insert_or_update(metadata) do
        {:ok, _metadata} ->
          :ok

        {:error, changeset} ->
          Logger.warn("Failed to save character metadata - #{inspect(changeset.errors)}")
          :error
      end
    end
  rescue
    error ->
      case error do
        %DBConnection.OwnershipError{} ->
          # 测试沙盒未签出连接：属预期噪音，降级记录
          Logger.debug("Skipped saving character metadata in sandbox")
          :error

        _ ->
          Logger.error("Failed to save character metadata - #{inspect(error)}")
          :error
      end
  end

  def save(_character), do: :error

  # b6/B4 多槽位序列化：每个槽位独立键（"weapon"/"cloth"/"head"/...），
  # 快照含可选 prop 表（string-key JSON）
  defp serialized_equipment(equipped) do
    Enum.into(equipped, %{}, fn {slot, snap} ->
      {to_string(slot), snapshot_to_json(snap)}
    end)
  end

  defp snapshot_to_json(snap) do
    json = %{"name" => Map.get(snap, :name)}

    json =
      case Map.get(snap, :skill_type) do
        nil -> json
        v -> Map.put(json, "skill_type", v)
      end

    json =
      case Map.get(snap, :damage) do
        nil -> json
        v -> Map.put(json, "damage", v)
      end

    json =
      case Map.get(snap, :armor) do
        nil -> json
        v -> Map.put(json, "armor", v)
      end

    case Map.get(snap, :prop) do
      nil -> json
      prop -> Map.put(json, "prop", stringify_keys(prop))
    end
  end

  defp stringify_keys(prop) when is_map(prop) do
    Enum.into(prop, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  @doc "把持久化记录合并进新建角色的 meta"
  def apply_to_character(character, nil), do: character

  @default_skills %{
    "unarmed" => 60,
    "sword" => 60,
    "dodge" => 60,
    "parry" => 60,
    "force" => 20
  }

  def apply_to_character(character, {:ok, metadata}) do
    # 保底合并：存档里的等级与默认值取较大者，
    # 防止历史坏档（空 skills 等）把角色打回零级
    skills =
      Map.merge(@default_skills, atomize_keys(metadata.skills), fn
        _key, default_lvl, loaded_lvl -> max(default_lvl, loaded_lvl)
      end)

    combat_exp = max(metadata.combat_exp, 0)
    potential = max(metadata.potential, 100)

    stats = %Stats{
      str: metadata.str,
      dex: metadata.dex,
      con: metadata.con,
      int: metadata.int,
      combat_exp: combat_exp,
      potential: potential,
      learned_points: max(metadata.learned_points || 0, 0),
      score: max(metadata.score || 0, 0),
      weiwang: max(metadata.weiwang || 0, 0),
      gongxian: max(metadata.gongxian || 0, 0),
      shen: metadata.shen || 0,
      skills: skills,
      mapped: atomize_keys(metadata.mapped),
      performs: MapSet.new(metadata.performs)
    }

    vitals =
      character.meta.vitals
      |> Map.put(:max_neili, metadata.max_neili)
      |> Map.put(:base_neili, metadata.max_neili)
      |> Map.put(:neili, metadata.max_neili)
      |> Map.put(:max_jingli, metadata.max_jingli || 0)
      |> Map.put(:jingli, metadata.max_jingli || 0)
      |> Kantele.Character.Vitals.recalculate_max_neili(stats)

    inventory = restore_inventory(character.inventory, metadata.inventory)
    combat = restore_equipment(Kantele.Character.Combat.new(), metadata.equipment)

    meta =
      character.meta
      |> Map.put(:stats, stats)
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)
      |> Map.put(:coins, max(metadata.coins || 0, 0))
      |> Map.put(:family, restore_family(metadata.family))
      |> Map.put(:nickname, metadata.nickname)
      |> Map.put(:title, metadata.title || "")
      |> Map.put(:option, metadata.option || %{})
      |> Map.put(:alias_commands, metadata.alias_commands || %{})

    %{character | meta: meta, inventory: inventory}
  end

  # 存档里的 family 是 string-key JSON，转回 atom-key 运行态
  defp restore_family(family) when is_map(family) and map_size(family) > 0 do
    %{
      name: family["name"],
      master_id: family["master_id"],
      master_name: family["master_name"]
    }
  end

  defp restore_family(_), do: nil

  defp serialize_family(nil), do: %{}

  defp serialize_family(%{} = family) do
    case {Map.get(family, :name), Map.get(family, :master_id)} do
      {nil, nil} -> %{}
      _ -> %{name: Map.get(family, :name), master_id: Map.get(family, :master_id), master_name: Map.get(family, :master_name)}
    end
  end

  defp serialize_family(_), do: %{}

  # 存档里有背包记录则按 item_id 重建实例；空记录保留默认新手物品
  defp restore_inventory(default_inventory, []) do
    default_inventory
  end

  defp restore_inventory(default_inventory, saved) when is_list(saved) do
    now = DateTime.utc_now()

    Enum.map(saved, fn entry ->
      %Kalevala.World.Item.Instance{
        id: Kalevala.World.Item.Instance.generate_id(),
        item_id: entry["item_id"],
        created_at: now,
        meta: %{}
      }
    end)
  end

  defp restore_inventory(default_inventory, _other), do: default_inventory

  # b6/B4 双读兼容：
  # - 新格式：每槽位一键（"weapon"/"cloth"/"head"/...）
  # - 旧格式：单层 %{"weapon" => snap, "armor" => snap}，"armor" 无类型信息，
  #   归入 cloth 槽位（袍类是历史唯一护甲）
  defp restore_equipment(combat, equipment) when is_map(equipment) do
    Enum.reduce(equipment, combat, fn {key, snap}, acc ->
      cond do
        key == "weapon" ->
          maybe_equip(acc, weapon_snapshot(snap), :weapon)

        key == "armor" ->
          maybe_equip(acc, armor_snapshot(snap), :cloth)

        true ->
          case Kantele.World.Item.Meta.normalize_armor_type(key) do
            nil -> acc
            slot -> maybe_equip(acc, armor_snapshot(snap), String.to_atom(slot))
          end
      end
    end)
  end

  defp maybe_equip(combat, nil, _slot), do: combat

  defp maybe_equip(combat, snapshot, slot),
    do: Kantele.Character.Combat.equip(combat, slot, snapshot)

  # 存档里的快照是 string-key 的 JSON 对象，转回 atom-key 快照
  defp weapon_snapshot(nil), do: nil

  defp weapon_snapshot(%{"name" => name} = s),
    do: %{
      name: name,
      skill_type: s["skill_type"] || "sword",
      damage: s["damage"] || 0,
      prop: prop_from_json(s["prop"])
    }

  defp armor_snapshot(nil), do: nil

  defp armor_snapshot(%{"name" => name} = s),
    do: %{name: name, armor: s["armor"] || 0, prop: prop_from_json(s["prop"])}

  defp prop_from_json(nil), do: nil

  defp prop_from_json(prop) when is_map(prop) do
    Enum.into(prop, %{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  defp prop_from_json(_), do: nil

  def apply_to_character(character, :error), do: character

  defp ensure_record(character_name) do
    case find_character(character_name) do
      nil ->
        # telnet 直接登录的角色尚无档案：首次保存时自动建档
        changeset = Character.create_changeset(%Character{}, %{name: character_name})

        case Repo.insert(changeset) do
          {:ok, character} ->
            {:ok, insert_metadata(character.id)}

          {:error, _changeset} ->
            case find_character(character_name) do
              nil ->
                :error

              character ->
                {:ok, insert_metadata(character.id)}
            end
        end

      character ->
        {:ok, insert_metadata(character.id)}
    end
  end

  defp insert_metadata(character_id) do
    case Repo.get_by(Metadata, character_id: character_id) do
      nil -> Repo.insert!(Metadata.changeset(%Metadata{}, %{character_id: character_id}))
      metadata -> metadata
    end
  end

  defp find_character(name) do
    Repo.one(from c in Character, where: c.name == ^name, limit: 1)
  end

  defp atomize_keys(nil), do: %{}

  # 统一为字符串键（与 Stats.skill/2 的查找方式一致）
  defp atomize_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {key, value}
    end)
  end
end
