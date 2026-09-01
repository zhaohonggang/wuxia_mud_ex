defmodule Kantele.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Kantele.Character

  module(ChannelCommand) do
    parse("general", :general, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(CloseCommand) do
    parse("close", :run, fn command ->
      command |> spaces() |> word(:target)
    end)

    parse("关", :run, fn command ->
      command |> spaces() |> word(:target)
    end)
  end

  module(OpenCommand) do
    parse("open", :run, fn command ->
      command |> spaces() |> word(:target)
    end)

    parse("开", :run, fn command ->
      command |> spaces() |> word(:target)
    end)
  end

  module(DelayedCommand) do
    parse("delay", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)
  end

  module(DrinkCommand) do
    parse("drink", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("heal", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("喝药", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    # 带参中文别名靠必需空格自然分词：喝某个东西不会误触喝?
    parse("喝", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(FillCommand) do
    parse("fill", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("灌水", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(EatCommand) do
    parse("eat", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    # 带参中文别名靠必需空格自然分词（"吃东西"不会误触 eat）
    parse("吃", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(EmoteCommand) do
    parse("emote", :broadcast, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("emotes", :list)

    # 表情名直用（数据在 data/emotes.ucl，新增表情需在此同步注册）
    parse("smile", :smile)

    parse("wave", :wave)

    parse("frown", :frown)
  end

  module(EnableCommand) do
    parse("enable", :run, fn command ->
      command |> spaces() |> word(:usage) |> spaces() |> word(:skill)
    end)
  end

  module(FightCommand) do
    parse("kill", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("hit", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("fight", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    # 中文别名：杀掉 必须先于 杀 注册（先注册先匹配）
    parse("杀掉", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("杀", :run, fn command ->
      command |> spaces() |> word(:name)
    end)
  end

  module(HaltCommand) do
    parse("halt", :run)
  end

  module(FleeCommand) do
    parse("flee", :run)
    parse("逃跑", :run)
  end

  module(WimpyCommand) do
    parse("wimpy", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("自动逃跑", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(SurrenderCommand) do
    parse("surrender", :run)
    parse("投降", :run)
  end

  module(GiveCommand) do
    parse("give", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("给", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(CutCommand) do
    parse("cut", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("cut", :run_bare)
  end

  module(DescribeCommand) do
    parse("describe", :run, fn command ->
      command |> spaces() |> text(:description)
    end)

    parse("描述", :run, fn command ->
      command |> spaces() |> text(:description)
    end)
  end

  module(WhistleCommand) do
    parse("whistle", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("xiao", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(FollowCommand) do
    parse("follow", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("跟随", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(RecallCommand) do
    parse("recall", :run)
    parse("回城", :run)
  end

  module(FingerCommand) do
    parse("finger", :run, fn command ->
      command |> spaces() |> text(:name)
    end)

    parse("finger", :list)

    parse("查找", :run, fn command ->
      command |> spaces() |> text(:name)
    end)

    parse("查找", :list)
  end

  module(HpCommand) do
    parse("hp", :run)

    parse("气", :run, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)
  end

  module(HelpCommand) do
    parse("help", :show, fn command ->
      command |> spaces() |> text(:topic)
    end)

    parse("帮助", :show, fn command ->
      command |> spaces() |> text(:topic)
    end)

    parse("help", :index)
    parse("帮助", :index)
  end

  module(CommandsCommand) do
    parse("commands", :run)
    parse("命令", :run)
  end

  module(ItemCommand) do
    parse("drop", :drop, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("get", :get, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    # 中文别名（A8/N1）：拿/捡 → get
    parse("拿", :get, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("捡", :get, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("put", :put, fn command ->
      command |> spaces() |> text(:item) |> string(" in ") |> text(:target)
    end)
  end

  module(JialiCommand) do
    parse("jiali", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(InfoCommand) do
    parse("info", :run)
  end

  module(InventoryCommand) do
    parse("i", :run)
    parse("inv", :run)
    parse("inventory", :run)
  end

  module(BackpackCommand) do
    parse("store", :store, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("store", :store_bare)

    parse("take", :take, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("take", :take_bare)

    parse("背包", :list)
  end

  module(LookCommand) do
    parse("look", :run)

    # 单字母命令需带词边界断言，否则会前缀误吃 learn 等长命令
    # （路由按注册顺序先到先得）
    parse("l", :run, [], fn combinator ->
      combinator
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z]))
    end)

    # 看：look 忽略参数，边界保证 "看书" 不误触（A8/N1）
    parse("看", :run, [], fn combinator ->
      combinator
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)
  end

  module(ListCommand) do
    parse("list", :run, fn command ->
      command |> spaces() |> text(:name)
    end)

    parse("list", :bare)
  end

  module(ShopCommand) do
    parse("shop", :run)
  end

  module(BuyCommand) do
    parse("buy", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("买", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(AbandonCommand) do
    parse("abandon", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)

    parse("fangqi", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)

    parse("放弃", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)
  end

  module(LearnCommand) do
    parse("learn", :run, fn command ->
      command |> spaces() |> word(:skill) |> spaces() |> text(:name)
    end)

    parse("学", :run, fn command ->
      command |> spaces() |> word(:skill) |> spaces() |> text(:name)
    end)
  end

  module(PracticeCommand) do
    parse("practice", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)

    parse("练", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)
  end

  module(MapCommand) do
    parse("map", :run)
  end

  module(MoveCommand) do
    parse("north", :north, aliases: ["n"])
    parse("south", :south, aliases: ["s"])
    parse("east", :east, aliases: ["e"])
    parse("west", :west, aliases: ["w"])
    parse("up", :up, aliases: ["u"])
    parse("down", :down, aliases: ["d"])

    # 中文方向别名（A8/N1）：单字加词边界，防止 "北上" 之类被吞成移动
    parse("北", :north, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)

    parse("南", :south, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)

    parse("西", :west, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)

    parse("东", :east, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)

    parse("上", :up, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)

    parse("下", :down, [], fn command ->
      command
      |> lookahead_not(utf8_char([?a..?z, ?A..?Z, ?0..?9, 0x4E00..0x9FFF]))
    end)
  end

  module(PerformCommand) do
    parse("perform", :run, fn command ->
      command |> spaces() |> text(:action)
    end)
  end

  module(ExertCommand) do
    parse("exert", :run, fn command ->
      command |> spaces() |> word(:function)
    end)
  end

  module(ExerciseCommand) do
    parse("exercise", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("dazuo", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("打坐", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(QuitCommand) do
    parse("quit", :run)
  end

  module(ReloadCommand) do
    parse("recompile", :recompile)
    parse("reload", :reload)
  end

  module(ReplyCommand) do
    parse("reply", :run, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(ScoreCommand) do
    parse("score", :run)
  end

  module(WieldCommand) do
    parse("wield", :wield, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("wear", :wear, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("unwield", :unwield, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("remove", :remove, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    # 中文别名（A8/N1）：穿 → wear、脱 → remove
    parse("穿", :wear, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("脱", :remove, fn command ->
      command |> spaces() |> word(:item_name)
    end)
  end

  module(SayCommand) do
    parse("say", :run, fn command ->
      command
      |> spaces()
      |> optional(
        repeat(
          choice([
            symbol("@") |> word(:at) |> spaces(),
            symbol(">") |> word(:adverb) |> spaces()
          ])
        )
      )
      |> text(:text)
    end)
  end

  module(TellCommand) do
    parse("tell", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(VersionCommand) do
    parse("version", :run)
  end

  module(WhisperCommand) do
    parse("whisper", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(WhoCommand) do
    parse("who", :run)
  end

  module(AskCommand) do
    parse("ask", :run, fn command ->
      command |> spaces() |> word(:name) |> spaces() |> text(:keyword)
    end)

    parse("问", :run, fn command ->
      command |> spaces() |> word(:name) |> spaces() |> text(:keyword)
    end)
  end

  module(ApprenticeCommand) do
    parse("apprentice", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("拜师", :run, fn command ->
      command |> spaces() |> word(:name)
    end)
  end

  module(DetachCommand) do
    parse("detach", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("叛师", :run, fn command ->
      command |> spaces() |> word(:name)
    end)
  end

  module(PaiCommand) do
    parse("pai", :run)

    # 门派 单字"门"易误触，用全词
    parse("门派", :run)
  end

  module(WorldStatusCommand) do
    parse("world_status", :run)
  end

  # ---- 技能进阶（Batch 1: LPC cmds/skill/） ----

  module(SkillsCommand) do
    parse("skills", :run)
    parse("myskill", :run)
    parse("技能", :run)
    parse("我的技能", :run)
  end

  module(CheckskillCommand) do
    parse("checkskill", :run, fn command ->
      command |> spaces() |> text(:skill)
    end)

    parse("查技能", :run, fn command ->
      command |> spaces() |> text(:skill)
    end)
  end

  module(PrepareCommand) do
    parse("prepare", :run, fn command ->
      command |> spaces() |> text(:action)
    end)

    parse("备招", :run, fn command ->
      command |> spaces() |> text(:action)
    end)
  end

  # ---- 精力养成（Batch 2: LPC cmds/skill/） ----

  module(RespirateCommand) do
    parse("respirate", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("tuna", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("吐纳", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)

    parse("炼精", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(JingzuoCommand) do
    parse("jingzuo", :run)
    parse("静坐", :run)
  end

  module(ClosedCommand) do
    parse("closed", :run)
    parse("闭关", :run)
  end

  module(StudyCommand) do
    parse("study", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)

    parse("yanjiu", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)

    parse("研习", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)

    parse("读书", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)
  end

  # ---- 个性化/组队/坐骑（Batch 6）----

  module(SaveCommand) do
    parse("save", :run)
    parse("存档", :run)
  end

  module(NickCommand) do
    parse("nick", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("昵称", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(ColorCommand) do
    parse("color", :run)
    parse("颜色", :run)
  end

  module(OptionCommand) do
    parse("option", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("选项", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(TitleCommand) do
    parse("title", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("头衔", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(AliasCommand) do
    parse("alias", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("别名", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(NoteCommand) do
    parse("note", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("便笺", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("笔记", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(QuestCommand) do
    parse("quest", :run)
    parse("myquest", :run)
    parse("任务", :run)
    parse("我的任务", :run)
  end

  module(AskQuestCommand) do
    parse("ask_quest", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("cancel_quest", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("问任务", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("取消任务", :run, fn command ->
      command |> spaces() |> word(:name)
    end)
  end

  # 钱庄存取：带参形式先注册，裸 "bank" 才落到 :show 查余额
  module(BankCommand) do
    parse("bank", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("银行", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("银行", :show)
    parse("bank", :show)
  end

  # 变卖/估价：接 Kantele.Npc.Dealer（do_value/do_sell）
  module(SellCommand) do
    parse("sell", :sell, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("卖", :sell, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("变卖", :sell, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("value", :value, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("估价", :value, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(RideCommand) do
    parse("ride", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("qi", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("骑马", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(UnrideCommand) do
    parse("unride", :run)
    parse("xia", :run)
    parse("下马", :run)
  end

  module(SuicideCommand) do
    parse("suicide", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("自杀", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(TuneCommand) do
    parse("tune", :run, fn command ->
      command |> spaces() |> word(:channel)
    end)

    parse("tune", :run_bare, fn command ->
      command
    end)
  end

  module(TeamCommand) do
    parse("team", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("组队", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("tt", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(BeepCommand) do
    parse("beep", :run, fn command ->
      command |> spaces() |> word(:target)
    end)
  end

  module(BrothersCommand) do
    parse("brothers", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)

    parse("兄弟", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(SwearCommand) do
    parse("swear", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(JifenCommand) do
    parse("jifen", :run)
    parse("积分", :run)
  end

  module(NewsCommand) do
    parse("news", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(PkdCommand) do
    parse("pkd", :run)
  end

  module(SchemeCommand) do
    parse("scheme", :run)
    parse("计划", :run)
  end

  module(SystemCommand) do
    parse("system", :run)
  end

  module(TianshuCommand) do
    parse("tianshu", :run)
    parse("天书", :run)
  end

  module(Score2Command) do
    parse("score2", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(TopCommand) do
    parse("top", :run, fn command ->
      command |> spaces() |> word(:category)
    end)
  end

  module(Top2Command) do
    parse("top2", :run)
  end

  module(ToppCommand) do
    parse("topp", :run)
  end

  module(LeagueCommand) do
    parse("league", :run)
    parse("帮派", :run)
  end

  module(TimeCommand) do
    parse("time", :run)
    parse("时间", :run)
  end

  module(ClsCommand) do
    parse("cls", :run)
    parse("clear", :run)
  end

  module(MissCommand) do
    parse("miss", :run, fn command ->
      command |> spaces() |> word(:item)
    end)
  end

  module(BjtimeCommand) do
    parse("bjtime", :run)
  end

  module(AssistCommand) do
    parse("assist", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(BegCommand) do
    parse("beg", :run)
  end

  module(CheckCommand) do
    parse("check", :run, fn command ->
      command |> spaces() |> word(:target)
    end)

    parse("dating", :run, fn command ->
      command |> spaces() |> word(:target)
    end)
  end

  module(AnswerCommand) do
    parse("answer", :run)
  end

  module(AcceptCommand) do
    parse("accept", :run)
  end

  module(VoteCommand) do
    parse("vote", :run)
  end

  module(HandCommand) do
    parse("hand", :run)
  end

  module(DrugCommand) do
    parse("drug", :run, fn command ->
      command |> spaces() |> word(:poison) |> spaces() |> string("in") |> spaces() |> word(:target)
    end)
  end

  module(PushCommand) do
    parse("push", :run)
  end

  module(StayCommand) do
    parse("stay", :run)
  end

  module(ReleaseCommand) do
    parse("release", :run)
  end

  module(ComeCommand) do
    parse("come", :run)
  end

  module(TrainCommand) do
    parse("train", :run)
  end

  module(StopCommand) do
    parse("stop", :run)
  end

  module(WashCommand) do
    parse("wash", :run, fn command ->
      command |> spaces() |> text(:target)
    end)
  end

  module(TalkCommand) do
    parse("talk", :run)
  end

  module(SearchCommand) do
    parse("search", :run)
  end

  module(RemoveCommand) do
    parse("remove", :run)
  end

  module(StealCommand) do
    parse("steal", :run, fn command ->
      command |> spaces() |> word(:item) |> spaces() |> string("from") |> spaces() |> word(:target)
    end)
  end

  module(GuardCommand) do
    parse("guard", :run, fn command ->
      command |> spaces() |> text(:target)
    end)
  end

  module(SpecialCommand) do
    parse("special", :run)
  end

  module(AnsuanCommand) do
    parse("ansuan", :run)
  end

  module(PourCommand) do
    parse("pour", :run, fn command ->
      command |> spaces() |> word(:poison) |> spaces() |> string("in") |> spaces() |> word(:target)
    end)
  end

  module(ToCommand) do
    parse("to", :run)
  end

  module(TouchCommand) do
    parse("touch", :run)
  end

  module(StabCommand) do
    parse("stab", :run)
  end

  module(LiuxiCommand) do
    parse("liuxi", :run)
    parse("柳溪", :run)
  end

  module(SecularizeCommand) do
    parse("secularize", :run)
    parse("huansu", :run)
    parse("还俗", :run)
  end

  module(SemoteCommand) do
    parse("semote", :run)
  end

  module(WenxuanCommand) do
    parse("wenxuan", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(PurchaseCommand) do
    parse("purchase", :run, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(DaubCommand) do
    parse("daub", :run, fn command ->
      command |> spaces() |> word(:poison) |> spaces() |> string("on") |> spaces() |> text(:target)
    end)
  end

  module(SetCommand) do
    parse("set", :run)
  end

  module(PasswdCommand) do
    parse("passwd", :run)
  end

  module(IdCommand) do
    parse("id", :run)
  end

  module(CookCommand) do
    parse("cook", :run, fn command ->
      command |> spaces() |> text(:dish_name)
    end)
  end

  module(DriveCommand) do
    parse("drive", :run, fn command ->
      command |> spaces() |> word(:vehicle) |> spaces() |> word(:direction)
    end)

    parse("赶车", :run, fn command ->
      command |> spaces() |> word(:vehicle) |> spaces() |> word(:direction)
    end)
  end

  module(MakeCommand) do
    parse("make", :run, fn command ->
      command |> spaces() |> text(:arg)
    end)
  end

  module(SleepCommand) do
    parse("sleep", :run)
    parse("睡觉", :run)
  end

  module(AuctionCommand) do
    parse("auction", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  module(BaitanCommand) do
    parse("baitan", :run, fn command ->
      command |> spaces() |> text(:rest)
    end)
  end

  # 表情名直用已改为 EmoteCommand 里的显式 parse（smile/wave/frown）。
  # 不再用 dynamic 路由：kalevala parse_dynamic_text 返回 3 元组，
  # Router.parse/3 只匹配 4 元组，命中必 CaseClauseError 崩 foreman（断线）
end
