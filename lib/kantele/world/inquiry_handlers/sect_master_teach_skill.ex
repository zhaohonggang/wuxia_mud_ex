defmodule Kantele.World.InquiryHandlers.SectMasterTeachSkill do
  @moduledoc """
  门派师父「问一句、直接授一门技能」（`kind = "sect_master_teach_skill"`）。

  覆盖 LPC 中不经 `MASTER_D->teach_pfm`、而是问询闭包里直接 `me->set_skill(...)`
  的场景（华山派）：

  - `kungfu/class/huashan/cheng-buyou.c learn_kuangfeng()`「狂风快剑」：
    同门 → 已会 → 内力上限/内功上界 → 基本剑法 120 → 轻功 180 →
    按悟性设技能等级（`int <= 30 ? int : 30 + (int - 30) * 2`）；
  - `kungfu/class/huashan/linghu.c learn_chongling()`「冲灵剑法」：
    已会 → 同门 → 华山剑法 100 → 按 `huashan-jian / 10` 设技能等级。

  与 `SectMasterGrant` 的分工：那一个授予 `performs`（绝招 id），本模块授予
  `stats.skills`（完整技能）。门控走纯函数 `SectMaster.teach_skill_grant/3`，
  便于 Loader 数据联验与单元测试。

  ## UCL 配置

      value = {
        kind = "sect_master_teach_skill"
        skill = "kuangfeng-jian"
        family = "华山派"
        gate_order = "family_first"        # 或 "known_first"（令狐冲）
        level_source = "int"               # 或技能 id，如 "huashan-jian"
        level_pivot = 30
        level_factor = 2
        max_neili_cap = 2000               # query("max_neili") > N 即拒
        max_skill_levels = { force = 205 } # query_skill(...) > N 即拒
        min_skill_levels = { sword = 120 dodge = 180 }
        learned = "你学会了「狂风快剑」！\n"
      }

  缺省拒绝文案见 `SectMaster.teach_skill_grant/3` 文档；每条均可用
  `*_deny` 键按 LPC 原文覆盖。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.SectMaster

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "skill")) ->
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

    case SectMaster.teach_skill_grant(stats_with_family(character), npc_stats, config) do
      {:error, msg} ->
        reply(conn, msg)

      {:ok, skill, level} ->
        stats = Stats.set_skill(character.meta.stats, skill, level)
        character = %{character | meta: %{character.meta | stats: stats}}
        Records.save(character)

        text = Map.get(config, "learned") || "你学会了「#{skill}」！\n"

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # 与 SectMasterGrant / NpcScriptEvent 同源：family 与 max_neili 不是 Stats 字段，
  # 由调用方补进 map 再交给纯函数判定。
  defp stats_with_family(character) do
    base =
      case character.meta.stats do
        %Stats{} = stats -> Map.from_struct(stats)
        stats when is_map(stats) -> stats
        _ -> %{}
      end

    base
    |> put_family(character)
    |> put_max_neili(character)
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

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
