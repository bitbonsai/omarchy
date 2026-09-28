#!/bin/bash

source "$(dirname "$0")/base-test.sh"

require_command python3

# collect_limits reaches the Zen gateway, so the reader that interprets its
# answer is exercised on its own: the collector loads as a module, and a fake
# urlopen stands in for the response.
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

COLLECTOR="$ROOT/bin/omarchy-agent-usage-opencode" TEST_HOME="$TEST_HOME" python3 - <<'PY'
import importlib.machinery
import importlib.util
import io
import json
import os
import pathlib
import sys
import urllib.error

loader = importlib.machinery.SourceFileLoader("collector", os.environ["COLLECTOR"])
spec = importlib.util.spec_from_loader(loader.name, loader)
collector = importlib.util.module_from_spec(spec)
loader.exec_module(collector)

home = os.environ["TEST_HOME"]
os.environ["XDG_CACHE_HOME"] = os.path.join(home, "cache")
limits_cache = pathlib.Path(os.environ["XDG_CACHE_HOME"]) / "omarchy" / "agent-usage" / "opencode-limits.json"


def check(description, condition, detail=""):
  if condition:
    print("ok - " + description)
    return
  print("not ok - " + description, file=sys.stderr)
  if detail:
    print(detail, file=sys.stderr)
  sys.exit(1)


def answer(payload=None, error=None):
  def open_(request, timeout=None):
    if error is not None:
      raise error
    return io.BytesIO(json.dumps(payload).encode())
  return open_


def clear_cache():
  limits_cache.unlink(missing_ok=True)


def clear_key():
  os.environ.pop("OPENCODE_API_KEY", None)
  os.environ.pop("XDG_DATA_HOME", None)
  os.environ["HOME"] = os.path.join(home, "empty")
  os.makedirs(os.environ["HOME"], exist_ok=True)
  clear_cache()


os.environ["OPENCODE_API_KEY"] = "zen_test"
collector.urllib.request.urlopen = answer({"usage": {
  "rolling": {"percent": 16, "resetsAt": "2999-01-01T00:00:00.000Z"},
  "weekly": {"percent": 6, "resetsAt": "2026-10-05T00:00:00.000Z"},
  "monthly": {"percent": 29, "resetsAt": "2026-10-11T15:38:40.000Z"},
}})
result = collector.collect_limits(True)
check(
  "OpenCode collector maps every Zen usage window",
  [(w["label"], w["percent"]) for w in result["limits"]] == [("Rolling (5h)", 0.16), ("Weekly (7-day)", 0.06), ("Monthly", 0.29)]
  and result["tierLabel"] == "Go" and result["usageStatusText"] == "",
  json.dumps(result),
)

# A panel that opens and shuts repeatedly must not probe every time.
collector.urllib.request.urlopen = answer(error=RuntimeError("probe should have been skipped"))
result = collector.collect_limits(False)
check(
  "OpenCode collector reuses a fresh probe cache without a request",
  [(w["label"], w["percent"]) for w in result["limits"]] == [("Rolling (5h)", 0.16), ("Weekly (7-day)", 0.06), ("Monthly", 0.29)]
  and result["usageStatusText"] == "",
  json.dumps(result),
)

collector.urllib.request.urlopen = answer({"usage": {"rolling": {"percent": 50, "resetsAt": "2999-01-01T00:00:00.000Z"}}})
result = collector.collect_limits(True)
check(
  "OpenCode collector --force probes past the cache",
  [(w["label"], w["percent"]) for w in result["limits"]] == [("Rolling (5h)", 0.5)],
  json.dumps(result),
)

clear_cache()
collector.urllib.request.urlopen = answer({"usage": {}})
result = collector.collect_limits(True)
check(
  "OpenCode collector reports a payload without windows",
  result["limits"] == [] and result["usageStatusText"] == "OpenCode limits unavailable",
  json.dumps(result),
)

clear_cache()
collector.urllib.request.urlopen = answer(error=urllib.error.HTTPError("https://x", 401, "Unauthorized", {}, None))
result = collector.collect_limits(True)
check(
  "OpenCode collector asks for a fresh key on 401",
  result["limits"] == [] and result["usageStatusText"] == "OpenCode limits unavailable" and "rejected the saved key" in result["authHelpText"],
  json.dumps(result),
)

clear_cache()
collector.urllib.request.urlopen = answer(error=urllib.error.HTTPError("https://x", 403, "Forbidden", {}, None))
result = collector.collect_limits(True)
check(
  "OpenCode collector names a missing Go subscription on 403",
  "no OpenCode Go subscription" in result["authHelpText"],
  json.dumps(result),
)

clear_cache()
collector.urllib.request.urlopen = answer(error=urllib.error.HTTPError("https://x", 500, "Server Error", {}, None))
result = collector.collect_limits(True)
check(
  "OpenCode collector shows a non-auth status code",
  "returned status 500" in result["authHelpText"],
  json.dumps(result),
)

clear_cache()
collector.urllib.request.urlopen = answer(error=urllib.error.URLError("no route"))
result = collector.collect_limits(True)
check(
  "OpenCode collector advises a retry when no server answered",
  result["retryAdvised"] is True and result["usageStatusText"] == "OpenCode limits unavailable",
  json.dumps(result),
)

clear_key()
collector.urllib.request.urlopen = answer({"usage": {"rolling": {"percent": 1}}})
result = collector.collect_limits(True)
check(
  "OpenCode collector falls back to local stats without a key",
  result["limits"] == [] and result["usageStatusText"] == "Local usage only" and result["authHelpText"] != "",
  json.dumps(result),
)

# A cached percentage is only good until its window resets.
collector.cache_root().mkdir(parents=True, exist_ok=True)
limits_cache.write_text(json.dumps({
  "fetchedAtMs": 0,
  "limits": [
    {"label": "Rolling (5h)", "percent": 0.9, "resetsAt": "2020-01-01T00:00:00.000Z"},
    {"label": "Monthly", "percent": 0.4, "resetsAt": "2999-01-01T00:00:00.000Z"},
  ],
}))
result = collector.collect_limits(True)
check(
  "OpenCode collector drops a cached window that has already reset",
  [w["label"] for w in result["limits"]] == ["Monthly"],
  json.dumps(result),
)

# The key can come from opencode's own credential store or, when a machine
# codes through pi, from pi's.
opencode_home = os.path.join(home, "opencode-data")
os.makedirs(os.path.join(opencode_home, "opencode"), exist_ok=True)
with open(os.path.join(opencode_home, "opencode", "auth.json"), "w") as handle:
  json.dump({"opencode": {"type": "api_key", "key": "from_opencode"}}, handle)
os.environ["XDG_DATA_HOME"] = opencode_home
check("OpenCode collector reads opencode's own credential", collector.subscription_key() == "from_opencode")

clear_key()
pi_home = os.path.join(home, "pi")
os.makedirs(os.path.join(pi_home, ".pi", "agent"), exist_ok=True)
with open(os.path.join(pi_home, ".pi", "agent", "auth.json"), "w") as handle:
  json.dump({"opencode-go": {"type": "api_key", "key": "from_pi"}}, handle)
os.environ["HOME"] = pi_home
check("OpenCode collector reads pi's credential as a last resort", collector.subscription_key() == "from_pi")
PY
