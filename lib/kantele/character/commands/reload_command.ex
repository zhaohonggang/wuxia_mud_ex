defmodule Kantele.Character.ReloadCommand do
  @moduledoc """
  WARNING

  Use this command only for development purposes!

  It will hard refresh all game state
  """

  use Kalevala.Character.Command

  alias Kantele.Character.ReloadView
  alias Kantele.World.Kickoff

  def recompile(conn, _params) do
    if Code.ensure_loaded?(Mix) do
      IEx.Helpers.recompile()
    end

    render(conn, ReloadView, "recompiled")
  end

  def reload(conn, _params) do
    if Code.ensure_loaded?(Mix) do
      IEx.Helpers.recompile()
    end

    case Kickoff.reload() do
      :ok ->
        render(conn, ReloadView, "reloaded")

      {:error, last_load} ->
        render(conn, ReloadView, "reload_failed", %{
          error: last_load.error,
          file: last_load.file
        })
    end
  end
end
