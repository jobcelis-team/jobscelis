defmodule StreamflixWebWeb.UserAgentTest do
  use ExUnit.Case, async: true

  alias StreamflixWebWeb.UserAgent

  @cases [
    {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
     "Edge", "Windows", :desktop},
    {"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
     "Chrome", "macOS", :desktop},
    {"Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0", "Firefox", "Linux",
     :desktop},
    {"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
     "Safari", "iOS", :mobile},
    {"Mozilla/5.0 (Linux; Android 14; SM-A556E) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/26.0 Chrome/122.0.0.0 Mobile Safari/537.36",
     "Samsung Internet", "Android", :mobile},
    {"Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
     "Safari", "iOS", :tablet},
    {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 OPR/115.0.0.0",
     "Opera", "Windows", :desktop},
    {"Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/76.0.3809.146 TV Safari/537.36",
     "Samsung Internet", "Smart TV", :tv},
    {"Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.128 Safari/537.36 WebAppManager",
     "Chrome", "Smart TV", :tv},
    {"Mozilla/5.0 (Linux; Android 12; BRAVIA 4K VH2 Build/STT1.211025.001.Z4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
     "Chrome", "Android", :tv},
    {"Mozilla/5.0 (Linux; Android 9; AFTMM Build/PS7633) AppleWebKit/537.36 (KHTML, like Gecko) Silk/120.4.1 like Chrome/120.0.6099.268 Safari/537.36",
     "Silk", "Android", :tv},
    {"Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 CrKey/1.56.500000",
     "Chrome", "Linux", :tv},
    {"Mozilla/5.0 (Windows NT 10.0; Win64; x64; Xbox; Xbox Series X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edge/44.18363.8131",
     "Edge", "Xbox", :tv},
    {"Mozilla/5.0 (Linux; Android 11; KFTRWI) AppleWebKit/537.36 (KHTML, like Gecko) Silk/120.4.1 like Chrome/120.0.6099.268 Safari/537.36",
     "Silk", "Android", :tablet},
    {"Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
     "Chrome", "Android", :tablet},
    {"curl/8.5.0", "curl", nil, :api},
    {"jobcelis-node/1.10.0", "Jobcelis SDK", nil, :api},
    {"python-requests/2.32.3", "Python", nil, :api}
  ]

  test "recognises common browsers, systems and devices" do
    for {ua, browser, os, device} <- @cases do
      assert UserAgent.parse(ua) == %{browser: browser, os: os, device: device}, ua
    end
  end

  test "unknown or missing user agents are reported generically" do
    assert UserAgent.parse(nil) == %{browser: nil, os: nil, device: :desktop}
    assert %{browser: nil, device: :api} = UserAgent.parse("SomethingElse/1.0")
  end
end
