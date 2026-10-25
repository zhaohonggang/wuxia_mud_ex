defmodule Kantele.World.RoomActions.Shaolin.Zhonglou7.Knock do
  @moduledoc """
  少林钟楼七层（`shaolin:zhonglou7`）敲大钟（P5-6 门/容器第三批）。

  LPC 源：`d/shaolin/zhonglou7.c` 的 `do_knock`（`add_action("do_knock", "knock")`）：

      int do_knock(string arg)
      {
              object me;
              mapping mine;

              me = this_player();
              if ( !arg || ( arg != "bell" ) ) return notify_fail("你要敲什麽？\\n");

              me->add("qi", -20);

              mine = me->query_entire_dbase();
              message_vision("$N敲了一下大钟，『咣……』声音传遍整个寺庙。\\n", me);
              write("钟声如迅雷般在你耳边炸响，你头脑中一片糊涂，\\n"
                  "全身摇摇欲坠，勉力支撑着不倒在地上。心中一个\\n"
                  "声音告诉你，得赶快离开这里，不然就没命了。\\n");
              if (random(2)==0) mine["combat_exp"] += 1;
              else mine["combat_exp"] -= 2;
              return 1;
      }

  ## 移植要点

  - `me->add("qi", -20)` → `Damage.receive_damage(character, :qi, 20)`：同为扣当前
    气血 20 点。引擎没有纯粹的 `add("qi", -N)` 原语，`receive_damage` 是最接近的
    等价物（附带心跳伤害登记；`who` 为 nil 且伤害 < 150，不触发 craze）。
  - `mine = me->query_entire_dbase()` 后直接改 mapping：LPC 的 mapping 是引用，
    改 `mine` 即改 dbase —— 这里等价于 `combat_exp ±`，走 `Stats.combat_exp`。
  - `random(2)==0` → `:rand.uniform(2) == 1`（Elixir 1..2，LPC 0..1）。
  - 文案里的「麽」是**繁体**，与 LPC 逐字一致，不改成简体。
  """

  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Feature.Damage
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "bell" -> knock_bell(conn, room_id)
      _other -> Helpers.render_to_player(conn, "你要敲什麽？\n")
    end
  end

  defp knock_bell(conn, room_id) do
    character = conn.private.update_character || conn.character

    {:ok, damaged} = Damage.receive_damage(character, :qi, 20)
    stats = damaged.meta.stats || %Stats{}
    exp = stats.combat_exp || 0

    # LPC random(2)==0 → +1，否则 -2
    new_exp =
      if :rand.uniform(2) == 1 do
        exp + 1
      else
        exp - 2
      end

    damaged = %{damaged | meta: %{damaged.meta | stats: %{stats | combat_exp: new_exp}}}
    Records.save(damaged)

    conn
    |> put_character(damaged)
    |> Helpers.broadcast_vision(room_id, "{npc}敲了一下大钟，『咣……』声音传遍整个寺庙。\n")
    |> Helpers.render_to_player(
      "钟声如迅雷般在你耳边炸响，你头脑中一片糊涂，\n" <>
        "全身摇摇欲坠，勉力支撑着不倒在地上。心中一个\n" <>
        "声音告诉你，得赶快离开这里，不然就没命了。\n"
    )
  end
end
