"""Runs a harness (Lua 5.1, lupa) with XMLPARSE(path): an XML file as nested Lua tables
{ tag = "Frame", attrs = { name = ... }, text = "...", [1] = child, ... }. Usage: full_run.py <harness.lua> <addon dir>"""
import sys
import xml.etree.ElementTree as ET
from lupa import lua51
L = lua51.LuaRuntime(unpack_returned_tuples=True)
def strip(tag): return tag.split("}", 1)[1] if "}" in tag else tag
def convert(el):
    t = L.table()
    t["tag"] = strip(el.tag)
    a = L.table()
    for k, v in el.attrib.items():
        a[strip(k)] = v
    t["attrs"] = a
    t["text"] = el.text or ""
    for i, ch in enumerate(el, 1):
        t[i] = convert(ch)
    return t
def xmlparse(path):
    try:
        return convert(ET.parse(path).getroot())
    except Exception as e:
        return str(e)
L.globals().XMLPARSE = xmlparse
src = open(sys.argv[1], encoding="utf-8").read()
fn = L.execute("return function(src, mod) local f, e = loadstring(src, '@harness'); if not f then error(e) end return f(mod) end")
fn(src, sys.argv[2])
