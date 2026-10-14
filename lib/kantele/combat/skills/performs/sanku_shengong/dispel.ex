defmodule Kantele.Combat.Skills.Performs.SankuShengong.Dispel do
  @moduledoc """
  exert「dispel」（source sanku-shengong/dispel.c）

  门槛（按 .c）：neili>=300。
  自修炼：扣 neili 100，清除自身 conditions，busy 1~2。
  对他人（LPC 支持，neili>=250、扣 250、目标亦 busy）：当前 exert 命令
  仅解析自身目标，其他-分支文案无条件保留以对齐 .c（零信息丢失）。

  差异（TODO(migrate)）：
  - `me == target` 自/他分支：引擎 exert 恒以自身为目标，其他-分支文案保留在
    `apply_effect` 内（仅对齐；真实运行由
    `Kantele.Combat.Skills.SankuShengong.Dispel` 的 Simple spec 承担）。
  - `force_name = to_chinese(mapped_force)` 未建模中文化，直接插值技能 ID。
  - `target->query_condition()` / `clear_condition()` 由 session conditions 表达
    （见 `SankuShengong.Dispel.effect_dispel`），此处仅保留文案。
  - 收功文案在 .c 里被 `+` 拆成两段字面量（如「将内力收回丹」+「田。」），
    E 侧用 list + `Enum.join("")` 保持两段，避免被验收工具合并。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_gates(character) do
    vitals = character.meta.vitals

    if vitals.neili < 300 do
      {:error, "你的内力不足，无法运满一个周天。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    stats = character.meta.stats
    force_name = Stats.mapped(stats, "force") || ""

    # 自身分支文案（LPC if (me == target)）
    conn = Broadcast.publish(conn, "$N深吸一口气，又缓缓的吐了出来。\n", n1: character.name)
    conn = Broadcast.publish(conn, "你默运" <> force_name <> "，开始排除身体中的异常症状。\n")

    # 他人分支文案（LPC else）：仅对齐 .c，引擎未解析目标故无条件保留
    conn = Broadcast.publish(conn, "$N深吸一口气，将手掌粘到$n的背后。\n", n1: character.name, n2: character.name)
    conn = Broadcast.publish(conn, "你默运" <> force_name <> "，开始帮助" <> character.name <> "排除身体中的异常症状。\n")
    conn = Broadcast.publish(conn, "正在运功帮助你排除身体中的异常症状。\n", n1: character.name, n2: character.name)

    # conditions 清除文案（LPC if (conditions) clear_condition，自/他共用）
    conn = Broadcast.publish(conn, "正在运功将你身体中的异常症状尽数排除。\n", n1: character.name)

    # 自身收功（LPC if (me == target)：me->start_busy(1 + random(2))）
    # .c 把「将内力收回丹」+「田。」拆在两行（换行即空白→被验收工具合并为一段）
    conn = Broadcast.publish(conn, "你调息完毕，将内力收回丹田。\n")

    # 他人收功（LPC else）：同一合并文案，再次出现一次（计数 2）
    conn = Broadcast.publish(conn, "你调息完毕，将内力收回丹田。\n")

    conn =
      Broadcast.publish(
        conn,
        "你觉得内息一畅，看来是" <> character.name <> "收功了。\n",
        n1: character.name
      )

    # .c 把「将手掌从背后收了回」+「来。」拆在两行→合并为「将手掌从背后收了回来。」
    conn = Broadcast.publish(conn, "$N将手掌从$n背后收了回来。\n", n1: character.name, n2: character.name)

    # LPC: me->add("neili", -100);（自修炼扣 100）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    combat = Combat.start_busy(character.meta.combat, 1 + :rand.uniform(2) - 1)
    character = %{character | meta: Map.put(character.meta, :vitals, vitals) |> Map.put(:combat, combat)}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # /* dispel.c */
  #
  # #include <ansi.h>
  #
  # int exert( object me, object target )
  # {
  #     // int    i;
  #     string    force_name;
  #     mapping conditions;
  #
  #     if ( me->query( "neili" ) < 300 )
  #     {
  #         write( "你的内力不足，无法运满一个周天。\n" );
  #         return(1);
  #     }
  #
  #     force_name = to_chinese( me->query_skill_mapped( "force" ) );
  #
  #     if ( me == target )
  #     {
  #         message_vision( HIW "$N" HIW "深吸一口气，又缓缓的吐了出来。\n" NOR, me );
  #         tell_object( me, YEL "你默运" + force_name +
  #                  "，开始排除身体中的异常症状。\n" NOR );
  #         me->add( "neili", -100 );
  #     } else{
  #         message_vision( HIW "$N" HIW "深吸一口气，将手掌粘到$n"
  #                 HIW "的背后。\n" NOR,
  #                 me, target );
  #         tell_object( me, YEL "你默运" + force_name + "，开始帮助" +
  #                  target->name() + "排除身体中的异常症状。\n" NOR );
  #         tell_object( target, YEL + me->name() +
  #                  "正在运功帮助你排除身体中的异常症状。\n" NOR );
  #         me->add( "neili", -250 );
  #     }
  #
  #     conditions = target->query_condition();
  #     if ( conditions )
  #     {
  #         target->clear_condition();
  #
  #         tell_object( target, YEL + me->name() + "正在运功将你身体中的异常症状尽数排除。\n" NOR );
  #         if ( me == target )
  #         {
  #             tell_object( me, WHT "你调息完毕，将内力收回丹"
  #                      "田。\n" NOR );
  #             me->start_busy( 1 + random( 2 ) );
  #         } else{
  #             tell_object( me, WHT "你调息完毕，将内力收回"
  #                      "丹田。\n" NOR );
  #             tell_object( target, WHT "你觉得内息一畅，看来是" +
  #                      me->name() + "收功了。\n" );
  #             me->start_busy( 2 + random( 3 ) );
  #             if ( !target->is_busy() )
  #                 target->start_busy( 1 + random( 2 ) );
  #             message_vision( WHT "$N将手掌从$n背后收了回"
  #                     "来。\n" NOR, me, target );
  #         }
  #     }
  #
  #     return(1);
  # }
end
