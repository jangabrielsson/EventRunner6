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
            opts.headers['Authorization']= "Basic "..er.base64encode((opts.user or "")..":"..(opts.pwd or ""))
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
        return tonumber(opts.timeout) and opts.timeout*1000 or 30*1000
    end
    
    local http = {
        get = er.createAsyncFun(function(cb,url,options,dflt) options=options or {}; options.method="GET" return httpCall(cb,url,options,dflt) end),
        put = er.createAsyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="PUT" return httpCall(cb,url,options,data,dflt) end),
        post = er.createAsyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="POST" return httpCall(cb,url,options,data,dflt) end),
        delete = er.createAsyncFun(function(cb,url,options,dflt) options=options or {}; options.method="DELETE" return httpCall(cb,url,options,dflt) end),
    }
    
    var.http = http
    
    local function hc3api(cb,method,api,data)
        local creds = er.variables._creds
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
        get = er.createAsyncFun(function(cb,path) return hc3api(cb,"GET",path,nil) end),
        put = er.createAsyncFun(function(cb,path,data) return hc3api(cb,"PUT",path,data) end),
        post = er.createAsyncFun(function(cb,path,data) return hc3api(cb,"POST",path,data) end),
        delete = er.createAsyncFun(function(cb,path) return hc3api(cb,"DELETE",path,nil) end),
    }
    var.hc3api = api2
    var._hc3api = hc3api

    ---- Dim light support
    local equations = {}
    function equations.linear(t, b, c, d) return c * t / d + b; end
    function equations.inQuad(t, b, c, d) t = t / d; return c * (t ^ 2) + b; end
    function equations.inOutQuad(t, b, c, d) t = t / d * 2; return t < 1 and c / 2 * (t ^ 2) + b or -c / 2 * ((t - 1) * (t - 3) - 1) + b end
    function equations.outInExpo(t, b, c, d) return t < d / 2 and equations.outExpo(t * 2, b, c / 2, d) or equations.inExpo((t * 2) - d, b + c / 2, c / 2, d) end
    function equations.inExpo(t, b, c, d) return t == 0 and b or c * (2 ^ (10 * (t / d - 1))) + b - c * 0.001 end
    function equations.outExpo(t, b, c, d) return t == d and  b + c or c * 1.001 * ((2 ^ (-10 * t / d)) + 1) + b end
    function equations.inOutExpo(t, b, c, d)
        if t == 0 then return b elseif t == d then return b + c end
        t = t / d * 2
        if t < 1 then return c / 2 * (2 ^ (10 * (t - 1))) + b - c * 0.0005 else t = t - 1; return c / 2 * 1.0005 * ((2 ^ (-10 * t)) + 2) + b end
    end
    
    local function dimLight(id,sec,dir,step,curve,start,stop)
        assert(tonumber(sec), "Bad dim args for deviceID:%s",id)
        local f = curve and equations[curve] or equations['linear']
        dir,step = dir == 'down' and -1 or 1, step or 1
        start,stop = start or 0,stop or 99
        fibaro.post({type='%dimLight',id=id,sec=sec,dir=dir,fun=f,t=dir == 1 and 0 or sec,start=start,stop=stop,step=step,_sh=true})
    end
    
    extraSetups[#extraSetups+1] = function()
        fibaro.event({type='%dimLight'},function(env)
            local e = env.event
            local ev,currV = e.v or -1,tonumber(fibaro.getValue(e.id,"value"))
            if not currV then
                fibaro.warningf(__TAG,"Device %d can't be dimmed. Type of value is %s",e.id,type(fibaro.getValue(e.id,"value")))
            end
            if e.v and math.abs(currV - e.v) > 2 then return end -- Someone changed the lightning, stop dimming
            e.v = math.floor(e.fun(e.t,e.start,(e.stop-e.start),e.sec)+0.5)
            if ev ~= e.v then fibaro.call(e.id,"setValue",e.v) end
            e.t=e.t+e.dir*e.step
            if 0 <= e.t and  e.t <= e.sec then fibaro.post(e,os.time()+e.step) end
        end)
    end

end

setTimeout(function() fibaro.loadLibrary(loadFuns) end,0)
