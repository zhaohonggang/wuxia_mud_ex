defmodule Kantele.World do
  @moduledoc """
  GenServer to load and boot the world
  """

  use Supervisor

  alias Kantele.World.Loader
  alias Kantele.World.ZoneCache

  defstruct characters: [], items: [], rooms: [], zones: []

  @doc """
  取某个房间某个方向的 valid_leave 提示语（LPC `notify_fail` 原文）

  房间侧判定成立时把移动中止掉，但中止事件里只有 reason 这个原子、带不了正文
  （Kalevala 的 `Movement.handle_request({:abort, event, reason})`），而房间回调里
  调用的 `Context.render/5` 只是把文本累积进 `context.output`、在移动链路上会被
  丢弃 —— 所以正文由角色侧在 abort 时按「房间 id + 方向」回查并渲染。
  """
  def exit_veto_message(room_id, dir) when is_binary(room_id) and is_binary(dir) do
    with [zone_id | _] <- String.split(room_id, ":"),
         {:ok, zone} <- ZoneCache.get(zone_id),
         room when not is_nil(room) <- find_room(zone, room_id) do
      vetoes = Map.get(room, :exit_vetoes, []) || []

      # 先找方向精确匹配的，再退回通配（direction = "*" / nil）。
      # all_dirs 的条件本来就是「所有方向都拦」（如 shaolin:dmyuan2 的心法门、
      # city:eproom 的拱猪桌），只按方向找会找不到提示语，玩家就只看到被拦、
      # 看不到原因。
      msg =
        Enum.find_value(vetoes, fn veto ->
          if Map.get(veto, :direction) == dir, do: Map.get(veto, :message)
        end)

      msg ||
        Enum.find_value(vetoes, fn veto ->
          case Map.get(veto, :direction) do
            "*" -> Map.get(veto, :message)
            nil -> Map.get(veto, :message)
            _ -> nil
          end
        end)
    else
      _ -> nil
    end
  end

  def exit_veto_message(_room_id, _dir), do: nil

  defp find_room(zone, room_id) do
    Enum.find(Map.get(zone, :rooms, []) || [], &(&1.id == room_id))
  end

  @doc """
  Dereference a world variable reference
  """
  def dereference(reference) when is_binary(reference) do
    dereference(String.split(reference, "."))
  end

  def dereference([zone_id | reference]) do
    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        Loader.dereference(zone, reference)

      _ ->
        :error
    end
  end

  @doc "按房间 id 查 flags（A5/D2；查不到或格式异常返回空列表）"
  def room_flags(room_id) when is_binary(room_id) do
    zone_id =
      room_id
      |> String.split(":")
      |> hd()

    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        zone
        |> zone_rooms()
        |> Enum.find(fn room -> Map.get(room, :id) == room_id end)
        |> case do
          nil ->
            []

          room ->
            flags = Map.get(room, :flags, [])
            if is_list(flags), do: flags, else: []
        end

      _ ->
        []
    end
  end

  def room_flags(_), do: []

  # 缓存中的 `Zone.rooms` 运行时是列表：Loader 在交给 ZoneCache 之前会经
  # `zone_rooms_to_list/1` 把 map 归一为 `Map.values/1`（见 loader.ex:178-179）。
  # 但直接写缓存的调用方（测试种子、外部工具）可能塞进未归一的 map，
  # 此时 `Enum.find/2`、`Enum.flat_map/2` 会拿到 `{key, value}` 元组，
  # 后续 `.id` / `Map.get/3` 便抛 BadMapError，把玩家指令甚至登录流程炸掉。
  # 这里统一兜底成列表，两种形状都能安全遍历。
  defp zone_rooms(zone) do
    case Map.get(zone, :rooms, []) do
      rooms when is_map(rooms) -> Map.values(rooms)
      rooms when is_list(rooms) -> rooms
      _ -> []
    end
  end

  @doc """
  出生点房间 id（A5/D2 startroom flag）

  优先取全库第一个带 "startroom" flag 的房间；没有则回落到 config
  `player.starting_room_id`（dereference 后的 id）。
  """
  def start_room_id() do
    case start_room_from_flags() do
      nil ->
        dereference(Kantele.Config.get([:player, :starting_room_id]))

      room_id ->
        room_id
    end
  end

  @doc """
  新玩家出生点（阎罗殿，对应 LPC `BORN_ROOM=/d/register/yanluodian`）

  新玩家首次登录、尚未完成注册问答（`meta.env[:setup_done] != true`）时，被放入
  此房间进行「洗点(washto)」与「投胎(born)」问答，与 LPC 玩家体验一致。

  完成注册后该房间不再作为登录落点——玩家重登回到 `meta.env[:startroom]`（其
  选定的出生地），见 `LoginController.process_character` 的落点逻辑。
  """
  def born_room_id(), do: "register:yanluodian"

  @doc """
  死亡落点（地府鬼门关，对应 LPC `login.h:27 DEATH_ROOM "/d/death/gate"`）。

  LPC `feature/damage.c:447-449` 在 `die()` 里 `ghost = 1; me->move(DEATH_ROOM)`，
  落点是**鬼门关**（白无常在此接引），不是阎罗殿深处。此前误设
  `death:yanluodian`（阎罗殿），玩家会直接跳过地府前段，故修正。
  """
  def death_room_id(), do: "death:gate"

  @doc """
  还阳落点（城外武庙，对应 LPC `login.h:28 REVIVE_ROOM "/d/city/wumiao"`）。

  LPC `d/death/npc/bai.c:96-106`（白无常 30 秒自动还阳）与 `hei.c:92-102`
  `ob->reincarnate(); ob->move(REVIVE_ROOM); ob->set("startroom", REVIVE_ROOM);`。
  """
  def revive_room_id(), do: "city:wumiao"

  @doc """
  查找 NPC 定义（供 `clone` 命令生物克隆用）。

  按 id（如 `"clone_lib:clone_tong_ren"`）精确匹配，否则按 name 在所有已缓存
  zone 里搜索。返回 `%Kalevala.Character{}` 定义或 `nil`。

  对应 LPC `clone.c` 的 `new(file)` —— 从世界数据里按路径/名实例化 NPC 原型。
  """
  def find_npc_definition(target) when is_binary(target) do
    # 先尝试精确 id 匹配（"zone:name" 格式）
    case String.split(target, ":") do
      [zone_id, _char_name] ->
        case ZoneCache.get(zone_id) do
          {:ok, zone} ->
            chars = zone_characters(zone)
            Enum.find(chars, &(&1.id == target))

          _ ->
            nil
        end

      _ ->
        nil
    end ||

      # 回退：按 name 在所有 zone 里搜索
      find_npc_definition_by_name(target)
  end

  defp find_npc_definition_by_name(target) do
    ZoneCache.keys()
    |> Enum.find_value(fn zone_id ->
      case ZoneCache.get(zone_id) do
        {:ok, zone} ->
          chars = zone_characters(zone)
          Enum.find(chars, &(String.downcase(&1.name) == String.downcase(target)))

        _ ->
          nil
      end
    end)
  end

  defp zone_characters(zone) do
    chars = Map.get(zone, :characters, %{})
    case chars do
      %{} = m -> Map.values(m)
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp start_room_from_flags() do
    ZoneCache.keys()
    |> Enum.sort()
    |> Enum.flat_map(fn zone_id ->
      case ZoneCache.get(zone_id) do
        {:ok, zone} -> zone_rooms(zone)
        _ -> []
      end
    end)
    |> Enum.find_value(fn room ->
      flags = Map.get(room, :flags, [])

      if is_list(flags) and "startroom" in flags do
        room.id
      else
        nil
      end
    end)
  end

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:ex_venture, :kantele_world, [])
    kickoff = Keyword.get(config, :kickoff, true)

    children = [
      {ZoneCache, [id: ZoneCache, name: ZoneCache]},
      # 擂台关闭状态（room.ex 的 movement_request 要跨房间读它）
      {Kantele.World.Arena, [id: Kantele.World.Arena, name: Kantele.World.Arena]},
      # FINGER_D 通缉告示牌（16 城门/关卡的 look_gaoshi 读它；P5-4p）
      {Kantele.World.FingerD, [id: Kantele.World.FingerD, name: Kantele.World.FingerD]},
      {Kantele.World.Items, [id: Kantele.World.Items, name: Kantele.World.Items]},
      {Kalevala.World, [name: Kantele.World]},
      {Kantele.World.Kickoff, [name: Kantele.World.Kickoff, start: kickoff]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
