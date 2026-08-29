defmodule Kantele.Item.SilentDest do
  @moduledoc """
  无人见过即销毁（对应 `feature/silentdest.c`）

  物品挂在无玩家的房间且其环境链上没有角色时，销毁之。
  `should_destruct?/2` 纯判定。

  - `env_chain_has_character?/1`: 环境链是否含 `is_character?` 的角色
  - `room_has_user?/1`: 房间是否至少有一名玩家
  - `should_destruct?/2`: 二者皆否 -> 可销毁（LPC reset 清场）
  """

  @doc "环境链是否存在角色（LPC: while(env) if(env->is_character()) return）"
  def env_chain_has_character?(env, char? \\ &is_character?/1) do
    walk_chain(env, char?)
  end

  @doc "房间内是否有玩家（LPC: filter all_inventory userp）"
  def room_has_user?(occupants, user? \\ &is_user?/1) do
    Enum.any?(occupants, user?)
  end

  @doc "是否应销毁（环境链无角色 且 房间无玩家）"
  def should_destruct?(env, occupants, opts \\ %{}) do
    not env_chain_has_character?(env, Map.get(opts, :char?, &is_character?/1)) and
      not room_has_user?(occupants, Map.get(opts, :user?, &is_user?/1))
  end

  defp walk_chain(nil, _char?), do: false
  defp walk_chain(env, char?) do
    if char?.(env) do
      true
    else
      walk_chain(Map.get(env, :environment), char?)
    end
  end

  defp is_character?(env), do: Map.get(env, :kind) == :character
  defp is_user?(occ), do: Map.get(occ, :kind) == :user
end