-- FreshStuff3 6.0 releases module.
-- Distributed under the MIT license.
-- TODO:
-- Levenshtein + coroutines
-- Commands
-- Config loader
-- get and edit releases
-- for getting the desired command syntax is: music/today, music/new
-- and music/23-59, maybe music/1,5,7,9,13,23-59
-- same as above for deletion (the numbers)

if not Host then 
  package.path = "C:/Users/szaka/Desktop/Linux/devel/"
  .."freshstuff3/freshstuff3/?.lua" 
end
local persistence = require "persistence"
local t = {}
print (string.sub(package.path, 1, -6).."data/releases.lua")
t.AllStuff = persistence.load (string.sub(package.path, 1, -6).."data/releases.lua") or {}
setmetatable (t.AllStuff, {
__len = function (tbl)
  local number = 0
  if tbl[1] then -- non-empty category
    number = #tbl
  else -- empty category or main AllStuff
    for k, v in pairs (tbl) do
      number = number + #v
    end
  end
  return number
end})
t.Commands, t.Coroutines, t.JournalTbl = {}, {}, {}

-- Events: you call these from the event handler Event()
t.CategoryAdded = function (ev, cat, self)
  SendDebug ("added a new category: "..cat)
end

t.RelAdded = function (ev, cat, rel, self)
  SendDebug ("added "..rel.title.." by "..rel.nick.." with ID "..cat.."/"..#self.AllStuff[cat])
end

t.AddCat = function (self, cat)
  if not self.AllStuff[cat] then
    self.AllStuff[cat] = {}
    Event("CategoryAdded", cat, self)
    self:Journal ("releases.lua", "Releases.AllStuff[\""..cat.."\"] = {}")
  else 
    SendDebug ("category already exists!")
  end
end

t.Add = function (self, cat, rel)
  if rel then
    local nick, title = rel.nick, rel.title
    assert (nick and title, "Invalid release object!")
    if self.AllStuff[cat] then
      table.insert (self.AllStuff[cat], {nick = nick, title = title, when = os.date ("*t")})
      self:Journal ("releases.lua", "table.insert(Releases.AllStuff[\""..cat.."\"], {nick = \""
        ..rel.nick.."\", title = \""..rel.title.."\", when = os.date (\"*t\")})")
      Event("RelAdded", cat, rel, self); 
    end
  end
end
t.Add2 = function (self, nick, data)
  local cat, tune=string.match(data,"(%S+)%s+(.+)")
  if cat then
    if Types[cat] then
      for _,word in pairs(ForbiddenWords) do
      if string.find(tune,word,1,true) then
        return "The release name contains the following forbidden"
        .." word (thus not added): "..word, 1
      end
    end
    if Coroutines[nick] then return "A release of yours is already "
      .."being processed. Please wait a few seconds!", 2 end
      local count = #AllStuff
      if count == 0 then
        if ReleaseApprovalPolicy ~= 1 then
          AllStuff(cat, nick, os.date("%m/%d/%Y"), tune)
            --HandleEvent("OnRelAdded", nick, data, cat, tune, count + 1)
            return "\""..tune.."\" has been added to the releases in this "
            .."category: \""..Types[cat].."\" with ID "..count + 1, 2
          else
            PendingStuff(cat, nick, os.date("%m/%d/%Y"), tune)
            return "\""..tune.."\" has been added to the pending releases "
            .."in this category: \""..Types[cat].."\" with ID "..count + 1
            ..", please wait until someone reviews it.", 2
          end
        else
          Releases.Coroutines[nick] = {
            Coroutine = coroutine.create(Main.ComparisonHelper),
            Release = tune,
            CurrID = 0, -- to check rel #1 so avoid off-by-one errors
            Category = cat,
            }
          return "Your release is being processed. You will be notified of"
          .." the result.", 2
        end
      else
        return "Unknown category: "..cat, 1
      end
    else
      return "yea right, like i know what you got 2 add when you don't tell"
      .."me!",1
    end
  end --    ,{},Levels.Add,"<type> <name> // Add release of given type."

-- t.Edit(cat, id[, rel])
-- if rel is unspecified then it deletes and id can be multiple, 
-- looking like {ps2 = {1,2,3,7,31}, music = {1,999}}
-- "music/1-99" and things will be processed in Commands table
-- RelEdited(), RelDeleted()
-- t.Move (id, newCat) with RelMoved() returning a list of moved

t.Get = function (self, Y, M, D)
--  local td, YY, MM, DD; if Y == "today" then td = os.date ("%d/%m/%Y") else td = os.date (
  local td = os.date ("%d/%m/%Y")
  for cat, arr in pairs (self.AllStuff) do
    local c = #arr
    local Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
    local dt = D.."/"..M.."/"..Y
    while c > 0 and dt == td do
      print (td,dt)
      local rel = arr[c]
      result[{cat = cat, ID = c}] = rel
      max = max + 1 
      c = c - 1
      Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
      dt = D.."/"..M.."/"..Y
    end
  end
end

-- Journaling functionality. This one adds a new entry to the journal.
-- We just append so it's fast.
t.Journal = function (self, filename, transaction)
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "a+")
  f:write (transaction.."\n")
  f:close()
end

-- Journal file loading. Note that journals also consist of proper Lua code.
-- Journal has to be deleted at certain intervals (following a successful save)
-- It only exists if the hub did not exit properly so it has to be deleted on a
-- successful exit. This way the FULL database is saved every X seconds only
-- therefore significantly fewer hub-stalling write operations are required.
-- Only if there is a crash in between two full saves will the journal file
-- remain in place.
-- SSD owners will love this.
t.OpenJournal = function (self, filename)
  local JournalTbl = {}
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "r+")
  local c = 0
  if f then
    for line in f:lines() do
      local func = load (line)
      if func then table.insert (JournalTbl, func) end
    end
    f:close ()
  end
  for _, func in ipairs (JournalTbl) do func() c = c + 1 end
  self:DelJournal (filename)
  if c == 0 then SendDebug ("Journal empty.") return end
  SendDebug ("Recovered "..c.." items from journal.")
