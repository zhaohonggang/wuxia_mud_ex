defmodule Kantele.World.NpcActions.Helpers do
  @moduledoc """
  NPC 私有动作（`NpcAction` handler）共享 helper。

  与 `Kantele.World.RoomActions.Helpers` 同构（广播/私发桥接），另补充 NPC 私有
  动作常需的**发物**与**存在性判断**：

  - `give_item/2,3` —— 把物品定义实例化后放进玩家背包并落盘（对应 LPC
    `ob = new(...); ob->move(me)`），发给玩家的「物品」链路与 NPC 脚本赠礼
    (`Kantele.Character.NpcScriptEvent.give_result`) 完全一致：
    `%Item.Instance{}` + `Records.save/1` + `put_character/2`。
  - `carries?/2` —— LPC `present(<name>, me)`：背包内是否有匹配该 id/别名的物品。
  - `room_has_item?/2` —— LPC `present(<name>, environment())`：房间地上是否有。
  - `family_name/1` —— 玩家门派名（`meta.family`）。
  - `flag?/2` —— 玩家 LPC `query("<flag>")`（读 `attributes` / `meta.env`）。
  - `temp/2`、`add_mark/3` —— LPC `query_temp` / `add_temp`（会话级，落 `meta.temp`）。
  - `food_full?/1` —— LPC `query("food") >= max_food_capacity()*90/100`。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.World.Item
  alias Kantele.Character.Family
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @doc "`write(msg)`：只推给当前玩家（不广播）"
  def render(conn, text), do: RoomHelpers.render_to_player(conn, text)

  @doc "`message_vision(msg, me)`：向房间广播（`$N` → `{npc}` 归一化）"
  def broadcast(conn, room_id, template, opts \\ []),
    do: RoomHelpers.broadcast_vision(conn, room_id, template, opts)

  @doc "NPC `command(\"say <text>\")`：以 NPC 名广播一句"
  def say(conn, room_id, npc_name, text),
    do: RoomHelpers.broadcast_vision(conn, room_id, "#{npc_name}说道：#{text}\n")

  @doc """
  `ob = new(<item_id>); ob->move(me)`：把 `item_id` 的一件实例放进玩家背包。

  `opts[:meta]`（map）非空时合并进实例的 `meta`（对应 LPC 发放时对副本
  `obj->set("no_sell", ...)` / `obj->set("value", ...)` 的按件改写）。
  定义缺失（`{:error, :not_found}`）时不动 `conn`。
  """
  def give_item(conn, item_id, opts \\ []) do
    case Items.get(item_id) do
      {:ok, _item} ->
        instance =
          %Item.Instance{
            id: Item.Instance.generate_id(),
            item_id: item_id,
            created_at: DateTime.utc_now()
          }
          |> put_instance_meta(Keyword.get(opts, :meta, %{}))

        character = current(conn)
        character = %{character | inventory: [instance | character.inventory]}
        Records.save(character)
        put_character(conn, character)

      _ ->
        conn
    end
  end

  @doc "同 `give_item/3`，发 `count` 件（LPC 田嫂发两个包子）。"
  def give_items(conn, item_id, count, opts \\ []) when is_integer(count) and count > 0 do
    Enum.reduce(1..count, conn, fn _i, conn -> give_item(conn, item_id, opts) end)
  end

  @doc "`present(<name>, me)`：背包内是否有 id/别名匹配 `name` 的物品"
  def carries?(character, name) do
    Enum.any?(character.inventory, fn inst ->
      Kantele.World.Item.matches?(Kantele.World.Item.instance_item(inst), name)
    end)
  end

  @doc "`present(<name>, environment())`：房间地上是否有匹配 `name` 的物品"
  def room_has_item?(room_id, name) when is_binary(room_id) do
    Enum.any?(Room.item_instances_by_id(room_id), fn inst ->
      Kantele.World.Item.matches?(Kantele.World.Item.instance_item(inst), name)
    end)
  end

  def room_has_item?(_room_id, _name), do: false

  @doc "玩家门派名（`me->query(\"family/family_name\")`）"
  def family_name(%{meta: %{family: family}}), do: Family.name(family)
  def family_name(_character), do: nil

  @doc """
  玩家 LPC `query(\"<flag>\")`：依次读 `character.attributes[flag]`、
  `character.meta.env[flag]`，缺省 `false`。
  （vendor 系统的 `is_vendor` / `bad_vendor` 用此读取；系统未建模时恒 false。）
  """
  def flag?(%{attributes: attrs} = character, flag) do
    case Map.get(attrs || %{}, flag) do
      nil -> env_flag?(character, flag)
      value -> truthy?(value)
    end
  end

  def flag?(character, flag), do: env_flag?(character, flag)

  defp env_flag?(%{meta: %{env: env}}, flag), do: truthy?(Map.get(env || %{}, flag))
  defp env_flag?(_character, _flag), do: false

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true

  @doc "`query_temp(key)`：读 `meta.temp[key]`（会话级）"
  def temp(conn, key), do: PlayerMeta.get_temp(current(conn).meta, key)

  @doc """
  `add_temp(\"mark/...\", 1)`：把 `meta.temp[key]` 自增后写回 `conn`。

  对应钱正伦的 `mark/zhenyuan_armor` / `mark/zhenyuan_weapon` 计数（会话级，
  不落盘 —— 与 LPC `add_temp` 一致）。
  """
  def add_mark(conn, key, delta \\ 1) do
    character = current(conn)
    meta = PlayerMeta.add_temp(character.meta, key, delta)
    put_character(conn, %{character | meta: meta})
  end

  @doc "`set_temp(key, value)`：写 `meta.temp[key]`（会话级）"
  def put_temp(conn, key, value) do
    character = current(conn)
    meta = PlayerMeta.put_temp(character.meta, key, value)
    put_character(conn, %{character | meta: meta})
  end

  @doc """
  `query("food") >= max_food_capacity()*90/100`

  食物**当前值**尚未建模（属 O4 饥饿系统）：`meta.vitals` 无 `food` 字段时按 `0`
  计，于是新玩家（未吃饱）= 未满，守卫放行。容量走 `Kantele.Feature.Damage`。
  """
  def food_full?(conn) do
    character = current(conn)
    food = food_value(character)
    max = max_food(character)
    is_integer(max) and max > 0 and food >= div(max * 90, 100)
  end

  defp food_value(character) do
    case Map.get(character.meta || %{}, :vitals) do
      %{} = vitals -> Map.get(vitals, :food) || 0
      _ -> 0
    end
  end

  defp max_food(character) do
    Kantele.Feature.Damage.max_food_capacity(character)
  rescue
    _ -> 0
  end

  # 当前生效的 character：`put_character/2` 只写 `private.update_character`，
  # 后续 helper 必须经此读取，否则会丢掉同一 handler 内先前的改动。
  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp put_instance_meta(instance, meta) when meta == %{} or meta == nil, do: instance

  defp put_instance_meta(instance, meta),
    do: %{instance | meta: Map.merge(instance.meta || %{}, meta)}
end
