defmodule Kantele.Object.CleanUp do
  @moduledoc """
  空闲对象清场（对应 `feature/clean_up.c` by Mud.Ren）

  纯决策：返回 `:never_again`（销毁） / `:again`（保留待下次）。
  判定顺序与 LPC 一致：
  1. no_clean_up == 1 的非复制对象 → 保留
  2. interactive（在线玩家）→ 保留
  3. 正在 quest 服务（quest_ob）→ 保留
  4. 被容器包裹（environment）→ 保留（由环境代管）
  5. 环境内任一：玩家 / quest 服务 / is_stay_in_room → 保留
  """
  @doc "决策：返回 :never_again（清场） / :again（保留）"
  def decide(opts) do
    %{
      is_clone?: is_clone,
      no_clean_up: no_clean_up,
      interactive?: interactive,
      quest_ob?: quest_ob,
      environment: env,
      occupants: occupants
    } = opts

    keep? =
      (not is_clone and no_clean_up == 1) or
        interactive or
        quest_ob or
        env != nil or
        room_has_live?(occupants)

    if keep?, do: :again, else: :never_again
  end

  @doc "环境内是否有在线玩家/quest/留守物 (LPC all_inventory 循环)"
  def room_has_live?(occupants) do
    Enum.any?(occupants, fn o ->
      Map.get(o, :interactive) || Map.get(o, :quest_ob) || Map.get(o, :stay_in_room)
    end)
  end
end
