defmodule Mix.Tasks.CheckRouteBranching do
  @moduledoc """
  Previews the `GTFSRouteBranching` logic, rendering diagrams for all non-trivial routes.

  Filter to a handful of routes and directions with `mix check_route_branching 33 Boat-F1:1 350:0`.

  Use `--save-graphs` to also save the stop and segment graphs as Graphviz .dot files.

  Use `--render-graphs` to render the stop and segment graphs with Graphviz.
  """

  use Mix.Task
  @shortdoc "Checks route branching"
  @requirements ["app.start"]

  require Logger
  alias GTFSRouteBranching.Segment
  alias GTFSRouteBranching.Segment.StickConnection
  alias GTFSRouteBranching.SegmentGraph
  alias GTFSRouteBranching.StopGraph

  @impl Mix.Task
  def run(args) do
    {opts, args} =
      OptionParser.parse!(args, strict: [save_graphs: :boolean, render_graphs: :boolean])

    save_graphs? = Keyword.get(opts, :save_graphs, false)

    render_graphs? =
      if Keyword.get(opts, :render_graphs, false) do
        if :os.find_executable(~c"dot") == false do
          Logger.warning("Graphviz not available, cannot render graphs")
          false
        else
          true
        end
      else
        false
      end

    system_data = fetch_system_data()
    {%{routes: routes}, system_data} = Map.split(system_data, [:routes])

    routes_directions =
      routes |> Map.keys() |> Enum.sort() |> Enum.flat_map(&[{&1, 0}, {&1, 1}])

    routes_directions =
      if args != [] do
        Enum.filter(routes_directions, fn {route_id, direction_id} ->
          route_id in args or "#{route_id}:#{direction_id}" in args
        end)
      else
        Enum.reject(routes_directions, fn {route_id, _} ->
          String.starts_with?(route_id, "Shuttle")
        end)
      end

    serious_issue =
      routes_directions
      |> Enum.map(fn {route_id, direction} ->
        route = routes[route_id]
        run_single_case(route, direction, system_data, save_graphs?, render_graphs?)
      end)
      |> tap(&IO.puts("Checked route branching across #{length(&1)} routes and directions"))
      |> then(&(:error in &1))

    if serious_issue do
      System.stop(1)
    end
  end

  defp run_single_case(route, direction, system_data, save_graphs?, render_graphs?) do
    caption =
      "#{route_label(route)} (#{route.id}) #{Enum.at(route.direction_names, direction)} (#{direction}) to #{Enum.at(route.direction_destinations, direction)}"

    %{data: stops} =
      fetch_api(
        url: "/stops",
        params: ["filter[route]": route.id, "filter[direction_id]": direction, "fields[stop]": ""]
      )

    stop_ids = stops |> Enum.map(fn stop -> stop.id end)

    {us, {stop_graph, segment_graph, segments}} =
      :timer.tc(fn ->
        GTFSRouteBranching.calculate(
          route,
          direction,
          stop_ids,
          system_data
        )
      end)

    if us > 5_000 do
      Logger.warning("#{caption} took #{us / 1000.0}ms")
    end

    output_path = Path.join(["route-branching", route.id, "#{direction}"])
    File.mkdir_p!(output_path)

    stop_graph
    |> render_dot(
      Path.join(output_path, "stopGraph.png"),
      &visualize_stop_graph_node/2,
      save_graphs?,
      render_graphs?
    )

    segment_names = GTFSRouteBranching.get_name_candidates(route, direction)

    if is_nil(segment_graph) do
      Logger.error("segment_graph nil")
    else
      segment_graph
      |> render_dot(
        Path.join(output_path, "segmentGraph.png"),
        &visualize_segment_graph_node(&1, &2, segment_names),
        save_graphs?,
        render_graphs?
      )
    end

    if is_nil(segments) do
      Logger.error("segments nil")
    else
      output_path
      |> Path.join("out.txt")
      |> File.write!([caption, "\n", visualize_segments(segments, system_data), "\n"])
    end

    if is_nil(segment_graph) or is_nil(segments) do
      :error
    else
      :ok
    end
  end

  defp fetch_system_data do
    %{data: stop_list} =
      fetch_api(url: "/stops", params: ["filter[location_type]": "0,1", "fields[stop]": "name"])

    %{data: route_pattern_list, included: %{route: route_list, trip: trip_list}} =
      fetch_api(
        url: "/route_patterns",
        params: [
          include: "route,representative_trip.stops",
          "fields[route]": "direction_names,direction_destinations,short_name,long_name,type",
          "fields[route_pattern]": "direction_id,typicality",
          "fields[stop]": "",
          "fields[trip]": ""
        ]
      )

    %{
      routes: Map.new(route_list, &{&1.id, &1}),
      route_patterns: Map.new(route_pattern_list, &{&1.id, &1}),
      representative_trips: Map.new(trip_list, &{&1.id, &1}),
      stops: Map.new(stop_list, &{&1.id, &1})
    }
  end

  defp fetch_api(opts) do
    response =
      Req.get!(
        [
          base_url: System.fetch_env!("API_URL"),
          headers: [
            {"accept", "application/vnd.api+json"},
            {"x-api-key", System.fetch_env!("API_KEY")}
          ]
        ],
        opts
      )

    data =
      case response.body["data"] do
        data when is_list(data) -> Enum.map(data, &parse_api_object/1)
        data -> parse_api_object(data)
      end

    included =
      response.body["included"]
      |> List.wrap()
      |> Enum.map(&parse_api_object/1)
      |> Enum.group_by(& &1.obj_type)

    %{data: data, included: included}
  end

  defp parse_api_object(obj) do
    type = String.to_atom(obj["type"])
    id = obj["id"]
    attributes = obj["attributes"]
    relationships = obj["relationships"]

    result = %{obj_type: type, id: id}

    result =
      Enum.reduce(attributes, result, fn {k, v}, result ->
        {k, v} = parse_attribute(type, k, v)
        Map.put(result, k, v)
      end)

    result =
      Enum.reduce(relationships, result, fn {rel, obj}, result ->
        data =
          case obj do
            %{"data" => data} -> data
            _ -> nil
          end

        {k, v} = parse_relationship(type, rel, data)
        Map.put(result, k, v)
      end)

    result
  end

  defp parse_attribute(type, key, value)

  defp parse_attribute(:route, "type", value) do
    {:type,
     case value do
       0 -> :light_rail
       1 -> :heavy_rail
       2 -> :commuter_rail
       3 -> :bus
       4 -> :ferry
     end}
  end

  defp parse_attribute(:route_pattern, "typicality", value) do
    {:typicality,
     case value do
       1 -> :typical
       2 -> :deviation
       3 -> :atypical
       4 -> :diversion
       5 -> :canonical_only
     end}
  end

  defp parse_attribute(_type, key, value) do
    {String.to_atom(key), value}
  end

  defp parse_relationship(type, rel, data)

  defp parse_relationship(_type, rel, data) when is_list(data) do
    value = Enum.map(data, & &1["id"])
    rel = String.replace_suffix(rel, "s", "_ids")
    {String.to_atom(rel), value}
  end

  defp parse_relationship(_type, rel, data) do
    value =
      case data do
        %{"id" => id} -> id
        nil -> nil
      end

    {String.to_atom(rel <> "_id"), value}
  end

  defp route_label(route)
  defp route_label(%{type: :bus, short_name: short_name}), do: short_name

  defp route_label(%{type: :commuter_rail, long_name: long_name}) do
    String.replace(long_name, "/", " / ")
  end

  defp route_label(%{long_name: long_name}), do: long_name

  defp visualize_stop_graph_node({stop_id, stop_count}, %StopGraph.Node{
         stop: stop,
         typicalities: typicalities
       }) do
    "#{stop.name} (#{stop_id}) ##{stop_count} [#{best_typicality(typicalities)}]"
  end

  defp visualize_segment_graph_node(
         id,
         %SegmentGraph.Node{stops: stops, typicalities: typicalities},
         segment_name_candidates
       ) do
    names = Enum.map(stops, & &1.name)

    stop_names =
      if Enum.sum_by(names, &String.length/1) > 50 and length(names) > 2 do
        [List.first(names), "...#{length(names) - 2} stops...", List.last(names)]
      else
        names
      end
      |> Enum.join(", ")

    if name = Segment.get_segment_name(stops, segment_name_candidates) do
      "#{name} branch (#{stop_names})"
    else
      stop_names
    end <> " (#{elem(id, 0)} ##{elem(id, 1)}) [#{best_typicality(typicalities)}]"
  end

  defp visualize_segments(segments, system_data) do
    Enum.flat_map(segments, fn segment ->
      non_typical =
        if segment.typical? do
          " "
        else
          "®"
        end

      for stop <- segment.stops do
        left = lane_box(stop, :left)
        center = lane_box(stop, :center)
        right = lane_box(stop, :right)

        stop = system_data.stops[stop.stop_id]
        "#{non_typical} #{left}#{center}#{right} #{stop.name}"
      end
    end)
    |> Enum.join("\n")
  end

  defp best_typicality(typicalities) do
    [:typical, :deviation, :atypical, :diversion, :canonical_only]
    |> Enum.find(&MapSet.member?(typicalities, &1))
  end

  defp render_dot(_, _, _, false, false), do: :ok

  defp render_dot(graph, path, process_vertex_label, save_graphs?, render_graphs?) do
    nodes_dot =
      graph
      |> :digraph.vertices()
      |> Enum.sort()
      |> Enum.map_join(fn id ->
        {_, label} = :digraph.vertex(graph, id)
        "#{dot_vertex_id(id)} [label=\"#{process_vertex_label.(id, label)}\"];\n"
      end)

    edges_dot =
      graph
      |> :digraph.edges()
      |> Enum.sort()
      |> Enum.map_join(fn {from, to} ->
        "#{dot_vertex_id(from)} -> #{dot_vertex_id(to)};\n"
      end)

    dot_source = "digraph G {\n" <> nodes_dot <> edges_dot <> "}\n"
    dot_path = Path.rootname(path) <> ".dot"
    File.write!(dot_path, dot_source)

    if render_graphs? do
      Mix.Shell.cmd(
        {"dot", ["-T#{Path.extname(path) |> String.trim_leading(".")}", "-o#{path}", dot_path]},
        fn exit_status ->
          IO.puts(exit_status)
        end
      )
    end

    if not save_graphs? do
      File.rm!(dot_path)
    end
  end

  defp dot_vertex_id({stop_id, stop_count}) do
    Regex.replace(~r"\W", "s#{stop_id}-c#{stop_count}", "_")
  end

  defp lane_box(stop, lane) do
    left = lane_side(stop, lane, :left)

    right = lane_side(stop, lane, :right)

    up =
      Enum.any?(
        stop.connections,
        &(&1.from_lane == lane and &1.from_vpos == :top)
      )
      |> if(do: :light)

    down =
      Enum.any?(
        stop.connections,
        &(&1.to_lane == lane and &1.to_vpos == :bottom)
      )
      |> if(do: :light)

    box_drawing(left, right, up, down)
  end

  defp lane_side(stop, lane, side) do
    cond do
      stop.stop_lane == lane -> :heavy
      lane_side_cross(lane, side, stop.connections) -> :light
      true -> nil
    end
  end

  defp lane_side_cross(lane, side, connections) do
    Enum.any?(connections, fn %StickConnection{from_lane: from_lane, to_lane: to_lane} ->
      from_side? = lane_relative_side(lane, from_lane) == side
      to_side? = lane_relative_side(lane, to_lane) == side
      from_side? != to_side?
    end)
  end

  defp lane_relative_side(:left, :left), do: :center
  defp lane_relative_side(:left, :center), do: :right
  defp lane_relative_side(:left, :right), do: :right
  defp lane_relative_side(:center, :left), do: :left
  defp lane_relative_side(:center, :center), do: :center
  defp lane_relative_side(:center, :right), do: :right
  defp lane_relative_side(:right, :left), do: :left
  defp lane_relative_side(:right, :center), do: :left
  defp lane_relative_side(:right, :right), do: :center

  defp box_drawing(left, right, up, down)
  defp box_drawing(nil, nil, nil, nil), do: " "
  defp box_drawing(nil, nil, nil, :light), do: "╷"
  defp box_drawing(nil, nil, :light, nil), do: "╵"
  defp box_drawing(nil, nil, :light, :light), do: "│"
  defp box_drawing(nil, :light, nil, nil), do: "╶"
  defp box_drawing(nil, :light, nil, :light), do: "┌"
  defp box_drawing(nil, :light, :light, nil), do: "└"
  defp box_drawing(nil, :light, :light, :light), do: "├"
  defp box_drawing(nil, :heavy, nil, nil), do: "╺"
  defp box_drawing(nil, :heavy, nil, :light), do: "┍"
  defp box_drawing(nil, :heavy, :light, nil), do: "┕"
  defp box_drawing(nil, :heavy, :light, :light), do: "┝"
  defp box_drawing(:light, nil, nil, nil), do: "╴"
  defp box_drawing(:light, nil, nil, :light), do: "┐"
  defp box_drawing(:light, nil, :light, nil), do: "┘"
  defp box_drawing(:light, nil, :light, :light), do: "┤"
  defp box_drawing(:light, :light, nil, nil), do: "─"
  defp box_drawing(:light, :light, nil, :light), do: "┬"
  defp box_drawing(:light, :light, :light, nil), do: "┴"
  defp box_drawing(:light, :light, :light, :light), do: "┼"
  defp box_drawing(:light, :heavy, nil, nil), do: "╼"
  defp box_drawing(:light, :heavy, nil, :light), do: "┮"
  defp box_drawing(:light, :heavy, :light, nil), do: "┶"
  defp box_drawing(:light, :heavy, :light, :light), do: "┾"
  defp box_drawing(:heavy, nil, nil, nil), do: "╸"
  defp box_drawing(:heavy, nil, nil, :light), do: "┑"
  defp box_drawing(:heavy, nil, :light, nil), do: "┙"
  defp box_drawing(:heavy, nil, :light, :light), do: "┥"
  defp box_drawing(:heavy, :light, nil, nil), do: "╾"
  defp box_drawing(:heavy, :light, nil, :light), do: "┭"
  defp box_drawing(:heavy, :light, :light, nil), do: "┵"
  defp box_drawing(:heavy, :light, :light, :light), do: "┽"
  defp box_drawing(:heavy, :heavy, nil, nil), do: "━"
  defp box_drawing(:heavy, :heavy, nil, :light), do: "┯"
  defp box_drawing(:heavy, :heavy, :light, nil), do: "┷"
  defp box_drawing(:heavy, :heavy, :light, :light), do: "┿"
end
