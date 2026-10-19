defmodule Kantele.World.NpcActions.Txbw do
  @moduledoc """
  P5-1d NPC 私有动作：`txbw`（天下布武学入门武功，`d/city/npc/txbw.c`
  `do_txbw(arg)`）。

  仅注册于 `city:wuguan`（扬州武馆，UCL `characters.txbw` 经
  `room_characters "wuguan"` 挂入，同间还有程老板 `characters.chen`）。
  花费 5000 gold 存款直接学会 29 种入门武功之一；`ask shi zhe about 学技能`
  可看清单（inquiry 层，未移植，不属本 verb）。

  ## 移植范围（守门分支）

  LPC `do_txbw` 的判定链（全部 `write` + `return 1`，命令恒消费）：

  1. 无 arg（或 `sscanf(arg, "%s", skill)` 取不到词）→ 用法提示
     「格式：txbw <技能名称>, 举例：txbw shaolin-shenfa」。
  2. `combat_exp < 800000` → 「你的实战经验不足，还是要多努力练功。」
  3. `balance < 5000 gold` → 「你的存款不足。」
  4. 技能名不在 29 个入门清单 → 「看清楚了，这里没有你要学的技能！」
     （LPC 把此判断放在经验/存款守卫**之后**，低经验玩家打错技能名先撞
     经验守卫——本 cond 保持同一顺序。）
  5. 技能已掌握（`query_skill(skill, 1) > 0`）→ 「这个技能你已经掌握，
     不要再浪费金钱了！」
  6. 成功：`improve_skill(skill, 1500000)` 直升 + 扣存款 5000 gold。
     **被未移植系统阻塞**（@todo，见下）。

  ## 与 LPC 的数值口径

  - 花费：LPC `5000 * 100 * 100` = 50,000,000 coin = 5000 gold。
    Kantele `Money` 面额 gold = 10_000 coin（与 LPC 100 silver × 100 coin
    一致），余额走 `PlayerMeta.bank_coins`（铜钱口径，银行 command 同源）。
  - 经验门槛 `800_000` 即 `combat_exp` 原值（非等级）。
  - 技能已掌握判定读 `stats.skills` map（缺省 0；清单本身不依赖技能数据是否在
    世界里注册）。注意 `Stats.skill/2` 对 `skills: nil` 的裸 struct 会
    `Map.get(nil)` 崩（库自身边界），故本模块先归一化再读。

  ## 未建模依赖（@todo）

  - **成功路径**：LPC `improve_skill(skill, 1500000)` 是**直升到指定等级**，
    而 Kantele `Stats.improve_skill/2` 语义为 +1（且带 level_gate 上限），
    非同一操作；直接写 `stats.skills[skill] = 1_500_000` 会绕过学习系统
    （P9 技能学习/等级门）。LPC 成功分支本身**无任何输出**（静默学会），
    故本模块对「可学」状态同样静默消费命令（返回未改动的 `conn`）——不发放
    奖励也不播假文案，待技能直升语义确定后补上。
  - 存款扣减本身可走 `PlayerMeta.put_bank_coins`（banker command 同款），
    待技能直升语义确定后与上一条一并接上。
  """

  use Kantele.World.NpcAction

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Economy.Money
  alias Kantele.World.NpcActions.Helpers

  @room_id "city:wuguan"

  @exp_required 800_000

  # 5000 gold，按 Money 面额折算成铜钱口径（gold = 10_000 coin）。
  @cost_coins 5_000 * Map.fetch!(Money.denominations(), "gold")

  # LPC do_txbw 内联 skill_list（29 个入门武功，按原文顺序）。
  @skill_list ~w(
    shaolin-shenfa
    hengshan-shenfa
    xiao-qinna
    huzhua-shou
    qingyun-shou
    sanyin-shou
    dashou-yin
    bagua-quan
    songshan-quan
    qixing-quan
    canglang-zhi
    zhongnan-zhi
    tiangang-zhi
    jueqing-zhang
    huashan-zhangfa
    benlei-zhang
    pobei-tui
    meinv-quan
    chanhun-suo
    xiewei-bian
    caiyan-gong
    jinyuan-gun
    yinhu-zhang
    lingshe-zhangfa
    tiexue-dao
    chuangwang-dao
    fenglei-panfa
    dali-chu
    hexing-bifa
    qingliang-daxuefa
  )

  @usage "格式：txbw <技能名称>, 举例：txbw shaolin-shenfa\n"

  @impl true
  def run(conn, %{room_id: room_id, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room_id do
      do_txbw(conn, to_string(trailing) |> String.trim())
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_txbw(conn, "") do
    Helpers.render(conn, @usage)
  end

  defp do_txbw(conn, skill) do
    character = conn.character
    meta = character.meta || %PlayerMeta{}
    stats = meta.stats || %Stats{}
    balance = PlayerMeta.bank_coins(meta)
    # `Stats.skill/2` 对 skills 为 nil 的裸 struct 会 Map.get(nil) 崩，先归一化。
    skills = Map.get(stats, :skills) || %{}

    cond do
      # LPC: combat_exp < 800000
      exp_of(stats) < @exp_required ->
        Helpers.render(conn, "你的实战经验不足，还是要多努力练功。\n")

      # LPC: balance < 5000 * 100 * 100
      balance < @cost_coins ->
        Helpers.render(conn, "你的存款不足。\n")

      # LPC: 清单循环未命中 → n > 0
      skill not in @skill_list ->
        Helpers.render(conn, "看清楚了，这里没有你要学的技能！\n")

      # LPC: query_skill(skill, 1) > 0
      Map.get(skills, skill, 0) > 0 ->
        Helpers.render(conn, "这个技能你已经掌握，不要再浪费金钱了！\n")

      # @todo 成功路径（直升技能 + 扣存款）待技能学习系统（P9）语义确定。
      # LPC 此处无输出，故同样静默消费（不改 conn）。
      true ->
        conn
    end
  end

  defp exp_of(%Stats{combat_exp: exp}) when is_integer(exp), do: exp
  defp exp_of(_stats), do: 0
end
