------------------
-- Arithmetic.
------------------

------------------
-- Arithmetic evaluation.
--
-- Lua is already a calculator, so the work is not evaluating the expression but
-- refusing to evaluate anything that is not one. Two gates: the text may only
-- contain arithmetic characters, and every identifier in it must be one of the
-- names below. It then runs through `load` with those names as its *entire*
-- environment -- checked: `os` and friends are not reachable from inside.
------------------

local MATH_ENV = {
  abs = math.abs,
  ceil = math.ceil,
  floor = math.floor,
  sqrt = math.sqrt,
  exp = math.exp,
  log = math.log,
  sin = math.sin,
  cos = math.cos,
  tan = math.tan,
  min = math.min,
  max = math.max,
  fmod = math.fmod,
  pi = math.pi,
  e = math.exp(1),
}

local function eval_math(text)
  local expr = vim.trim(text)
  -- Only arithmetic characters. Anything else is not an expression.
  if expr == "" or expr:find("[^%w%s%+%-%*/%%%^%(%)%.,_]") then
    return nil
  end
  -- Every name must be one we deliberately exposed.
  for word in expr:gmatch("[%a_][%w_]*") do
    if MATH_ENV[word] == nil then
      return nil
    end
  end
  -- Require an actual operation: a bare `42` is not a calculation.
  if not expr:find("[%+%-%*/%%%^]") and not expr:find("%(") then
    return nil
  end
  local fn = load("return " .. expr, "=math", "t", MATH_ENV)
  if not fn then
    return nil
  end
  local ok, v = pcall(fn)
  -- Reject NaN and infinities: `1/0` is not a useful thing to paste into code.
  if not ok or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
    return nil
  end
  if v == math.floor(v) and math.abs(v) < 2 ^ 53 then
    return string.format("%d", v)
  end
  return (string.format("%.10g", v))
end

return {
  {
    name = "Evaluate math",
    ft = "text",
    -- Cheap shape check first; `eval_math` does the real validation.
    supported = { "%d", "[%+%-%*/%%%^%(]" },
    run = function(t)
      return eval_math(t)
    end,
  },
}
