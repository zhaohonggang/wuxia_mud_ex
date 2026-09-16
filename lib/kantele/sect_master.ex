defmodule Kantele.SectMaster do
  @moduledoc """
  门派师父判定（F3）：纯函数宿主——只做门槛判定链条，不改写任何既有入参形状。

  - 切片 2：纯函数收口，不动宿主调用点。
  - 切片 3：`skills_event.ex teach/2` 已接入 `teachable?/3`（替换原手工
    `Master.prevent_learn?` 门派块，行为等价）；recruit/apprentice/detach/inquiry
    仍按计划后续切片逐个接入。

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
  alias Kantele.Character.Stats
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

  @doc """
  问答授绝招判定（UCL `inquiries` 脚本 map；镜像 `class/wudang/yu.c` `ask_me`）。

  `config` 键为字符串（loader `parse_inquiry_value/1` 归一）：
    - `"perform_id"` 授予的绝招 id（如 `"huzhua-shou/juehu"`）
    - `"skill"` 必修技能（等级 < 1 即拒，对应 yu.c「连…都没学」）
    - `"min_levels"` 额外技能门槛 `%{技能 => 等级}`（yu.c 的 force 180 / huzhua-shou 120）
    - `"min_gongxian"` / `"min_shen"` 贡献（400）/ 杀气（100000）门槛
    - `"cost_gongxian"` 授予后扣除的贡献（400）

  同门校验：`player_stats`/`npc_stats` 若带 `:family` 则比较，缺失则不拦（yu.c
  「不是我们武当派的人」分支）。入参可为 `%Stats{}` 或等形 map（跨进程宿主由
  调用方补 `:family`）。

  返回 `{:ok, perform_id, cost}` | `{:error, msg}`；调用方据 `cost` 扣 `gongxian`
  并 `Stats.learn_perform/2`。
  """
  def inquiry_grant(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen", 0) || 0
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, "这门绝招暂不外传。\n"}

      perform_known?(player, perform_id) ->
        {:error, "这一招你不是已经会了吗？\n"}

      not same_family?(player, npc) ->
        {:error, "你我并非同门，何来讨教绝招之说？\n"}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, "你连#{skill}都没学，还谈什么绝招可言？\n"}

      stat(player, :gongxian) < min_gongxian ->
        {:error, "你为本派效力还不够，这招我先不忙传你。\n"}

      stat(player, :shen) < min_shen ->
        {:error, "这一招太过阴恨，若被你用去我恐怕不放心！\n"}

      not meets_levels?(player, min_levels) ->
        {:error, "你的修为还不够，练高了再来吧。\n"}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # ---- 内部取数（只读真宿主形状，不臆造） ----
  #
  # 角色 -> family map。真宿主两种落点：
  # - 玩家展开 `meta.family` 是 map（family_event.ex:17）；
  # - NPC（NonPlayerMeta）没有 `:family` 字段，门派身份只在 `meta.teach.family`
  #   （loader.parse_teach 的字符串门派名，skills_event.ex:38-39 同源读法）。
  #   这里按 host 顺序：先 meta.family map，缺失则用 teach.family 合成 %{name:}，
  #   保证 teach/2 侧面同门派非嫡传判定与 host 一致。
  defp family_of(%{meta: meta} = character) when is_map(meta) do
    case Map.get(meta, :family) do
      family when is_map(family) and map_size(family) > 0 ->
        family

      _ ->
        teach_family(character, meta)
    end
  end

  # 直接给 family map（不包 meta 壳，如 build_conn 侧传 student_family map）
  defp family_of(family) when is_map(family), do: family
  defp family_of(_), do: %{}

  # teach.family 合成（host 同源：skills_event.ex:39）
  defp teach_family(_character, meta) do
    case Map.get(Map.get(meta, :teach) || %{}, :family) do
      nil -> %{}
      name -> %{name: name}
    end
  end

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

  # ---- inquiry_grant 内部（%Stats{} / map 归一为 map，family 走 Map.get） ----

  defp normalize_stats(%Stats{} = stats),
    do: stats |> Map.from_struct() |> Map.put(:family, Map.get(stats, :family))

  defp normalize_stats(%{} = stats), do: stats
  defp normalize_stats(_), do: %{}

  defp perform_known?(player, perform_id),
    do: MapSet.member?(Map.get(player, :performs) || MapSet.new(), perform_id)

  defp skill_level_of(player, skill),
    do: Map.get(Map.get(player, :skills) || %{}, skill, 0)

  defp stat(player, key), do: Map.get(player, key) || 0

  # 两方都带 :family 才比较，缺失不拦（无从判定）
  defp same_family?(player, npc) do
    case {Map.get(player, :family), Map.get(npc, :family)} do
      {player_family, npc_family} when is_binary(player_family) and is_binary(npc_family) ->
        player_family == npc_family

      _ ->
        true
    end
  end

  defp meets_levels?(player, min_levels) when is_map(min_levels),
    do: Enum.all?(min_levels, fn {skill, level} -> skill_level_of(player, skill) >= level end)

  defp meets_levels?(_player, _min_levels), do: true
end