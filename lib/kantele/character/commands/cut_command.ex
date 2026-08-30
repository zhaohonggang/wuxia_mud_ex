defmodule Kantele.Character.CutCommand do
  @moduledoc """
  解剖命令：`cut <部位> from <尸体>` / `cut <who>`（`cmds/std/cut.c` + `feature/cutable.c`）

  - `cut <who>` 等同 `cut ? from <who>`，列出该尸体可割部位
  - `cut <部位> from <who>` 割下指定部位：先经房间解析尸体目标（cut.c 守卫：
    附近无物/割自己/活人），再转尸体进程执行 `do_cut`
  - 部位产物以物品实例直接入包（auto_get 简化：不落房间）

  携带施术者武器/修为快照（validate_cut 需要的 weapon_skill_type/weapon_name/
  skills/force），由尸体侧校验部位并裁决。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  def run(conn, params) do
    arg = params["arg"] || ""

    case String.trim(arg) do
      "" ->
        conn
        |> render(CommandView, "text", %{text: "你要割什么东西？\n"})
        |> prompt(CommandView, "prompt", %{})

      arg ->
        {part, who} = parse_arg(arg)

        conn
        |> event("room/cut", %{
          name: who,
          part: part,
          weapon_skill_type: weapon_skill_type(conn.character),
          weapon_name: weapon_name(conn.character),
          skills: conn.character.meta.stats.skills,
          force: Stats.effective(conn.character.meta.stats, "force")
        })
        |> assign(:prompt, false)
    end
  end

  def run_bare(conn, _params), do: run(conn, %{"arg" => ""})

  # cut.c：`cut <part> from <who>`；无 from 则整串视为 <who>，部位置 "?"（列出可割部位）
  defp parse_arg(arg) do
    case String.split(arg, " from ", parts: 2) do
      [part, who] -> {String.trim(part), String.trim(who)}
      _ -> {"?", arg}
    end
  end

  defp weapon_skill_type(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: skill_type} -> skill_type
      _ -> nil
    end
  end

  defp weapon_name(character) do
    case Combat.weapon(character.meta.combat) do
      %{name: name} -> name
      _ -> nil
    end
  end
end