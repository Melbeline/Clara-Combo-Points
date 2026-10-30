import sys
from lupa import lua51
L = lua51.LuaRuntime(unpack_returned_tuples=True)
src = open(sys.argv[1], encoding="utf-8").read()
fn = L.execute("return function(src, mod) local f, e = loadstring(src, '@harness'); if not f then error(e) end return f(mod) end")
fn(src, sys.argv[2])
