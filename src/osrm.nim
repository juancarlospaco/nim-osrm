## Open Source Routing Machine for OpenStreetMap
## =============================================
## .. image:: http://project-osrm.org/images/osrm_logo.svg
## - Modern C++ Routing engine and JSON API for shortest paths in road networks.
## - Handles continental-sized network queries within miliseconds.
## - Supports Car, Bicycle, Walk modes with easily customized profiles.
## - No Login, no auth, no payments, no credit card, no api key, just works.
## - Powered by OSRM, OpenStreetMap and Nim lang.
##
## Command Line App
## ----------------
##
## Finds the best fastest Route between 2 Coordinates (lat,lon) in supplied order
## using the Open Source Routing Machine for OpenStreetMap API online services.
## For Uglyfied JSON use ``--ugly`` (does not reduce bandwith usage).
## If you dont have any Hints for the Query just use an empty string.
## This requires at least basic skills with JSON and OpenStreeMap. Use:
## .. code::
##   ./osrm --color --lower --alternatives --steps --straight --overview --hints --timeout=9 --profile=bike --format=geojson --from_lat=42.666 --from_lon=10.55 --to_lat=15.42 --to_lon=12.75 "hint,hint,hint"
# http://project-osrm.org/docs/v5.7.0/api/#tile-service responds Permission Denied as of 2018.
import asyncdispatch, httpclient, strutils, json
{.passL: "-s".}
const
  osrm_api_ver* = "v1" ## Open Source Routing Machine API Version.
  osrm_api_url* =
    when defined(ssl):
      "https://router.project-osrm.org/" ## Open Source Routing Machine API URL (SSL).
    else:
      "http://router.project-osrm.org/"  ## Open Source Routing Machine API URL (No SSL).

type
  OpenSourceRoutingMachineBase*[HttpType] = object ## Base object.
    timeout*: byte  ## Timeout Seconds for API Calls, byte type, 0~255.
    proxy*: Proxy  ## Network IPv4 / IPv6 Proxy support, Proxy type.
  OSRM* = OpenSourceRoutingMachineBase[HttpClient]           ##  Sync Open Source Routing Machine API Client.
  AsyncOSRM* = OpenSourceRoutingMachineBase[AsyncHttpClient] ## Async Open Source Routing Machine API Client.
  OSRMCoords* = tuple[lat: float32, lon: float32] ## Tuple of Float32 Coordinates
  OSRMBearings* = tuple[value: range[0..360], `range`: range[0..180]]  ## Tuple of SubRange Integers.
  OSRMProfile* = enum ## Profiles endpoints of Open Source Routing Machine API.
    OSRMCar = "car"         # To get the way on Car.
    OSRMBike = "bike"       # To get the way on Bike.
    OSRMFoot = "foot"       # To get the way on Foot.
    OSRMDriving = "driving" # Seems kinda hybrid ???.

template clientify(this: OSRM | AsyncOSRM): untyped =
  ## Build & inject basic HTTP Client with Headers, Proxy, Timeout, DoNotTrack.
  var client {.inject.} =
    when this is AsyncOSRM: newAsyncHttpClient(
      proxy = when declared(this.proxy): this.proxy else: nil, userAgent="")
    else: newHttpClient(
      timeout = when declared(this.timeout): this.timeout.int * 1_000 else: -1,
      proxy = when declared(this.proxy): this.proxy else: nil, userAgent="")
  client.headers = newHttpHeaders({"dnt": "1", "accept":
    "application/vnd.api+json", "content-type": "application/vnd.api+json"})

func preprocess_coordinates(coordinates: seq[OSRMCoords]): string =
  ## Make a seq of OSRMCoords to string like "{lon},{lat};{lon},{lat}"
  var coordina: seq[string]
  for coord in coordinates:
    coordina.add $coord.lon & "," & $coord.lat  #TODO: Make this 2 to 1 Generic?
  result = coordina.join(";")

func preprocess_bearings(bearings: seq[OSRMBearings]): string =
  ## Make a seq of OSRMBearings to string like "{lon},{lat};{lon},{lat}"
  var bearinga: seq[string]
  for bear in bearings:
    bearinga.add $bear.value & "," & $bear.`range`
  result = bearinga.join(";")

