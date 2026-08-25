defmodule Web.PageController do
  use Web, :controller

  alias ExVenture.Characters
  alias Kantele.World.Kickoff

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def health(conn, _params) do
    # world: ok（最近一次加载成功）/ degraded（失败，旧世界降级运行）/ unknown
    {world, last_load_error} =
      case Kickoff.status() do
        %{status: :ok} ->
          {"ok", nil}

        %{status: :error, error: error} ->
          {"degraded", error}

        _ ->
          {"unknown", nil}
      end

    json(conn, %{
      status: "OK",
      world: world,
      last_load_error: last_load_error
    })
  end

  def client(conn, _params) do
    %{current_user: user} = conn.assigns

    case Characters.all_for(user) do
      [] ->
        conn
        |> put_flash(:info, "Please create a character first!")
        |> redirect(to: Routes.profile_path(conn, :show))

      characters ->
        conn
        |> assign(:characters, characters)
        |> put_layout("simple.html")
        |> render("client.html")
    end
  end
end
