defmodule GTFSRouteBranchingTest do
  use ExUnit.Case, async: true

  import GTFSRouteBranching.Factory

  alias GTFSRouteBranching.Segment
  alias GTFSRouteBranching.Segment.BranchStop
  alias GTFSRouteBranching.Segment.StickConnection

  defp to_system_data_map(objects), do: Map.new(objects, &{&1.id, &1})

  defp forward(s1, s2, s3, lane) do
    [
      %StickConnection{
        service_status: nil,
        from_stop: s1,
        to_stop: s2,
        from_lane: lane,
        to_lane: lane,
        from_vpos: :top,
        to_vpos: :center
      },
      %StickConnection{
        service_status: nil,
        from_stop: s2,
        to_stop: s3,
        from_lane: lane,
        to_lane: lane,
        from_vpos: :center,
        to_vpos: :bottom
      }
    ]
    |> Enum.reject(&(is_nil(&1.from_stop) or is_nil(&1.to_stop)))
  end

  describe "calculate/4" do
    test "parallel segments work" do
      route = build(:route)
      a = build(:stop, id: "a")
      b = build(:stop, id: "b")
      c = build(:stop, id: "c")
      d = build(:stop, id: "d")
      trip1 = build(:trip, stop_ids: [a.id, b.id, d.id])
      trip2 = build(:trip, stop_ids: [a.id, c.id, d.id])

      pattern1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip1.id
        )

      pattern2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip2.id
        )

      {_, _, segments} =
        GTFSRouteBranching.calculate(
          route,
          pattern1.direction_id,
          [a.id, b.id, c.id, d.id],
          %{
            route_patterns: to_system_data_map([pattern1, pattern2]),
            representative_trips: to_system_data_map([trip1, trip2]),
            stops: to_system_data_map([a, b, c, d])
          }
        )

      assert segments == [
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     closure_status: nil,
                     stop_id: a.id,
                     stop_lane: :center,
                     connections: [
                       %StickConnection{
                         service_status: nil,
                         from_stop: a.id,
                         to_stop: b.id,
                         from_lane: :center,
                         to_lane: :right,
                         from_vpos: :center,
                         to_vpos: :bottom
                       },
                       %StickConnection{
                         service_status: nil,
                         from_stop: a.id,
                         to_stop: c.id,
                         from_lane: :center,
                         to_lane: :left,
                         from_vpos: :center,
                         to_vpos: :bottom
                       }
                     ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     closure_status: nil,
                     stop_id: b.id,
                     stop_lane: :right,
                     connections:
                       forward(a.id, b.id, d.id, :right) ++
                         [
                           %StickConnection{
                             service_status: nil,
                             from_stop: a.id,
                             to_stop: c.id,
                             from_lane: :left,
                             to_lane: :left,
                             from_vpos: :top,
                             to_vpos: :bottom
                           }
                         ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     closure_status: nil,
                     stop_id: c.id,
                     stop_lane: :left,
                     connections:
                       forward(a.id, c.id, d.id, :left) ++
                         [
                           %StickConnection{
                             service_status: nil,
                             from_stop: b.id,
                             to_stop: d.id,
                             from_lane: :right,
                             to_lane: :right,
                             from_vpos: :top,
                             to_vpos: :bottom
                           }
                         ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     closure_status: nil,
                     stop_id: d.id,
                     stop_lane: :center,
                     connections: [
                       %StickConnection{
                         service_status: nil,
                         from_stop: b.id,
                         to_stop: d.id,
                         from_lane: :right,
                         to_lane: :center,
                         from_vpos: :top,
                         to_vpos: :center
                       },
                       %StickConnection{
                         service_status: nil,
                         from_stop: c.id,
                         to_stop: d.id,
                         from_lane: :left,
                         to_lane: :center,
                         from_vpos: :top,
                         to_vpos: :center
                       }
                     ]
                   }
                 ],
                 typical?: true
               }
             ]
    end

    test "Red Line works" do
      alewife = build(:stop, id: "place-alfcl")
      trunk_interior = build_list(11, :stop)
      jfk = build(:stop, id: "place-jfk")
      savin_hill = build(:stop, id: "place-shmnl")
      ashmont_interior = build_list(2, :stop)
      ashmont = build(:stop, id: "place-asmnl", name: "Ashmont")
      north_quincy = build(:stop, id: "place-nqncy")
      braintree_interior = build_list(3, :stop)
      braintree = build(:stop, id: "place-brntn", name: "Braintree")

      route =
        build(:route, direction_destinations: ["Ashmont/Braintree", "Alewife"], type: :heavy_rail)

      trunk_ids = [alewife.id] ++ Enum.map(trunk_interior, & &1.id) ++ [jfk.id]

      ashmont_ids = [savin_hill.id] ++ Enum.map(ashmont_interior, & &1.id) ++ [ashmont.id]

      braintree_ids = [north_quincy.id] ++ Enum.map(braintree_interior, & &1.id) ++ [braintree.id]

      t1 = build(:trip, stop_ids: trunk_ids ++ ashmont_ids)
      t2 = build(:trip, stop_ids: trunk_ids ++ braintree_ids)

      p1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: t1.id
        )

      p2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: t2.id
        )

      {_, _, segments} =
        GTFSRouteBranching.calculate(
          route,
          0,
          trunk_ids ++ ashmont_ids ++ braintree_ids,
          %{
            route_patterns: to_system_data_map([p1, p2]),
            representative_trips: to_system_data_map([t1, t2]),
            stops:
              to_system_data_map(
                trunk_interior ++
                  ashmont_interior ++
                  braintree_interior ++
                  [alewife, jfk, savin_hill, ashmont, north_quincy, braintree]
              )
          }
        )

      jfk_to_north_quincy_skip = %StickConnection{
        service_status: nil,
        from_stop: jfk.id,
        to_stop: north_quincy.id,
        from_lane: :left,
        to_lane: :left,
        from_vpos: :top,
        to_vpos: :bottom
      }

      assert segments == [
               %Segment{
                 name: nil,
                 stops:
                   [
                     %BranchStop{
                       closure_status: nil,
                       stop_id: alewife.id,
                       stop_lane: :center,
                       connections:
                         forward(nil, alewife.id, List.first(trunk_interior).id, :center)
                     }
                   ] ++
                     Enum.with_index(
                       trunk_interior,
                       fn stop, index ->
                         %BranchStop{
                           closure_status: nil,
                           stop_id: stop.id,
                           stop_lane: :center,
                           connections:
                             forward(
                               Enum.at(trunk_ids, index),
                               stop.id,
                               Enum.at(trunk_ids, index + 2),
                               :center
                             )
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         closure_status: nil,
                         stop_id: jfk.id,
                         stop_lane: :center,
                         connections: [
                           %StickConnection{
                             service_status: nil,
                             from_stop: List.last(trunk_interior).id,
                             to_stop: jfk.id,
                             from_lane: :center,
                             to_lane: :center,
                             from_vpos: :top,
                             to_vpos: :center
                           },
                           %StickConnection{
                             service_status: nil,
                             from_stop: jfk.id,
                             to_stop: north_quincy.id,
                             from_lane: :center,
                             to_lane: :left,
                             from_vpos: :center,
                             to_vpos: :bottom
                           },
                           %StickConnection{
                             service_status: nil,
                             from_stop: jfk.id,
                             to_stop: savin_hill.id,
                             from_lane: :center,
                             to_lane: :right,
                             from_vpos: :center,
                             to_vpos: :bottom
                           }
                         ]
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Ashmont",
                 stops:
                   [
                     %BranchStop{
                       closure_status: nil,
                       stop_id: savin_hill.id,
                       stop_lane: :right,
                       connections:
                         forward(jfk.id, savin_hill.id, List.first(ashmont_interior).id, :right) ++
                           [jfk_to_north_quincy_skip]
                     }
                   ] ++
                     Enum.with_index(
                       ashmont_interior,
                       fn stop, index ->
                         %BranchStop{
                           closure_status: nil,
                           stop_id: stop.id,
                           stop_lane: :right,
                           connections:
                             forward(
                               Enum.at(ashmont_ids, index),
                               stop.id,
                               Enum.at(ashmont_ids, index + 2),
                               :right
                             ) ++ [jfk_to_north_quincy_skip]
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         closure_status: nil,
                         stop_id: ashmont.id,
                         stop_lane: :right,
                         connections:
                           forward(List.last(ashmont_interior).id, ashmont.id, nil, :right) ++
                             [jfk_to_north_quincy_skip]
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Braintree",
                 stops:
                   [
                     %BranchStop{
                       closure_status: nil,
                       stop_id: north_quincy.id,
                       stop_lane: :left,
                       connections:
                         forward(
                           jfk.id,
                           north_quincy.id,
                           List.first(braintree_interior).id,
                           :left
                         )
                     }
                   ] ++
                     Enum.with_index(
                       braintree_interior,
                       fn stop, index ->
                         %BranchStop{
                           closure_status: nil,
                           stop_id: stop.id,
                           stop_lane: :left,
                           connections:
                             forward(
                               Enum.at(braintree_ids, index),
                               stop.id,
                               Enum.at(braintree_ids, index + 2),
                               :left
                             )
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         closure_status: nil,
                         stop_id: braintree.id,
                         stop_lane: :left,
                         connections:
                           forward(List.last(braintree_interior).id, braintree.id, nil, :left)
                       }
                     ],
                 typical?: true
               }
             ]
    end

    test "Foxboro Event Service branch naming works" do
      # not replicating the entire data set for Foxboro
      route =
        build(:route,
          type: :commuter_rail,
          long_name: "Foxboro Event Service",
          direction_destinations: ["Foxboro or Providence", "South Station or Foxboro"]
        )

      south_station = build(:stop, name: "South Station")
      foxboro = build(:stop, name: "Foxboro")
      providence = build(:stop, name: "Providence")

      t1 = build(:trip, direction_id: 0, stop_ids: [south_station.id, foxboro.id])
      t2 = build(:trip, direction_id: 0, stop_ids: [south_station.id, providence.id])
      t3 = build(:trip, direction_id: 1, stop_ids: [providence.id, south_station.id])
      t4 = build(:trip, direction_id: 1, stop_ids: [providence.id, foxboro.id])

      p1 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          typicality: :typical,
          representative_trip_id: t1.id
        )

      p2 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          typicality: :typical,
          representative_trip_id: t2.id
        )

      p3 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          typicality: :typical,
          representative_trip_id: t3.id
        )

      p4 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          typicality: :typical,
          representative_trip_id: t4.id
        )

      stop_ids = [south_station.id, foxboro.id, providence.id]

      system_data = %{
        route_patterns: to_system_data_map([p1, p2, p3, p4]),
        representative_trips: to_system_data_map([t1, t2, t3, t4]),
        stops: to_system_data_map([south_station, foxboro, providence])
      }

      assert {_, _,
              [
                %Segment{name: "South Station"},
                %Segment{name: "Foxboro"},
                %Segment{name: "Providence"}
              ]} =
               GTFSRouteBranching.calculate(
                 route,
                 0,
                 stop_ids,
                 system_data
               )

      assert {_, _,
              [
                %Segment{name: "Providence"},
                %Segment{name: "Foxboro"},
                %Segment{name: "South Station"}
              ]} =
               GTFSRouteBranching.calculate(
                 route,
                 1,
                 Enum.reverse(stop_ids),
                 system_data
               )
    end

    test "skipping same stop does not drop connection" do
      route = build(:route)
      a = build(:stop, id: "a")
      b = build(:stop, id: "b")
      c = build(:stop, id: "c")
      trip1 = build(:trip, stop_ids: [a.id, b.id, c.id])
      trip2 = build(:trip, stop_ids: [b.id, b.id, c.id])

      pattern1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip1.id
        )

      pattern2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip2.id
        )

      {_, _, segments} =
        GTFSRouteBranching.calculate(
          route,
          0,
          [a.id, b.id, c.id],
          %{
            route_patterns: to_system_data_map([pattern1, pattern2]),
            representative_trips: to_system_data_map([trip1, trip2]),
            stops: to_system_data_map([a, b, c])
          }
        )

      assert [
               _,
               %Segment{
                 stops: [
                   %BranchStop{stop_id: "b", stop_lane: :right, connections: atypical_connections}
                 ],
                 typical?: false
               },
               _
             ] = segments

      assert atypical_connections ==
               forward(nil, "b", "b", :right) ++
                 [
                   %StickConnection{
                     service_status: nil,
                     from_stop: "a",
                     from_lane: :left,
                     from_vpos: :top,
                     to_stop: "b",
                     to_lane: :left,
                     to_vpos: :bottom
                   }
                 ]
    end

    test "fallback works" do
      # simplest failure case is four branches
      route = build(:route)
      a = build(:stop, id: "a")
      b = build(:stop, id: "b")
      c = build(:stop, id: "c")
      d = build(:stop, id: "d")
      e = build(:stop, id: "e")
      trip1 = build(:trip, stop_ids: [a.id, b.id])
      trip2 = build(:trip, stop_ids: [a.id, c.id])
      trip3 = build(:trip, stop_ids: [a.id, d.id])
      trip4 = build(:trip, stop_ids: [a.id, e.id])

      pattern1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip1.id
        )

      pattern2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip2.id
        )

      pattern3 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip3.id
        )

      pattern4 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip4.id
        )

      {{stop_graph, segment_graph, segments}, log} =
        ExUnit.CaptureLog.with_log(fn ->
          GTFSRouteBranching.calculate(
            route,
            pattern1.direction_id,
            [a.id, b.id, c.id, d.id, e.id],
            %{
              route_patterns: to_system_data_map([pattern1, pattern2, pattern3, pattern4]),
              representative_trips: to_system_data_map([trip1, trip2, trip3, trip4]),
              stops: to_system_data_map([a, b, c, d, e])
            }
          )
        end)

      assert :digraph.info(stop_graph)
      assert :digraph.info(segment_graph)

      assert segments == [
               %Segment{
                 stops: [
                   %BranchStop{
                     stop_id: a.id,
                     stop_lane: :center,
                     connections: [],
                     closure_status: nil
                   },
                   %BranchStop{
                     stop_id: b.id,
                     stop_lane: :center,
                     connections: [],
                     closure_status: nil
                   },
                   %BranchStop{
                     stop_id: c.id,
                     stop_lane: :center,
                     connections: [],
                     closure_status: nil
                   },
                   %BranchStop{
                     stop_id: d.id,
                     stop_lane: :center,
                     connections: [],
                     closure_status: nil
                   },
                   %BranchStop{
                     stop_id: e.id,
                     stop_lane: :center,
                     connections: [],
                     closure_status: nil
                   }
                 ],
                 name: nil,
                 typical?: true
               }
             ]

      assert log =~ "A segment had more than two parallel segments"

      [fallback] =
        Segment.apply_alerts(segments, [
          build(:alert, effect: :stop_closure, informed_entities: [%{stop: b.id}])
        ])

      assert Enum.find(fallback.stops, &(&1.stop_id == b.id)).closure_status == :closed

      assert Enum.all?(Enum.reject(fallback.stops, &(&1.stop_id == b.id)), fn stop ->
               stop.closure_status == :open
             end)
    end
  end

  describe "service alerts" do
    setup do
      build(:branching_system)
    end

    defp calculate_alerts(context, alerts) do
      {stop_graph, segment_graph, segments} =
        GTFSRouteBranching.calculate(
          context.route,
          0,
          context.canon_stop_ids,
          context.system_data
        )

      :digraph.delete(stop_graph)
      :digraph.delete(segment_graph)

      segments
      |> Segment.apply_alerts(alerts)
      |> Enum.flat_map(& &1.stops)
    end

    test "resolves empty alerts to open stops and normal connections", context do
      stops = calculate_alerts(context, [])
      assert Enum.all?(stops, &(&1.closure_status == :open))
      assert Enum.all?(Enum.flat_map(stops, & &1.connections), &(&1.service_status == :normal))
    end

    for effect <- [:stop_closure, :station_closure, :dock_closure] do
      test "#{effect} closes only matching stops", context do
        alert =
          build(:alert,
            effect: unquote(effect),
            informed_entities: [%{stop: "b"}, %{stop: nil}, %{stop: "unrelated"}]
          )

        stops = calculate_alerts(context, [alert])
        assert Enum.find(stops, &(&1.stop_id == "b")).closure_status == :closed
        assert Enum.all?(Enum.reject(stops, &(&1.stop_id == "b")), &(&1.closure_status == :open))
        assert Enum.all?(Enum.flat_map(stops, & &1.connections), &(&1.service_status == :normal))
      end
    end

    for effect <- [:shuttle, :suspension] do
      test "#{effect} affects every piece of the matching connection", context do
        alert =
          build(:alert,
            effect: unquote(effect),
            informed_entities: [%{stop: "a"}, %{stop: "c"}]
          )

        stops = calculate_alerts(context, [alert])
        connections = Enum.flat_map(stops, & &1.connections)

        {affected, unaffected} =
          Enum.split_with(connections, &(&1.from_stop == "a" and &1.to_stop == "c"))

        assert length(affected) == 3
        assert Enum.all?(affected, &(&1.service_status == unquote(effect)))
        assert Enum.all?(unaffected, &(&1.service_status == :normal))
        assert Enum.all?(stops, &(&1.closure_status == :open))

        passing_stop = Enum.find(stops, &(&1.stop_id == "b"))
        assert Enum.any?(passing_stop.connections, &(&1.service_status == unquote(effect)))
      end
    end

    test "does not combine endpoints from separate alerts or match nil stops", context do
      alerts =
        Enum.map(["a", "c", nil], fn stop ->
          build(:alert, informed_entities: [%{stop: stop}])
        end)

      connections = context |> calculate_alerts(alerts) |> Enum.flat_map(& &1.connections)
      assert Enum.all?(connections, &(&1.service_status == :normal))
    end

    test "suspension takes precedence regardless of alert ordering", context do
      shuttle = build(:alert, effect: :shuttle, informed_entities: [%{stop: "a"}, %{stop: "c"}])
      suspension = %{shuttle | effect: :suspension}

      for alerts <- [[shuttle, suspension], [suspension, shuttle]] do
        affected =
          context
          |> calculate_alerts(alerts)
          |> Enum.flat_map(& &1.connections)
          |> Enum.filter(&(&1.from_stop == "a" and &1.to_stop == "c"))

        assert Enum.all?(affected, &(&1.service_status == :suspension))
      end
    end

    test "refreshes cached segments and clears previous alerts without changing layout",
         context do
      {stop_graph, segment_graph, cached_segments} =
        GTFSRouteBranching.calculate(
          context.route,
          0,
          context.canon_stop_ids,
          context.system_data
        )

      :digraph.delete(stop_graph)
      :digraph.delete(segment_graph)

      stops = Enum.flat_map(cached_segments, & &1.stops)
      assert Enum.all?(stops, &is_nil(&1.closure_status))
      assert Enum.all?(Enum.flat_map(stops, & &1.connections), &is_nil(&1.service_status))

      alerts = [
        build(:alert, effect: :stop_closure, informed_entities: [%{stop: "b"}]),
        build(:alert, effect: :shuttle, informed_entities: [%{stop: "a"}, %{stop: "c"}])
      ]

      updated = Segment.apply_alerts(cached_segments, alerts)
      assert updated != cached_segments
      assert Segment.apply_alerts(updated, []) == Segment.apply_alerts(cached_segments, [])

      suspension = build(:alert, informed_entities: [%{stop: "b"}, %{stop: "d"}])

      assert Segment.apply_alerts(updated, [suspension]) ==
               Segment.apply_alerts(cached_segments, [suspension])
    end

    test "calculate does not apply alerts from system data", context do
      alert = build(:alert, effect: :stop_closure, informed_entities: [%{stop: "b"}])
      system_data = Map.put(context.system_data, :alerts, [alert])

      {stop_graph, segment_graph, segments} =
        GTFSRouteBranching.calculate(context.route, 0, context.canon_stop_ids, system_data)

      :digraph.delete(stop_graph)
      :digraph.delete(segment_graph)

      stops = Enum.flat_map(segments, & &1.stops)
      assert Enum.all?(stops, &is_nil(&1.closure_status))
      assert Enum.all?(Enum.flat_map(stops, & &1.connections), &is_nil(&1.service_status))

      [closed_stop] =
        segments
        |> Segment.apply_alerts([alert])
        |> Enum.flat_map(& &1.stops)
        |> Enum.filter(&(&1.closure_status == :closed))

      assert closed_stop.stop_id == "b"
    end
  end
end
