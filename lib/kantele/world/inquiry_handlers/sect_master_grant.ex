defmodule Kantele.World.InquiryHandlers.SectMasterGrant do
  @moduledoc """
  门派师父授绝招（`kind = "sect_master_grant"`），镜像 LPC
  `kungfu/class/gaibang/li.c` 的 `ask_skill1` / `ask_skill2`（黎生「五丁开山」、
  「绝命一踢」）。

  门控走 `SectMaster.inquiry_grant/3`（纯函数宿主），成功后 `Stats.learn_perform/2`
  习得绝招、扣除贡献、`Records.save/1` 落盘，并把问询键（中文绝招名）作为
  `perform_name` 渲染回给玩家。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "sect_master_grant"
        perform_id = "tongchui-zhang/kai"   # 授予的绝招 id
        skill = "tongchui-zhang"             # 必修技能（< 1 即拒）
        min_levels = { tongchui-zhang = 80, force = 90 }  # 额外技能门槛
        min_gongxian = 100                   # 贡献下限
        min_shen = 1000                      # 杀气下限
        cost_gongxian = 100                  # 授予后扣除贡献
        family = "丐帮"                      # 限门派；缺省不拦
        family_deny = "..."                  # 非本门文案（自动加敬称由 inquiry_grant 回填）
        skill_deny = "..."                   # 必修技能未学文案
        gongxian_deny = "..."                # 贡献不足文案
        shen_deny = "..."                    # 杀气不足文案
        level_deny = { tongchui-zhang = "..." }  # 各技能单独文案
        maxed = "这招我不是已经教会你了吗？"  # 已习得文案（inquiry_grant 返回错误时使用）
        learned = "你学会了「五丁开山」。"     # 学会文案（缺省用 perform_name）
        msg_one = "$N微微点了点头……"   # LPC msg1 演示文案，向房间广播（UCL 标识符不能含数字）
        gate_order = "lpc_masterd"       # 绝情谷：按 masterd.c 原顺序判门控
        level_order = [ "force", "tanqin-jifa", "kunlun-jian" ]  # 昆仑：逐条固定顺序
        requires_perform = "qiankun-jian/qian"  # 昆仑逆转乾坤的前置绝招
        improve_skills = [ "sword", "qiankun-jian", "martial-cognize" ]  # 昆仑：各 +1 级
      }

  门控顺序（严格按 `SectMaster.inquiry_grant/3`）：

  perform_id 缺失 → 已学会（maxed） → 非同门 → 必修技能 < 1 → 杀气上限 →
  贡献下限 → 杀气下限 → 技能等级 → 内力上限 → 通过。

  `gate_order = "lpc_masterd"`（绝情谷）改为 masterd.c 原顺序：
  同门 → 已学会 → 神 → 贡献 → 技能存在/等级 → 内力。

  `gate_order = "lpc_kunlun"`（昆仑内联 ask_skill*）改为：
  已学会 → 同门 → 必修技能存在 → 贡献 → 前置绝招 → `level_order` 有序门槛。
  `dex` / `max-neili` 以伪技能键出现在 `min_levels`，从而精确保留 LPC 的相对顺序。

  与 `npc_script_event.ex` 的 `perform_result/2` 同源：`stats_with_family/1` 把
  `meta.family` 门派名和 `meta.vitals.max_neili` 并入 stats map 后传给
  `inquiry_grant`，供同门校验与内力门槛使用。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "perform_id")) ->
        conn

      Map.get(data, :asker_id) != character.id ->
        conn

      true ->
        run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    npc_stats = %{family: Map.get(data, :npc_family)}

    case SectMaster.inquiry_grant(stats_with_family(character), npc_stats, config) do
      {:error, msg} ->
        reply(conn, msg)

      {:ok, perform_id, cost} ->
        conn = broadcast_msg1(conn, config, data)

        stats =
          character.meta.stats
          |> Stats.learn_perform(perform_id)
          |> improve_all(Map.get(config, "improve_skills") || [])
          |> deduct_gongxian(cost)

        character = %{character | meta: %{character.meta | stats: stats}}
        Records.save(character)

        perform_name = Map.get(data, :perform_name) || perform_id

        text =
          Map.get(config, "learned") ||
            "你学会了「#{perform_name}」。\n"

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- 与 `npc_script_event.ex perform_result/2` 同源的 stats 归一 ----

  defp stats_with_family(character) do
    base =
      case character.meta.stats do
        %Stats{} = stats -> Map.from_struct(stats)
        stats when is_map(stats) -> stats
        _ -> %{}
      end

    base
    |> put_family(character)
    |> put_beggarlvl(character)
    |> put_max_neili(character)
    |> put_marks(character)
  end

  # #986 洪七公「天下无狗」LPC `query("family/beggarlvl") < 9`：从门派 map 带入
  # 袋数（无持久列时缺省 0，与 LPC 查询缺省一致）。不配置袋数的门派 stats 不变。
  defp put_beggarlvl(stats, character) do
    family = character.meta.family || %{}

    case Map.get(family, :beggarlvl) || Map.get(family, "beggarlvl") do
      lvl when is_integer(lvl) -> Map.put(stats, :beggarlvl, lvl)
      _ -> stats
    end
  end

  # #903 桃花岛九阴四招：LPC `can_learn/jiuyin-shengong/<perform>` 是 accept_object
  # 写入的 temp/mark。门控在 SectMaster 读 stats.marks，故此处必须显式带入。
  # marks 为空时不改变既有 map（老配置零影响）。
  defp put_marks(stats, character) do
    case Map.get(character.meta, :marks) do
      marks when is_map(marks) and map_size(marks) > 0 -> Map.put(stats, :marks, marks)
      _ -> stats
    end
  end

  defp put_family(stats, character) do
    case character.meta.family do
      family when is_map(family) and map_size(family) > 0 ->
        Map.put(stats, :family, Family.name(family))

      _ ->
        stats
    end
  end

  defp put_max_neili(stats, character) do
    case Map.get(character.meta.vitals || %{}, :max_neili) do
      neili when is_integer(neili) -> Map.put(stats, :max_neili, neili)
      _ -> stats
    end
  end

  # LPC masterd.c:214-261 `message_sort(HIY "\n" + msg1 + "\n\n" NOR, ob, who)`：
  # 私定演示文案时向房间广播；未配置或不在房间时静默跳过（老配置零影响）。
  defp broadcast_msg1(conn, config, data) do
    case {Map.get(config, "msg_one") || Map.get(config, "msg1"), Map.get(data, :npc_room_id)} do
      {msg, room_id} when is_binary(msg) and byte_size(msg) > 0 and is_binary(room_id) ->
        Helpers.broadcast(conn, room_id, render_msg1(msg, data))

      _ ->
        conn
    end
  end

  @doc """
  LPC `message_vision(msg1, me, this_object())` 占位符替换：`$n` = 提问者、`$N` = NPC。
  旧路径把 `$n` 原样广播（GAP #822），此处在广播前替换，保留逐字文案。

  同时支持转换器归一化占位 `{npc}`（= NPC）与 `{name}`（= 提问者）——`data/world/*.ucl`
  的房间级文件不允许出现裸 `$n`/`$N`（见 `scripts/validate_ucl.py` 的 Chars 校验），
  故 2026-11-22 起 manually-authored 的 msg_one 一律写 `{npc}`/`{name}`，与
  `clone_lib.ucl` 的逐字归档（object_only，豁免）并存。
  """
  def render_msg1(msg, data) when is_binary(msg) and is_map(data) do
    msg
    |> String.replace("$n", to_string(Map.get(data, :asker_name) || ""))
    |> String.replace("$N", to_string(Map.get(data, :npc_name) || ""))
    |> String.replace("{npc}", to_string(Map.get(data, :npc_name) || ""))
    |> String.replace("{name}", to_string(Map.get(data, :asker_name) || ""))
  end

  # ---- 消息渲染 ----

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  # ---- 门控细节（与 inquiry_grant 保持同源，供测试/扩展使用）----

  # 昆仑 LPC 每招成功后 `improve_skill(...,1500000)`：在本引擎中每次调用 = +1 级。
  # 缺省空数组，既有配置零影响。
  defp improve_all(stats, skills) when is_list(skills) do
    Enum.reduce(skills, stats, fn skill, acc ->
      case skill do
        name when is_binary(name) and byte_size(name) > 0 ->
          {acc, _improved?} = Stats.improve_skill(acc, name)
          acc

        _ ->
          acc
      end
    end)
  end

  defp improve_all(stats, _skills), do: stats

  defp deduct_gongxian(%Stats{} = stats, cost) when is_integer(cost) and cost > 0 do
    %{stats | gongxian: max((stats.gongxian || 0) - cost, 0)}
  end

  # #940 欧阳锋 ask_skill3 原文是 `me->add("gongxian",1000)`（增加而非扣除）。
  # 不改写 LPC 笔误；UCL 以负 cost_gongxian 表达，仅在显式负值时走此分支。
  defp deduct_gongxian(%Stats{} = stats, cost) when is_integer(cost) and cost < 0 do
    %{stats | gongxian: (stats.gongxian || 0) - cost}
  end

  defp deduct_gongxian(stats, _cost), do: stats
end
