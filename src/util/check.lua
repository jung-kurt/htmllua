local err, hnd
local ok = {}
local gllist = {}
if #arg > 1 then
  hnd, err = io.popen(arg[1] .. ' -o /dev/null -l ' .. arg[2])
  if hnd then
    for j = 3, #arg do
      ok[arg[j]] = true
    end
    for str in hnd:lines() do
      if str:match(']%s+SETTABUP.*_ENV', 1, true) then
        local sym = str:match('"(.-)"')
        if sym then
          if not ok[sym] then
            gllist[#gllist + 1] = sym
          end
        end
      end
    end
    hnd:close()
  end
else
  err = 'expecting arguments LUAC_PATH and LUA_TO_CHECK'
end
if err then
  io.stderr:write(err, '\n')
  os.exit(1)
elseif #gllist > 0 then
  io.write('globals found in ', arg[2], ':')
  for j, str in ipairs(gllist) do
    io.write(' ', str)
  end
  io.write('\n')
  os.exit(2)
end
os.exit(0)
