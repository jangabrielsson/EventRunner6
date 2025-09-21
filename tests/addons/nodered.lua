
local function loadLibrary(er)
    local var = er.variables

    local IPaddress
    local function getIPaddress(name)
        if fibaro.plua then
            return fibaro.plua.config.IPAddress
        elseif IPaddress then return IPaddress 
        else
            name = name or ".*"
            local networkdata = api.get("/proxy?url=http://localhost:11112/api/settings/network")
            for n,d in pairs(networkdata.networkConfig or {}) do
                if n:match(name) and d.enabled then IPaddress = d.ipConfig.ip; return IPaddress end
            end
        end
    end
    
    local NR_trans = {}
    function quickApp:fromNodeRed(ev)
        ev = type(ev)=='string' and json.decode(ev) or ev
        local tag = ev._transID
        ev._IP,ev._async,ev._from,ev._transID=nil,nil,nil,nil
        local f = NR_trans[tag]
        if f then
            NR_trans[tag] = nil
            f(ev,200)
        else fibaro.post(ev) end
    end
    
    local function nodePost(event,cb)
        event._from = quickApp.id
        event._IP = getIPaddress()
        local noderedURL = var.noderedURL
        local noderedAuth = var.noderedAuth
        assert(noderedURL,"noderedURL not defined")
        local params =  {
            options = {
                headers = {
                    ['Accept']='application/json',['Content-Type']='application/json', 
                    ['Authorization']=noderedAuth
                },
                data = json.encode(event), 
                timeout=4000, 
                method = 'POST'
            },
            success = function(res)
                _,res.data = pcall(json.decode,res.data)
                cb(res.status,res.data) 
            end,
            error = function(err) cb(err) end
        }
        net.HTTPClient():request(noderedURL,params)
    end
    
    function var.async.nodered(cb,event,dflt)
        event = table.copy(event)
        event._async = false
        nodePost(event,function(status,data)
            if status==200 then
                cb(data,200)
            else
                cb(dflt,status)
            end
        end)
        return 10*1000,"NodeRed"-- Timeout
    end
    
    local NRID = 1
    function var.async.nodered_as(cb,event,dflt)
        event = table.copy(event)
        event._async = true
        event._transID = NRID; NRID=NRID+1
        NR_trans[event._transID] = cb
        nodePost(event,function(status,data)
            if status==200 then
            else
                fibaro.warningf(__TAG,"Nodered %s",status)
                NR_trans[event._transID] = nil
                cb(dflt,status)
            end
        end)
        return 10*1000,"NodeRed" -- Timeout
    end

    var.nr = { post = var.async.nodered, post_as = var.async.nodered_as }
    var.async.nodered, var.async.nodered_as = nil -- cleanup

end

setTimeout(function() fibaro.loadLibrary(loadLibrary) end,0)
