# Assign coordinates to rooms in a zone UCL file.
#
# Rooms that already carry a non-zero coordinate are left untouched but still
# used as anchors while walking the exit graph. Rooms with missing / all-zero
# coordinates are assigned coordinates derived from neighbouring anchors via
# their exit directions. Fully disconnected subgraphs are stacked above the
# origin on increasing z levels, each orphan-rooted component at (0,0,level).
#
# Usage:
#   mix run scripts/assign_room_coords.exs <zone.ucl> <start_room_id>
#
# Example:
#   mix run scripts/assign_room_coords.exs data/world/test.ucl test_guangchang
#
# The file is rewritten in place. Only x/y/z lines inside `rooms "X"` blocks
# are replaced; every other line is preserved verbatim.

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
    "westdown" => {-1, 0, -1}
  }

  # Non-geometric exit names (in/out/zone portals) do not move coordinates.
  @skip_dirs ~w(in out)

  def run(path, start_id) do
    content = File.read!(path)
    lines = String.split(content, "\n")

    {room_ids, fields, exits_map} = scan(lines)

    unless Enum.member?(room_ids, start_id) do
      IO.puts("ERROR: start room '#{start_id}' not found in #{path}")
      exit({:shutdown, 1})
    end

    assigned = assign_coords(room_ids, fields, exits_map, start_id)
    new_content = rewrite(lines, fields, assigned)
    File.write!(path, new_content)
    report(fields, assigned, start_id, path)
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

  # -> {dir, {:local, id}} | {dir, :external}
  defp parse_exit_row(line) do
    line = String.replace(line, ~r/[ \t]+\}$/, " ")

    case Regex.run(~r/^[ \t]*(\w+)[ \t]*=[ \t]*(.+?)[ \t]*$/, line) do
      [_, dir, raw] ->
        target = raw |> String.trim() |> String.replace(~r/^"|"$/, "")

        {dir,
         if Regex.match?(~r/^rooms\.[a-z0-9_]+\.[iI][dD]$/, target) do
           id = target |> String.replace(~r/^rooms\./, "") |> String.replace(~r/\.id$/, "")
           {:local, id}
         else
           :external
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
      exits_map: exits_map
    }

    state =
      state
      |> drain()
      |> orphans(room_ids)

    state.assigned
  end

  # Rooms that already had a non-zero coordinate act as anchors and are simply
  # visited (their coordinates are preserved). Rooms left with only zeros get a
  # fresh component root stacked at (0,0,layer).
  defp orphans(state, room_ids) do
    Enum.reduce(room_ids, state, fn id, st ->
      if MapSet.member?(st.visited, id) or Map.has_key?(st.assigned, id) do
        st
      else
        current = current_coord(Map.get(st.fields, id, %{}))

        st =
          if current != {0, 0, 0} do
            Map.put(st, :assigned, Map.put(st.assigned, id, current))
          else
            Map.put(st, :assigned, Map.put(st.assigned, id, {0, 0, st.layer}))
            |> Map.update!(:layer, &(&1 + 1))
          end

        st
        |> Map.update!(:visited, &MapSet.put(&1, id))
        |> Map.put(:queue, [id])
        |> drain()
      end
    end)
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
            # a zero-coordinate room reached from the start would overlay
            # the origin; leave it for the orphans pass to stack on z
            {st, q}

          current == {0, 0, 0} ->
            st = %{
              st
              | assigned: Map.put(st.assigned, tid, candidate),
                visited: MapSet.put(st.visited, tid)
            }

            {st, [tid | q]}

          true ->
            # anchor: keep existing non-zero coordinates, continue walking
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

  # ---- writing ----
  # Rebuild the file, replacing x/y/z lines inside every `rooms "id"` block.
  # The start room is always normalised to (0,0,0); other rooms get their
  # assigned coordinate only when it differs from the file content (existing
  # non-zero anchors are therefore kept verbatim).

  defp rewrite(lines, fields, assigned) do
    lines
    |> Enum.reduce({[], nil}, &rewrite_line(&1, &2, fields, assigned))
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp rewrite_line(line, {out, state}, fields, assigned) do
    cond do
      is_nil(state) ->
        case Regex.run(~r/^[ \t]*rooms "([^"]+)"[ \t]*\{/, line) do
          [_, id] -> {[line | out], {:room, id, 1, []}}
          nil -> {[line | out], nil}
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

      true ->
        {[line | out], nil}
    end
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
    AssignRoomCoords.run(path, start_id)

  _ ->
    IO.puts("usage: mix run scripts/assign_room_coords.exs <zone.ucl> <start_room_id>")
    exit({:shutdown, 1})
end
