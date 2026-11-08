defmodule Kantele.Character.ComeCommand do
  @moduledoc """
  驯兽跟随命令：`come <野兽>`（LPC `cmds/std/come.c`）。

  门控顺序照抄 LPC：自己在战斗中 → 驭兽术 >= 10 → 已有 comedby →
  参数 → present → userp → race → 野兽在打架 / 忙 → 无主 →
  别人的（反扑）→ 自己 → living → 精力。
  成功后扣精、`set_temp("comedby", id)`、`set_leader(me)`。

  共享判定见 `Kantele.Character.BeastTaming`。
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
      Taming.player_fighting?(me) ->
        Taming.reject(conn, "一边打架一边驯兽？你真是活腻了！\n")

      Taming.training_level(me) < Taming.min_skill() ->
        Taming.reject(conn, "你的驭兽术还不纯熟，无法让野兽跟随你！\n")

      Taming.comedby(me) ->
        Taming.reject(conn, "已经有野兽跟着你了！\n")

      arg == "" ->
        Taming.reject(conn, "你要让什么野兽跟随你？\n")

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

      Taming.fighting?(npc) ->
        Taming.reject(conn, "#{name}正在打架，没空理你！\n")

      Taming.busy?(npc) ->
        Taming.reject(conn, "#{name}正在忙乎，没空理你！\n")

      Taming.no_owner?(npc) ->
        Taming.reject(conn, "#{name}是只无主野兽，你得先驯服(train)它啊！\n")

      Taming.foreign_owner?(npc, me) ->
        Taming.retaliate(conn, npc, me)
        Taming.reject(conn, "#{name}早被人家驯服了，你不是找死啊！\n")

      Taming.self_target?(me, npc) ->
        Taming.reject(conn, "你没问题吧，自己跟自己？\n")

      not Taming.living?(npc) ->
        Taming.reject(conn, "这只野兽晕倒了，你怎能让它跟你呢？\n")

      Taming.tired?(me) ->
        Taming.reject(conn, "现在你太累了，无法让野兽跟随。\n")

      true ->
        execute(conn, me, npc)
    end
  end

  defp execute(conn, me, npc) do
    cost = Taming.jing_cost(me)
    text = "只见#{me.name}冲着#{npc.name}手中摆了个手式，它一窜就跟上了。\n\n"

    conn =
      conn
      |> Taming.pay_jing(cost)
      |> Taming.set_comedby(npc)

    Taming.follow(npc, me)
    Taming.emit(conn, text)
  end
end
