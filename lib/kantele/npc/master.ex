defmodule Kantele.Npc.Master do
  @moduledoc """
  师门掌门/师父（对应 `feature/master.c`）

  - `prevent_learn?/2`: 是否阻止向我学习。若非我嫡传但同门派 -> 阻止
  - `attempt_detach/2`: 叛师处理，返回
    `{:noop}`（非我弟子） / `{:detach, %{penalty?: bool}}`（执行叛师）

  副作用（skill_expell_penalty、unconcious、删除 family/gongxian/quest、
  置 title）由宿主执行。
  """

  alias Kantele.Character.Family

  @doc "prevent_learn：非嫡传但同门派 -> 阻止 (`true`)"
  def prevent_learn?(my_family, _me_family, asker_family) do
    not Family.is_apprentice_of?(my_family, asker_family) and
      Family.has_family?(asker_family) and
      Family.same_family?(my_family, asker_family)
  end

  @doc "attempt_detach：叛师处理决策"
  def attempt_detach(my_family, asker_family, old_family) do
    cond do
      not Family.is_apprentice_of?(my_family, asker_family) ->
        {:noop}

      true ->
        # LPC: old_family_name 未设或与当前门派不同 -> 罚武功
        penalty? =
          old_family == nil or old_family != Family.name(asker_family)

        {:detach, %{penalty?: penalty?}}
    end
  end
end
