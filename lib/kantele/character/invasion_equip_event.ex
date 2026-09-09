defmodule Kantele.Character.InvasionEquipEvent do
  @moduledoc """
  入侵 NPC 自动装备事件处理器

  由 SpawnController 通过 initial_events 触发，延迟 1 秒后运行，
  将背包中的武器/护甲装备到 combat.equipped 槽位。
  """

  use Kalevala.Character.Event

  require Logger

  import Kalevala.Character.Conn

  alias Kantele.Character.Combat
  alias Kantele.Item.Equip
  alias Kantele.World.Invasion.NPC
  alias Kantele.World.Items

  @impl true
  def call(conn, %Kalevala.Event{data: data}) do
    conn
    |> NPC.equip_invader(data)
    |> Logger.debug("invasion NPC equipped: #{inspect(data)}")
  rescue
    e ->
      Logger.warn("invasion equip event failed: #{Exception.message(e)}")
      conn
  catch
    :exit, reason ->
      Logger.warn("invasion equip event exit: #{inspect(reason)}")
      conn
  end
end