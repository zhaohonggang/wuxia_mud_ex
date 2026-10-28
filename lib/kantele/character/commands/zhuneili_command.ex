defmodule Kantele.Character.ZhuneiliCommand do
  @moduledoc """
  注内力：`注内力`（对应 LPC `adm/npc/ganjiang.c` 的 `do_help`，L307-363）

  玩家在干将锻造会话可助炉时，以内力哺育炉火，提升道具锻造点数，单次生效。

  ## 门控

      if (status != "waiting")      → "没你什么业务。"
      if (!can_help)                → "现在不是你帮忙的时候！"

  LPC 判的是玩家 temp `item/status == "waiting"`（`start_work` 置位）。本仓把
  干将的 6 段 vision 合并成即时广播，`waiting` 与 `inputing`（起名阶段）同时
  成立，所以两个状态都放行 —— 真正的窗口判据是 `can_help`（LPC 在
  `work_step_1` 置位、`work_step_2` 删除）。

  ## 体力链（**注意失败是有代价的**）

  LPC 不是「不够就干净拒绝」，而是逐项扣、逐项判，中途不支就地倒下并把该项
  归零：

  | 判据 | 失败后果 |
  |---|---|
  | `jing < 180` | `jing = 0`，中止 |
  | 扣 `jing 180` 后 `qi < 300` | `qi = 0`，中止（**jing 已扣**） |
  | 扣 `qi 300` 后 `neili < 800` 或 `max_neili < 1000` | `neili = 0`，中止（**jing、qi 已扣**） |

  这是原版刻意的手感：没准备好就别硬上，硬上会伤身。

  ## 成功

      point += point * query_skill("force") / 800
      can_help → false
      max_neili -= 200
      neili     -= 200

  `query_skill("force")` 走 `Stats.effective/3`（基本技能折半 + 特技 + apply）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.Forging
  alias Kantele.World.RoomActions.Helpers

  @jing_min 180
  @qi_min 300
  @neili_min 800
  @max_neili_min 1_000
  @jing_cost 180
  @qi_cost 300
  @neili_cost 200
  @max_neili_cost 200
  @force_divisor 800

  # LPC 三段「眼前一黑」共用同一句 vision，只有 tell_object 的病因不同
  @collapse_vision "$N长啸一声，双手搭上炉边，正待以内力哺育炉火，突然眼前一黑……\n"
  @success_vision "$N长啸一声，双手搭上炉边。刹那间炉火沸腾，一道白光直冲霄汉。\n\n"

  def run(conn, %{}) do
    character = conn.character
    session = Forging.get(character.id)

    cond do
      is_nil(session) ->
        fail(conn, "没你什么业务。\n")

      session.status not in ["waiting", "inputing"] ->
        fail(conn, "没你什么业务。\n")

      not Map.get(session, :can_help, false) ->
        fail(conn, "现在不是你帮忙的时候！\n")

      true ->
        handle_zhuneili(conn, character, session)
    end
  end

  defp handle_zhuneili(conn, character, session) do
    vitals = character.meta.vitals

    cond do
      (vitals.jing || 0) < @jing_min ->
        collapse(conn, character, :jing, "你感到精力衰竭。\n")

      (vitals.qi || 0) < @qi_min ->
        # jing 已按 LPC 先扣
        character = spend(character, jing: @jing_cost)
        collapse(conn, character, :qi, "你感到心虚气短。\n")

      (vitals.neili || 0) < @neili_min or (vitals.max_neili || 0) < @max_neili_min ->
        # jing、qi 已按 LPC 先扣
        character = spend(character, jing: @jing_cost, qi: @qi_cost)
        collapse(conn, character, :neili, "你感到内力枯竭。\n")

      true ->
        succeed(conn, character, session)
    end
  end

  # 中途不支：该项归零 + 房间 vision + 私人病因提示。已扣的 jing/qi 不退。
  defp collapse(conn, character, vital, reason) do
    character = zero(character, vital)
    Records.save(character)

    conn
    |> Helpers.broadcast_vision(character.room_id, @collapse_vision)
    |> put_character(character)
    |> render(CommandView, "text", %{text: reason})
    |> prompt(CommandView, "prompt", %{})
  end

  defp succeed(conn, character, session) do
    force = Stats.effective(character.meta.stats, "force", Combat.skill_applies(character))
    point = session.point || 0
    new_point = point + div(point * force, @force_divisor)

    character = spend(character, jing: @jing_cost, qi: @qi_cost)
    vitals = character.meta.vitals
    new_max_neili = max((vitals.max_neili || 0) - @max_neili_cost, 0)
    new_neili = max(min((vitals.neili || 0) - @neili_cost, new_max_neili), 0)

    character = %{character | meta: %{character.meta | vitals: %{vitals | max_neili: new_max_neili, neili: new_neili}}}

    Forging.put(character.id, %{session | can_help: false, point: new_point})
    Records.save(character)

    conn
    |> Helpers.broadcast_vision(character.room_id, @success_vision)
    |> put_character(character)
    |> prompt(CommandView, "prompt", %{})
  end

  # 扣 vitals（钳到 0，LPC receive_damage 不会留负数）
  defp spend(character, costs) do
    vitals = character.meta.vitals

    new_vitals =
      Enum.reduce(costs, vitals, fn {vital, cost}, acc ->
        Map.put(acc, vital, max((Map.get(acc, vital) || 0) - cost, 0))
      end)

    %{character | meta: %{character.meta | vitals: new_vitals}}
  end

  defp zero(character, vital) do
    vitals = character.meta.vitals
    %{character | meta: %{character.meta | vitals: Map.put(vitals, vital, 0)}}
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
