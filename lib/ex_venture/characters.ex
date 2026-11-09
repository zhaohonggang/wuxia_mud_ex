defmodule ExVenture.Characters.Character do
  @moduledoc """
  Schema for a character controlled by a player
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias ExVenture.Characters.PlayableCharacter

  schema "characters" do
    field(:name, :string)
    field(:wiz_level, :integer, default: 0)

    has_many(:playable, PlayableCharacter)

    timestamps()
  end

  def create_changeset(struct, params) do
    struct
    |> cast(params, [:name, :wiz_level])
    |> validate_required([:name])
  end

  def update_changeset(struct, params) do
    struct
    |> cast(params, [:name, :wiz_level])
    |> validate_required([:name])
  end
end

defmodule ExVenture.Characters do
  @moduledoc """
  Characters are controlled by players to act inside of the game
  """

  import Ecto.Query

  alias ExVenture.Characters.Character
  alias ExVenture.Characters.Metadata
  alias ExVenture.Characters.PlayableCharacter
  alias ExVenture.Repo
  require Logger

  @doc """
  Get all characters for a user
  """
  def all_for(user) do
    Character
    |> join(:left, [c], pc in assoc(c, :playable))
    |> where([c, pc], pc.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Count all registered characters (对应 LPC mudinfo.c: count_ppls)
  """
  def count_all do
    Repo.aggregate(Character, :count, :id)
  end

  @doc """
  List all wizard characters (wiz_level > 0), 对应 LPC SECURITY_D->query_wizlist()
  """
  def all_wizards do
    Character
    |> where([c], c.wiz_level > 0)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Get a character scoped to the user accessing it
  """
  def get(id) do
    case Repo.get(Character, id) do
      nil ->
        {:error, :not_found}

      character ->
        {:ok, character}
    end
  end

  @doc """
  Get a character scoped to the user accessing it
  """
  def get(user, id) do
    query =
      Character
      |> join(:left, [c], pc in assoc(c, :playable))
      |> where([c, pc], c.id == ^id and pc.user_id == ^user.id)
      |> limit(1)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      character ->
        {:ok, character}
    end
  end

  @doc """
  Create a new character for a user
  """
  def create(user, params) do
    changeset = Character.create_changeset(%Character{}, params)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:character, changeset)
      |> Ecto.Multi.insert(:playable_character, fn %{character: character} ->
        user
        |> Ecto.build_assoc(:playable_characters)
        |> PlayableCharacter.create_changeset(character)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{character: character}} ->
        {:ok, character}

      {:error, :character, changeset, _changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Update basic information about a character
  """
  def update(character, params) do
    character
    |> Character.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Delete a character for a user
  """
  def delete(character) do
    query =
      PlayableCharacter
      |> where([pc], pc.character_id == ^character.id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:playable_characters, query)
    |> Ecto.Multi.delete(:character, character)
    |> Repo.transaction()
  end

  @doc """
  Delete a character by name (LPC `UPDATE_D->remove_user` equivalent)

  Used by the in-game `suicide` command, which only knows the character's
  name (the live `Kalevala.Character` is keyed to the DB row by name, not id).
  Returns `{:error, :not_found}` when no row matches, so callers need no
  defensive id-casting and the call is safe to make unconditionally.
  """
  def delete_by_name(name) when is_binary(name) do
    case Repo.get_by(Character, name: name) do
      nil -> {:error, :not_found}
      character -> delete(character)
    end
  rescue
    e ->
      Logger.warn("delete_by_name failed for #{inspect(name)}: #{Exception.message(e)}")
      {:error, :db_unavailable}
  end

  @doc """
  Remove `brother_id` from the sworn-brothers list of the character named
  `name` (LPC `UPDATE_D->clear_user_data(arg, "brothers:" + id)` equivalent).

  Used when a player breaks the oath (`brothers out <name>`): both sides' lists
  must be cleared, but the partner may be offline. This edits the persisted
  `Metadata.brothers` directly so it works regardless of online/offline state.
  Returns `{:error, :not_found}` when the target row is missing, and rescues
  DB errors (unavailable sandbox connection, etc.) returning `{:error, :db_unavailable}`
  so the calling command never crashes.
  """
  def remove_brother(name, brother_id) when is_binary(name) and is_binary(brother_id) do
    with %Character{} = character <- Repo.one(from c in Character, where: c.name == ^name, limit: 1),
         %Metadata{} = metadata <- Repo.get_by(Metadata, character_id: character.id) do
      new_brothers =
        Enum.reject(metadata.brothers || [], fn brother ->
          Map.get(brother, "id") == brother_id or Map.get(brother, :id) == brother_id
        end)

      metadata
      |> Metadata.changeset(%{brothers: new_brothers})
      |> Repo.update()
    else
      _ -> {:error, :not_found}
    end
  rescue
    e ->
      Logger.warn("remove_brother failed for #{inspect(name)}/#{inspect(brother_id)}: #{Exception.message(e)}")
      {:error, :db_unavailable}
  catch
    :exit, reason ->
      Logger.warn("remove_brother exited for #{inspect(name)}/#{inspect(brother_id)}: #{inspect(reason)}")
      {:error, :db_unavailable}
  end
end
