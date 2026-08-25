defmodule Kantele.Character.ApprenticeCommand do
  @moduledoc """
  拜师命令：`apprentice <师父>`（A11/N5 门派 v0）

  经房间转发给目标 NPC；NPC 带 teach 配置（有门派）即应允，
  玩家记录 family（门派名/师父），贡献自此累积。叛师/逐出等留待 b 期。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    conn
    |> event("family/apprentice", %{name: params["name"]})
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Character.PaiCommand do
  @moduledoc """
  门派信息：`pai`，只读展示师承与门派贡献（A11/N5 v0）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.PaiView

  def run(conn, _params) do
    character = conn.character

    render(conn, PaiView, "display", %{
      family: character.meta.family,
      gongxian: character.meta.stats.gongxian || 0,
      score: character.meta.stats.score || 0,
      weiwang: character.meta.stats.weiwang || 0,
      shen: character.meta.stats.shen || 0,
      teach: nil
    })
  end
end
