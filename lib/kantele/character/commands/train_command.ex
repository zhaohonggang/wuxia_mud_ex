defmodule Kantele.Character.TrainCommand do
  @moduledoc """
  驯兽命令：`train <野兽>`（LPC `cmds/std/train.c`）。

  逐条落地 LPC 的 12 道门：驭兽术 >= 10、参数、房间 present、userp、
  race == 野兽、已有主人（自己的 / 别人的）、自己、living、精力、
  随机失败、精力扣减 + 技能提升 + 主人登记。

  共享判定与状态见 `Kantele.Character.BeastTaming` /
  `Kantele.Character.BeastState`。与 LPC 的差异（owner 类型混用、
  race 未进 UCL、NPC temp 用 ETS）统一记在 `BeastTaming` 的 moduledoc。

  单测可用 `conn.private[:beast_characters]` 注入房间 NPC、
  `[:beast_roll]` 固定成败、`[:beast_retaliate]` 拦截反扑、
  `[:beast_broadcast]` 拦截房间广播。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.BeastTaming, as: Taming

  def run(conn, params) do
    arg =
      params
      |> Map.get("target", "")
      |> to_string()
      |> String.trim()

    me = conn.character

    cond do
      Taming.training_level(me) < Taming.min_skill() ->
        Taming.reject(conn, "你的驭兽术还不纯熟，无法训练野兽！\n")

      arg == "" ->
        Taming.reject(conn, "你要训练什么野兽？\n")

      true ->
        case Taming.find(conn, arg) do
          nil -> Taming.reject(conn, "这里没有这只野兽吧？\n")
          npc -> adjudicate(conn, me, npc)
        end
    end
  end

  defp adjudicate(conn, me, npc) do
    name = to_string(npc.name)

    cond do
      Taming.player?(npc) ->
        Taming.reject(conn, "人家也是玩家，你搞什么搞啊？\n")

      not Taming.beast?(npc) ->
        Taming.reject(conn, "这不是野兽，你晕头了吧？\n")

      Taming.owned_by?(npc, me) ->
        Taming.reject(conn, "#{name}就是你驯服过的，你还折腾个啥劲儿呢！\n")

      Taming.foreign_owner?(npc, me) ->
        Taming.reject(conn, "#{name}早被人家驯服了，你还折腾个啥劲儿呢！\n")

      Taming.self_target?(me, npc) ->
        Taming.reject(conn, "你没这么笨吧，把自己不当人？\n")

      not Taming.living?(npc) ->
        Taming.reject(conn, "这只野兽晕倒了，你怎能训得它动呢？\n")

      Taming.tired?(me) ->
        Taming.reject(conn, "现在你太累了，无法训练野兽。\n")

      true ->
        execute(conn, me, npc)
    end
  end

  defp execute(conn, me, npc) do
    cost = Taming.jing_cost(me)
    opening = "只见#{me.name}冲着#{npc.name}手脚乱摆，口中似对它轻轻细语。\n\n"

    if Taming.roll_failure?(conn, me, npc) do
      # LPC：opening 广播给全场，notify_fail 只给 me；ob->kill_ob(me) + start_busy(1)
      Taming.broadcast(conn, opening)
      Taming.retaliate(conn, npc, me)
      conn = Taming.busy_player(conn, 1)

      Taming.reject(
        conn,
        opening <> "你驭兽术不精，那东西野性不泯，冲着你就窜了过来！\n"
      )
    else
      success = "顿时#{npc.name}冲着#{me.name}摇了摇尾巴，很温驯的样子。\n\n"

      conn =
        conn
        |> Taming.pay_jing(cost)
        |> Taming.improve_training()
        |> Taming.clear_player_enemies()

      Taming.claim(npc, me)
      Taming.emit(conn, opening <> success)
    end
  end
end
