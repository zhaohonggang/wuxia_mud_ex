defmodule Kantele.Character.Family do
  @moduledoc """
  师徒/门派关系引擎（对应 `feature/apprentice.c` from ES2/XKX）

  在运行态 family map（`%{name, master_id, master_name, generation, title,
  privs, enter_time}`，与框架 `meta.family` 的 atom-key 约定一致）上做派生
  与收徒逻辑。纯函数，不落盘副作用由宿主负责。

  备注：LPC 用 `family_name`，框架统一为 `name`（见 `family_event.ex` 写入
  `%{name:, master_id:, master_name:}`）。
  """

  @doc "是否有门派（LPC: mapp(query(family))）"
  def has_family?(family) when is_map(family) and map_size(family) > 0, do: true
  def has_family?(_), do: false

  @doc "某玩家是否是我的嫡传弟子 (LPC: is_apprentice_of)"
  def is_apprentice_of?(my_family, other_family) do
    cond do
      match_master?(my_family, other_family) ->
        true

      # 转世后同门派也算（LPC: reborn/family_name == other family_name）
      reborn_same_family?(my_family, other_family) ->
        true

      true ->
        false
    end
  end

  @doc "家族名（nil-safe）"
  def name(family), do: Map.get(family, :name) || Map.get(family, "name")

  @doc """
  assign_apprentice：设定辈分称号与权限 (LPC: assign_apprentice(title, privs))

  返回带 title 的新 family。`title/1` 按 generation 计算称谓：
  - gen 0: 家族名 + 称号（仅玩家/无 title 时）
  - gen 1: 家族名 + "开山祖师"
  - gen n: 家族名 + "第n代" + 称号
  """
  def assign_apprentice(family, title, privs \\ 0) do
    family
    |> Map.put(:title, title)
    |> Map.put(:privs, privs)
    |> maybe_set_rank_title(title)
  end

  @doc "创建新家族 (LPC: create_family(name, generation, title))；priv=-1 全权限"
  def create_family(name, generation, title) do
    %{name: name, generation: generation}
    |> Map.put(:master_id, nil)
    |> Map.put(:master_name, nil)
    |> assign_apprentice(title, -1)
  end

  @doc """
  收徒 (LPC: recruit_apprentice)：师父收徒，生成徒弟家族 map

  返回 `{:error, :already}` / `{:error, :no_family}` /
  `{:ok, new_family, %{class_propagate?: bool, inherit_title: boolean}}`。
  """
  def recruit_apprentice(my_family, other_family, opts \\ %{}) do
    cond do
      is_apprentice_of?(my_family, other_family) -> {:error, :already}
      not has_family?(my_family) -> {:error, :no_family}
      true -> do_recruit(my_family, other_family, opts)
    end
  end

  @doc "门派名称比较（nil 安全）"
  def same_family?(a, b), do: name(a) == name(b)

  # ---- internal ----

  defp do_recruit(my_family, _other_family, opts) do
    # LPC: non-bonze/eunach class propagates to apprentice
    class_propagate? =
      Map.get(opts, :class) not in [nil, "bonze", "eunach"] and
        true

    new_family = %{
      master_id: Map.get(my_family, :master_id) || Map.get(opts, :master_id),
      master_name: Map.get(my_family, :master_name) || Map.get(opts, :master_name),
      name: name(my_family),
      generation: (Map.get(my_family, :generation) || 0) + 1,
      enter_time: Map.get(opts, :enter_time) || div(System.system_time(:second), 1)
    }

    inherit_title = Map.get(opts, :inherit_title)
    born_family = Map.get(opts, :born_family)

    new_family =
      if inherit_title do
        Map.put(new_family, :title, inherit_title)
      else
        Map.put(new_family, :title, if(born_family != "没有", do: "传人", else: "弟子"))
      end

    if inherit_title do
      {:ok, new_family, %{class_propagate?: class_propagate?, inherit_title: true}}
    else
      new_family = assign_apprentice(new_family, new_family.title, 0)
      {:ok, new_family, %{class_propagate?: class_propagate?, inherit_title: false}}
    end
  end

  defp match_master?(my_family, other_family) do
    mid = Map.get(other_family, :master_id)

    mid != nil and
      mid == Map.get(my_family, :master_id) and
      Map.get(other_family, :master_name) == Map.get(my_family, :master_name)
  end

  defp reborn_same_family?(my_family, other_family) do
    my_reborn = Map.get(my_family, :reborn_family)
    other_name = name(other_family)
    my_reborn != nil and other_name != nil and my_reborn == other_name
  end

  defp maybe_set_rank_title(family, title) do
    gen = Map.get(family, :generation)
    fname = name(family)

    display =
      cond do
        gen == nil -> fname && "#{fname}#{title}"
        gen == 0 -> fname && "#{fname}#{title}"
        gen == 1 -> "#{fname}开山祖师"
        true -> "#{fname}第#{chinese_number(gen)}代#{title}"
      end

    if display, do: Map.put(family, :rank_title, display), else: family
  end

  defp chinese_number(n) when n in 0..9, do: Enum.at(~w(零 一 二 三 四 五 六 七 八 九), n)
  defp chinese_number(n), do: Integer.to_string(n)
end
