defmodule Kantele.World.Story.Challenger do
  @moduledoc """
  Q3-stretch：真实「挑战者」摆擂。

  挑战故事播到摆擂时，本模块以与 loader 相同的路径启动一个真实 NPC 进程
  （`Kalevala.World.start_character` + `SpawnController`），它会自动进房间
  （`private.characters`）、被 `look`/`fight` 到，并参与真实战斗：

  - **应战**：玩家输入 `accept`（`Kantele.Character.AcceptCommand`）开打；
  - **战斗**：走既有 combat 引擎（双方 `combat/start`→`combat/tick` 互殴），
    NPC 死亡流程（`CombatEvent.die`）自动给击杀者 combat_exp/potential，
    并把挑战者 `meta.loot`（玄铁令）作为击杀掉落发给击杀者；
  - **结算**：`CombatEvent.die` 里反向调用 `on_died/2` 清理登记并广而告之。

  本模块只在 Story 侧登记/广播，不接触战斗细节；生命期独立于 StoryDaemon。
  """

  use GenServer

  require Logger

  alias Kantele.Character.Combat
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Communication
  alias Kantele.World.Story.Gift

  @default_challenge_room "liuxi:guangchang"
  @default_name "神秘挑战者"
  @reward_loot ["liuxi:misc/xuantie-ling"]

  defstruct [:challenger]

  # ---- API ----

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc "当前摆擂的挑战者（可按房间过滤）：`nil` 或无"
  def current(room_id \\ nil, server \\ __MODULE__),
    do: GenServer.call(server, {:current, room_id})

  @doc "随机挑一个在线玩家所在的房间摆擂（无人则回退到中央广场）"
  def spawn_random(server \\ __MODULE__),
    do: GenServer.call(server, :spawn_random, 10_000)

  @doc "在指定房间摆擂；`opts` 可覆盖 name/zone_id/supervisor_name/loot"
  def spawn(server \\ __MODULE__, room_id, opts \\ []),
    do: GenServer.call(server, {:spawn, room_id, opts}, 10_000)

  @doc "玩家应战登记（accept 命令调用）"
  def accept(server \\ __MODULE__, player),
    do: GenServer.call(server, {:accept, player})

  @doc "挑战者死亡结算（CombatEvent.die 反向调用）；cready 清登记并公告胜者"
  def on_died(server \\ __MODULE__, challenger_id, killer),
    do: GenServer.cast(server, {:on_died, challenger_id, killer})

  @doc "手工收摊（运维/测试）"
  def despawn(server \\ __MODULE__), do: GenServer.call(server, :despawn)

  # ---- GenServer ----

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:current, room_id}, _from, state) do
    challenger =
      case state.challenger do
        %{room_id: challenger_room} = challenger when room_id in [nil, challenger_room] ->
          challenger

        _ ->
          nil
      end

    {:reply, challenger, state}
  end

  def handle_call(:spawn_random, _from, state) do
    if Mix.env() == :test do
      # 单元/离线测试不向真实世界摆擂，避免污染房间角色集合
      {:reply, {:error, :test_env_no_spawn}, state}
    else
      room_id =
        case Gift.random_player() do
          nil -> @default_challenge_room
          player -> player.room_id
        end

      do_spawn_and_reply(room_id, [], state)
    end
  end

  def handle_call({:spawn, room_id, opts}, _from, state) do
    do_spawn_and_reply(room_id, opts, state)
  end

  def handle_call({:accept, player}, _from, state) do
    case state.challenger do
      nil ->
        {:reply, {:error, :no_challenger}, state}

      challenger ->
        challenger = Map.put(challenger, :accepted_by, player.id)

        announce(
          "{color foreground=\"red\"}【 挑  战 】{/color} #{player.name} 朗声道：我来领教！话音未落已纵身跃上擂台。\n"
        )

        {:reply, :ok, %{state | challenger: challenger}}
    end
  end

  def handle_call(:despawn, _from, state) do
    {:reply, state.challenger != nil, %{state | challenger: nil}}
  end

  @impl true
  def handle_cast({:on_died, challenger_id, killer}, state) do
    case state.challenger do
      %{id: ^challenger_id} = challenger ->
        announce(
          "{color foreground=\"red\"}【 挑  战 】{/color} " <>
            "#{killer_name(killer)} 击败了不可一世的神秘挑战者，赢得满堂喝彩！\n" <>
            "据说战胜者从其身上得到了一枚玄铁令。\n"
        )

        Logger.info("challenger defeated - id=#{challenger.id} killer=#{killer_name(killer)}")
        {:noreply, %{state | challenger: nil}}

      other when not is_nil(other) ->
        # 死的是上一场未清理的 NPC（故事早已换场），只记日志不广播
        Logger.debug("challenger corpse cleanup - id=#{challenger_id}")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  # ---- 摆擂 ----

  defp do_spawn_and_reply(room_id, opts, state) do
    case do_spawn(room_id, opts) do
      {:ok, challenger} -> {:reply, {:ok, challenger}, %{state | challenger: challenger}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp do_spawn(room_id, opts) do
    with {:ok, zone_id} <- room_zone_id(room_id),
         character <- build_character(room_id, zone_id, opts),
         {:ok, pid} <- start_character(character, opts),
         true <- Process.alive?(pid) || {:error, {:npc_not_alive, character.id}} do
      challenger = %{
        id: character.id,
        name: character.name,
        room_id: room_id,
        pid: pid,
        accepted_by: nil
      }

      announce(
        "{color foreground=\"red\"}【 挑  战 】{/color} 一个黑衣蒙面的神秘人在 #{room_id} 摆下擂台，" <>
          "朗声道：但使天下英雄，胜我一招半式，这枚玄铁令拱手相让！\n"
      )

      {:ok, challenger}
    else
      {:error, reason} ->
        Logger.warn("challenger spawn failed - #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp room_zone_id(room_id) do
    # 注意：gen_server 以 `Room.global_name/1` 注册，:global.whereis_name 需要内部 term
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        room = :sys.get_state(pid)

        case Map.get(room, :data) do
          %{zone_id: zone_id} when is_binary(zone_id) -> {:ok, zone_id}
          _ -> {:error, {:no_zone_id, room_id}}
        end

      _ ->
        {:error, {:room_not_running, room_id}}
    end
  end

  defp build_character(room_id, zone_id, opts) do
    %Kalevala.Character{
      id: "challenge-#{System.unique_integer([:positive])}",
      name: Keyword.get(opts, :name, @default_name),
      description:
        "一个黑衣蒙面的神秘人，双目沉静，气息绵长，显然不是易与之辈。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      meta: %NonPlayerMeta{
        zone_id: zone_id,
        initial_events: [],
        vitals: %Vitals{
          qi: 900,
          max_qi: 900,
          base_qi: 900,
          jing: 300,
          max_jing: 300,
          base_jing: 300,
          jingli: 0,
          max_jingli: 0,
          neili: 600,
          max_neili: 600,
          base_neili: 600
        },
        stats: %Stats{
          str: 45,
          dex: 45,
          con: 40,
          int: 30,
          combat_exp: 200_000,
          potential: 0,
          learned_points: 0,
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0,
          skills: %{"unarmed" => 120, "dodge" => 110, "parry" => 100, "force" => 80},
          mapped: %{},
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "passive",
          spawn_room_id: room_id,
          respawn_delay: 60_000,
          no_kill: false,
          apply: %{"attack" => 80, "damage" => 60, "armor" => 30}
        },
        combat: Combat.new(),
        loot: Keyword.get(opts, :loot, @reward_loot),
        goods: nil,
        inquiries: nil,
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
    }
  end

  defp start_character(character, opts) do
    config = [
      supervisor_name:
        Keyword.get(
          opts,
          :supervisor_name,
          Kalevala.World.CharacterSupervisor.global_name(character.meta.zone_id)
        ),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]

    Kalevala.World.start_character(character, config)
  end

  defp announce(text) do
    Communication.announce("general", text)
  rescue
    e -> Logger.warn("challenger announce failed - #{Exception.message(e)}")
  catch
    :exit, reason -> Logger.warn("challenger announce failed - #{inspect(reason)}")
  end

  defp killer_name(nil), do: "无名侠士"
  defp killer_name(%{name: name}), do: name
  defp killer_name(name) when is_binary(name), do: name
end