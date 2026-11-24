defmodule StreamflixWebWeb.UserAgent do
  @moduledoc """
  Turns a User-Agent string into what the account page shows for a session:
  browser (or API client), operating system and device type.

  Done when rendering, from the user agent stored with each session, so it also
  applies to sessions created before this existed. Only common browsers and
  clients are recognised; anything else is reported generically.
  """

  @type device :: :desktop | :mobile | :tablet | :tv | :api

  @type t :: %{browser: String.t() | nil, os: String.t() | nil, device: device()}

  @spec parse(String.t() | nil) :: t()
  def parse(nil), do: %{browser: nil, os: nil, device: :desktop}

  def parse(ua) when is_binary(ua) do
    lower = String.downcase(ua)
    browser = browser(lower)
    os = os(lower)

    %{browser: browser, os: os, device: device(lower, browser)}
  end

  # Order matters: Edge and Opera also say "Chrome", Chrome also says "Safari".
  @browsers [
    {"Edge", ["edg/", "edga/", "edgios/", "edge/"]},
    {"Opera", ["opr/", "opera"]},
    {"Samsung Internet", ["samsungbrowser"]},
    {"Silk", ["silk/"]},
    {"Firefox", ["firefox/", "fxios/"]},
    {"Chrome", ["chrome/", "crios/"]},
    {"Safari", ["safari/"]},
    {"Jobcelis SDK", ["jobcelis"]},
    {"curl", ["curl/"]},
    {"Postman", ["postmanruntime"]},
    {"Python", ["python-requests", "python-urllib", "aiohttp", "httpx"]},
    {"Node.js", ["node-fetch", "undici", "axios", "node/"]},
    {"Go", ["go-http-client"]},
    {"Java", ["okhttp", "java/", "apache-httpclient"]},
    {"Dart", ["dart:io", "dart/"]}
  ]

  @api_clients ~w(Jobcelis\ SDK curl Postman Python Node.js Go Java Dart)

  defp browser(lower) do
    Enum.find_value(@browsers, fn {name, needles} ->
      if String.contains?(lower, needles), do: name
    end)
  end

  @systems [
    {"Windows", ["windows"]},
    {"iOS", ["iphone", "ipad", "ipod"]},
    {"Android", ["android"]},
    {"macOS", ["mac os x", "macintosh"]},
    {"ChromeOS", ["cros"]},
    {"Linux", ["linux", "x11"]}
  ]

  defp os(lower) do
    cond do
      String.contains?(lower, ["tizen", "webos", "web0s"]) ->
        "Smart TV"

      String.contains?(lower, ["xbox"]) ->
        "Xbox"

      String.contains?(lower, ["playstation"]) ->
        "PlayStation"

      true ->
        Enum.find_value(@systems, fn {name, needles} ->
          if String.contains?(lower, needles), do: name
        end)
    end
  end

  # Smart TVs, TV sticks and consoles (their browsers often say "Android" or
  # "Linux" too, so they are checked before tablets and phones)
  @tv_markers [
    "smart-tv",
    "smarttv",
    "tizen",
    "webos",
    "web0s",
    "android tv",
    "googletv",
    "crkey",
    "appletv",
    "roku",
    "aftb",
    "aftm",
    "afts",
    "aftt",
    "hbbtv",
    "netcast",
    "vidaa",
    "bravia",
    "xbox",
    "playstation",
    " tv safari",
    "; tv)"
  ]

  defp device(lower, browser) do
    cond do
      browser in @api_clients ->
        :api

      String.contains?(lower, @tv_markers) ->
        :tv

      String.contains?(lower, ["ipad", "tablet", "kindle", "silk/"]) ->
        :tablet

      String.contains?(lower, "android") and not String.contains?(lower, "mobile") ->
        :tablet

      String.contains?(lower, ["mobile", "iphone", "ipod"]) ->
        :mobile

      not String.contains?(lower, "mozilla") ->
        :api

      true ->
        :desktop
    end
  end
end
