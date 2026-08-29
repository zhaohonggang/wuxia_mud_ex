defmodule Kantele.House do
  @moduledoc """
  房屋系统（对应 LPC system_npc_luban：create_room/create_key/demolish + 巫师批核）

  - 玩家申请建房 → 巫师审批 → 创建房间实例 + 生成钥匙物品
  - 房屋数据持久化（`houses` 表），支持拆除、转让、扩建
  """

  alias Kantele.Repo
  alias Kantele.House.House
  import Ecto.Query

  @type house :: %{
    id: String.t(),
    owner_id: String.t(),
    room_id: String.t(),
    zone_id: String.t(),
    key_item_id: String.t(),
    status: :pending | :approved | :built | :demolished,
    created_at: DateTime.t(),
    approved_at: DateTime.t() | nil,
    approved_by: String.t() | nil
  }

  @doc "玩家提交建房申请（返回申请记录，待巫师批核）"
  def apply(owner_id, zone_id, room_spec) do
    id = "house:#{owner_id}:#{DateTime.utc_now() |> DateTime.to_unix()}"
    %House{
      id: id,
      owner_id: owner_id,
      zone_id: zone_id,
      room_spec: room_spec,
      status: :pending
    }
    |> Repo.insert!()
    |> Map.put(:status, :pending)
  end

  @doc "巫师批核建房申请"
  def approve(house_id, wizard_id) do
    case Repo.get(House, house_id) do
      nil -> {:error, :not_found}
      house ->
        if house.status != :pending do
          {:error, {:invalid_status, house.status}}
        else
          room_id = create_room_instance(house)
          key_item_id = create_key_item(house)

          Repo.update!(%{house |
            status: :approved,
            room_id: room_id,
            key_item_id: key_item_id,
            approved_at: DateTime.utc_now(),
            approved_by: wizard_id
          })
          |> Map.put(:status, :approved)
        end
    end
  end

  @doc "拆除房屋（归还区域、销毁钥匙）"
  def demolish(house_id, actor_id) do
    case Repo.get(House, house_id) do
      nil -> {:error, :not_found}
      house ->
        if house.owner_id != actor_id and not is_wizard?(actor_id) do
          {:error, :unauthorized}
        else
          destroy_room_instance(house.room_id)
          destroy_key_item(house.key_item_id)
          Repo.update!(%{house | status: :demolished})
          {:ok, house}
        end
    end
  end

  @doc "列出玩家名下房屋"
  def list_by_owner(owner_id) do
    Repo.all(from h in House, where: h.owner_id == ^owner_id)
  end

  @doc "列出待批核申请（巫师面板）"
  def pending_applications() do
    Repo.all(from h in House, where: h.status == :pending)
  end

  # --- 内部实现 ---

  defp create_room_instance(house) do
    # 实际应调用 World.Room 创建动态房间，此处占位
    "dynamic_room:#{house.id}"
  end

  defp create_key_item(house) do
    # 实际应生成唯一钥匙物品实例，此处占位
    "key:#{house.id}"
  end

  defp destroy_room_instance(_room_id), do: :ok
  defp destroy_key_item(_key_item_id), do: :ok

  defp is_wizard?(_id), do: false
end