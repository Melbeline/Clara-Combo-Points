import sys
from lupa.lua51 import LuaRuntime
lua = LuaRuntime()
src = open(sys.argv[1]).read()
f = lua.execute("return function(src, p) local fn = assert(loadstring(src)); return fn(p) end")
f(src, sys.argv[2])
