defmodule Kantele.Character.StayCommand do
  @moduledoc """
  停留命令：`stay`（LPC `cmds/std/stay.c`，源文件名是 `ting.c`）。

  LPC 不收参数：用 `query_temp("comedby")` 记下的野兽 id 回房间 `present()`
  找回对象，再走 owner / 自己 / living / 打架四道门，成功后删除 `comedby`
  并 `set_leader(0)`。

  `stay.c:21-22` 把 LPC 对象型的 `query_temp("owner")` 与字符串型的
  `me->query("id")` 比较，会对刚驯服的野兽恒判成「被人家驯服了」并反咬
  主人（LPC 遗留 bug）。本端口按 `BeastTaming` 的 id 归一语义处理。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.BeastTaming, as: Taming

  def run(conn, _params) do
    me = conn.character
    comedby = Taming.comedby(me)

    cond do
      is_nil(comedby) ->
        Taming.reject(conn, "已经没有野兽跟着你了！\n")

      Taming.player_fighting?(me) ->
        Taming.reject(conn, "一边打架一边驯兽？你真是活腻了！\n")

      true ->
        case Taming.find(conn, to_string(comedby)) do
          nil -> Taming.reject(conn, "这里没有这只野兽吧？\n")
          npc -> adjudicate(conn, me, npc)
        end
    end
  end

  defp adjudicate(conn, me, npc) do
    name = to_string(npc.name)

    cond do
      Taming.no_owner?(npc) ->
        Taming.reject(conn, "#{name}是只无主野兽，你得先驯服(train)它啊！\n")

      Taming.foreign_owner?(npc, me) ->
        Taming.retaliate(conn, npc, me)
        Taming.reject(conn, "#{name}是被人家驯服了，你不是找死啊！\n")

      Taming.self_target?(me, npc) ->
        Taming.reject(conn, "你没问题吧，自己跟自己？\n")

      not Taming.living?(npc) ->
        Taming.reject(conn, "这只野兽晕倒了，你怎能让它跟你呢？\n")

      Taming.fighting?(npc) ->
        Taming.reject(conn, "它正在大打出手，没空理你呢？\n")

      true ->
        text =
          "只见#{me.name}冲着#{npc.name}手中摆了个手式，它冲着你点了点头。\n\n"

        conn = Taming.clear_comedby(conn)
        Taming.unfollow(npc)
        Taming.emit(conn, text)
    end
  end
end
