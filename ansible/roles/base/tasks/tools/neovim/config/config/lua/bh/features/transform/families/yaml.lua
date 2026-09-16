------------------
-- YAML, via python3 + pyyaml.
--
-- pyyaml rather than a Lua round-trip because it preserves key order, and
-- because there is no pure-Lua YAML parser worth trusting. A missing
-- interpreter or module means these entries simply never appear.
------------------

local u = require("bh.features.transform.util")

local PY_J2Y = [[
import sys, json, yaml
yaml.safe_dump(json.loads(sys.stdin.read()), sys.stdout,
               sort_keys=False, default_flow_style=False, allow_unicode=True)
]]

local PY_Y2J = [[
import sys, json, yaml
d = yaml.safe_load(sys.stdin.read())
if d is None or isinstance(d, (str, int, float, bool)):
    sys.exit(1)
json.dump(d, sys.stdout, indent=2, ensure_ascii=False, sort_keys=False)
]]

return {
  {
    name = "JSON → YAML",
    ft = "yaml",
    supported = function(t)
      return u.is_json(t) and u.python_module("yaml")
    end,
    run = function(t)
      return u.sh({ "python3", "-c", PY_J2Y }, t)
    end,
  },
  {
    name = "YAML → JSON",
    ft = "json",
    -- JSON is itself valid YAML, so without the `not` every JSON buffer would
    -- also offer a pointless "YAML → JSON".
    supported = function(t)
      return not u.is_json(t) and u.python_module("yaml")
    end,
    run = function(t)
      return u.sh({ "python3", "-c", PY_Y2J }, t)
    end,
  },
}
