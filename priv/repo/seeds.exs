{:ok, _api_token} =
  case ExVenture.Repo.get_by(ExVenture.APIKeys.APIKey, token: "6e8d83d9-a028-4eb7-bc7b-9b32bac697b6") do
    nil ->
      ExVenture.APIKeys.create(%{
        token: "6e8d83d9-a028-4eb7-bc7b-9b32bac697b6",
        is_active: true
      })

    existing ->
      IO.puts("[seeds] skip existing api key")
      {:ok, existing}
  end

{:ok, _user} =
  case ExVenture.Repo.get_by(ExVenture.Users.User, username: "user") do
    nil ->
      ExVenture.Users.create(%{
        username: "user",
        email: "user@example.com",
        password: "password",
        password_confirmation: "password"
      })

    existing ->
      IO.puts("[seeds] skip existing user: user")
      {:ok, existing}
  end

{:ok, admin} =
  case ExVenture.Repo.get_by(ExVenture.Users.User, username: "admin") do
    nil ->
      ExVenture.Users.create(%{
        username: "admin",
        email: "admin@example.com",
        password: "password",
        password_confirmation: "password"
      })

    existing ->
      IO.puts("[seeds] skip existing user: admin")
      {:ok, existing}
  end

{:ok, _admin} =
  admin
  |> Ecto.Changeset.change(%{role: "admin"})
  |> ExVenture.Repo.update()

#
# The World
#

defmodule Seeds do
  alias ExVenture.Rooms
  alias ExVenture.Zones

  def create_zone(%{seed?: false}), do: :ok

  def create_zone(zone_data) do
    case ExVenture.Repo.get_by(ExVenture.Zones.Zone, key: zone_data.id) do
      nil ->
        {:ok, zone} =
          Zones.create(%{
            key: zone_data.id,
            name: zone_data.name,
            description: zone_data.name
          })

        {:ok, zone} = Zones.publish(zone)

        Enum.each(zone_data.rooms, fn room ->
          create_room(zone, room)
        end)

      existing_zone ->
        IO.puts("[seeds] skip existing zone #{zone_data.id}")
        Enum.each(zone_data.rooms, fn room ->
          create_room(existing_zone, room)
        end)
    end
  end

  def create_room(zone, params) do
    case ExVenture.Repo.get_by(ExVenture.Rooms.Room, key: params.key) do
      nil ->
        {:ok, room} =
          Rooms.create(zone, %{
            key: params.key,
            name: params.name,
            description: params.description,
            listen: params.description,
            map_icon: params.map_icon,
            x: params.x,
            y: params.y,
            z: params.z
          })

        {:ok, _room} = ExVenture.Rooms.publish(room)

      existing_room ->
        # 同 key 房间已存在，跳过重复插入，避免 rooms_key_index 唯一约束冲突
        IO.puts("[seeds] skip existing room #{params.key}")
        :ok
    end
  end
end

world = Kantele.World.Loader.load()

Enum.each(world.zones, fn zone ->
  Seeds.create_zone(zone)
end)
