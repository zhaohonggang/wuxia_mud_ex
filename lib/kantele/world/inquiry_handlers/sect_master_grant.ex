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
      }

  门控顺序（严格按 `SectMaster.inquiry_grant/3`）：

  perform_id 缺失 → 已学会（maxed） → 非同门 → 必修技能 < 1 → 杀气上限 →
  贡献下限 → 杀气下限 → 技能等级 → 内力上限 → 通过。

  `gate_order = "lpc_masterd"`（绝情谷）改为 masterd.c 原顺序：
  同门 → 已学会 → 神 → 贡献 → 技能存在/等级 → 内力。

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

  # LPC masterd.c:214-261 `message_sort(HIY "\n" + msg1 + "\n\n" NOR, ob, who)`：
  # 私定演示文案时向房间广播；未配置或不在房间时静默跳过（老配置零影响）。
  defp broadcast_msg1(conn, config, data) do
    case {Map.get(config, "msg_one") || Map.get(config, "msg1"),
          Map.get(data, :npc_room_id)} do
      {msg, room_id} when is_binary(msg) and byte_size(msg) > 0 and is_binary(room_id) ->
        Helpers.broadcast(conn, room_id, msg)

      _ ->
        conn
    end
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

  defp deduct_gongxian(%Stats{} = stats, cost) when is_integer(cost) and cost > 0 do
    %{stats | gongxian: max((stats.gongxian || 0) - cost, 0)}
  end

  defp deduct_gongxian(stats, _cost), do: stats
end
