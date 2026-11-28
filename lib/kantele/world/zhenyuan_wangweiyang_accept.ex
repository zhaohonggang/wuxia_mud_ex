defmodule Kantele.World.ZhenyuanWangweiyangAccept do
  @moduledoc """
  王维扬 `accept_object/2`（LPC `kungfu/class/zhenyuan/wangweiyang.c:616-702`）。

  LPC 原文三分支：

  1. 物品既不是 `HOUBEI`（厚背紫金刀）也不是 `LETTER`（商剑鸣引荐信）→
     `command("say 你给我这种东西干什么？")`，`return 0`（拒收，物品留在玩家身上）。
  2. 引荐信 → 已会「天刀八势」时只 `shake` + `shit`；否则 `nod` → `haha` →
     `say` → `message_sort(msg, me, this_object())` → `haha` →
     `tell_object(你学会了「天刀八势」)` → 19 次 `improve_skill(...,1500000)` →
     `set("can_perform/bagua-dao/tian",1)`。
  3. 厚背紫金刀 → 非嫡传 `多谢这位<respect>将厚背紫金刀交回。`，嫡传
     `很好，很好！`，随后 `destruct(ob)`。

  `message_sort` 这里 `me` = 玩家、`you` = 王维扬，与 #803 侠客岛（me = NPC）
  **方向相反**：玩家私有版 `$n` → 王维扬、`$N` → 「你」；旁观者版 `$N` → 玩家名。
  因此本模块自带反向渲染，不复用 `InquiryHandlers.MessageSort`。

  NPC 进程只负责判定规则与发事件；玩家状态（`stats.performs` / `stats.skills` /
  背包销毁）只能由玩家进程改，故 `handle_player/2` 由 `GiveEvent` 的事件路由调用。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @letter_id "clone_lib:sjmletter"
  @houbei_id "clone_lib:houbeidao"
  @perform_id "bagua-dao/tian"

  # LPC 19 次 improve_skill(...,1500000) 原顺序（force/nei-bagua/parry/wai-bagua/
  # blade/bagua-dao 各 3 次，martial-cognize 1 次）。引擎每次调用 = +1 级。
  @improve_skills [
    "force",
    "force",
    "force",
    "nei-bagua",
    "nei-bagua",
    "nei-bagua",
    "parry",
    "parry",
    "parry",
    "wai-bagua",
    "wai-bagua",
    "wai-bagua",
    "blade",
    "blade",
    "blade",
    "bagua-dao",
    "bagua-dao",
    "bagua-dao",
    "martial-cognize"
  ]

  # LPC `message_sort(HIY "\n$n" ... , me, this_object())`，逐字保留。
  @letter_sort "\n" <>
                 "$n微笑着点了点头，对$N道：“你可知道何为「八卦」吗？”" <>
                 "$N想也不想，随口答道：“八卦乃天居乾、地居坤、风居巽、云居震、" <>
                 "飞龙居坎、武翼居兑、鸟翔居离、蜿盘居艮。”" <>
                 "$n听后颇为赞许，笑道：“你这是只知其一，不知其二。" <>
                 "所谓「八卦」的真谛乃是一个「阵」字。”" <>
                 "$N闷了好一会，默默思考这一句话，突然双目一亮，叫道：" <>
                 "“师父，弟子终于明白什么是真正的「八卦」了！”" <>
                 "$n大笑道：“你只要明白了这个道理，那么这八势刀法你就已经学会了。”\n"

  @doc "LPC `HOUBEI` 对应的 ex 物品 id"
  def houbei_id, do: @houbei_id

  @doc "LPC `LETTER` 对应的 ex 物品 id"
  def letter_id, do: @letter_id

  @doc "LPC `can_perform/bagua-dao/tian` 对应的 perform id"
  def perform_id, do: @perform_id

  @doc "19 次 improve_skill 的技能序列（逐字顺序）"
  def improve_skills, do: @improve_skills

  @doc "LPC message_sort 原模板"
  def letter_sort, do: @letter_sort

  @doc """
  `message_sort(msg, me = 玩家, you = 王维扬)` 的占位符渲染。

  `$n` = you（王维扬）、`$N` = me；玩家私有版 target_name 传「你」，
  旁观者版传玩家姓名，与 LPC str1/str3 严格对应。
  """
  def render_letter_sort(text, npc_name, target_name)
      when is_binary(text) and is_binary(npc_name) and is_binary(target_name) do
    text
    |> String.replace("$n", npc_name)
    |> String.replace("$N", target_name)
    |> String.replace("{npc}", npc_name)
    |> String.replace("{name}", target_name)
  end

  # ---- NPC 进程侧（GiveEvent 命中 zhenyuan_wangweiyang 规则时调用） ----

  def handle(conn, npc, item_instance, data, _from_name, rule) do
    reply_to = Map.get(data, :reply_to)

    if is_pid(reply_to) do
      send(reply_to, %Event{
        from_pid: self(),
        topic: "zhenyuan/wangweiyang_accept",
        data: %{
          action: Map.get(rule, :action),
          from_id: Map.get(data, :from_id),
          from_name: Map.get(data, :from_name),
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          npc_id: Map.get(npc, :id),
          npc_name: Map.get(npc, :name) || "王维扬",
          npc_room_id: Map.get(data, :npc_room_id) || Map.get(npc, :room_id)
        }
      })
    end

    put_character(conn, npc)
  end

  # ---- 玩家进程侧（事件路由 GiveEvent.zhenyuan_wangweiyang_accept/2 委托） ----

  def handle_player(conn, %{data: data}) do
    character = current(conn)

    if Map.get(data, :from_id) != character.id do
      conn
    else
      instance_id = Map.get(data, :instance_id)
      inventory = Enum.reject(character.inventory || [], &(&1.id == instance_id))
      character = %{character | inventory: inventory}
      npc_name = Map.get(data, :npc_name) || "王维扬"
      room_id = Map.get(data, :npc_room_id) || Map.get(character, :room_id)

      case Map.get(data, :action) do
        "letter" -> letter_branch(conn, character, npc_name, room_id)
        "houbei" -> houbei_branch(conn, character, npc_name, room_id)
        _ -> conn
      end
    end
  end

  def handle_player(conn, _event), do: conn

  # 引荐信：已会则 shake + shit（LPC 无 tell_object）；未会走完整授艺链。
  defp letter_branch(conn, character, npc_name, room_id) do
    stats = character.meta.stats || Stats.new()

    if Stats.perform_known?(stats, @perform_id) do
      conn =
        conn
        |> npc_emote(room_id, npc_name, "#{npc_name}摇了摇头。")
        |> npc_emote(room_id, npc_name, "#{npc_name}破口大骂：“Shit!!怎么又死了~~”")

      conn
      |> finish_player(character)
      |> prompt(CommandView, "prompt", %{})
    else
      observer_sort = render_letter_sort(@letter_sort, npc_name, character.name)
      private_sort = render_letter_sort(@letter_sort, npc_name, "你")

      conn =
        conn
        |> npc_emote(room_id, npc_name, "#{npc_name}点了点头。")
        |> npc_emote(room_id, npc_name, "#{npc_name}「哈哈哈」大笑几声。")
        |> npc_say(room_id, npc_name, "好，好！既然这样，我就传你这招「天刀八势」！")
        |> render(CommandView, "text", %{text: private_sort})
        |> room_broadcast(room_id, observer_sort, exclude_actor: true)
        |> npc_emote(room_id, npc_name, "#{npc_name}「哈哈哈」大笑几声。")
        |> render(CommandView, "text", %{text: "你学会了「天刀八势」。\n"})

      stats =
        @improve_skills
        |> Enum.reduce(stats, fn skill, acc ->
          {acc, _improved?} = Stats.improve_skill(acc, skill)
          acc
        end)
        |> Stats.learn_perform(@perform_id)

      character = put_in(character.meta.stats, stats)

      conn
      |> finish_player(character)
      |> prompt(CommandView, "prompt", %{})
    end
  end

  # 厚背紫金刀：嫡传/非嫡传分文案，物品 destruct（玩家侧移除实例）。
  defp houbei_branch(conn, character, npc_name, room_id) do
    respect = Map.get(character.meta || %{}, :respect) || Helpers.respect(character)

    text =
      if wangweiyang_disciple?(character) do
        "很好，很好！"
      else
        "多谢这位#{respect}将厚背紫金刀交回。"
      end

    conn
    |> npc_say(room_id, npc_name, text)
    |> finish_player(character)
    |> prompt(CommandView, "prompt", %{})
  end

  defp finish_player(conn, character) do
    Records.save(character)
    put_character(conn, character)
  end

  # LPC `query("family/master_id")` 是 LPC id "wang weiyang"；ex loader 用
  # "zhenyuan_wangweiyang"，两者都认（兼容历史存档，同昆仑两极剑处理）。
  defp wangweiyang_disciple?(%{meta: %{family: family}}) when is_map(family) do
    master_id = Map.get(family, :master_id) || Map.get(family, "master_id")

    master_id in ["zhenyuan_wangweiyang", "wang weiyang"]
  end

  defp wangweiyang_disciple?(_character), do: false

  # `command("nod"/"haha"/"shake"/"shit")` 的实际 emote 文案取自 LPC
  # `/data/emoted.o`：nod="$P点了点头。"、haha="$P「哈哈哈」大笑几声。"、
  # shake="$P摇了摇头。"、shit="$P破口大骂：“Shit!!怎么又死了~~”"。
  # 这里传整句（NPC 名为字面量），避免 VisionView 把 `{npc}` 渲染成「你」。
  defp npc_emote(conn, room_id, _npc_name, text), do: room_broadcast(conn, room_id, text <> "\n")

  defp npc_say(conn, room_id, npc_name, text),
    do: room_broadcast(conn, room_id, "#{npc_name}说道：#{text}\n")

  defp room_broadcast(conn, room_id, text, opts \\ [])
       when is_binary(room_id) and byte_size(room_id) > 0 do
    RoomHelpers.broadcast_vision(conn, room_id, text, opts)
  end

  defp room_broadcast(conn, _room_id, _text, _opts), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
