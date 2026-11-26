defmodule Kantele.World.KunlunLiangjiAccept do
  @moduledoc """
  昆仑何足道收还两极剑 accept_object（对应 LPC `kungfu/class/kunlun/hezudao.c` `accept_object`）。

  LPC 原文：

      if (base_name(ob) != LIANGJI) {
              command("say 你给我这种东西干什么？");
              return 0;                       # 拒收，物品不销毁
      }
      if (me->query("family/master_id") != query("id"))
              command("say 多谢这位" + RANK_D->query_respect(me) + "将我的宝剑交回。");
      else
              command("say 很好，很好！");
      destruct(ob);                           # 物品销毁，不进 NPC 背包
      return 1;

  本模块在 NPC 进程执行（give_event `handle_accept_give` 命中
  `kind:"kunlun_liangji"` 规则时调用）。两极剑归还的**销毁 + 分文案**在
  玩家侧 `GiveEvent.kunlun_liangji_returned/2` 完成（NPC 看不到玩家 family/
  respect，且物品实例归属玩家背包）。
  """

  alias Kalevala.Event

  import Kalevala.Character.Conn, only: [put_character: 2]

  def handle(conn, npc, item_instance, data, _from_name) do
    reply_to = Map.get(data, :reply_to)

    if is_pid(reply_to) do
      send(reply_to, %Event{
        from_pid: self(),
        topic: "kunlun/liangji_return",
        data: %{
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          to_id: npc.id,
          from_id: Map.get(data, :from_id)
        }
      })
    end

    put_character(conn, npc)
  end
end