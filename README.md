# GTFSRouteBranching

Calculates diagrams for branching routes. See [docs](https://mbta.github.io/gtfs_route_branching) for more detail.

```
   ┯  A
  ┌┷┐ B
® ┿ │ C
  │ ┿ D
  └┯┘ E
   ┷  F
```

## Service alerts

Apply a list of alerts to generated or cached segments:

```elixir
alerts = [
  %{effect: :shuttle, informed_entities: [%{stop: "stop-a"}, %{stop: "stop-b"}]}
]

segments_with_alerts = GTFSRouteBranching.Segment.apply_alerts(cached_segments, alerts)
```

Stop, station, and dock closure alerts set matching stops' `closure_status` to `:closed`;
other stops are `:open`. Shuttle and suspension alerts affect connections only when both
endpoint IDs appear in the same alert. Every drawn piece of that connection receives the
same `service_status`: `:shuttle`, `:suspension`, or `:normal` when unaffected. Suspension
takes precedence. IDs match the diagram's stop IDs directly; `nil` IDs are ignored.

`apply_alerts/2` matches stop IDs only; it does not filter alerts by route or direction.
The caller must pass alerts already scoped to the route and direction represented by the
segments.

This replaces previous statuses without changing layout or names. Passing `[]` clears
all alert effects. `calculate/4` returns segments with `nil` statuses until alerts are processed.

## Installation

```elixir
def deps do
  [
    {:gtfs_route_branching, github: "mbta/gtfs_route_branching", tag: "0.1.1"}
  ]
end
```
