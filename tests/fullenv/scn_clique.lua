-- The built-in Clique's binding page in the harness: the "Not on the target frame" box made under the Where choices
-- (the Units heading below it), checked from the binding, saved with it, and the binding's snippet keeping off the
-- target frame.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local A = ns.CliquePrivate
check(ns.CliqueRuns and type(A) == "table", "the built-in Clique runs")
if A then
  local config = A:GetBindingConfig()
  local ok, e = pcall(function() env.SlashCmdList["CLIQUE"]("") end)
  check(ok, "/clique opens: " .. tostring(e))
  local page = config:GetEditPage()
  local bind = { key = "BUTTON3", type = "spell", spell = "Abolish Disease", sets = { default = true, friend = true }, nottarget = true }
  A.bindings = A.bindings or {}
  table.insert(A.bindings, bind)
  ok, e = pcall(function() page:ShowEditPageSelectedBinding(bind) end)
  check(ok, "the binding's page shown: " .. tostring(e))
  local box = page.notTargetCheck
  check(box ~= nil, "the box made")
  if box then
    check(box.text and box.text:GetText() == A.L["Not on the target frame"], "its text: " .. tostring(box.text and box.text:GetText()))
  end
  -- (where it sits, its check and the click snippet: test173; the harness's frames keep no points nor check state)
end
print("scenario: clique failures " .. fails)
