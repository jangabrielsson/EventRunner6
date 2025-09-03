local function loadFuns(er)
  print("Loading addons...")
  local fmt = string.format
  local var = er.variables
  var.QA = er.qa
  local uptime = os.time() - api.get("/settings/info").serverStatus
  local uptimeStr = fmt("%d days, %d hours, %d minutes",uptime // (24*3600),(uptime % 24*3600) // 3600, (uptime % 3600) // 60)
  var.uptime = uptime
  var.uptimeStr = uptimeStr
  var.uptimeMinutes = uptime // 60
  
  -- Example of home made property object
  Weather = {}
  er.definePropClass("Weather") -- Define custom weather object
  function Weather:__init() PropObject.__init(self) end
  function Weather.getProp.temp(prop,env) return api.get("/weather").Temperature end
  function Weather.getProp.humidity(prop,env) return  api.get("/weather").Humidity end
  function Weather.getProp.wind(prop,env) return  api.get("/weather").Wind end
  function Weather.getProp.condition(prop,env) return  api.get("/weather").WeatherCondition end
  function Weather.trigger.temp(prop) return {type='weather', property='Temperature'} end
  function Weather.trigger.humidity(prop) return {type='weather', property='Humidity'} end
  function Weather.trigger.wind(prop) return {type='weather', property='Wind'} end
  function Weather.trigger.condition(prop) return {type='weather', property='WeatherCondition'} end
  var.weather = Weather()
  
  -- Sync http call
--[[
  local function httpCall(cb,url,options,data,dflt)
        local opts = table.copy(options)
        opts.headers = opts.headers or {}
        if opts.type then
            opts.headers["content-type"]=opts.type
            opts.type=nil
        end
        if not opts.headers["content-type"] then
            opts.headers["content-type"] = 'application/json'
        end
        if opts.user and opts.pwd then 
            opts.headers['Authorization']= fibaro.utils.basicAuthorization((opts.user or ""),(opts.pwd or ""))
            opts.user,opts.pwd=nil,nil
        end
        opts.data = data and json.encode(data)
        --opts.checkCertificate = false
        local basket = {}
        net.HTTPClient():request(url,{
            options=opts,
            success = function(res0)
                pcall(function()
                    res0.data = json.decode(res0.data)  
                end)
                cb(res0.data or dflt,res0.status)
            end,
            error = function(err) cb(dflt,err) end
        })
        return opts.timeout and opts.timeout//1000 or 30*1000,"HTTP"
    end
    
    local http = {
        get = ER.asyncFun(function(cb,url,options,dflt) options=options or {}; options.method="GET" return httpCall(cb,url,options,dflt) end),
        put = ER.asyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="PUT" return httpCall(cb,url,options,data,dflt) end),
        post = ER.asyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="POST" return httpCall(cb,url,options,data,dflt) end),
        delete = ER.asyncFun(function(cb,url,options,dflt) options=options or {}; options.method="DELETE" return httpCall(cb,url,options,dflt) end),
    }
    
    var.http = http
    
    local function hc3api(cb,method,api,data)
        local creds = defVars._creds
        if not creds then setTimeout(function() cb(nil,404) end,0) end
        net.HTTPClient():request("http://localhost/api"..api,{
            options = {
                method = method or "GET",
                headers = {
                    ['Accept'] = 'application/json',
                    ["Authorization"] = creds,
                    ['X-Fibaro-Version'] = '2',
                   -- ["Content-Type"] = "application/json",
                },
                data = data and json.encode(data) or nil
            },
            success = function(resp)
                cb(json.decode(resp.data),200)
            end,
            error = function(err)
                cb(nil,err)
            end
        })
    end

    local api2 = {
        get = ER.asyncFun(function(cb,path) return hc3api(cb,"GET",path,nil) end),
        put = ER.asyncFun(function(cb,path,data) return hc3api(cb,"PUT",path,data) end),
        post = ER.asyncFun(function(cb,path,data) return hc3api(cb,"POST",path,data) end),
        delete = ER.asyncFun(function(cb,path) return hc3api(cb,"DELETE",path,nil) end),
    }
    var.hc3api = api2
    var._hc3api = hc3api
--]]
end

setTimeout(function() loadFuns(fibaro.EventRunner._er) end,0)