end

t.DelJournal = function (self, filename)
  os.remove (string.sub(package.path, 1, -6).."journal/"..filename)
  persistence.store (string.sub(package.path, 1, -6).."data/"..filename, self.AllStuff)  
end

-- fake database generator
t.FakeStuff = function (self, num)
  local randomtype = {}
  for k, v in pairs(self.AllStuff) do
    table.insert (randomtype, k)
  end
  for k = 1, num do
    local no = math.random(#randomtype)
    self:Add (randomtype[no], {nick = "bastya_elvtars"..no^3, title = string.sub(os.tmpname (),2,-1)}) 
  end
end

t.OnTimer = function (self)
  t:DelJournal("releases.lua")
end

t.OnExit = t.OnTimer

-- Levenshtein distance algorithm from http://bit.ly/bCGkiX
-- Here I use it for comparing two strings. In my practice, 75% means they're
-- nearly identical so further check is required.
-- @return Is actually the ratio of the difference and the longer string, sub-
-- @return tracted from 1.
t.Levenshtein = function (self, string1, string2)
  string1 = string1:lower(); string2 = string2:lower()
  local str1, str2, distance = {}, {}, {};
  local str1len, str2len = string1:len(), string2:len();
  for s in string.gmatch(string1, "(.)") do
    table.insert(str1, s);
  end
  for s in string.gmatch(string2, "(.)") do
    table.insert(str2, s)
  end
  for i = 0, str1len do
    distance[i] = distance[i] or {}
    distance[i][0] = i;
  end
  for i = 0, str2len do
    distance[i] = distance[i] or {}
    distance[0][i] = i;
  end
  for i = 1, str1len do
    for j = 1, str2len do
      local tmpdist = 1;
      if(str1[i-1] == str2[j-1]) then
        tmpdist = 0;
      end
      distance[i][j] = math.min( distance[i-1][j] + 1,
      distance[i][j-1]+1, distance[i-1][j-1] + tmpdist);
    end
  end
  return 1-distance[str1len][str2len]/math.max(str1len, str2len)
end

t.ComparisonHelper = function (tbl, nick)
  local PIC = 0 -- Processed Items Counter (smart acronym, SRSLY)
  local req, id = tbl.Release, tbl.CurrID
  local match = {}
  local bExact
  while true do -- endless loop
    -- raise release ID by 1
    id = id + 1
    if id > #Releases.AllStuff then
      -- we have reached the last release, so stop this thread
      break
    end
    local percent = 100*Levenshtein (AllStuff[id][4], req) -- compare
    PIC = PIC + 1
    if percent >= MaxMatch then
      table.insert(match, {id, req, percent}) -- there is a match, register
      -- if 100% match found, further checking is futile
      if percent == 100 then return PIC, match; end
    end
    if PIC >= ItemsToCheckAtOnce then -- no more for this session
      Coroutines[nick].CurrID = id -- record the last processed ID
      coroutine.yield(PIC)-- and go sleeping
      PIC = 0
      -- When we wake up, the loop resumes
    end
  end
  id = 0
  while true do
    id = id + 1
    if id > #Releases.PendingStuff then break end
    local percent = 100*Levenshtein (PendingStuff[id][4], req)
    PIC = PIC + 1
    if percent == 100 then -- if matches
      table.insert(match, {id, req, percent, true})
      return PIC, match
    end
    if PIC >= ItemsToCheckAtOnce then
      Coroutines[nick].CurrID = id
      coroutine.yield(PIC)
      PIC = 0
    end
  end
  return PIC, match -- return if there are matches, stopping the coroutine
end

t.MainTableParser = function ()
  local bOK, rePIC, match, nick, tbl
  while true do
    nick, tbl = next (t.Coroutines, nick)
    if nick then
      if coroutine.status(tbl.Coroutine) ~= "dead" then
        bOK, rePIC, match = coroutine.resume(tbl.Coroutine, tbl, nick)
        -- syntax error
        if not bOK then return nil, rePIC; end
        -- the coroutine finished
        if match then return match, tbl, nick end
        -- reached the max number of items, sleep
        if rePIC >= ItemsToCheckAtOnce then coroutine.yield() end
      else
        Coroutines[nick] = nil
      end
    else
      -- If the table is empty, we just return an empty table plus 2 nil's.
      -- If not, the gets returned with friends either non-nil.
      -- See Timer() below.
      return match or {}, tbl, nick
    end
  end
end

t.MainTableHelper = coroutine.create (t.MainTableParser)

function Timer ()
  if coroutine.status (t.MainTableHelper) == "dead" then
    MainTableHelper = coroutine.create (t.MainTableParser)
  end
  local bOK, match, tbl, nick = coroutine.resume (t.MainTableHelper)
  if nick then -- the coroutine explicitly returned = finished
    local tune, cat = tbl.Release, tbl.Category
    if next (match) then
      -- Sort the table in reverse order for percentages.
      -- This ensures that if a 100% is found nothing will get added
      -- afterwards.
      table.sort(match, function (el1, el2)
        return el1[3] > el2[3]
      end)
      for k, v in ipairs (match) do
        local id, rel, percent, bPending = table.unpack (v)
        local msg =
        "\""..rel.."\" has been added to the to-be-reviewed releases "
        .."in this category: \""..Types[cat].."\" with ID "
        ..(#Releases.PendingStuff + 1)
        ..". \r\nIt needs approval by an authorized user before it"
        .."could appear on the list"
        local msg_op = "A release has been added by "..nick.. " that is"
        .." quite similar to the following release(s):\r\n"
        local FoundSame -- boolean for 100% match
        local policy_msg =
        {
        msg..". Note that it is quite similar to the following release(s):",
        msg.." BECAUSE it is quite similar to the following release(s):",
        }
        msg = policy_msg[ReleaseApprovalPolicy] or "\""..tune
        .."\" has been added to the releases in this category: \""
        ..Types[cat].."\" with ID "..(#Releases.AllStuff + 1)..". Note that it is"
        .." quite similar to the following release(s):"
        if percent == 100 then -- identical!
          if bPending then
            PM(nick, "A release with the same name is already "
            .."awaiting  approval. Release has NOT been added.")
          else
            PM(nick, "Your release is identical to the following "
            .."release(s): \r\nID# "..id.." - Name: "..tune
            ..".\r\n\r\nRelease has NOT been added.")
          end
          FoundSame = true
          break -- break the loop, we already have this release
        else
          msg = msg.."\r\n"..id.." - "..tune.." ("..percent.."%)"
          msg_op = msg_op.."\r\n"..id.." - "..tune.." ("..percent
          .."%)"
        end
        if not FoundSame then
          if ReleaseApprovalPolicy ~= 3 then
            msg_op = msg_op.."\r\n\r\nPlease review! Thanks!"
            PendingStuff(cat, nick, os.date("%m/%d/%Y"),
            tune, msg, msg_op)
          else
            AllStuff(cat, nick, os.date("%m/%d/%Y"), tune, msg, msg_op)
          end
        end
      end
    else -- not even a single similar release found, add the stuff
      if ReleaseApprovalPolicy ~= 1 then
        msg = "\""..tbl.Release
        .."\" has been added to the releases in this category: \""
        ..Types[cat].."\" with ID "..(#AllStuff + 1).."."
        AllStuff(cat, nick, os.date("%m/%d/%Y"), tune, msg)
      end
    end
  elseif not bOK then -- there is a syntax error
    SendOut(match) -- forward it to ops
  end
end

return t
