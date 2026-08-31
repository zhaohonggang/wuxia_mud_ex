defmodule Kantele.Character.DetachCommand do
  @moduledoc """
  叛师命令：`detach <师父>` / `叛师 <师父>`

  向目标 NPC 发起叛师请求。NPC 侧使用 Kantele.Npc.Master.attempt_detach
  判定是否为嫡传弟子，是则执行叛师（扣武功/清门派/清贡献），否则婉拒。
  """

  use Kalevala.Character.Command

  alias Kalevala.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"name" => name}) do
    conn
    |> event("family/detach", %{name: name})
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Character.DetachEvent do
  @moduledoc """
  叛师事件处理（玩家侧）

  - `family/detach`：玩家发起，房间转发给目标 NPC
  - `family/detach-result`：NPC 应答，玩家侧执行惩罚/清理
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  # ---- 玩家侧应答 ----
  def detach_result(conn, %{data: %{ok: true, penalty?: penalty?}}) do
    character = conn.character

    # 叛师惩罚：若 penalty? 则降武功/清门派/清贡献
    stats = character.meta.stats
    meta = character.meta

    stats =
      if penalty? do
        # 降武功：各技能 -1 到最小 1（对应 skill_expell_penalty）
        Stats.all(stats)
        |> Enum.reduce(stats, fn {skill_id, level}, acc ->
          if level > 1 do
            Map.put(acc, skill_id, level - 1)
          else
            acc
          end
        end)
        |> Map.put(:gongxian, 0)
      else
        stats
      end

    # 清门派
    meta = Map.put(meta, :family, nil)

    character = %{character | meta: Map.put(meta, :stats, stats)}
    Records.save(character)

    text =
      if penalty? do
        "你毅然决然地叛离了师门！武功尽失一重，门派贡献归零。\n"
      else
        "你离开了师门，但武功未受影响。\n"
      end

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  def detach_result(conn, %{data: %{ok: false, reason: reason}}) do
    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
