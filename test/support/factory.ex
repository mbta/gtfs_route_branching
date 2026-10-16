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
end
