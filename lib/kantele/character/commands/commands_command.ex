defmodule Kantele.Character.CommandsCommand do
  @moduledoc """
  列出当前可用的全部游戏命令（从命令路由器自动收集）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandsView

  # 与 commands.ex 路由保持同步；recompile/reload/delay/world_status 为内部命令不列出
  @descriptions %{
    "channels" => "频道聊天（general）",
    "commands" => "本列表",
    "drop" => "丢弃物品",
    "eat" => "吃东西：eat 物品",
    "emote" => "在房间表演动作",
    "emotes" => "可用动作列表",
    "enable" => "技能映射：enable 用法 特技",
    "exert" => "运功：exert powerup",
    "exercise" => "打坐练内功：exercise 耗气量",
    "fight" => "开战（同 kill）",
    "get" => "拾取物品",
    "halt" => "停手脱离战斗",
    "help" => "帮助主题",
    "info" => "房间信息",
    "inventory" => "背包（简写 i/inv）",
    "jiali" => "加力：jiali 0-N（0 关闭）",
    "kill" => "攻击目标",
    "learn" => "拜师学习：learn 技能 师父 [x次数]",
    "list" => "查看商人货物：list [商人]",
    "buy" => "购买：buy 物品",
    "ask" => "问询：ask 某人 关键词",
    "apprentice" => "拜师：apprentice 某人",
    "pai" => "门派信息",
    "look" => "查看房间",
    "map" => "区域地图",
    "perform" => "绝招：perform 武功.招式",
    "practice" => "练习：practice 技能",
    "quit" => "退出游戏",
    "remove" => "脱下护甲",
    "score" => "角色状态",
    "unwield" => "卸下武器",
    "wear" => "穿戴护甲",
    "wield" => "装备武器",
    # Batch 1: 技能进阶
    "skills" => "技能列表",
    "myskill" => "技能列表（同 skills）",
    "checkskill" => "查技能详情：checkskill 技能名",
    "prepare" => "组合拳术：prepare 指法 掌法",
    # Batch 2: 精力养成
    "respirate" => "吐纳炼精：respirate 耗精量",
    "tuna" => "吐纳（同 respirate）",
    "jingzuo" => "峨嵋静坐",
    "closed" => "闭关修行（大宗师）",
    "study" => "研读秘籍：study 书籍 [次数]"
  }

  def run(conn, _params) do
    commands =
      @descriptions
      |> Enum.map(fn {name, description} -> %{name: name, description: description} end)
      |> Enum.sort_by(& &1.name)

    render(conn, CommandsView, "index", %{commands: commands})
  end
end
