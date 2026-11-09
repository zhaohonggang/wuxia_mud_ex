defmodule Kantele.Character.SuicideCommand do
  @moduledoc """
  自杀：`suicide` / `suicide -f <密码>`（cmds/usr/suicide.c）

  LPC 流程：`suicide -f` → 索要管理密码（`input_to`，隐藏输入）→ 校验
  `ad_password` → 15 秒 `halt` 可中止倒计时 → `UPDATE_D->remove_user(id)`
  连锁删除档案 + rumor 广播（combat_exp>=1000）。

  本端口简化（与 `passwd <新密码>` 内联风格一致，且不实现隐藏 input_to）：
  - 密码以 `suicide -f <密码>` 内联给出；校验 `meta.password`（明文，由 `passwd`
    写入；本端口未引入 bcrypt，沿用既有约定）。
  - 校验通过即**立即删除**角色档案（`ExVenture.Characters.delete_by_name`，
    按 name 删除 Character + PlayableCharacter），不实现 15 秒倒计时 / `halt`
    中止窗口（有意简化，待 v2）。
  - 删除前广播房间「化作轻烟」消息（排除自身）；combat_exp>=1000 时另发
    rumor 频道广播（LPC `CHANNEL_D->do_channel(..., "rumor", ...)`）。
  - 最后向玩家输出告别语并 `halt` 断开连接（LPC remove_user 后 link 失效）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Communication
  alias Kantele.World.Room
  alias ExVenture.Characters

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    case String.split(rest, ~r/\s+/, parts: 2) do
      ["-f", password] ->
        attempt_suicide(conn, String.trim(password))

      ["-f"] ->
        ask_password(conn)

      _ ->
        show_warning(conn)
    end
  end

  def run(conn, _params), do: show_warning(conn)

  defp show_warning(conn) do
    conn
    |> render(CommandView, "text", %{
      text:
        "您选择永远死掉的自杀方式，这个角色的资料将永远删除，请务必\n考虑清楚，确定的话请输入完整的自杀(suicide -f <密码>)指令。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp ask_password(conn) do
    conn
    |> render(CommandView, "text", %{
      text: "请输入您的管理密码（格式：suicide -f <密码>）：\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp attempt_suicide(conn, ""), do: ask_password(conn)

  defp attempt_suicide(conn, password) do
    cond do
      Combat.busy?(conn.character.meta.combat) ->
        busy(conn)

      carrying_player?(conn.character.inventory) ->
        conn
        |> render(CommandView, "text", %{
          text: "你身上还有个大活人呢，想不开也别急呀？\n"
        })
        |> prompt(CommandView, "prompt", %{})

      not password_matches?(conn.character, password) ->
        conn
        |> render(CommandView, "text", %{
          text: "\n密码错误！请注意，自杀必须输入管理密码。\n\n"
        })
        |> prompt(CommandView, "prompt", %{})

      true ->
        perform_deletion(conn)
    end
  end

  defp busy(conn) do
    conn
    |> render(CommandView, "text", %{text: "你上一个动作还没完成。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp password_matches?(character, password) do
    Map.get(character.meta, :password) == password
  end

  # LPC：deep_inventory 里有其它玩家/角色则拒绝。本端口背包只放物品/驭兽实例，
  # 角色不会进背包；此处仅做防御性检查（携带含 :character 字段的实例时拦截）。
  defp carrying_player?(inventory) when is_list(inventory) do
    Enum.any?(inventory, fn item -> Map.get(item, :character) != nil end)
  end

  defp carrying_player?(_), do: false

  defp perform_deletion(conn) do
    character = conn.character
    name = character.name
    room_id = character.room_id

    # LPC tell_room(environment(me), me->name() + "在你的面前化作轻烟……", ({me}))
    Room.tell_room(%{id: room_id}, "#{name}在你的面前化作轻烟，渐渐消失了……\n", character.pid)

    # LPC combat_exp >= 1000 -> CHANNEL_D->do_channel(this_object(), "rumor", ...)
    if combat_exp(character) >= 1000 do
      Communication.announce("rumor", "#{name}自杀了，以后你再也看不到这个人了。\n")
    end

    # LPC UPDATE_D->remove_user(me->query("id")) —— 按 name 删除 DB 档案
    Characters.delete_by_name(name)

    conn
    |> assign(:prompt, false)
    |> render(CommandView, "text", %{
      text: "既然如此…那就……永别了，#{name}。\n欢迎您能够以新的身份再次光临。\n"
    })
    |> halt()
  end

  defp combat_exp(character) do
    case character.meta.stats do
      %{combat_exp: exp} when is_integer(exp) -> exp
      _ -> 0
    end
  end
end
