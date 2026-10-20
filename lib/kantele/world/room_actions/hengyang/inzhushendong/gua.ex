defmodule Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua do
  @moduledoc """
  `d/hengyang/inzhushendong.c` 的 `do_gua`（`add_action("do_gua", "gua")`）。

  LPC 原文：

      int do_gua(string arg)
      {
          object me = this_player();

          if (me->is_busy())
                return notify_fail("你现在正忙着呢。\\n");

          if (me->is_fighting())
                return notify_fail("你在战斗哦？！小心，来了！！！\\n");

          if (! arg || arg != "bi")
                return notify_fail("你要刮什么？\\n");

          write(HIG "\\n你走到山壁旁，将山壁上的尘土一一刮去，后面景象一一显露了出来。\\n" NOR);
          me->set_temp("gua", 1);

          return 1;
      }

  刮去尘土后设置角色会话 temp `gua`，随后 `look bi` / `look pic1..3`
  才显示石壁图案（见 `Kantele.World.ItemDescHandlers.GatedText`）。
  `canwu` / `think` 属于学招逻辑（P5-7），本试点不注册。
  """
  use Kantele.World.RoomAction

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @message "\n你走到山壁旁，将山壁上的尘土一一刮去，后面景象一一显露了出来。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    combat = conn.character.meta.combat

    cond do
      busy?(combat) ->
        Helpers.render_to_player(conn, "你现在正忙着呢。\n")

      fighting?(combat) ->
        Helpers.render_to_player(conn, "你在战斗哦？！小心，来了！！！\n")

      String.trim(arg) != "bi" ->
        Helpers.render_to_player(conn, "你要刮什么？\n")

      true ->
        conn
        |> Helpers.render_to_player(@message)
        |> put_temp("gua", 1)
    end
  end

  defp busy?(nil), do: false
  defp busy?(combat), do: Combat.busy?(combat)

  defp fighting?(nil), do: false
  defp fighting?(combat), do: Combat.fighting?(combat)

  defp put_temp(conn, key, value) do
    character = %{
      conn.character
      | meta: PlayerMeta.put_temp(conn.character.meta, key, value)
    }

    %{conn | private: %{conn.private | update_character: character}}
  end
end
