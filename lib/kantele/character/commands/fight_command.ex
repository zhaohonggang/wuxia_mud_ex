defmodule Kantele.Character.FightCommand do
  @moduledoc """
  开战命令：`fight <目标>` / `kill <目标>`

  目标解析走房间事件，由房间在本地角色中按名字精确匹配
  （Kalevala.Character.matches?/2），NPC 均为单词名可直接命中。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    conn
    |> event("combat/attack", %{name: params["name"]})
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Character.HaltCommand do
  @moduledoc """
  停手命令：`halt`，向所有敌人发停手请求并清空自身敌人列表
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    combat = character.meta.combat

    Enum.each(combat.enemies, fn enemy ->
      send(enemy.pid, %Event{from_pid: self(), topic: "combat/halt", data: %{id: character.id}})
    end)

    conn
    |> put_character(%{character | meta: %{character.meta | combat: Combat.new()}})
    |> render(CommandView, "text", %{text: "你收住招式，退开几步。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
