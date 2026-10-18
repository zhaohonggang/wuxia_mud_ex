defmodule Kantele.World.NpcActions.Decide do
  @moduledoc """
  NPC 私有动词 `decide`（P5-1c）。

  对应 LPC 里各 NPC 的 `add_action("decide", "do_decide")`。玩家对 NPC 输入
  `decide`（无参数）时，由 `NpcActionDispatcher` 路由到此模块；本模块按
  `room_id` 分派到具体 NPC 的分支（与 `Yao` 同一命名/分派约定）。

  已移植：

  - `guiyun:taihu` —— 陆小凤（`d/guiyun/npc/xiaolu.c`）：决定是否加入归云庄，
    是则发放引荐书信 `obj/xin`。
  - `xiangyang:qianzhuang` —— 黄真（`d/xiangyang/npc/huangzhen.c`）：处理
    `want_join` / `want_tuoli` 两个临时标记，加入/退出「商业协会」。

  ## @todo 未移植（会话提示早先已定：以实际代码为准，遇红区/外部依赖先记录）

  - `beijing:dongchang` —— 海公公（`d/beijing/npc/haigonggong.c`）：`pending/zigong`
    标记命中后设 `gender=无性`/`class=eunach`、加 `combat_exp`、并调用
    `unconcious()`。**昏迷/`unconcious` 属红区（本次不触碰）**；待红区解锁后补。
  - `register:entry` —— 水笙（`d/register/npc/shuisheng.c`）：邮箱注册流程，
    Kantele 走 Web 账号，暂无对应机制（@todo）。

  两者均返回 `:not_handled`（放行全局命令），与未注册时的 P7 行为一致。
  """
  use Kantele.World.NpcAction

  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  @letter "guiyun:xin"
  @shang_ling "clone_lib:shang_ling"

  @impl true
  def run(conn, %{room_id: room_id, npc: npc}) do
    case room_id do
      "guiyun:taihu" -> xiaolu(conn, room_id, npc)
      "xiangyang:qianzhuang" -> huangzhen(conn, room_id, npc)
      _ -> :not_handled
    end
  end

  # 陆小凤：命中标记 → 注销标记 + 发引荐书信；否则反问「你要决定干嘛？」
  defp xiaolu(conn, room_id, npc) do
    if Helpers.temp(conn, "guiyun/decide") do
      conn
      |> Helpers.delete_temp("guiyun/decide")
      |> Helpers.give_item(@letter)
      |> Helpers.broadcast(room_id, "$N双手抱拳，道：有劳少庄主费心了。\n")
      |> Helpers.broadcast(room_id, "#{npc.name}说道：好！\n")
      |> Helpers.broadcast(room_id, "#{npc.name}给$N一封书信。\n")
      |> Helpers.broadcast(
        room_id,
        "#{npc.name}说道：这位#{Helpers.respect(conn.character)}请先到敝庄盘恒数日，以后再图相叙。\n"
      )
    else
      Helpers.broadcast(conn, room_id, "#{npc.name}对$N奇怪地说道：你要决定干嘛？\n")
    end
  end

  # 黄真：want_join → 加入商业协会；want_tuoli → 退出；否则「没理你」
  defp huangzhen(conn, room_id, npc) do
    cond do
      Helpers.temp(conn, "want_join") ->
        conn
        |> Helpers.broadcast(room_id, "#{npc.name}对着$N微笑道：如今世道钱乃万能之物，以后好好干吧。\n")
        |> Helpers.put_env("is_vendor", 1)
        |> Helpers.delete_temp("want_join")
        |> Helpers.give_item(@shang_ling)

      Helpers.temp(conn, "want_tuoli") ->
        leave_vendor(conn, room_id, npc)

      true ->
        Helpers.render(conn, "#{npc.name}瞄了你一眼，皱了皱眉，没理你。\n")
    end
  end

  defp leave_vendor(conn, room_id, npc) do
    conn =
      conn
      |> Helpers.broadcast(room_id, "#{npc.name}对着$N点点头：人各有志，从此以后你我再无瓜葛。\n")
      |> Helpers.delete_env("is_vendor")
      |> Helpers.put_env("bad_vendor", 1)
      |> Helpers.delete_temp("want_tuoli")

    # LPC 原码此处有个多余分号（`if(objectp(ob = present(...)));`），导致「注销」
    # 文案恒播。此处按**正确语义**实现：仅在确实持有商令时移除并播报（@todo LPC bug 兼容）。
    case Helpers.take_item(conn, "shang ling") do
      {true, conn} ->
        Helpers.broadcast(conn, room_id, "#{npc.name}将$N的#{shang_ling_name()}注销了。\n")

      {false, conn} ->
        conn
    end
  end

  defp shang_ling_name do
    case Items.get(@shang_ling) do
      {:ok, item} -> item.name
      _ -> "商令"
    end
  end
end
