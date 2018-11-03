# Nim-OSRM

[Open Source Routing Machine](https://project-osrm.org) for [OpenStreetMap](https://openstreetmap.org) API Lib and App.

![Open Source Routing Machine](http://project-osrm.org/images/osrm_logo.svg "Open Source Routing Machine")


# Install

- `nimble install osrm`


# Use

```nim
import osrm, asyncdispatch, json

let ## Demo Data.
  foo: OSRMCoords = (lat: 13.388860.float32, lon: 52.517037.float32)
  bar: OSRMCoords = (lat: 13.397634.float32, lon: 52.529407.float32)

## Sync client.
let osrmc = OSRM(timeout: 99.byte, proxy: nil)
echo osrmc.nearest(number=42.byte, profile=OSRMBike, coordinates= @[foo]).pretty
echo osrmc.route(profile=OSRMBike, coordinates= @[foo, bar]).pretty
echo osrmc.table(profile=OSRMBike, coordinates= @[foo, bar], sources= @[0.byte, 1.byte], destinations= @[0.byte, 1.byte]).pretty
echo osrmc.match(profile=OSRMCar, coordinates= @[foo, bar]).pretty
echo osrmc.trip(profile=OSRMCar, coordinates= @[foo, bar]).pretty

## Async client.
proc async_osrm() {.async.} =
  let
    async_osrmc = AsyncOSRM(timeout: 99.byte)
    async_response = await async_osrmc.nearest(number=42.byte, profile=OSRMBike, coordinates= @[foo])
  echo async_response.pretty

wait_for async_osrm()

# Check the Docs for more API Calls...
```


# Command Line App

Finds the best fastest Route between 2 Coordinates (lat,lon) in supplied order
using the Open Source Routing Machine for OpenStreetMap API online services.

- For Uglyfied JSON use ``--ugly`` (does not reduce bandwith usage).
- If you dont have any Hints for the Query just use an empty string.
- This requires at least basic skills with JSON and OpenStreeMap.
- The App supports English and Spanish.

**Use:**

```
./osrm --color --lower --alternatives --steps --straight --overview --hints --timeout=9 --profile=bike --format=geojson --from_lat=42.666 --from_lon=10.55 --to_lat=15.42 --to_lon=12.75 "hint,hint,hint"
```

**Uso (Spanish):**

```
./osrm --color --minusculas --alternativas --pasos --derecho --resumen --sugerencias --timeout=9 --perfil=bici --formato=geojson --desde_lat=42.666 --desde_lon=10.55 --hasta_lat=15.42 --hasta_lon=12.75 "hint,hint,hint"
```


# API

- Modern C++ Routing engine and JSON API for shortest paths in road networks.
- Handles continental-sized network queries within miliseconds.
- Supports Car, Bicycle, Walk modes with easily customized profiles.
- No Login, no auth, no payments, no credit card, no api key, just works.
- Powered by OSRM, OpenStreetMap and Nim lang.
- [Check the OpenStreetMap Wiki](https://wiki.openstreetmap.org/wiki/API_v0.6), the Lib is a 1:1 copy of the official Docs.
- This Library uses API Version `1.0` from Year `2018`.
- Each proc links to the official OSRM API docs.
- All procs should return an JSON Object `JsonNode` type.
- The order of the procs follows the order on the OSRM Wiki.
- The naming of the procs follows the naming on the OSRM Wiki.
- The errors on the procs follows the errors on the OSRM Wiki.
- API Calls use HTTP `GET`.
- Coordinates are `float32`.
- API Calls are Anonymous and use a blank User-Agent.
- API Calls use [the DoNotTrack HTTP Header.](https://en.wikipedia.org/wiki/Do_Not_Track)
- The `timeout` argument is on Seconds.
- For Proxy support define a `OSM.proxy` or `AsyncOSM.proxy` of `Proxy` type.
- No OS-specific code, so it should work on Linux, Windows and Mac. Not JS.
- Run the module itself for an Example.
- Run `nim doc osrm.nim` for more Documentation.


# Support

- All OSRM API is supported.


# FAQ

- This works without SSL ?.

Yes.

- This works with SSL ?.

Yes.

- This works with Asynchronous code ?.

Yes.

- This works with Synchronous code ?.

Yes.

- This requires API Key or Login ?.

No.

- This requires Credit Card or Payments ?.

No.

- Can I use the OpenStreetMap data ?.

Yes. [**You MUST give Credit to OpenStreetMap Contributors!.**](https://wiki.openstreetmap.org/wiki/Legal_FAQ#3a._I_would_like_to_use_OpenStreetMap_maps._How_should_I_credit_you.3F)


# Requisites

- None.
