# Assign coordinates to rooms in a zone UCL file.
#
# Rooms that already carry a non-zero coordinate are left untouched but still
# used as anchors while walking the exit graph. Rooms with missing / all-zero
# coordinates are assigned coordinates derived from neighbouring anchors via
# their exit directions. Fully disconnected subgraphs are stacked above the
# origin on increasing z levels, each orphan-rooted component at (0,0,level).
#
# Usage:
#   mix run scripts/assign_room_coords.exs <zone.ucl> <start_room_id> [--dry-run|--output <output_file>]
#
# Options:
#   --dry-run          Print the new content to stdout, don't write any file
#   --output <file>    Write new content to <output_file> instead of overwriting input
#
# Examples:
#   mix run scripts/assign_room_coords.exs data/world/test.ucl test_guangchang
#   mix run scripts/assign_room_coords.exs data/world/test.ucl test_guangchang --dry-run
#   mix run scripts/assign_room_coords.exs data/world/test.ucl test_guangchang --output /tmp/test_new.ucl

defmodule AssignRoomCoords do
  # direction -> {dx, dy, dz}; NB projected so minimap renders north-up
  @dirs %{
    "north" => {0, 1, 0},
    "south" => {0, -1, 0},
    "east" => {1, 0, 0},
    "west" => {-1, 0, 0},
    "northeast" => {1, 1, 0},
    "northwest" => {-1, 1, 0},
    "southeast" => {1, -1, 0},
    "southwest" => {-1, -1, 0},
    "northup" => {0, 1, 1},
    "southup" => {0, -1, 1},
    "eastup" => {1, 0, 1},
    "westup" => {-1, 0, 1},
    "up" => {0, 0, 1},
    "down" => {0, 0, -1},
    "northdown" => {0, 1, -1},
    "southdown" => {0, -1, -1},
    "eastdown" => {1, 0, -1},
    "westdown" => {-1, 0, -1},
    # Portal-like exits that don't change spatial coordinates
    "enter" => {0, 0, 0},
    "out" => {0, 0, 0},
    "in" => {0, 0, 0},
    "go_in" => {0, 0, 0},
    # climb acts like up
    "climb" => {0, 0, 1}
  }

  # Non-geometric exit names that should be skipped for coordinate purposes
  # (but they're still traversed for graph connectivity)
  @skip_dirs ~w()

  def run(args) do
    {opts, [path, start_id], _} = OptionParser.parse(args, switches: [dry_run: :boolean, output: :string], strict: false)

    content = File.read!(path)
    lines = String.split(content, "\n")

    {room_ids, fields, exits_map} = scan(lines)

    unless Enum.member?(room_ids, start_id) do
      IO.puts("ERROR: start room '#{start_id}' not found in #{path}")
      exit({:shutdown, 1})
    end

    {assigned, final_exits_map} = assign_coords(room_ids, fields, exits_map, start_id)
    room_set = MapSet.new(room_ids)
    new_content = rewrite(lines, fields, assigned, final_exits_map, room_set)
    |> add_missing_exit_blocks(final_exits_map)
    report(fields, assigned, start_id, path)

    cond do
      Keyword.get(opts, :dry_run) ->
        IO.puts(new_content)

      output = Keyword.get(opts, :output) ->
        File.write!(output, new_content)
        IO.puts("Written to #{output}")

      true ->
        File.write!(path, new_content)
    end
  end

  # ---- scanning ----
  # Returns {ordered_room_ids, %{room_id => %{x,y,z}}, %{room_id => [{dir,target}]}}
  #
  # `rooms "X"` and `room_exits "X"` blocks are delimited by brace depth;
  # braces inside double-quoted strings are ignored. Works for both 4-space
  # (test.ucl) and top-level (liuxi.ucl) styles.

  defp scan(lines) do
    {room_ids, fields, exits_map, _state} = Enum.reduce(lines, {[], %{}, %{}, nil}, &scan_line/2)

    {Enum.reverse(room_ids), fields, exits_map}
  end

  defp scan_line(line, {room_ids, fields, exits, state}) do
    cond do
      is_nil(state) ->
        scan_start(line, room_ids, fields, exits)

      match?({:room, _, _, _}, state) ->
        in_room(line, state, room_ids, fields, exits)

      match?({:exits, _, _, _}, state) ->
        in_exits(line, state, room_ids, fields, exits)

      true ->
        {room_ids, fields, exits, nil}
    end
  end

  defp scan_start(line, room_ids, fields, exits) do
    cond do
      m = Regex.run(~r/^[ \t]*rooms "([^"]+)"[ \t]*\{/, line) ->
        {room_ids, fields, exits, {:room, Enum.at(m, 1), 1, []}}

      m = Regex.run(~r/^[ \t]*room_exits "([^"]+)"[ \t]*\{/, line) ->
        {room_ids, fields, exits, {:exits, Enum.at(m, 1), 1, []}}

      true ->
        {room_ids, fields, exits, nil}
    end
  end

  defp in_room(line, state, room_ids, fields, exits) do
    {:room, rid, depth, acc} = state
    {open, close} = brace_counts(line)
    depth2 = depth + open - close

    if depth2 == 0 do
      fields = Map.put(fields, rid, parse_fields(acc))
      {[rid | room_ids], fields, exits, nil}
    else
      {room_ids, fields, exits, {:room, rid, depth2, [line | acc]}}
    end
  end

  defp in_exits(line, state, room_ids, fields, exits) do
    {:exits, eid, edepth, eacc} = state
    {open, close} = brace_counts(line)
    depth2 = edepth + open - close

    eacc2 =
      case parse_exit_row(line) do
        nil -> eacc
        row -> [row | eacc]
      end

    if depth2 == 0 do
      exits = Map.put(exits, eid, Enum.reverse(eacc2))
      {room_ids, fields, exits, nil}
    else
      {room_ids, fields, exits, {:exits, eid, depth2, eacc2}}
    end
  end

  # Count { and } in a line, ignoring braces inside "..."
  defp brace_counts(line) do
    {o, c, _q} =
      line
      |> String.to_charlist()
      |> Enum.reduce({0, 0, false}, fn
        ?", {o, c, q} -> {o, c, not q}
        ?{, {o, c, false} -> {o + 1, c, false}
        ?}, {o, c, false} -> {o, c + 1, false}
        _, acc -> acc
      end)

    {o, c}
  end

  defp parse_fields(acc) do
    # acc is newest-first; order does not matter for field extraction
    Enum.reduce(acc, %{}, fn line, map ->
      cond do
        m = Regex.run(~r/^[ \t]*x[ \t]*=[ \t]*(-?\d+)/, line) ->
          Map.put(map, :x, String.to_integer(Enum.at(m, 1)))

        m = Regex.run(~r/^[ \t]*y[ \t]*=[ \t]*(-?\d+)/, line) ->
          Map.put(map, :y, String.to_integer(Enum.at(m, 1)))

        m = Regex.run(~r/^[ \t]*z[ \t]*=[ \t]*(-?\d+)/, line) ->
          Map.put(map, :z, String.to_integer(Enum.at(m, 1)))

        true ->
          map
      end
    end)
  end

  # -> {dir, {:local, id}} | {dir, {:external, target_string}}
  defp parse_exit_row(line) do
    line = String.replace(line, ~r/[ \t]+\}$/, " ")

    case Regex.run(~r/^[ \t]*(\w+)[ \t]*=[ \t]*(.+?)[ \t]*$/, line) do
      [_, "room_id", _] ->
        # room_id = rooms.xxx.id is metadata, not an exit
        nil

      [_, dir, raw] ->
        target = raw |> String.trim() |> String.replace(~r/^"|"$/, "")

        {dir,
         if Regex.match?(~r/^rooms\.[a-z0-9_]+\.[iI][dD]$/, target) do
           id = target |> String.replace(~r/^rooms\./, "") |> String.replace(~r/\.id$/, "")
           {:local, id}
         else
           {:external, target}
         end}

      nil ->
        nil
    end
  end

  # ---- coordinate assignment ----

  defp assign_coords(room_ids, fields, exits_map, start_id) do
    state = %{
      assigned: %{start_id => {0, 0, 0}},
      visited: MapSet.new([start_id]),
      layer: 1,
      queue: [start_id],
      fields: fields,
      exits_map: exits_map,
      layer_anchors: %{0 => start_id},  # z level -> room_id at that level
      new_exits: %{}  # room_id -> [{dir, target_room_id}] to add
    }

    state =
      state
      |> drain()
      |> orphans(room_ids)

    # Merge new_exits into exits_map for writing
    final_exits_map = merge_new_exits(state.exits_map, state.new_exits)

    {state.assigned, final_exits_map}
  end

  # Rooms that already had a non-zero coordinate act as anchors and are simply
  # visited (their coordinates are preserved). Rooms left with only zeros get a
  # fresh component root stacked at (0,0,layer).
  # When a new layer is created, connect it vertically to the previous layer's anchor.
    defp orphans(state, room_ids) do
    Enum.reduce(room_ids, state, &process_orphan_room/2)
  end

