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
    field(:max_neili, :integer, default: 200)
    field(:skills, :map, default: %{})
    field(:mapped, :map, default: %{})
    field(:performs, {:array, :string}, default: [])

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
      :max_neili,
      :skills,
      :mapped,
      :performs
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
          max_neili: meta.vitals.max_neili,
          skills: meta.stats.skills,
          mapped: meta.stats.mapped,
          performs: MapSet.to_list(meta.stats.performs)
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

  @doc "把持久化记录合并进新建角色的 meta"
  def apply_to_character(character, nil), do: character

  def apply_to_character(character, {:ok, metadata}) do
    stats = %Stats{
      str: metadata.str,
      dex: metadata.dex,
      con: metadata.con,
      int: metadata.int,
      combat_exp: metadata.combat_exp,
      potential: metadata.potential,
      skills: atomize_keys(metadata.skills),
      mapped: atomize_keys(metadata.mapped),
      performs: MapSet.new(metadata.performs)
    }

    vitals = %{character.meta.vitals | max_neili: metadata.max_neili, neili: metadata.max_neili}

    meta =
      character.meta
      |> Map.put(:stats, stats)
      |> Map.put(:vitals, vitals)

    %{character | meta: meta}
  end

  def apply_to_character(character, :error), do: character

  defp ensure_record(character_name) do
    case find_character(character_name) do
      nil ->
        :error

      character ->
        case Repo.get_by(Metadata, character_id: character.id) do
          nil ->
            {:ok, Repo.insert!(Metadata.changeset(%Metadata{}, %{character_id: character.id}))}

          metadata ->
            {:ok, metadata}
        end
    end
  end

  defp find_character(name) do
    Repo.one(from c in Character, where: c.name == ^name, limit: 1)
  end

  defp atomize_keys(nil), do: %{}

  defp atomize_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      key = if is_binary(key), do: String.to_atom(key), else: key
      {key, value}
    end)
  end
end