proc osrm_request(this: OSRM | AsyncOSRM, service: string, profile: OSRMProfile,
    coordinates: seq[OSRMCoords], args: string, generate_hints=true,
    bearings: seq[OSRMBearings] = @[], hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## Base function for all Open Source Routing Machine HTTPS GET API Calls.
  assert coordinates.len > 0, "seq[OSRMCoords] must not be an empty seq."
  assert args.len > 1, "Unkown Error: args must not be an empty string."
  let
    cord = preprocess_coordinates(coordinates)
    hint = "generate_hints=" & $generate_hints
    bear = if bearings.len > 0: preprocess_bearings(bearings) else: ""
    hnts = if hints.len > 0: hints.join(";") else: ""
    base_url = osrm_api_url & $service & "/" & osrm_api_ver & "/" & $profile
    url = base_url & "/" & cord & ".json?" & hint & bear & hnts & args
  clientify(this)
  let responses =
    when this is AsyncOSRM: await client.get(url=url)
    else: client.get(url=url)
  result = parse_json(await responses.body)

proc nearest*(this: OSRM | AsyncOSRM, number: byte, profile: OSRMProfile,
    coordinates: seq[OSRMCoords], generate_hints=true,
    bearings: seq[OSRMBearings] = @[], hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## http://project-osrm.org/docs/v5.7.0/api/#nearest-service
  doAssert number.int > 1, "Number argument must be a Positive Byte > 1 (1~255)"
  doAssert coordinates.len == 1, "Exactly one Coordinate pair must be provided"
  result = await osrm_request(
    this, args="&number=" & $number, service="nearest", profile=profile, hints=hints,
    coordinates=coordinates, generate_hints=generate_hints, bearings=bearings)

proc route*(this: OSRM | AsyncOSRM, alternatives=false, steps=false,
    continue_straight=false, geometries="geojson", overview=true,
    profile: OSRMProfile, coordinates: seq[OSRMCoords], generate_hints=true,
    bearings: seq[OSRMBearings] = @[], hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## http://project-osrm.org/docs/v5.7.0/api/#route-service
  doAssert geometries in ["polyline", "polyline6", "geojson"], "Geometries must be one of polyline,polyline6,geojson"
  doAssert coordinates.len > 1, "Not enough input coordinates given, minimum number of coordinates is 2"
  let
    a = "&alternatives=" & $alternatives
    b = "&steps=" & $steps
    c = "&annotations=true" # As of 2018, API complains other than true here?.
    d = "&continue_straight=" & $continue_straight
    e = "&geometries=" & $geometries
    f = if overview: "&overview=full" else: "&overview=false"
  result = await osrm_request(
    this, args=a & b & c & d & e & f, service="route", profile=profile, hints=hints,
    coordinates=coordinates, generate_hints=generate_hints, bearings=bearings)

proc table*(this: OSRM | AsyncOSRM, sources, destinations: seq[byte] = @[], profile: OSRMProfile,
    coordinates: seq[OSRMCoords], generate_hints=true, bearings: seq[OSRMBearings] = @[],
    hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## http://project-osrm.org/docs/v5.7.0/api/#table-service
  doAssert coordinates.len > 1, "Not enough input coordinates given, minimum number of coordinates is 2"
  let
    a = if sources == @[]: "&sources=all" else: "&sources=" & sources.join(";")
    b = if destinations == @[]: "&destinations=all" else: "&destinations=" & destinations.join(";")
  result = await osrm_request(
    this, args=a & b, service="table", profile=profile, hints=hints,
    coordinates=coordinates, generate_hints=generate_hints, bearings=bearings)

proc match*(this: OSRM | AsyncOSRM, steps=false, geometries="geojson", overview=true,
    timestamps: seq[int] = @[], gaps=true, tidy=false, profile: OSRMProfile,
    coordinates: seq[OSRMCoords], generate_hints=true, bearings: seq[OSRMBearings] = @[],
    hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## http://project-osrm.org/docs/v5.7.0/api/#match-service
  doAssert coordinates.len > 1, "Not enough input coordinates given, minimum number of coordinates is 2"
  doAssert geometries in ["polyline", "polyline6", "geojson"], "Geometries must be one of polyline,polyline6,geojson"
  let
    a = "&steps=" & $steps
    b = "&annotations=true" # As of 2018, API complains other than true here?.
    c = "&geometries=" & $geometries
    d = if overview: "&overview=full" else: "&overview=false"
    e = if timestamps == @[]: "&timestamps=" & timestamps.join(";") else: ""
    f = if gaps: "&gaps=split" else: "&gaps=ignore"
    g = "&tidy=" & $tidy
  result = await osrm_request(
    this, args=a & b & c & d & f & g, service="match", profile=profile, hints=hints,
    coordinates=coordinates, generate_hints=generate_hints, bearings=bearings)

proc trip*(this: OSRM | AsyncOSRM, roundtrip=true, source=true, destination=true,
    steps=false, geometries="geojson", overview=true, profile: OSRMProfile,
    coordinates: seq[OSRMCoords], generate_hints=true, bearings: seq[OSRMBearings] = @[],
    hints: seq[string] = @[]): Future[JsonNode] {.multisync.} =
  ## http://project-osrm.org/docs/v5.7.0/api/#trip-service
  doAssert coordinates.len > 1, "Not enough input coordinates given, minimum number of coordinates is 2"
  doAssert geometries in ["polyline", "polyline6", "geojson"], "Geometries must be one of polyline, polyline6, geojson"
  let
    a = "&steps=" & $steps
    b = "&annotations=true" # As of 2018, API complains other than true here?.
    c = "&geometries=" & $geometries
    d = if overview: "&overview=full" else: "&overview=false"
    e = "&roundtrip=" & $roundtrip
    f = if source: "&source=any" else: "&source=first"
    g = if destination: "&destination=any" else: "&destination=first"
  result = await osrm_request(
    this, args=a & b & c & d & f & g, service="trip", profile=profile, hints=hints,
    coordinates=coordinates, generate_hints=generate_hints, bearings=bearings)


runnableExamples:   # Everything below is optional, is for Docs, etc.
  import asyncdispatch, json
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

when is_main_module and defined(release) and not defined(js):  # When release, its a command line app to make queries.
  {.optimization: size.}
  import parseopt, terminal, random
  const helpy = """
  Finds the best fastest Route between 2 Coordinates (lat,lon) in supplied order
  using the Open Source Routing Machine for OpenStreetMap API online services.

  For Uglyfied JSON use --ugly (does not reduce bandwith usage).
  If you dont have any Hints for the Query just use an empty string.
  This requires at least basic skills with JSON and OpenStreeMap.
  For more information and help check the Documentation.

  Para JSON Minificado afeado usar --fea (no reduce uso de ancho de banda).
  Si no tenes ninguna Sugerencia (Hint) para la consulta usa un string vacio.
  Requiere por lo menos conocimientos basicos de JSON y OpenStreeMap.
  Para mas informacion y ayuda ver la Documentacion.

  👑 https://github.com/juancarlospaco/nim-osrm#nim-osrm 👑

  Use:
  ./osrm --color --lower --alternatives --steps --straight --overview --hints --timeout=9 --profile=bike --format=geojson --from_lat=42.666 --from_lon=10.55 --to_lat=15.42 --to_lon=12.75 "hint,hint,hint"
  Uso (Spanish):
  ./osrm --color --minusculas --alternativas --pasos --derecho --resumen --sugerencias --timeout=9 --perfil=bici --formato=geojson --desde_lat=42.666 --desde_lon=10.55 --hasta_lat=15.42 --hasta_lon=12.75 "hint,hint,hint"
  """
  var
    profile: OSRMProfile
    taimaout = 99.byte
    formato = "geojson"
    point_a, point_b: OSRMCoords
    from_lat, from_lon, to_lat, to_lon: float32
    minusculas, alternatives, steps, straight, overview, hints, fea: bool
  for tipoDeClave, clave, valor in getopt():
    case tipoDeClave
    of cmdShortOption, cmdLongOption:
      case clave
      of "version":                      quit("0.1.5", 0)
      of "license", "licencia":          quit("MIT", 0)
      of "help", "ayuda":                quit(helpy, 0)
      of "minusculas", "lower":          minusculas = true
      of "alternatives", "alternativas": alternatives = true
      of "steps", "pasos", "pasitos":    steps = true
      of "straight", "derecho":          straight = true
      of "overview", "resumen":          overview = true
      of "hints", "sugerencias":         hints = true
      of "ugly", "fea":                  fea = true
      of "timeout":                      taimaout = valor.parseInt.byte # HTTTP Timeout.
      of "format", "formato":            formato = valor.string.strip.toLowerAscii
      of "from_lat", "desde_lat":        from_lat = valor.parseFloat.float32
      of "from_lon", "desde_lon":        from_lon = valor.parseFloat.float32
      of "to_lat", "hasta_lat":          to_lat = valor.parseFloat.float32
      of "to_lon", "hasta_lon":          to_lon = valor.parseFloat.float32
      of "color":
        randomize()
        setBackgroundColor(bgBlack)
        setForegroundColor([fgRed, fgGreen, fgYellow, fgBlue, fgMagenta, fgCyan, fgWhite].rand)
      of "profile", "perfil":
        let value = valor.string.strip.toLowerAscii
        if value in ["car", "auto", "automovil", "coche", "vehiculo"]:
          profile = OSRMCar
        elif value in ["bike", "bici", "bicicleta", "bicycle"]:
          profile = OSRMBike
        elif value in ["foot", "pie", "caminando", "trotando"]:
          profile = OSRMFoot
        elif value in ["driving", "manejando", "hybrid"]:
          profile = OSRMDriving
        else:
          quit("Wrong Parameters for Profile,see Help with --help:" & $value, 1)
    of cmdArgument:
      let
        point_a = (lat: from_lat, lon: from_lon)
        point_b = (lat: to_lat, lon: to_lon)
        jints = if valor.split(",").len > 1: valor.string.strip.toLowerAscii.split(",") else: @[]
        clientito = OSRM(timeout: taimaout)
        respuesta = clientito.route(
          alternatives=alternatives, steps=steps, continue_straight=straight,
          overview=overview, geometries=formato, profile=profile, hints=jints,
          coordinates= @[point_a, point_b], generate_hints=hints)
        resultadito = if fea: $respuesta else: respuesta.pretty
      if minusculas: echo resultadito.toLowerAscii else: echo resultadito
    of cmdEnd: quit("Wrong Parameters, see Help with --help", 1)