defp process_orphan_room(id, st) do
    if MapSet.member?(st.visited, id) or Map.has_key?(st.assigned, id) do
      st
    else
      current = current_coord(Map.get(st.fields, id, {}))

      st =
        if current != {0, 0, 0} do
          Map.put(st, :assigned, Map.put(st.assigned, id, current))
        else
          # New orphan at new z layer
          new_z = st.layer
          prev_anchor = Map.get(st.layer_anchors, new_z - 1)

          st =
            Map.put(st, :assigned, Map.put(st.assigned, id, {0, 0, new_z}))
            |> Map.update!(:layer, &(&1 + 1))
            |> Map.put(:layer_anchors, Map.put(st.layer_anchors, new_z, id))

          # Add vertical connection: up from topmost of previous anchor's up-chain, down from this orphan
          if prev_anchor do
            topmost = find_topmost_via_up(prev_anchor, st.exits_map, st.new_exits)
            add_vertical_exits(st, topmost, id)
          else
            st
          end
        end

      st
      |> Map.update!(:visited, &MapSet.put(&1, id))
      |> Map.put(:queue, [id])
      |> drain()
    end
  end
  defp add_vertical_exits(state, from_id, to_id) do
    # Find the topmost room by following "up" exits from the previous anchor
    topmost = find_topmost_via_up(from_id, state.exits_map, state.new_exits)

    # Find the bottommost room by following "down" exits from the new orphan
    bottommost = find_bottommost_via_down(to_id, state.exits_map, state.new_exits)

    # Add up exit from topmost to new orphan
    new_exits_from = Map.get(state.new_exits, topmost, []) ++ [{"up", {:local, to_id}}]
    # Add down exit from bottommost to topmost
    new_exits_to = Map.get(state.new_exits, bottommost, []) ++ [{"down", {:local, topmost}}]

    %{state
      | new_exits: state.new_exits
              |> Map.put(topmost, new_exits_from)
              |> Map.put(bottommost, new_exits_to)}
  end

  # Find the topmost room by following "up" exits from the given room
  # Returns the room_id at the top of the up-chain
  defp find_topmost_via_up(start_id, exits_map, new_exits) do
    find_topmost_via_up(start_id, exits_map, new_exits, MapSet.new([start_id]))
  end

  defp find_topmost_via_up(current, exits_map, new_exits, visited) do
    # Check both original exits_map and new_exits for "up" exits
    exits = Map.get(exits_map, current, []) ++ Map.get(new_exits, current, [])

    up_exit = Enum.find(exits, fn {dir, _} -> dir == "up" end)

    case up_exit do
      {"up", {:local, next_id}} ->
        if MapSet.member?(visited, next_id) or not real_room?(next_id, exits_map, new_exits) do
          current
        else
          find_topmost_via_up(next_id, exits_map, new_exits, MapSet.put(visited, next_id))
        end

      _ ->
        current
    end
  end

  # Find the bottommost room by following "down" exits from the given room
  # Returns the room_id at the bottom of the down-chain
  defp find_bottommost_via_down(start_id, exits_map, new_exits) do
    find_bottommost_via_down(start_id, exits_map, new_exits, MapSet.new([start_id]))
  end

  defp find_bottommost_via_down(current, exits_map, new_exits, visited) do
    # Check both original exits_map and new_exits for "down" exits
    exits = Map.get(exits_map, current, []) ++ Map.get(new_exits, current, [])

    down_exit = Enum.find(exits, fn {dir, _} -> dir == "down" end)

    case down_exit do
      {"down", {:local, next_id}} ->
        if MapSet.member?(visited, next_id) or not real_room?(next_id, exits_map, new_exits) do
          current
        else
          find_bottommost_via_down(next_id, exits_map, new_exits, MapSet.put(visited, next_id))
        end

      _ ->
        current
    end
  end

  # A "real" room is one that either has an exit block in this zone (exits_map)
  # or already received a new exit entry (new_exits). Phantom targets referenced
  # by test data (room_above, room_below...) are not followed.
  defp real_room?(id, exits_map, new_exits) do
    Map.has_key?(exits_map, id) or Map.has_key?(new_exits, id)
  end

  defp drain(state) do
    case state.queue do
      [] ->
        state

      [id | rest] ->
        {cx, cy, cz} = Map.fetch!(state.assigned, id)
        exits = Map.get(state.exits_map, id, [])

        {state, new_queue} =
          Enum.reduce(exits, {state, []}, fn {dir, target}, {st, q} ->
            visit_neighbour({cx, cy, cz}, dir, target, st, q)
          end)

        %{state | queue: rest ++ Enum.reverse(new_queue)}
        |> drain()
    end
  end

  defp visit_neighbour(from, dir, target, st, q) do
    if dir in @skip_dirs or not Map.has_key?(@dirs, dir) or target == :external do
      {st, q}
    else
      {_, tid} = target

      if not Map.has_key?(st.fields, tid) or MapSet.member?(st.visited, tid) do
        {st, q}
      else
        {tdx, tdy, tdz} = Map.fetch!(@dirs, dir)
        {cx, cy, cz} = from
        candidate = {cx + tdx, cy + tdy, cz + tdz}
        current = current_coord(Map.get(st.fields, tid, %{}))

        cond do
          candidate == {0, 0, 0} ->
            {st, q}

          current == {0, 0, 0} ->
            st = %{
              st
              | assigned: Map.put(st.assigned, tid, candidate),
                visited: MapSet.put(st.visited, tid)
            }

            {st, [tid | q]}

          true ->
            st = %{
              st
              | assigned: Map.put(st.assigned, tid, current),
                visited: MapSet.put(st.visited, tid)
            }

            {st, [tid | q]}
        end
      end
    end
  end

  defp current_coord(%{x: x, y: y, z: z}), do: {x, y, z}
  defp current_coord(_), do: {0, 0, 0}

  # Merge new_exits into the original exits_map
  defp merge_new_exits(exits_map, new_exits) do
    Enum.reduce(new_exits, exits_map, fn {room_id, new_exit_list}, acc ->
      existing = Map.get(acc, room_id, [])
      # Avoid duplicates: only add if not already present
      merged =
        Enum.reduce(new_exit_list, existing, fn {dir, target}, existing_list ->
          if Enum.any?(existing_list, fn {d, t} -> d == dir && t == target end) do
            existing_list
          else
            [{dir, target} | existing_list]
          end
        end)
      Map.put(acc, room_id, Enum.reverse(merged))
    end)
  end

  defp current_coord(%{x: x, y: y, z: z}), do: {x, y, z}
  defp current_coord(_), do: {0, 0, 0}

  # ---- writing ----
  # Rebuild the file, replacing x/y/z lines inside every `rooms "id"` block,
  # and updating `room_exits "id"` blocks with new exits.

  defp rewrite(lines, fields, assigned, exits_map, room_set) do
    lines
    |> Enum.reduce({[], nil}, &rewrite_line(&1, &2, fields, assigned, exits_map, room_set))
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp rewrite_line(line, {out, state}, fields, assigned, exits_map, room_set) do
    cond do
      is_nil(state) ->
        case Regex.run(~r/^[ \t]*rooms "([^"]+)"[ \t]*\{/, line) do
          [_, id] -> {[line | out], {:room, id, 1, []}}
          nil ->
            case Regex.run(~r/^[ \t]*room_exits "([^"]+)"[ \t]*\{/, line) do
              [_, id] -> {[line | out], {:exits, id, 1, []}}
              nil -> {[line | out], nil}
            end
        end

      match?({:room, _, _, _}, state) ->
        {:room, id, depth, acc} = state
        {open, close} = brace_counts(line)
        depth2 = depth + open - close

        if depth2 == 0 do
          # closing brace line of the room block
          block = Enum.reverse([line | acc])
          new_block = build_block(block, fields, assigned, id)
          {Enum.reverse(new_block) ++ out, nil}
        else
          {out, {:room, id, depth2, [line | acc]}}
        end

      match?({:exits, _, _, _}, state) ->
        {:exits, eid, edepth, eacc} = state
        {open, close} = brace_counts(line)
        depth2 = edepth + open - close

        if depth2 == 0 do
          # closing brace line of the exits block
          block = Enum.reverse([line | eacc])
          new_block = build_exits_block(block, eid, exits_map, room_set)
          {Enum.reverse(new_block) ++ out, nil}
        else
          {out, {:exits, eid, depth2, [line | eacc]}}
        end

      true ->
        {[line | out], nil}
    end
  end

  # Generate a `room_exits` block for rooms that have exits in the final map but
  # no `room_exits` block in the source file (their new vertical exits would
  # otherwise be silently lost). The block is placed right after the room's
  # own `rooms "id"` block.
  defp add_missing_exit_blocks(content, exits_map) do
    lines = String.split(content, "\n")

    block_ids =
      Enum.reduce(lines, MapSet.new(), fn line, acc ->
        case Regex.run(~r/^[ \t]*room_exits "([^"]+)"[ \t]*\{/, line) do
          [_, id] -> MapSet.put(acc, id)
          _ -> acc
        end
      end)

    missing =
      exits_map
      |> Enum.filter(fn {id, exits} ->
        exits != [] and not MapSet.member?(block_ids, id)
      end)
      |> Map.new()

    if map_size(missing) == 0 do
      content
    else
      {out, _state} =
        Enum.reduce(lines, {[], nil}, fn line, {out, state} ->
          cond do
            is_nil(state) ->
              case Regex.run(~r/^[ \t]*rooms "([^"]+)"[ \t]*\{/, line) do
                [_, id] -> {[line | out], {id, 1}}
                _ -> {[line | out], nil}
              end

            match?({_, depth} when is_integer(depth), state) ->
              {id, depth} = state
              {open, close} = brace_counts(line)
              depth2 = depth + open - close

              if depth2 <= 0 do
                block_lines =
                  if Map.has_key?(missing, id),
                    do: build_new_exits_block(id, Map.fetch!(missing, id)),
                    else: []

                {Enum.reverse(block_lines) ++ [line | out], nil}
              else
                {[line | out], {id, depth2}}
              end

            true ->
              {[line | out], nil}
          end
        end)

      Enum.reverse(out) |> Enum.join("\n")
    end
  end

  defp build_new_exits_block(id, exits) do
    header = "  room_exits \"#{id}\" {"
    room_id_line = "    room_id = rooms.#{id}.id"

    exit_lines =
      Enum.map(exits, fn
        {dir, {:local, target}} -> "    #{dir} = rooms.#{target}.id"
        {dir, {:external, target}} -> "    #{dir} = #{target}"
      end)

    [header, room_id_line] ++ exit_lines ++ ["    }"]
  end

  defp build_block(content, fields, assigned, id) do
    coord = Map.get(assigned, id)
    current = current_coord(Map.get(fields, id, %{}))

    cond do
      coord == nil ->
        content

      coord == current ->
        content

      true ->
        replace_or_insert(content, coord)
    end
  end

  # Replace the x/y/z lines with the assigned values; if a coordinate line is
  # absent from the block, insert the missing ones at the top of the block.
  defp replace_or_insert(content, {x, y, z}) do
    replaced =
      Enum.map(content, fn line ->
        cond do
          m = Regex.run(~r/^([ \t]*)x[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "x = #{x}"

          m = Regex.run(~r/^([ \t]*)y[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "y = #{y}"

          m = Regex.run(~r/^([ \t]*)z[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "z = #{z}"

          true ->
            line
        end
      end)

    missing =
      for {k, v} <- [{:x, x}, {:y, y}, {:z, z}], not exists?(replaced, k) do
        "#{k} = #{v}"
      end

    indent =
      case Enum.find(content, fn l -> Regex.match?(~r/^[ \t]*\S/, l) end) do
        nil -> "  "
        l -> Regex.run(~r/^([ \t]*)\S/, l) |> Enum.at(1)
      end

    inserted = Enum.map(missing, &(indent <> &1))
    inserted ++ replaced
  end

  defp exists?(replaced, k) do
    Enum.any?(replaced, &String.match?(&1, ~r/^[ \t]*#{k}[ \t]*=/))
  end

  # Build/update room_exits block with new exits
  defp build_exits_block(content, eid, exits_map, room_set) do
    new_exits = Map.get(exits_map, eid)
    if new_exits == nil do
      content
    else
      # Parse existing exits from content
      existing =
        Enum.reduce(content, [], fn line, acc ->
          case parse_exit_row(line) do
            nil -> acc
            row -> [row | acc]
          end
        end)
        |> Enum.reverse()

      # Merge new exits, avoiding duplicates
      merged =
        Enum.reduce(existing, new_exits, fn {dir, target}, acc ->
          if Enum.any?(acc, fn {d, t} -> d == dir && t == target end) do
            acc
          else
            [{dir, target} | acc]
          end
        end)
        |> Enum.reverse()

      # Rebuild block: keep non-exit lines (like room_id = ...) and replace exit lines
      indent =
        case Enum.find(content, fn l -> Regex.match?(~r/^[ \t]*\S/, l) end) do
          nil -> "  "
          l -> Regex.run(~r/^([ \t]*)\S/, l) |> Enum.at(1)
        end

      # Keep non-exit lines (room_id = ...) and add merged exits
      non_exit_lines =
        Enum.filter(content, fn line ->
          parse_exit_row(line) == nil
        end)

      # An up/down exit whose target is a room not present in this zone is a
      # phantom reference (test data like room_above/room_below). When the new
      # z-axis link replaces it with a real room, comment the phantom out.
      exit_lines =
        Enum.map(merged, fn {dir, target} = row ->
          comment = phantom_updown?(row, merged, room_set)
          render_exit_row(dir, target, indent, comment)
        end)

      # Add closing brace
      closing_brace = Enum.find(content, fn line -> String.match?(line, ~r/^[ \t]*\}[ \t]*$/) end) || indent <> "}"

      non_exit_lines ++ exit_lines ++ [closing_brace]
    end
  end

  defp render_exit_row(dir, {:local, target}, indent, comment) do
    prefix = if comment, do: indent <> "# ", else: indent
    prefix <> dir <> " = rooms." <> target <> ".id"
  end

  defp render_exit_row(dir, {:external, target}, indent, _comment) do
    indent <> dir <> " = " <> target
  end

  # True when {dir,target} is a phantom up/down (points to a room not in this
  # zone) AND a real replacement exists for the same direction in merged.
  defp phantom_updown?({dir, {:local, target_id}}, merged, room_set) do
    if dir in ["up", "down"] and not MapSet.member?(room_set, target_id) do
      has_real_replacement =
        Enum.any?(merged, fn {d, {:local, tid}} ->
          d == dir and tid != target_id and MapSet.member?(room_set, tid)
        end)

      has_real_replacement
    else
      false
    end
  end

  defp phantom_updown?(_other, _merged, _room_set), do: false

  # Replace the x/y/z lines with the assigned values; if a coordinate line is
  # absent from the block, insert the missing ones at the top of the block.
  defp replace_or_insert(content, {x, y, z}) do
    replaced =
      Enum.map(content, fn line ->
        cond do
          m = Regex.run(~r/^([ \t]*)x[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "x = #{x}"

          m = Regex.run(~r/^([ \t]*)y[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "y = #{y}"

          m = Regex.run(~r/^([ \t]*)z[ \t]*=[ \t]*-?\d+/, line) ->
            Enum.at(m, 1) <> "z = #{z}"

          true ->
            line
        end
      end)

    missing =
      for {k, v} <- [{:x, x}, {:y, y}, {:z, z}], not exists?(replaced, k) do
        "#{k} = #{v}"
      end

    indent =
      case Enum.find(content, fn l -> Regex.match?(~r/^[ \t]*\S/, l) end) do
        nil -> "  "
        l -> Regex.run(~r/^([ \t]*)\S/, l) |> Enum.at(1)
      end

    inserted = Enum.map(missing, &(indent <> &1))
    inserted ++ replaced
  end

  defp exists?(replaced, k) do
    Enum.any?(replaced, &String.match?(&1, ~r/^[ \t]*#{k}[ \t]*=/))
  end

  # ---- report ----

  defp report(fields, assigned, start_id, path) do
    ids = Map.keys(fields)
    IO.puts("zone: #{Path.basename(path)}  rooms: #{length(ids)}")

    {anchors, new_coords} =
      Enum.reduce(ids, {0, 0}, fn id, {a, n} ->
        current = current_coord(Map.get(fields, id, %{}))
        assigned_coord = Map.get(assigned, id)

        cond do
          current != {0, 0, 0} and assigned_coord in [nil, current] -> {a + 1, n}
          current == {0, 0, 0} and assigned_coord not in [nil, {0, 0, 0}] -> {a, n + 1}
          id != start_id and assigned_coord == current -> {a, n}
          true -> {a, n}
        end
      end)

    IO.puts("anchor rooms (kept non-zero): #{anchors}")
    IO.puts("rooms assigned new coords:    #{new_coords}")
    IO.puts("start room: #{start_id} -> (0,0,0)")
  end
end

case System.argv() do
  [path, start_id] ->
    AssignRoomCoords.run([path, start_id])

  [path, start_id | rest] ->
    AssignRoomCoords.run([path, start_id | rest])

  _ ->
    IO.puts("usage: mix run scripts/assign_room_coords.exs <zone.ucl> <start_room_id> [--dry-run|--output <output_file>]")
    IO.puts("  --dry-run          Print new content to stdout")
    IO.puts("  --output <file>    Write to output file instead of overwriting input")
    exit({:shutdown, 1})
end