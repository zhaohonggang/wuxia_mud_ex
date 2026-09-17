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

  - `family/detach`：玩家命令发出，由房间转发给目标 NPC（见
    `Kantele.World.Room.DetachRequestEvent`）
  - `family/detach-result`：NPC 回执其门派身份 `%{ok, family, master_id,
    master_name}`；玩家侧据**自身** family 用 `Master.attempt_detach` 判定
    是否嫡传与是否惩罚，惩罚则降武功/清门派/清贡献（玩家侧校验）

  `old_family`（转世脱离一次免罚）暂传 `nil`（正常叛师=罚）；将来接转世
  历史字段后再补。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Npc.Master

  def detach_result(conn, %{data: %{ok: false, reason: reason}}) do
    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def detach_result(conn, %{data: %{ok: true, family: family_name} = data}) do
    character = conn.character
    player_family = character.meta.family

    npc_family = %{
      name: family_name,
      master_id: Map.get(data, :master_id),
      master_name: Map.get(data, :master_name)
    }

    result =
      if is_map(player_family) do
        Master.attempt_detach(npc_family, player_family, nil)
      else
        {:noop}
      end

    case result do
      {:noop} ->
        conn
        |> render(CommandView, "text", %{
          text: "#{Map.get(data, :master_name, "师父")}摆了摆手：你并非我门下弟子，何来叛师之说？\n"
        })
        |> prompt(CommandView, "prompt", %{})

      {:detach, %{penalty?: penalty?}} ->
        stats = apply_penalty(character.meta.stats, penalty?)

        meta =
          character.meta
          |> Map.put(:family, nil)
          |> Map.put(:stats, stats)

        character = %{character | meta: meta}
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
  end

  # 降武功：各技能 -1 到最小 1（对应 skill_expell_penalty 的简化；LPC 精确版需
  # 逐技能 type/enable 元数据，暂缺来源）+ 清贡献
  defp apply_penalty(stats, true = _penalty?) do
    skills =
      Enum.reduce(stats.skills || %{}, %{}, fn {skill_id, level}, acc ->
        if is_integer(level) and level > 1 do
          Map.put(acc, skill_id, level - 1)
        else
          Map.put(acc, skill_id, level)
        end
      end)

    %{stats | skills: skills, gongxian: 0}
  end

  defp apply_penalty(stats, _penalty?), do: stats
end
