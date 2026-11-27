defmodule GTFSRouteBranching.Factory do
  @moduledoc false
  use ExMachina

  def route_factory do
    %{
      id: Uniq.UUID.uuid7(),
      direction_destinations: ["Harvard Square", "Nubian Station"],
      long_name: "Harvard Square - Nubian Station",
      type: :bus
    }
  end

  def route_pattern_factory do
    %{
      id: Uniq.UUID.uuid7(),
      direction_id: 0,
      typicality: :typical,
      representative_trip_id: "60168428",
      route_id: "66"
    }
  end

  def stop_factory do
    %{
      id: Uniq.UUID.uuid7(),
      name: "Harvard Sq @ Garden St - Dawes Island",
      parent_station_id: nil
    }
  end

  def trip_factory do
    %{
      id: Uniq.UUID.uuid7(),
      stop_ids: []
    }
  end

  def alert_factory do
    %{effect: :suspension, informed_entities: []}
  end

  def branching_system_factory do
    route = build(:route)
    stops = Enum.map(~w(a b c d), &build(:stop, id: &1))
    trips = Enum.map([~w(a b d), ~w(a c d)], &build(:trip, stop_ids: &1))

    patterns =
      Enum.map(trips, fn trip ->
        build(:route_pattern, route_id: route.id, representative_trip_id: trip.id)
      end)

    %{
      route: route,
      canon_stop_ids: ~w(a b c d),
      system_data: %{
        route_patterns: Map.new(patterns, &{&1.id, &1}),
        representative_trips: Map.new(trips, &{&1.id, &1}),
        stops: Map.new(stops, &{&1.id, &1})
      }
    }
  end
end
