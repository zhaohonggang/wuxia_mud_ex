defmodule Kantele.Character.FollowEvent do
  @moduledoc """
  跟随的事件处理（Batch 5）

  - `follow/set-leader`（跟随者）：记录 leader 并提示
  - `follow/register`（被跟随者）：把跟随者登记进 meta.followers
  - `follow/unregister`（被跟随者）：按 id 移除跟随者
  - `follow/move`（跟随者）：跟随 leader 移动，沿同一出口执行移动
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView

  def set_leader(conn, %{data: %{leader: leader}}) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | leader: leader}})
    |> render(CommandView, "text", %{text: "你决定开始跟随#{leader.name}一起行动。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def register(conn, %{data: %{follower: follower}}) do
    character = conn.character
    followers = ensure_followers(character)

    followers =
      Enum.reject(followers, &(&1.id == follower.id)) ++ [follower]

    conn
    |> put_character(%{character | meta: %{character.meta | followers: followers}})
    |> render(CommandView, "text", %{text: "#{follower.name}决定开始跟随你一起行动。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def unregister(conn, %{data: %{follower_id: follower_id}}) do
    character = conn.character
    followers = ensure_followers(character)

    followers = Enum.reject(followers, &(&1.id == follower_id))

    conn
    |> put_character(%{character | meta: %{character.meta | followers: followers}})
  end

  def move(conn, %{data: %{exit_name: exit_name}}) when is_binary(exit_name) and exit_name != "" do
    conn
    |> request_movement(exit_name)
    |> assign(:prompt, false)
  end

  def move(conn, _event), do: conn

  defp ensure_followers(character) do
    case Map.get(character.meta, :followers) do
      nil -> []
      followers when is_list(followers) -> followers
    end
  end
end
