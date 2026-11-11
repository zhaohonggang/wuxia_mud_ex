defmodule Kantele.World.MirrorDaemon.Zixu do
  @moduledoc """
  子虚道人 NPC（宝镜任务发布者）：
  - 固定驻守 liuxi:zixu_guan (子虚观)
  - 玩家 ask mirror/宝镜/乾坤宝镜 → 给乾坤宝镜（每人限 1 个，记 mirror_count）
  - 玩家 ask 心魔幻境 → 校验已持宝镜后发 `maze/enter` 给玩家侧 MazeEvent
    （传送进镜像房间 liuxi:maze_room + 生成心魔 NPC；击败后由 CombatEvent.enemy_died
    按 name 识别「心魔」发放神魂引踪香并送回子虚观，见 P-D）
  """

  require Logger

  alias Kantele.Character.{NPCConfig, NonPlayerMeta, Stats, Vitals}
  alias Kantele.Character.Combat
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items

  @liuxi_zone "liuxi"
  # 待定义
  @mirror_item "liuxi:item/mirror"

  @doc "构建子虚道人 NPC 角色结构（zone_id 可注入，测试用独立 zone 避免抢占 liuxi 监督树）"
  def build_zixu(zone_id \\ @liuxi_zone) do
    room_id = "#{zone_id}:zixu_guan"

    meta =
      %NonPlayerMeta{
        zone_id: zone_id,
        initial_events: [],
        vitals: %Vitals{
          qi: 50_000,
          max_qi: 50_000,
          base_qi: 50_000,
          jing: 50_000,
          max_jing: 50_000,
          base_jing: 50_000,
          jingli: 50_000,
          max_jingli: 50_000,
          neili: 100_000,
          max_neili: 100_000,
          base_neili: 100_000
        },
        stats: %Stats{
          str: 50,
          dex: 50,
          con: 50,
          int: 50,
          combat_exp: 12_000_000,
          potential: 0,
          learned_points: 0,
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0,
          skills: %{
            "force" => 500,
            "huntian-baojian" => 500,
            "parry" => 500,
            "dodge" => 500,
            "unarmed" => 500,
            "sword" => 500,
            "lunhui-jian" => 500,
            "poison" => 500,
            "medical" => 500,
            "lingbo-weibu" => 500,
            "qiankun-danuoyi" => 500,
            "buddhism" => 500,
            "taoism" => 500,
            "literate" => 500,
            "martial-cognize" => 500
          },
          mapped: %{
            "force" => :huntian_baojian,
            "parry" => :qiankun_danuoyi,
            "unarmed" => :huntian_baojian,
            "dodge" => :lingbo_weibu,
            "sword" => :lunhui_jian
          },
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "friendly",
          spawn_room_id: room_id,
          respawn_delay: 0,
          no_kill: true,
          apply: %{}
        },
        combat: Combat.new(),
        loot: [],
        goods: nil,
        inquiries: %{
          "mirror" => :ask_mirror,
          "宝镜" => :ask_mirror,
          "乾坤宝镜" => :ask_mirror,
          "心魔幻境" => :ask_maze
        },
        teach: nil,
        turn_in: nil,
        quest: nil,
        coagents: [],
        parts: %{},
        no_cut: %{},
        default_clone: nil,
        been_cut: 0,
        defeated_by: nil
      }
      # 子虚道人标记
      |> Map.put(:kind, "zixu")

    %Kalevala.Character{
      id: "zixu_daoren",
      name: "子虚道人",
      description: "此人身着道袍，须发皆白，一副仙风道骨的气派，这便是武林中号称「子虚乌有」二道仙中的子虚道人，传说此人早已得道成仙，可通神界。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      meta: meta
    }
  end

  def start_zixu(zone_id \\ @liuxi_zone) do
    invader = build_zixu(zone_id)

    config = [
      supervisor_name: Kalevala.World.CharacterSupervisor.global_name(zone_id),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]

    Kalevala.World.start_character(invader, config)
  end

  @doc """
  构建心魔 NPC 角色结构（P-D 心魔幻境挑战对象）。

  每名进入幻境的玩家按 `player_id` 生成独立心魔（`maze_xinmo_<player_id>`），
  避免多名玩家共用同一实例。驻守 `liuxi:maze_room`，attitude=hostile 可被击杀。
  """
  def build_xinmo(zone_id \\ @liuxi_zone, player_id \\ nil) do
    room_id = "#{zone_id}:maze_room"
    id = if player_id, do: "maze_xinmo_#{player_id}", else: "maze_xinmo"

    meta =
      %NonPlayerMeta{
        zone_id: zone_id,
        initial_events: [],
        vitals: %Vitals{
          qi: 15_000,
          max_qi: 15_000,
          base_qi: 15_000,
          jing: 15_000,
          max_jing: 15_000,
          base_jing: 15_000,
          jingli: 15_000,
          max_jingli: 15_000,
          neili: 20_000,
          max_neili: 20_000,
          base_neili: 20_000
        },
        stats: %Stats{
          str: 40,
          dex: 40,
          con: 40,
          int: 40,
          combat_exp: 2_000_000,
          potential: 0,
          learned_points: 0,
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0,
          skills: %{
            "force" => 300,
            "unarmed" => 300,
            "parry" => 300,
            "dodge" => 300,
            "sword" => 300,
            "huntian-baojian" => 300,
            "lunhui-jian" => 300,
            "lingbo-weibu" => 300,
            "qiankun-danuoyi" => 300,
            "buddhism" => 300,
            "taoism" => 300,
            "literate" => 300,
            "martial-cognize" => 300
          },
          mapped: %{
            "force" => :huntian_baojian,
            "parry" => :qiankun_danuoyi,
            "unarmed" => :huntian_baojian,
            "dodge" => :lingbo_weibu,
            "sword" => :lunhui_jian
          },
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "hostile",
          spawn_room_id: room_id,
          respawn_delay: 0,
          no_kill: false,
          apply: %{}
        },
        combat: Combat.new(),
        loot: [],
        goods: nil,
        inquiries: %{},
        teach: nil,
        turn_in: nil,
        quest: nil,
        coagents: [],
        parts: %{},
        no_cut: %{},
        default_clone: nil,
        been_cut: 0,
        defeated_by: nil
      }
      |> Map.put(:kind, "xinmo")

    %Kalevala.Character{
      id: id,
      name: "心魔",
      description:
        "一团由执念凝成的黑影，面目依稀是你自己的模样，手中长剑泛着森然寒气。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      meta: meta
    }
  end

  @doc """
  启动心魔 NPC 真实进程（P-D，best-effort）。

  仅当 `zone_id` 的 CharacterSupervisor 已存在（世界已加载）时才生成；
  否则返回 `{:error, :supervisor_not_started}`，调用方静默忽略即可
  （测试环境通常不加载世界，不生成）。死亡即销毁、不重启（restart: :temporary）。
  """
  def start_xinmo(zone_id \\ @liuxi_zone, player_id \\ nil) do
    supervisor_name = Kalevala.World.CharacterSupervisor.global_name(zone_id)

    case :global.whereis_name(supervisor_name) do
      pid when is_pid(pid) ->
        invader = build_xinmo(zone_id, player_id)

        config = [
          supervisor_name: supervisor_name,
          communication_module: Kantele.Communication,
          initial_controller: Kantele.Character.SpawnController,
          quit_view: {Kantele.Character.QuitView, "disconnected"}
        ]

        Kalevala.World.start_character(invader, config)

      _ ->
        {:error, :supervisor_not_started}
    end
  end

  @doc """
  NPC 侧问询应答（Q5-T3，NpcAskEvent 对 atom 问询的分发目标）：

  - `:ask_mirror` → 发 `mirror/give` 事件给 asker（限 1 判定在玩家侧 MirrorEvent）
  - `:ask_maze` → 返回占位文本
  """
  def respond_to_ask(conn, %{reply_to: reply_to, asker_id: asker_id}, answer) do
    case answer do
      :ask_mirror ->
        send(reply_to, %Kalevala.Event{
          topic: "mirror/give",
          data: %{
            npc_name: conn.character.name,
            item_id: @mirror_item,
            asker_id: asker_id
          }
        })

        conn

      :ask_maze ->
        send(reply_to, %Kalevala.Event{
          topic: "maze/enter",
          data: %{
            npc_name: conn.character.name,
            asker_id: asker_id
          }
        })

        conn

      _ ->
        conn
    end
  end

  defp publish_tell(conn, asker_id, text) do
    Kalevala.Character.Conn.publish_message(
      conn,
      "characters:#{asker_id}",
      text,
      [],
      &publish_error/2
    )
  end

  defp publish_error(conn, _error), do: conn
end
