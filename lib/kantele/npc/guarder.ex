defmodule Kantele.Npc.Guarder do
  @moduledoc """
  门派/区域守卫（对应 `feature/guarder.c`，mudren for FamilyWar）

  `permit_pass/3`：按门派/出生门派/所携带者放行判定，返回
  `{:allow}` / `{:deny, msg}`（msg 可含 $N/$n 占位由宿主渲染）。
  `check_enemy/3`：fight/kill/hit 的敌对判定，返回 `{:ignore}`（放行/驳回）
  或 `{:kill, ob_id}`（触发击杀）。

  纯函数：`my_family`/`my_name`/`guarder_msgs` 由宿主注入，`carried` 为
  携带者门派名列表。
  """

  @doc "守卫识别 (LPC: is_guarder)"
  def is_guarder?(_self), do: true

  @doc "放行判定 (LPC: permit_pass) full 版本"
  def permit_pass(opts) do
    %{
      living?: living,
      my_family: my_fam,
      guest_family: fam,
      guest_born_family: born_fam,
      carried_families: carried,
      msgs: msgs
    } = opts

    msgs = msgs || %{}

    cond do
      not living ->
        {:allow}

      born_fam == my_fam and fam != nil and fam != my_fam ->
        {:deny, Map.get(msgs, :refuse_home) || default_refuse_home(fam, my_fam)}

      my_fam != fam and my_fam != born_fam ->
        {:deny, Map.get(msgs, :refuse_other) || default_refuse_other(my_fam)}

      Enum.any?(carried, fn c -> c != fam end) ->
        {:deny, Map.get(msgs, :refuse_carry) || "你背的是谁？还不快快放下！"}

      true ->
        {:allow}
    end
  end

  @doc """
  kill_enemy：守卫被攻击时呼唤帮手

  检查 coagents 列表，若守卫在 startroom 且有帮手，则返回待调用的帮手列表。
  宿主负责：加载 startroom、find coagent、调用 Coagent.start_help/1、发送消息。
  """
  def kill_enemy(opts) do
    %{
      coagents: coagents,
      startroom: startroom,
      current_room: current_room,
      enemy_id: enemy_id,
      enemy_name: enemy_name,
      enemy_in_target_room?: enemy_in_room
    } = opts

    cond do
      is_list(coagents) && length(coagents) < 1 ->
        {:no_coagents, "no coagents configured"}

      current_room != startroom ->
        {:not_at_startroom, "guarder not in startroom, skipping coagent call"}

      true ->
        helpers =
          coagents
          |> Enum.filter(fn c -> is_map(c) end)
          |> Enum.map(fn c ->
            %{
              id: Map.get(c, "id"),
              startroom: Map.get(c, "startroom"),
              target_id: enemy_id,
              target_room: current_room,
              in_target_room?: enemy_in_room
            }
          end)

        {:helpers_notified, helpers}
    end
  end

  @doc "check_enemy：按 fight/kill/hit 判定是否敌对。返回 :ignore 或 {:kill}"
  def check_enemy(opts) do
    %{my_family: my_fam, enemy_family: e_fam, enemy_name: e_name} = opts
    type = Map.get(opts, :type, "fight")

    if e_fam != my_fam do
      case type do
        "fight" -> {:ignore}
        _ -> {:kill, Map.get(opts, :enemy_id)}
      end
    else
      case type do
        t when t in ["hit", "kill"] -> {:kill, Map.get(opts, :enemy_id)}
        "fight" -> {:refuse_fight, e_name}
        _ -> {:ignore}
      end
    end
  end

  defp default_refuse_home(fam, my_fam),
    do: "你既然已经入了#{fam}，还来我们#{my_fam}干什么？"

  defp default_refuse_other(my_fam), do: "对不起，不是我们#{my_fam}的人不得入内！"
end
