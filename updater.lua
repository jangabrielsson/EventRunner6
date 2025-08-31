--%%name:ERUpdater
--%%type:com.fibaro.genericDevice
--%%desktop:true
--%%uid:f1e8b33e2-3c4b-2c5a-9f6a-7b8c2369e1f2c
--%%save:ERUpdater.fqa
--%%u:{label='l1', text="ER Updater"}
--%%u:{select='version', options={}, onToggled='versionSelected'}
--%%u:{select='qa', options={}, onToggled='qaSelected'}
--%%u:{label='sel', text=''}
--%%u:{{button='upd', text="Update", onReleased='updateClicked'},{button='ref', text="Refresh", onReleased='refreshClicked'},{button='install', text="Install", onReleased='installClicked'}}

local VERSION = "0.0.4"
local ER_UUID = "f1e8b22e2-3c4b-4d5a-9f6a-7b8c2360e1f2c"
local fmt = string.format

function QuickApp:onInit()
  self:debug(self.name,self.id)
  self:updateView('sel',"text","")
  setInterval(function() self:refreshClicked() end, 60*60*1000) -- Refresh every hour
  self:refreshClicked()
end

function QuickApp:refreshClicked()
  local res = api.get("/devices?property=[quickAppUuid,"..ER_UUID.."]") or {}
  local ers = {{type='option', text="---", value=""}}
  for _,q in ipairs(res) do ers[#ers+1] = {type='option', text=fmt("%s: %s",q.id,q.name),value=tostring(q.id)} end
  self:updateView('qa','options',ers)
  self:git_getQATags('jangabrielsson','EventRunner6',function(ok,data)
    local vers = {{type'option', text="---", value=""}}
    if ok then
      local tags = json.decode(data)
      for _,t in ipairs(tags) do 
        vers[#vers+1] = {type='option', text=t.name, value=t.name} 
      end
    end
    self:updateView('version','options',vers)
  end)
end

function QuickApp:installClicked()
end

local qa,version = nil,nil
function QuickApp:versionSelected(ev)
  version = ev.values[1]
  self:updateView("sel",'text',fmt("Selected: %s / %s",qa or "?",version or "?"))
end

function QuickApp:qaSelected(ev)
  qa = tonumber(ev.values[1])
  self:updateView("sel",'text',fmt("Selected: %s / %s",qa or "?",version or "?"))
end

function QuickApp:updateClicked(ev)
  if not qa or not version then
    self:ERROR("Please select both EventRunner6 and version")
    return
  end
  self:updateMe(qa, nil, version)
end

function QuickApp:INFO(...) self:debug(fmt(...)) end
function QuickApp:ERROR(...) self:error(fmt(...)) end

function QuickApp:updateMe(id, myVersion, toVersion)
  local id = tonumber(id)
  if id == nil then
    self:error("No valid EventRunner6 ID")
    return
  end
  self:git_getQA('jangabrielsson','EventRunner6',"EventRunner6.fqa",toVersion,function(ok,data)
    if ok then
      self:INFO("Found version v%s", toVersion)
      local fqa = json.decode(data)
      local files,main = fqa.files,nil
      for i,f in ipairs(files) do if f.isMain then main = i break end end
      if not main then
        self:ERROR("No main file found in EventRunner6 v%s",toVersion)
        return
      end
      table.remove(files,main) -- skip main
      local res,code = api.put("/quickApp/"..id.."/files", files)
      if code > 202 then 
        self:ERROR("Failed to update EventRunner6 v%s files",toVersion)
        return
      end
      self:INFO("Updated %d files",#files)
    else
      self:ERROR("Failed to get EventRunner6 v%s",toVersion)
      -- Send error response
    end
  end)
end

function QuickApp:git_getQA(user,repo,name,tag,cb)
  local url = urlencode(fmt("%s/%s/%s/%s",user,repo,tag,name))
  url = "https://raw.githubusercontent.com/"..url
  net.HTTPClient():request(url,{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
end

function QuickApp:git_getQATags(user,repo,cb)
  local url = fmt("https://api.github.com/repos/%s/%s/tags",user,repo)
  net.HTTPClient():request(url,{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
end

function urlencode(str) -- very useful
  if str then
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w %-%_%.%~])", function(c) return ("%%%02X"):format(string.byte(c)) end)
    str = str:gsub(" ", "%%20")
  end
  return str
end