defmodule Kantele.Character.FanliangyiEvent do
  @moduledoc """
  反两仪刀阵合作方事件（`fanliangyi-dao/makearray` 绝招的队友侧）。

  队长在自身进程组阵后投递 `fanliangyi-dao/array`（data 含 `leader` 与
  `n`）；队员侧 `array/2` 复验自身可查的门槛（会刀、>=30、激发 blade、
  持刀、max_neili>=50、未在阵中），通过则以 `n` 为当量
  attack/defense/damage/armor 临时加成并挂无期限 `array/fanliangyi-dao`
  buff（LPC `set_temp("array/level", n)` + `set_temp("no_quit",1)` 中的
  no_quit 未建模）。

  差异（TODO(migrate)）：
  - 校验不过静默忽略，不回执队长文案（队长远程无法取队龙泉技能/武器）；
  - 阵无解散机制（LPC `dismiss_array` 需队长侧遍历队伍，未建模）。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @array_key "array/fanliangyi-dao"

  def array(conn, %{data: %{leader: %{name: leader_name}, n: n}}) do
    character = conn.character
    combat = character.meta.combat

    if valid?(character, combat) do
      buff =
        %Combat.Buff{
          key: @array_key,
          applies: %{attack: -n, defense: -n, damage: -n, armor: -n}
        }

      combat =
        combat
        |> Combat.apply_temp(%{attack: n, defense: n, damage: n, armor: n})
        |> Combat.add_buff(buff)

      conn
      |> put_character(%{character | meta: %{character.meta | combat: combat}})
      |> render(CommandView, "text", %{
        text: "[反两仪刀阵] 你与#{leader_name}站定两仪方位，顿时两人之间显得浑然天成、毫无破绽。\n"
      })
      |> prompt(CommandView, "prompt", %{})
    else
      conn
    end
  end

  defp valid?(character, combat) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    Stats.skill(stats, "fanliangyi-dao") >= 30 &&
      Stats.mapped(stats, "blade") == "fanliangyi-dao" &&
      match?(%{skill_type: "blade"}, Combat.weapon(combat)) &&
      vitals.max_neili >= 50 &&
      not Combat.buff_active?(combat, @array_key)
  end
end