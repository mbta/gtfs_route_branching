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

## Installation

```elixir
def deps do
  [
    {:gtfs_route_branching, github: "mbta/gtfs_route_branching", tag: "0.1.1"}
  ]
end
```
