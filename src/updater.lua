--%%name:ERUpdater
--%%type:com.fibaro.genericDevice
--%%desktop:true
--%%uid:f1e8b33e2-3c4b-2c5a-9f6a-7b8c2369e1f2c
--%%save:dist/ERUpdater.fqa

--%%u:{label='l1', text="ER Updater"}

--%%u:{select='qaList', options={}, onToggled='qaList'}
--%%u:{select='qaVersion', options={}, onToggled='qaVersion'}
--%%u:{select='qaInstance', options={}, onToggled='qaInstance'}

--%%u:{label='sel', text=''}

--%%u:{{button='upd', text="Update", onReleased='updateClicked'},{button='ref', text="Refresh", onReleased='refreshClicked'},{button='install', text="Install", onReleased='installClicked'}}
--%%file:$fibaro.lib.Selectable,selectable
--%%u:{label='msg', text=''}
--%% offline:true

local VERSION = "0.0.49"
local fmt = string.format

local function map(f,t) for k,v in pairs(t) do f(v,k) end end
local QATYPE,QATAG,QAID = "?","?","?"

QAList = {}
class "QAList"(Selectable)
function QAList:__init(qa) Selectable.__init(self,qa,"qaList") end
function QAList:text(item) return item.name end -- { name=..., path=..., uid=..., ...}
function QAList:value(item) return item.uid end
function QAList:sort(a,b) return a.name < b.name end -- sort list by name
function QAList:selected(item)  -- select QA list item
  quickApp:git_getQATags('jangabrielsson',item.name,function(ok,data)
    local tags = {}
    if ok then
      local tags0 = json.decode(data)
      for i=1,5 do local t = tags0[i]; if t==nil then break end tags[#tags+1] = {name=t.name, uid=t.name} end
    end
    local devs = api.get("/devices?property=[quickAppUuid,"..item.uid.."]") or {}
    QATYPE,QATAG,QAID = item.name,"?","?"
    quickApp:updateView("sel","text",fmt("%s:%s:%s",QATYPE,QATAG,QAID))
    self.qa.QAversions:update(tags)
    self.qa.QAinstance:update(devs)
  end)

end

QAversions = {}
class "QAversions"(Selectable)
function QAversions:__init(qa) Selectable.__init(self,qa,"qaVersion") end
function QAversions:text(item) return item.name end
function QAversions:value(item) return item.uid end
function QAversions:sort(a,b) return a.name >= b.name end
function QAversions:selected(item) -- {name=.., value=...} item selected 
  QATAG = item.name
  quickApp:updateView("sel","text",fmt("%s:%s:%s",QATYPE,QATAG,QAID))
end

QAinstance = {}
class "QAinstance"(Selectable)
function QAinstance:__init(qa) Selectable.__init(self,qa,"qaInstance") end
function QAinstance:text(item) return fmt("%s:%s (%s)",item.id,item.name,item.properties.model or "") end
function QAinstance:value(item) return item.id end
function QAinstance:sort(a,b) return a.name < b.name end
function QAinstance:selected(item) -- {name=.., value=...} item selected 
  QAID = item.id
  quickApp:updateView("sel","text",fmt("%s:%s:%s",QATYPE,QATAG,QAID))
end

function QuickApp:onInit()
  quickApp = self
  self:debug(self.name,self.id)
  self:updateView('l1',"text",fmt("QA Manager v%s",VERSION))

  self.QAList = QAList(self)
  self.QAversions = QAversions(self)
  self.QAinstance = QAinstance(self)
  self.QAversions:update({})
  self.QAinstance:update({})

  self:updateView('sel',"text","")
  self:updateView('msg',"text","")
  setInterval(function() self:refreshClicked() end, 60*60*1000) -- Refresh every hour
  self:refreshClicked()
end

function QuickApp:refreshClicked()
  self:git_getRepo(function(ok,data)
    if not ok then 
      self:ERROR(self:message("Failed to get QA manifest: %s",data))
      return
    end
    local repos = json.decode(data)
    for k,v in pairs(repos) do v.name = k end
    self.QAList:update(repos)
  end)
end

function QuickApp:installClicked()
  if not version then
    self:ERROR("Please select a version")
    return
  end
  self:git_getQA('jangabrielsson','EventRunner6',"dist/EventRunner6.fqa",version,function(ok,data)
    if not ok then 
      self:ERROR(self:message("Failed to get EventRunner6 v%s",version))
      return
    end
    data = json.decode(data)
    local res,code = api.post("/quickApp/",data)
    if code > 202 then 
      self:ERROR(self:message("Failed to install EventRunner6 %s %s",version,data))
    else
      self:INFO(self:message("Installed EventRunner6 v%s as ID %s.",version,res.id))
      self:refreshClicked()
    end
  end)
end

function QuickApp:versionSelected(ev)
  version = ev.values[1]
  self:updateView("sel",'text',fmt("Selected: %s / %s",qadev or "?",version or "?"))
end

function QuickApp:qadevSelected(ev)
  qadev = tonumber(ev.values[1])
  self:updateView("sel",'text',fmt("Selected: %s / %s",qadev or "?",version or "?"))
end

function QuickApp:updateClicked(ev)
  if not qadev or not version then
    self:ERROR(self:message("Please select both EventRunner6 and version"))
    return
  end
  self:updateMe(qadev, nil, version)
end

function QuickApp:INFO(...) self:debug(fmt(...)) end
function QuickApp:ERROR(...) self:error(fmt(...)) end

function QuickApp:updateMe(id, myVersion, toVersion)
  local id = tonumber(id)
  if id == nil then
    self:error("No valid EventRunner6 ID")
    return
  end
  self:git_getQA('jangabrielsson','EventRunner6',"dist/EventRunner6.fqa",toVersion,function(ok,data)
    if ok then
      self:INFO(self:message("Found version v%s", toVersion))
      local fqa = json.decode(data)
      local files,main = fqa.files,nil
      for i,f in ipairs(files) do if f.isMain then main = i break end end
      if not main then
        self:ERROR(self:message("No main file found in EventRunner6 v%s",toVersion))
        return
      end
      table.remove(files,main) -- skip main
      local res,code = api.put("/quickApp/"..id.."/files", files)
      if code > 202 then
        self:ERROR(self:message("Failed to update EventRunner6 %s files",toVersion))
        return
      end
      self:INFO(self:message("Updated %d files",#files))
    else
      self:ERROR(self:message("Failed to get EventRunner6 v%s",toVersion))
      -- Send error response
    end
  end)
end

function QuickApp:git_getRepo(cb)
  net.HTTPClient():request("https://raw.githubusercontent.com/jangabrielsson/plua/refs/heads/main/docs/QAs.json",{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
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

function QuickApp:message(fm,...)
  local args,str = {...},fm or ""
  if #args > 0 then str = fmt(fm,...) end
  self:updateView('msg','text',str)
  return str
end

function urlencode(str) -- very useful
  if str then
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w %-%_%.%~])", function(c) return ("%%%02X"):format(string.byte(c)) end)
    str = str:gsub(" ", "%%20")
  end
  return str
end