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
    maybe_recompile()
    render(conn, ReloadView, "recompiled")
  end

  def reload(conn, _params) do
    maybe_recompile()

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

  # `IEx.Helpers.recompile/0` 会触发全项目重编译 + 协议合并，在并发测试套件里
  # 会长时间占用全局 code_server（实测全量套件单用例超时 60s），并可能 purge
  # 掉其它用例正在使用的模块。测试环境只需验证命令回执，跳过真实重编译。
  defp maybe_recompile do
    if Code.ensure_loaded?(Mix) and Mix.env() != :test do
      IEx.Helpers.recompile()
    end

    :ok
  end
end
