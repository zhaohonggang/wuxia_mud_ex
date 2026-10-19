defmodule Kantele.World.NpcActions.Peiyao do
  @moduledoc """
  P5-1e NPC 私有动作：`peiyao`（向平一指配药，`d/city/npc/ping.c` 的
  `ask_job()` + `do_peiyao()` + `working()`）。

  注册于 `kaifeng:yaopu`（药铺）。世界数据已就绪：`clone_lib.ucl` 的
  `characters "city_ping"` 已带 `add_actions = ["peiyao", ...]`，`kaifeng.ucl`
  的 `room_characters "yaopu"` 已通过 clone_lib 回退引用 `characters.city_ping.id`
  —— **无需改 UCL**。

  ## 移植范围（LPC `ask_job` / `do_peiyao` / `working` 判定链）

  1. `combat_exp < 5000` → 拒绝「就凭你就这点能力，我看你来药臼都端不起来！」
  2. `combat_exp > 20000 且 mark/job_peiyao > 1000` → 拒绝「让你干这活，也太屈就你了吧。」
  3. `qi < 5` → 拒绝「你还是先歇歇吧，万一累出人命来我可负担不起。」
  4. 未领活（`temp job/peiyao` 为空）→ 问职入口：设 `temp job/peiyao=1`，
     提示「好，你就帮我配药(peiyao)吧！喏，就这几味。」
     **注意**：Kantele 尚未建模 inquiry/ask_job 层（见 task/jobs/txbw @todo），
     故把 `ask_job` 合并进 `peiyao` 勒令：第一次输入 `peiyao` 视为领活，
     第二次输入才执行配药并结算。
  5. 已领活 → `is_busy()` 拒绝「你正忙着呢，别着急。」；
     否则执行配药（LPC 为 4 轮 `start_busy` 多轮 `working()`，本层因缺
     忙乱回调机制退化为**单轮**，@todo 见 `Combat` `busy` 字段）：
     - `receive_damage("qi", 1)`
     - 奖励 `b = 30 + random(20)` 经验/潜能 + 20 铜钱（币 item 缺，文案呈现，
       发物路径 `Helpers.give_item` @todo）
     - `mark/job_peiyao + 1`（持久，落 `meta.marks`）
     - 清 `temp job/peiyao`
     - 若 `mark/job_peiyao > 50 && random(50) == 1` → 赠「丹玉磨」（item 缺，@todo）

  ## 已建模依赖

  - `combat_exp`/`potential` → `Kantele.Character.Stats`（`character.meta.stats`）
  - `qi` 受损 → `Kantele.Feature.Damage.receive_damage/3`（返回 `{:ok, character}`）
  - `temp job/peiyao` → `meta.temp`（会话级，`Helpers.temp/put_temp`）
  - `mark/job_peiyao` → `meta.marks`（`PlayerMeta.mark/put_mark`，持久，随角色落盘）
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Feature.Damage
  alias Kantele.World.NpcActions.Helpers

  @room_id "kaifeng:yaopu"
  @npc_name "平一指"
  @weak_exp_threshold 5_000
  @rich_exp_threshold 20_000
  @rich_job_count 1000
  @min_qi 5
  @reward_exp_base 30
  @reward_exp_span 20
  @reward_coin 20
  @rare_job_count 50
  @rare_span 50

  @impl true
  def run(conn, %{room_id: room_id}) when is_binary(room_id) do
    if room_id == @room_id do
      do_peiyao(conn)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_peiyao(conn) do
    character = conn.character
    meta = character.meta || %PlayerMeta{}
    stats = meta.stats || %Stats{}
    vitals = meta.vitals
    combat_exp = stats.combat_exp || 0
    temp = meta.temp || %{}
    marks = meta.marks || %{}
    job_count = marks["job/peiyao"] || 0
    qi = if vitals, do: vitals.qi, else: 0

    cond do
      # LPC: if (me->query("combat_exp") < 5000)
      combat_exp < @weak_exp_threshold ->
        Helpers.render(conn, "就凭你就这点能力，我看你来药臼都端不起来！\n")

      # LPC: if (me->query("combat_exp") > 20000 && me->query("mark/job_peiyao") > 1000)
      combat_exp > @rich_exp_threshold and job_count > @rich_job_count ->
        Helpers.render(conn, "让你干这活，也太屈就你了吧。\n")

      # LPC: if (me->query("qi") < 5)
      qi < @min_qi ->
        Helpers.render(conn, "你还是先歇歇吧，万一累出人命来我可负担不起。\n")

      # LPC ask_job：未领活 → 设 temp job/peiyao，提示再次输入 peiyao 开始配药
      is_nil(temp["job/peiyao"]) ->
        conn
        |> Helpers.put_temp("job/peiyao", 1)
        |> then(&Helpers.render(&1, "好，你就帮我配药(peiyao)吧！喏，就这几味。\n"))

      # LPC do_peiyao：已领活，忙乱则拒绝
      meta.combat && Combat.busy?(meta.combat) ->
        Helpers.render(conn, "你正忙着呢，别着急。\n")

      # LPC working：执行一轮配药并结算
      true ->
        settle(conn, character, meta, stats, vitals, job_count)
    end
  end

  defp settle(conn, character, meta, stats, vitals, job_count) do
    b = @reward_exp_base + :rand.uniform(@reward_exp_span) - 1

    {:ok, wounded} = Damage.receive_damage(character, :qi, 1)

    new_exp = (stats.combat_exp || 0) + b
    new_potential = (stats.potential || 0) + b
    new_job_count = job_count + 1

    conn =
      conn
      |> put_character(%{
        wounded
        | meta: %{
              wounded.meta
              | stats: %{stats | combat_exp: new_exp, potential: new_potential},
                marks: Map.put(meta.marks || %{}, "job/peiyao", new_job_count),
                temp: Map.delete((meta.temp || %{}), "job/peiyao")
            }
      })

    conn =
      conn
      |> then(&Helpers.render(&1, "你把药材包好，递给#{@npc_name}。\n"))
      |> then(&Helpers.render(&1, "#{@npc_name}看了你配的药，点头道：不错，不错！这是给你的报酬！\n"))
      |> then(&Helpers.render(&1, "\n你获得了#{b}点经验和潜能。\n\n"))
      |> then(&Helpers.render(&1, "你获得了#{@reward_coin}铜钱。\n"))

    # LPC：mark/job_peiyao > 50 且 random(50) == 1 时赠「丹玉磨」
    # @todo：`/clone/misc/dymo` item 定义缺，发物路径 `Helpers.give_item` 未就绪，
    #       此处仅文案呈现，不发物。
    rare = new_job_count > @rare_job_count and :rand.uniform(@rare_span) == 1
    conn =
      if rare do
        Helpers.render(conn, "#{@npc_name}嘿嘿一笑，道：干得不错，有点意思，这个丹玉磨就算是我送给你的礼物吧。\n")
      else
        conn
      end

    persist(conn)
  end

  # 落盘 `combat_exp` / `potential` / `marks`（`put_character/2` 只改内存态）。
  # 仅对真实玩家落盘：单测 fixture 的 `id` 为 nil，跳过可避免 `Records.save/1`
  # 因 `meta.combat`/`meta.vitals` 缺省而在沙盒里刷 error 日志。
  defp persist(conn) do
    character = conn.private.update_character || conn.character

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Kantele.Character.Records.save(character)
    end

    conn
  end
end
