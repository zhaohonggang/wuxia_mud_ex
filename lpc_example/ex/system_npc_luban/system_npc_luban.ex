defmodule ExKantele.World.Npc.Luban do
  @moduledoc """
  对应原文件: lpc_example/system_npc/system_npc_luban.c (鲁班, 99972B)

  迁移判定: C —— **系统型服务 NPC**（营造/建房系统），半数据半行为。
  能力本质：鲁班 = 房屋建造官。玩家买房(contract 表单)-> 选户型 ->
  填房名/代号/描述 -> 缴纳现金 -> 巫师批核 -> `create_room` 撷取
  户型原型房文件并生成个人专属房间 + 门匙 `create_new_key`。

  本模块移植**自包含**部分:
    - room_example  户型表（3 种：独乐居/彩虹居/盘龙居 + 房间文件清单 + 造价）
    - ban_room_id   禁用作房间代号/出口的保留名
    - check_room_name / check_room_id / check_house_type  三查校验
    - obey_description  描述净化（ANSI 色码替换 + 转义清洗）
    - file_dir / to_player  玩家房间文件路径映射
    - str_width  中文字符宽度（CJK=2）

  框架需新增 Kantele.House（户型表 + 合同表单 + 建房/拆房 + 门匙），
  见 FRAMEWORK_REQUIREMENTS.md。
  """

  # ---- 户型表 (room_example)：type 为英文代号，name 为中文名，value 造价 ----
  @room_example [
    %{
      name: "独乐居",
      type: "dule",
      value: 20_000_000,
      files: %{
        "xiaoyuan" => "/d/room/dule/xiaoyuan.c",
        "xiaowu" => "/d/room/dule/dulewu.c"
      }
    },
    %{
      name: "彩虹居",
      type: "caihong",
      value: 70_000_000,
      files: %{
        "xiaoyuan" => "/d/room/caihong/xiaoyuan.c",
        "dating" => "/d/room/caihong/dating.c",
        "houyuan" => "/d/room/caihong/houyuan.c",
        "woshi" => "/d/room/caihong/woshi.c"
      }
    },
    %{
      name: "盘龙居",
      type: "panlong",
      value: 800_000_000,
      files: %{
        "dayuan" => "/d/room/panlong/dayuan.c",
        "qianting" => "/d/room/panlong/qianting.c",
        "zuowei" => "/d/room/panlong/zuowei.c",
        "youwei" => "/d/room/panlong/youwei.c",
        "zoudao" => "/d/room/panlong/zoudao.c",
        "yingke" => "/d/room/panlong/yingke.c",
        "chashi" => "/d/room/panlong/chashi.c",
        "yishi" => "/d/room/panlong/yishiting.c",
        "zuoyanwu" => "/d/room/panlong/yanwu1.c",
        "youyanwu" => "/d/room/panlong/yanwu2.c",
        "zhongting" => "/d/room/panlong/zhongting.c",
        "zuoxiang" => "/d/room/panlong/zuoxiang.c",
        "youxiang" => "/d/room/panlong/youxiang.c",
        "houyuan" => "/d/room/panlong/houyuan.c",
        "chufang" => "/d/room/panlong/chufang.c",
        "wuchang" => "/d/room/panlong/lianwu.c",
        "huayuan" => "/d/room/panlong/huayuan.c",
        "zhulin" => "/d/room/panlong/zhulin.c",
        "tingtao" => "/d/room/panlong/tingtao.c",
        "jusuo" => "/d/room/panlong/jusuo.c",
        "shufang" => "/d/room/panlong/shufang.c",
        "woshi" => "/d/room/panlong/woshi.c"
      }
    }
  ]

  # ---- 预留的房间代号/出口名，禁用 ----
  @ban_room_id [
    "north", "south", "east", "west",
    "northup", "southup", "eastup", "westup",
    "northdown", "southdown", "eastdown", "westdown",
    "northeast", "northwest", "southeast", "southwest",
    "up", "down", "enter", "out", "in"
  ]

  @wizlevel 4

  # ---- 房屋命名校验 ----

  @doc """
  check_room_name：房名必须 2-6 个中文字（strwidth 4..12）且为中文。
  Returns :ok | {:error, msg}
  """
  def check_room_name(name) do
    w = str_width(name)

    cond do
      w < 4 or w > 12 -> {:error, "对不起，你房屋的名字必须是 2 到 6 个中文字。"}
      not all_chinese?(name) -> {:error, "对不起，请您用「中文」为房屋取名字。"}
      true -> :ok
    end
  end

  @doc """
  check_room_id：房间代号必须 3-10 个英文字母且不在保留名单。
  Returns :ok | {:error, msg}
  """
  def check_room_id(roomid) do
    len = String.length(roomid)

    cond do
      len < 3 or len > 10 ->
        {:error, "对不起，你房屋的代号必须是 3 到 10 个英文字母。"}

      not Regex.match?(~r/^[A-Za-z]+$/, roomid) ->
        {:error, "对不起，你房屋的代号必须用英文字母。"}

      roomid in @ban_room_id ->
        {:error, "不要起这种名字！免得人家误会。"}

      true ->
        :ok
    end
  end

  @doc """
  check_house_type：按 type(英文) 或 name(中文) 查户型，返回该户型 map 或 nil。
  """
  def check_house_type(type) do
    Enum.find(@room_example, fn h -> h.type == type or h.name == type end)
  end

  @doc "房型列表（供表单/界面展示）"
  def room_example, do: @room_example

  # ---- 文本宽度 / 中文判定 ----

  @doc "字符串显示宽度：CJK 字符按 2 计（strwidth 语义）"
  def str_width(s) when is_binary(s) do
    s
    |> String.graphemes()
    |> Enum.reduce(0, fn g, acc -> acc + if(cjk?(g), do: 2, else: 1) end)
  end

  def cjk?(g) do
    String.to_charlist(g) |> Enum.any?(fn c -> c > 0x7F end)
  end

  def all_chinese?(s) when is_binary(s) do
    s != "" and
      s
      |> String.graphemes()
      |> Enum.all?(&cjk?/1)
  end

  # ---- 描述净化 ----

  @ansi_map %{
    "$BLK$" => "\e[30m", "$RED$" => "\e[31m", "$GRN$" => "\e[32m",
    "$YEL$" => "\e[33m", "$BLU$" => "\e[34m", "$MAG$" => "\e[35m",
    "$CYN$" => "\e[36m", "$WHT$" => "\e[37m",
    "$HIR$" => "\e[1;31m", "$HIG$" => "\e[1;32m", "$HIY$" => "\e[1;33m",
    "$HIB$" => "\e[1;34m", "$HIM$" => "\e[1;35m", "$HIC$" => "\e[1;36m",
    "$HIW$" => "\e[1;37m", "$NOR$" => "\e[0m"
  }

  @doc """
  obey_description：净化用户描述。
    - 过长(>420 宽)拒收
    - 替换 双引号"->'、\\n->换行、去 Tab 与空格
    - ANSI 色码 token -> 转义码；末尾补 NOR
  Returns {:ok, cleaned} | :error
  """
  def obey_description(desc) when desc in [nil, ""], do: {:ok, ""}

  def obey_description(desc) do
    if str_width(desc) > 420 do
      :error
    else
      cleaned =
        desc
        |> String.replace("\"", "'")
        |> String.replace("\n", "\n")
        |> String.replace("\t", "")
        |> String.replace(" ", "")
        |> replace_ansi()
        |> Kernel.<>("\e[0m")

      {:ok, cleaned}
    end
  end

  defp replace_ansi(s) do
    Enum.reduce(@ansi_map, s, fn {k, v}, acc -> String.replace(acc, k, v) end)
  end

  # ---- 玩家房间文件路径 ----

  @doc "file_dir：玩家房屋数据目录根（DATA_DIR + room/<player_id>/）"
  def file_dir(data_dir, player_id), do: data_dir <> "room/" <> player_id <> "/"

  @doc """
  to_player：把户型原型文件路径映射为玩家专属路径。
  file = \"/d/room/panlong/xiaoyuan.c\" -> data_dir/room/<player>/xiaoyuan.c
  """
  def to_player(data_dir, player_id, file) do
    stem = file |> String.split("/") |> List.last()
    file_dir(data_dir, player_id) <> stem
  end

  @doc "房型是否为可批核的处理等级条件（巫师等级 >= 4）"
  def processable?(wiz_level), do: wiz_level >= @wizlevel
end
