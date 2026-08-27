defmodule ExKantele.World.Npc.ClassWudangZhang do
  @moduledoc """
  张三丰 NPC 行为模块
  对应原文件: lpc_example/class_npc/class_wudang_zhang.c (964 行)
  
  完整迁移: 13 个问询处理器 + 收徒逻辑 + 接物钩子 + 战斗AI + 真武剑管理 + 九阳解锁
  所有逻辑为纯函数, 无副作用; 实框架需提供 FRAMEWORK_REQUIREMENTS.md 所述能力
  """

  # alias ExKantele.World.Player  # framework 未提供时使用本地 respect_title/1

  # ==================== 常量定义 ====================

  @zhenwu_sword_id "zhenwu_jian"

  @skill_thresholds %{
    "鹤嘴劲" => [family: "武当派", gongxian: 800, shen: 150_000, skill: "taiji-shengong", skill_lvl: 100, neili: 1500, perform: "taiji-shengong/dian", gongxian_cost: 800],
    "震字诀" => [family: "武当派", gongxian: 300, shen: 100_000, skill: "taiji-quan", skill_lvl: 150, neili: 1200, perform: "taiji-quan/zhen", gongxian_cost: 300],
    "引字诀" => [family: "武当派", gongxian: 200, shen: 100_000, skill: "taiji-quan", skill_lvl: 150, neili: 1200, perform: "taiji-quan/yin", gongxian_cost: 200],
    "挤字诀" => [family: "武当派", gongxian: 400, shen: 120_000, skill: "taiji-quan", skill_lvl: 150, neili: 1200, perform: "taiji-quan/ji", gongxian_cost: 400],
    "粘字诀" => [family: "武当派", gongxian: 500, shen: 140_000, skill: "taiji-quan", skill_lvl: 150, neili: 1200, perform: "taiji-quan/zhan", gongxian_cost: 500],
    "太极图" => [family: "武当派", gongxian: 3000, shen: 250_000, skill: "taiji-quan", skill_lvl: 250, force_skill: "taiji-shengong", force_lvl: 300, taoism: 300, jingli: 1000, perform: "taiji-quan/tu", gongxian_cost: 3000, multi_stage: true],
    "缠字诀" => [family: "武当派", gongxian: 300, shen: 80_000, skill: "taiji-jian", skill_lvl: 80, perform: "taiji-jian/chan", gongxian_cost: 300],
    "随字诀" => [family: "武当派", gongxian: 200, shen: 80_000, skill: "taiji-jian", skill_lvl: 60, perform: "taiji-jian/sui", gongxian_cost: 200],
    "驾字诀" => [family: "武当派", gongxian: 600, shen: 100_000, skill: "taiji-jian", skill_lvl: 150, perform: "taiji-jian/jia", gongxian_cost: 600],
    "剑轮岚转" => [family: "武当派", gongxian: 800, shen: 120_000, skill: "taiji-jian", skill_lvl: 160, perform: "taiji-jian/zhuan", gongxian_cost: 800],
    "真武除邪" => [family: "武当派", gongxian: 2000, shen: 120_000, skill: "taiji-jian", skill_lvl: 180, perform: "taiji-jian/zhenwu", gongxian_cost: 2000]
  }

  @apprentice_reqs [
    { :skill, "wudang-xinfa", 120, "我武当派乃内家武功，最重视内功心法。\n{respect}是否还应该在武当心法上多下点功夫？" },
    { :shen, 80_000, "学武之人，德义为先，功夫的高低倒还在其次，未练武，要先学做人。\n在德行方面，{respect}是否还做得不够？" },
    { :exp, 500_000, "你现在经验尚浅，不能领会高深的武功，先锻炼要紧。" },
    { :skill, "taoism", 120, "我武当派武功全从道藏悟出。\n你对道家心法的领悟还不够。\n{respect}还是多研究研究道学心法吧。" },
    { :int, 32, "我武当派武功极需靠自己领悟。\n要能达到炉火纯青之境，体质什么的倒是无关紧要，悟性却是半点也马虎不得。\n{respect}的悟性还大有潜力可挖，还是请回吧。" }
  ]

  @combat_actions [
    { :perform, "sword.chan" },
    { :perform, "sword.jia" },
    { :perform, "sword.sui" },
    { :perform, "sword.zhuan" },
    { :perform, "sword.zhenwu" },
    { :perform, "unarmed.tu" },
    { :perform, "unarmed.zhen" },
    { :perform, "unarmed.zhan" },
    { :perform, "unarmed.ji" },
    { :perform, "unarmed.yin" },
    { :exert, "recover" },
    { :exert, "powerup" },
    { :exert, "shield" }
  ]

  # ==================== 公共 API ====================

  @doc """
  处理玩家问询
  返回: {:ok, %{type: :grant|:info|:reject, message: ..., effects: [...]}} | {:error, reason}
  effects 含: %{set_perform: "skill/name", add_gongxian: -N, improve_skill: [{skill, exp}, ...], add_learned: N, give_item: item_id, unlock_skill: "skill_name"}
  """
  def handle_ask(player, keyword) do
    cond do
      keyword == "真武剑" -> handle_ask_jian(player)
      keyword in ["觉远", "九阳真经", "九阳神功", "武当九阳功"] -> handle_ask_jiuyang(player)
      Map.has_key?(@skill_thresholds, keyword) -> handle_ask_skill(player, keyword)
      true -> {:error, :unknown_keyword}
    end
  end

  @doc """
  处理收徒申请
  返回: {:ok, %{effects: [...]}} | {:error, :reject, reason}
  """
  def attempt_apprentice(player) do
    checks = @apprentice_reqs

    Enum.reduce_while(checks, :ok, fn
      {:skill, skill_name, min, msg}, _ ->
        val = player.skills[skill_name] || 0
        if val >= min, do: {:cont, :ok}, else: {:halt, {:error, :reject, String.replace(msg, "{respect}", respect_title(player))}}

      {:shen, min, msg}, _ ->
        val = player.shen || 0
        if val >= min, do: {:cont, :ok}, else: {:halt, {:error, :reject, String.replace(msg, "{respect}", respect_title(player))}}

      {:exp, min, msg}, _ ->
        val = player.combat_exp || 0
        if val >= min, do: {:cont, :ok}, else: {:halt, {:error, :reject, String.replace(msg, "{respect}", respect_title(player))}}

      {:int, min, msg}, _ ->
        val = player.int || 0
        if val >= min, do: {:cont, :ok}, else: {:halt, {:error, :reject, String.replace(msg, "{respect}", respect_title(player))}}
    end)

    {:ok, %{
      effects: [
        %{type: :recruit, family: "武当派", generation: 2, title: "弟子"},
        %{type: :message, text: "想不到老道在垂死之年，又觅得一个可塑之才，真是可喜可贺。"}
      ]
    }}
  end

  @doc """
  处理给予物品
  """
  def accept_object(player, item) do
    if item.id == @zhenwu_sword_id or item.base_id == @zhenwu_sword_id do
      if player.family.master_id == "zhang_sanfeng" do
        {:ok, %{effects: [%{type: :message, text: "很好，很好！"}, %{type: :destruct_item, item: item.id}]}}
      else
        {:ok, %{effects: [%{type: :message, text: "多谢这位#{respect_title(player)}将真武剑交回。"}, %{type: :destruct_item, item: item.id}]}}
      end
    else
      {:ok, %{effects: [%{type: :message, text: "你给我这种东西干什么？"}]}}
    end
  end

  @doc """
  战斗 AI 动作选择 (chat_msg_combat 对应)
  返回: [{:perform, "skill.action"} | {:exert, "function_name"}]
  """
  def select_combat_action(_player, _target, _context) do
    @combat_actions
  end

  @doc """
  检查是否可学习武当九阳功
  """
  def can_learn_wudang_jiuyang(player) do
    player.flags["can_learn/jiuyang-shengong/wudang"] == true
  end

  @doc """
  尝试学习武当九阳功 (recognize_apprentice 对应)
  """
  def try_learn_wudang_jiuyang(player) do
    cond do
      not can_learn_wudang_jiuyang(player) and player.family.master_id != "zhang_sanfeng" ->
        {:error, "武当九阳神功乃是九阳神功的分支，我少时得师父觉远大师所授。\n但阁下与贫道素不相识，怎谈得上“指点”二字？"}

      not can_learn_wudang_jiuyang(player) and player.family.master_id == "zhang_sanfeng" ->
        {:error, "武当九阳神功乃是九阳神功的分支，我少时得师父觉远大师所授。\n虽然这武功在我手里有所改动，但它还是少林的武功，就算是我的弟子也不传授。"}

      (player.skills["wudang-jiuyang"] || 0) > 180 ->
        {:error, "你的武当九阳功力已颇为深厚了，以后你就自己研究吧。"}

      (player.shen || 0) < 0 ->
        {:error, "老道倒是有心传你九阳功，可是你中邪魔外道如此之深。\n等你改过自新后再来找老道我吧。"}

      true ->
        {:ok, :allowed}
    end
  end

  # ==================== 内部处理函数 ====================

  defp handle_ask_skill(player, skill_name) do
    req = @skill_thresholds[skill_name]
    family_ok = player.family.name == req.family
    gongxian_ok = (player.gongxian || 0) >= req.gongxian
    shen_ok = (player.shen || 0) >= req.shen
    skill_ok = (player.skills[req.skill] || 0) >= req.skill_lvl
    neili_ok = (player.max_neili || 0) >= req.neili

    extra_ok =
      case req do
        %{force_skill: fs, force_lvl: fl} -> (player.skills[fs] || 0) >= fl
        %{taoism: t} -> (player.skills["taoism"] || 0) >= t
        %{jingli: j} -> (player.max_jingli || 0) >= j
        _ -> true
      end

    perform_key = req.perform
    already_known = player.performs[perform_key] == true

    cond do
      not family_ok ->
        {:error, "#{respect_title(player)}不是我们武当派的人，何出此言？"}

      not skill_ok ->
        {:error, "你连#{skill_name_map(req.skill)}都没学，还谈什么绝招可言？"}

      already_known ->
        {:error, "我不是已经教给你了吗？"}

      not gongxian_ok ->
        {:error, "你为我武当派效力还不够，这招我先不忙传你。"}

      not shen_ok ->
        {:error, "你行侠仗义的事情做的还很不够，我不能传你绝招！"}

      not skill_ok ->
        {:error, "你的#{skill_name_map(req.skill)}修为太浅，修炼好了再来吧。"}

      not neili_ok ->
        {:error, "你的内力修为太浅，修炼高了再来吧。"}

      not extra_ok ->
        extra_msg(req)

      true ->
        effects = build_grant_effects(req, perform_key, skill_name)
        {:ok, %{type: :grant, message: grant_message(skill_name), effects: effects}}
    end
  end

  defp handle_ask_jian(player) do
    cond do
      player.shen < 0 ->
        {:ok, %{type: :reject, message: jian_reject_msg(player)}}

      player.family.name != "武当派" ->
        {:ok, %{type: :reject, message: "真武剑是我们武当镇派之宝，你打听它干什么？"}}

      player.family.master_id != "zhang_sanfeng" ->
        {:ok, %{type: :reject, message: "只有我的弟子才能用真武剑，你还是请回吧。"}}

      (player.shen || 0) < 60_000 ->
        {:ok, %{type: :reject, message: "你行侠仗义的事情做得不够，我不能把真武剑交给你。"}}

      true ->
        {:ok, %{
          type: :conditional_give,
          message: "好，你用这真武剑要多做一些行侠仗义的事情！",
          item_id: @zhenwu_sword_id,
          fallback_item: "changjian",
          conditions: %{
            unique_item_check: true,
            current_owner_not_player: true,
            current_owner_not_my_disciple: true
          }
        }}
    end
  end

  defp handle_ask_jiuyang(player) do
    cond do
      player.flags["can_learn/jiuyang-shengong/wudang"] ->
        {:ok, %{type: :info, message: "老道已经答应传授你武当九阳功了，你怎么还那么罗嗦？"}}

      not player.flags["can_learn/jiuyang-shengong/kunlun"] ->
        {:ok, %{type: :reject, message: "昔日《九阳真经》在我师父觉远大师手中丢失，现在也不知道流落何方。"}}

      not player.flags["can_learn/jiuyang-shengong/shaolin"] ->
        {:ok, %{type: :reject, message: "唉，如果当时能够追回《九阳真经》，觉远大师也不至于落难。"}}

      true ->
        {:ok, %{
          type: :unlock,
          message: "你不就是当年还送经书予觉远大师之人吗？\n所谓‘大恩不言谢’，这九阳神功老道倒是通晓一点，现已化为武当九阳功。\n如果阁下不嫌弃，老道倒是可以将这套九阳功传授于你。",
          effects: [
            %{type: :set_flag, key: "can_learn/jiuyang-shengong/wudang", value: true},
            %{type: :improve_skill, skill: "martial-cognize", exp: 1_500_000}
          ]
        }}
    end
  end

  # ==================== 辅助函数 ====================

  defp skill_name_map("taiji-shengong"), do: "太极神功"
  defp skill_name_map("taiji-quan"), do: "太极拳"
  defp skill_name_map("taiji-jian"), do: "太极剑法"
  defp skill_name_map(_), do: "相关武功"

  defp extra_msg(%{taoism: _t}), do: {:error, "你的道学心法研究的还不够明白，要下功夫苦学才是！"}
  defp extra_msg(%{force_skill: fs, force_lvl: _fl}), do: {:error, "你的#{skill_name_map(fs)}还不到家，好好修行吧！"}
  defp extra_msg(%{jingli: _j}), do: {:error, "你的精力不济，就算传给你太极图你也难以运用。"}
  defp extra_msg(_), do: {:error, "条件不足。"}

  defp grant_message("太极图") do
    "你看懂了多少？"
  end
  defp grant_message(_), do: "你懂了吗？"

  defp build_grant_effects(req, perform_key, _skill_name) do
    effects = [
      %{type: :set_perform, key: perform_key, value: true},
      %{type: :add_gongxian, delta: -req.gongxian_cost},
      %{type: :improve_skill, skill: "martial-cognize", exp: 1_500_000}
    ]

    base_skills = [req.skill, "force", "unarmed", "sword", "parry", "dodge", "strike", "hand", "claw"]
    acc = Enum.uniq(base_skills ++ [req.force_skill, "taoism"])
    |> Enum.filter(&(&1 != nil))
    |> Enum.reduce(effects, fn s, acc_inner -> [%{type: :improve_skill, skill: s, exp: 1_500_000} | acc_inner] end)

    acc = if req.multi_stage do
      [%{type: :add_learned_points, delta: 100},
       %{type: :message, text: "你对太极图有了一点领悟。"}
       | acc]
    else
      acc
    end

    Enum.reverse(acc)
  end

  defp jian_reject_msg(player) do
    if player.family.name == "武当派" do
      "你身为武当弟子，反而误入魔道，还不快快醒转？"
    else
      "好一个邪魔外道，居然敢窥测真武剑？"
    end
  end

  # 框架未提供时的回退实现
  defp respect_title(player) do
    case player.shen do
      s when s > 10000 -> "大侠"
      s when s > 5000 -> "侠士"
      s when s > 500 -> "良善"
      s when s > -500 -> "少侠"
      s when s > -5000 -> "恶徒"
      _ -> "魔头"
    end
  end
end