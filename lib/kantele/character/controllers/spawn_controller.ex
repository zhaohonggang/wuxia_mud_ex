defmodule Kantele.Character.SpawnController do
  use Kalevala.Character.Controller

  require Logger

  alias Kalevala.Brain
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.Combat
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.NonPlayerEvents
  alias Kantele.Character.SpawnView
  alias Kantele.Character.TellEvent
  alias Kantele.CharacterChannel
  alias Kantele.Communication
  alias Kantele.Item.Equip
  alias Kantele.World.Item, as: WorldItem

  @impl true
  def init(conn) do
    character = conn.character

    # 启动自然回复循环（foreman 自投递）
    Kantele.Character.CombatEvent.kick_regen()

    conn = equip_carry(conn)

    conn =
      Enum.reduce(character.meta.initial_events, conn, fn initial_event, conn ->
        delay_event(conn, initial_event.delay, initial_event.topic, initial_event.data)
      end)

    conn
    |> move(:to, character.room_id, SpawnView, "spawn", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> event("room/look", %{})
  end

  @impl true
  def event(conn, event) do
    cond do
      dead?(conn.character) and event.topic == "combat/respawn" ->
        # 尸体只放行自己的重生定时器，其余事件静默忽略
        NonPlayerEvents.call(conn, event)

      dead?(conn.character) ->
        # 尸体不跑行为树
        conn

      true ->
        conn.character.brain
        |> Brain.run(conn, event)
        |> NonPlayerEvents.call(event)
    end
  end

  defp dead?(%{meta: %{combat: %Kantele.Character.Combat{dead: true}}}), do: true
  defp dead?(_), do: false

  # ---- LPC `carry_object(...)`：NPC 出生时把随身装备穿上 ----
  #
  # LPC:
  #     carry_object("/clone/weapon/gangdao")->wield();
  #     carry_object("/clone/cloth/cloth")->wear();
  #
  # 转换器只保留了物品列表（`carry = [{ id = items.gangdao.id }]`），
  # `wield()` / `wear()` 的动作丢了，所以按**物品自身类型**推断该穿哪：
  # 有 skill_type -> 兵器槽，有 armor/armor_type -> 对应衣物槽。
  #
  # 算法与玩家的 `wield` / `wear` 命令共用（wield_command 的
  # put_weapon_snapshot/3、apply_armor_prop/2），保证同一把刀 NPC 拿着
  # 和玩家拿着属性一致 —— 不自己重算一遍。
  #
  # 为什么放在出生时而不是加载时：加载期 Items cache 的 ETS 表还不存在
  # （`Kantele.World.Kickoff` 是 load 完之后才 `cache_item`），
  # 在 loader 里查会 `argument error` 直接崩掉整个区的解析。
  defp equip_carry(conn) do
    case Map.get(conn.character.meta, :carry) || [] do
      [] ->
        conn

      item_ids ->
        Enum.reduce(item_ids, conn, &put_one/2)
    end
  end

  defp put_one(item_id, conn) do
    item = WorldItem.fetch(item_id)

    instance = %Instance{
      id: Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      item: item
    }

    character = %{conn.character | inventory: conn.character.inventory ++ [instance]}

    conn = put_character(conn, character)

    case slot_of(item) do
      nil -> conn
      slot -> equip_slot(conn, slot, item)
    end
  end

  defp slot_of(%{meta: meta}) do
    cond do
      armor_slot(meta) != nil -> armor_slot(meta)
      Map.get(meta, :skill_type) not in [nil, ""] -> :weapon
      true -> nil
    end
  end

  defp equip_slot(conn, :weapon, item) do
    snapshot = %{
      name: item.name,
      skill_type: Map.get(item.meta, :skill_type, "sword"),
      damage: Map.get(item.meta, :damage) || 0,
      prop: Map.get(item.meta, :weapon_prop),
      flag: Map.get(item.meta, :flag, 1)
    }

    combat = Combat.equip(conn.character.meta.combat, :weapon, snapshot)

    put_character(conn, %{conn.character | meta: %{conn.character.meta | combat: combat}})
  end

  defp equip_slot(conn, slot, item) do
    snapshot = %{
      name: item.name,
      armor: Map.get(item.meta, :armor) || 0,
      prop: Map.get(item.meta, :armor_prop),
      consistence: Map.get(item.meta, :consistence) || 100
    }

    combat =
      conn.character.meta.combat
      |> Combat.equip(slot, snapshot)
      |> Combat.apply_temp(Equip.wear_state(%{}, snapshot.armor, snapshot.prop))

    put_character(conn, %{conn.character | meta: %{conn.character.meta | combat: combat}})
  end

  # 与 wield_command.armor_slot/1 同源
  defp armor_slot(meta) do
    case Map.get(meta, :armor_type) do
      nil -> nil
      "" -> nil
      other -> Kantele.World.Item.Meta.normalize_armor_type(other)
    end
  end

  @impl true
  def recv(conn, _text), do: conn

  @impl true
  def display(conn, _text), do: conn

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]

    case Communication.register("characters:#{character.id}", CharacterChannel, options) do
      :ok ->
        :ok

      {:error, :already_registered} ->
        # foreman 崩溃重启等场景下频道仍在，直接复用
        Logger.warn("Character channel already registered, reusing - #{character.id}")

        :ok

      {:error, reason} ->
        Logger.error("Failed to register character channel - #{inspect(reason)}")

        :ok
    end

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end
