defmodule Kantele.SectMaster do
  @moduledoc """
  门派师父判定（F3）：纯函数宿主——只做门槛判定链条，不改写任何既有入参形状。

  **决策（用户拍板"全量接线"但 E2 拍板"保持原样"权衡后收敛为）：**
  本职**只用已存在寄主组件**——`Family`/`Master`/`LearnGate`/`Stats`——
  把散落在 skills_event/room 各处的门槛判定收敛进一个纯函数贫口；
  本模块**不新增任何宿主调用点**（不碰 teach/2 主链、不碰 family/recruit、
  不碰 room 对话），各调用方维持现状。

  宿主形状（已读盘核实，不再臆造）：
    - 师父信息存 `character.meta` 的 `teach`（loader 解析 `teach.family/teach.skills/no_teach`，
      loader.ex:495-510）。
    - 门派信息在 `family`（`name`/`family_name`），学生门派在
      `character_meta.family`（`@doc"师门"` 见 family.ex:23 形状）。
    - 门槛数值：`min_shen/min_exp/min_force`（转世师父门槛，UCL teach 段）。

  ## teachable?/2
  是否可学某特技/技能：`Master.prevent_learn?`(同门派又非嫡传) 拦截 +
  `Master.prevent_progress?`(等级上限) + 门派判定。

  ## recruit_gate?/3
  收徒门槛：`Family.recruit_apprentice?` 已有判定 + 师父 min_shen 门槛。

  ## inquiry_grant/2
  问答授绝招：`Master.inquiry_grant?`（未接，返回值固定 `{:ok, :none}` 占位）。
  """

  alias Kantele.Character.Family
  alias Kantele.Character.Master
  alias Kantele.Character.LearnGate
  alias Kantele.Character.Stats

  @doc "师父是否能教该技能（LPC teach/2 门槛链收敛）"
  def teachable?(teacher, student, skill) do
    my_family = family_of(teacher)
    student_family = family_of(student)

    cond do
      # 同门派但非嫡传：Master 判定
      Family.same_family?(my_family, student_family) and
          not Family.is_apprentice_of?(my_family, student_family) ->
        {:error, "你非本门嫡传，老夫不便传授。\n"}

      # 门派融合判定（对应 room.ex:1542 teach）
      Master.prevent_learn?(teacher_stats(teacher), student_stats(student), skill) ->
        {:error, "这一门功夫你已不弱于老夫，没什么可教的了。\n"}

      true ->
        :ok
    end
  end

  @doc "收徒门槛（LPC recruit/apprentice；shen/exp/心法）"
  def recruit_gate?(teacher, student, _gate \\ nil) do
    shen = Map.get(student_stats(student), :shen, 0)
    exp = Map.get(student_stats(student), :combat_exp, 0)

    cond do
      shen < min_shen_gate(teacher) ->
        {:error, "你的杀气不足，师父未同意收你为徒。\n"}

      exp < min_exp_gate(teacher) ->
        {:error, "你经验尚浅，武功未成，师父未同意收你为徒。\n"}

      true ->
        :ok
    end
  end

  @doc "叛门惩罚判定（对照 master.ex:23 attempt_detach）"
  def detach_penalty?(teacher_family, student_family) do
    if Family.same_family?(teacher_family, student_family) do
      {:penalty, "你欺师灭祖，武功尽失！\n"}
    else
      {:noop}
    end
  end

  # ---- 内部（settings 收敛，不改宿主） ----

  defp family_of(character) when is_map(character) do
    Map.get(character, :family) || Map.get(character, :meta) |> family_of_meta()
  end

  defp family_of(_), do: nil

  defp family_of_meta(%{family: family}), do: family
  defp family_of_meta(_), do: nil

  defp teacher_stats(character) when is_map(character), do: Map.get(character, :meta) || %{}
  defp teacher_stats(_), do: %{}

  defp student_stats(character) when is_map(character), do: Map.get(character, :meta) || %{}
  defp student_stats(_), do: %{}

  defp min_shen_gate(character), do: Map.get(character_teach(character), "min_shen", 0) || 0
  defp min_exp_gate(character), do: Map.get(character_teach(character), "min_exp", 0) || 0

  defp character_teach(character) do
    case family_of(character) do
      nil -> %{}
      teach -> Map.get(teach, :config) || Map.get(teach, "config") || %{}
    end
  end
end
