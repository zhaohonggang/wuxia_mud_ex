defmodule Kantele.Character.DivorceCommand do
  @moduledoc """
  离婚命令：`divorce`

  对应 LPC cmds/usr/divorce.c。二次确认后清除双方 meta.spouse。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Presence
  alias Kantele.Character.Records

  def run(conn, %{"arg" => _arg}) do
    run(conn, %{})
  end

  def run(conn, %{}) do
    character = conn.character

    case PlayerMeta.spouse(character.meta) do
      nil ->
        render_msg(conn, "你现在好像是单身一人吧？\n")

      spouse ->
        if PlayerMeta.get_temp(character.meta, "pending/divorce") do
          do_divorce(conn, character, spouse)
        else
          meta = PlayerMeta.put_temp(character.meta, "pending/divorce", 1)
          new_conn = put_character(conn, %{character | meta: meta})
          save(new_conn)

          render_msg(
            new_conn,
            "你身边连个证婚的人都没有，就这样草草离了？要是确定，就再输入一次 divorce 表示决心。\n"
          )
        end
    end
  end

  defp do_divorce(conn, character, spouse) do
    meta = PlayerMeta.put_spouse(character.meta, nil)
    new_conn = put_character(conn, %{character | meta: meta})
    save(new_conn)

    # 若配偶在线，通知其同步清除 meta.spouse
    if partner = find_player(spouse.id) do
      send(partner.pid, %Event{from_pid: self(), topic: "engage/divorced", data: %{}})
    end

    render_msg(new_conn, "你下定决心，和#{spouse.name}(#{spouse.id})彻底分手，从此各走各路。\n")
  end

  defp find_player(id) do
    Enum.find(Presence.characters(), fn c -> c.id == id end)
  end

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
