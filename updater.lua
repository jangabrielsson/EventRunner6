--%%name:ERUpdater
--%%type:com.fibaro.genericDevice
--%%uid:f1e8b22e2-3c4b-4d5a-9f6a-7b8c2360e1f2c

function QuickApp:onInit()
end

function QuickApp:updateMe(id)
  self:git_getQATags('jangabrielsson','EventRunner6',function(ok,data)
    if ok then
      self:debug("Tags: "..data)
    else
      self:debug("Failed to get tags: "..data)
    end
  end)
end


function QuickApp:git_getQA(user,repo,name,tag,cb)
  local url = urlencode(fmt("/%s/%s/%s/%s",user,repo,tag,name))
  url = "https://raw.githubusercontent.com"..url
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