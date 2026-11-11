-- The world map in a fight (ClassicUI's Era look): no secure frame of ours hung on it, so it stays unprotected and the
-- game's own code opens, closes and relevels it in a fight (a secure child made it protected: refused when tainted)
local H = ...
local env = H.env
local n = 0
for _, f in ipairs(H.frames or {}) do
  local t = rawget(f, "__template")
  if type(t) == "string" and t:find("SecureHandlerShowHideTemplate", 1, true) then n = n + 1 end
end
print("scenario: secure show/hide watchers made: " .. n)
