"""Reads the game's generated API documentation (Lua tables) and writes apidoc.lua: namespaces and their
functions with return types, global functions, script object (widget) methods, enumerations, constants,
structures and events. Usage: extract_apidoc.py <Blizzard_APIDocumentationGenerated dir> <out.lua>"""
import sys, os
from lupa import lua51
src, out = sys.argv[1], sys.argv[2]
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute("""
DOCS = {}
APIDocumentation = { AddDocumentationTable = function(self, t) DOCS[#DOCS + 1] = t end }
local function deep() return setmetatable({}, { __index = function() return 0 end }) end
setmetatable(_G, { __index = function(t, k) if type(k) == "string" and k:match("^%u") then local v = setmetatable({}, { __index = function() return deep() end }); rawset(t, k, v); return v end end })
""")
for f in sorted(os.listdir(src)):
    if f.endswith(".lua"):
        code = open(os.path.join(src, f), encoding="utf-8").read()
        L.execute(code)
# serialize to a compact Lua data file
L.execute(r"""
local function q(s) return string.format("%q", tostring(s)) end
local out = {}
local function emit(s) out[#out + 1] = s end
local function rets(fn)
  local r = {}
  for _, v in ipairs(fn.Returns or {}) do
    r[#r + 1] = "{" .. q(v.Type) .. "," .. tostring(v.Nilable and true or false) .. (v.InnerType and ("," .. q(v.InnerType)) or "") .. "}"
  end
  return "{" .. table.concat(r, ",") .. "}"
end
emit("return {")
emit("systems = {")
for _, d in ipairs(DOCS) do
  if d.Type == "System" then
    emit("{ name = " .. q(d.Name) .. ", ns = " .. (d.Namespace and q(d.Namespace) or "nil") .. ", functions = {")
    for _, fn in ipairs(d.Functions or {}) do emit("[" .. q(fn.Name) .. "] = " .. rets(fn) .. ",") end
    emit("}, events = {")
    for _, ev in ipairs(d.Events or {}) do emit(q(ev.LiteralName or ev.Name) .. ",") end
    emit("} },")
  end
end
emit("}, scriptObjects = {")
for _, d in ipairs(DOCS) do
  if d.Type == "ScriptObject" then
    emit("[" .. q(d.Name) .. "] = {")
    for _, fn in ipairs(d.Functions or {}) do emit("[" .. q(fn.Name) .. "] = " .. rets(fn) .. ",") end
    emit("},")
  end
end
emit("}, tables = {")
for _, d in ipairs(DOCS) do
  for _, t in ipairs(d.Tables or {}) do
    if t.Type == "Enumeration" then
      emit("{ kind = 'enum', name = " .. q(t.Name) .. ", values = {")
      for _, f in ipairs(t.Fields or {}) do if f.EnumValue then emit("[" .. q(f.Name) .. "] = " .. tostring(f.EnumValue) .. ",") end end
      emit("} },")
    elseif t.Type == "Constants" then
      emit("{ kind = 'const', name = " .. q(t.Name) .. ", values = {")
      for _, f in ipairs(t.Values or {}) do
        local v = f.Value
        if type(v) == "number" or type(v) == "boolean" then emit("[" .. q(f.Name) .. "] = " .. tostring(v) .. ",")
        elseif type(v) == "string" then emit("[" .. q(f.Name) .. "] = " .. q(v) .. ",") end
      end
      emit("} },")
    elseif t.Type == "Structure" then
      emit("{ kind = 'struct', name = " .. q(t.Name) .. ", fields = {")
      for _, f in ipairs(t.Fields or {}) do emit("{" .. q(f.Name) .. "," .. q(f.Type) .. "," .. tostring(f.Nilable and true or false) .. "},") end
      emit("} },")
    end
  end
end
emit("} }")
RESULT = table.concat(out, "\n")
""")
open(out, "w", encoding="utf-8").write(L.globals().RESULT)
print("docs", len(L.globals().DOCS))
