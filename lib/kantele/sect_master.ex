defmodule Kantele.SectMaster do
  @moduledoc """
  门派师父判定（F3 切片 2）：纯函数宿主——只做门槛判定链条，不改写任何既有入参形状。

  本模块**不新增任何宿主调用点**（不碰 teach/2 主链、不碰 family/recruit、
  不碰 room 对话），各调用方维持现状；只把散落的门槛判定收敛成纯函数以便
  后续 F3 接线时逐点替换。

  宿主形状（已读盘核实，不再臆造）：
    - 师父收徒门槛存 `character.meta.apprentice`（loader `parse_apprentice/1`
      loader.ex:481-510 解析 UCL `apprentice` 段，形状 `%{family:, min_shen:,
      min_exp:, min_skills:, no_recruit:}`；family 为字符串门派名）。
    - 门派信息为 family **map**（`%{name:, master_id:, master_name:, ...}`，
      见 family.ex:5-7、family_event.ex:17 写入形状）；`Family.name/1` 只吃 map，
      字符串会 BadMapError（room.ex:402/2458 同契约）。
    - 师徒/门派判定走 `Family`（`same_family?/2`、`is_apprentice_of?/2`、
      `has_family?/1`）与 `Kantele.Npc.Master`（`prevent_learn?/3`、`attempt_detach/3`）。

  ## teachable?/3
  是否可学某技能：同门派非嫡传被 `Master.prevent_learn?` 拦（对照
  skills_event.ex:43-45）+ 师父已不高于学生等级（对照 skills_event.ex:63-69）。

  ## recruit_gate?/3
  收徒门槛：`meta.apprentice` 的 min_shen/min_exp/min_skills。

  ## detach_penalty?/2
  叛门惩罚判定（对照 master.ex:23 attempt_detach 的同门近似）。
  """

  alias Kantele.Character.Family
  alias Kantele.Npc.Master

  @doc "师父是否能教该技能（host 链：skills_event.ex:38-69）"
  def teachable?(teacher, student, skill) do
    my_family = family_of(teacher)
    student_family = family_of(student)

    cond do
      # 同门派但非嫡传：Master.prevent_learn? 判定（skills_event.ex:43-45）
      Master.prevent_learn?(my_family, student_family, student_family) ->
        {:error, "你已入别派，老夫不便传授。\n"}

      # 师父已不高于学生（skills_event.ex:63-69）
      not teaches?(teacher, skill) or skill_level(teacher, skill) <= skill_level(student, skill) ->
        {:error, "这一门功夫你已不弱于老夫，没什么可教的了。\n"}

      true ->
        :ok
    end
  end

  @doc "收徒门槛（UCL apprentice 段：min_shen/min_exp/min_skills，loader.ex:481-510）"
  def recruit_gate?(teacher, student, gate \\ nil) do
    config = gate || apprentice_config(teacher)

    min_shen = Map.get(config, :min_shen, 0) || 0
    min_exp = Map.get(config, :min_exp, 0) || 0
    min_skills = Map.get(config, :min_skills, %{}) || %{}

    shen = Map.get(student_stats(student), :shen, 0) || 0
    exp = Map.get(student_stats(student), :combat_exp, 0) || 0

    cond do
      shen < min_shen ->
        {:error, "你的杀气不足，师父未同意收你为徒。\n"}

      exp < min_exp ->
        {:error, "你经验尚浅，武功未成，师父未同意收你为徒。\n"}

      not meets_min_skills?(student, min_skills) ->
        {:error, "你根基尚浅，这几样本事还未练成，先回去打好基础再来吧。\n"}

      true ->
        :ok
    end
  end

  @doc "叛门惩罚判定（同门派叛师=罚，对照 master.ex:23 attempt_detach 同门近似）"
  def detach_penalty?(teacher_family, student_family) do
    if Family.same_family?(teacher_family, student_family) do
      {:penalty, "你欺师灭祖，武功尽失！\n"}
    else
      {:noop}
    end
  end

  # ---- 内部取数（只读真宿主形状，不臆造） ----

  # 角色 -> family map：接受 `%{family: %{name:..}}`（meta 壳）或直接 family map
  defp family_of(%{meta: %{family: family}}) when is_map(family), do: family
  defp family_of(%{family: family}) when is_map(family), do: family
  defp family_of(_), do: %{}

  # 角色 -> meta 壳
  defp meta_of(character) when is_map(character), do: Map.get(character, :meta) || %{}
  defp meta_of(_), do: %{}

  defp student_stats(character) do
    stats = Map.get(meta_of(character), :stats) || %{}
    %{shen: Map.get(stats, :shen, 0) || 0, combat_exp: Map.get(stats, :combat_exp, 0) || 0}
  end

  defp apprentice_config(character), do: Map.get(meta_of(character), :apprentice) || %{}

  defp teaches?(character, skill), do: skill_level(character, skill) > 0

  defp skill_level(character, skill) do
    stats = Map.get(meta_of(character), :stats)
    Map.get(Map.get(stats || %{}, :skills) || %{}, skill, 0)
  end

  defp meets_min_skills?(character, min_skills) do
    Enum.all?(min_skills, fn {skill, level} -> skill_level(character, skill) >= level end)
  end
end