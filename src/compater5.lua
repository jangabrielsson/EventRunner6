MODULES = MODULES or {}

local function loadModule(m,er)
  m._inited = true
  if not m._inited then
    m._inited = true
    print("Loading rules from ",m.name)
    m.loader(er)
  end
end

function LoadModules(er) -- global lua function
  table.sort(MODULES,function(a,b) return a.prio < b.prio end) -- Sort modules in priority order
  
  local afterModules = 0
  for i=1,#MODULES do
    if MODULES[i].prio < 0 then loadModule(MODULES[i],er)
    else 
      afterModules = i
      break 
    end
  end
  setTimeout(function()
    for i=afterModules,#MODULES do loadModule(MODULES[i],er) end
  end,0)
  return #MODULES>=1
end

local function funs(er)
  er.var = er.variables
  er.triggerVar = er.triggerVariables
  function er.defVar(name,init) er.variables[name] = init end
  function er.defTriggerVar(name,init) er.triggerVariables[name] = init end
  function er.defvars(tab) 
    assert(type(tab) =="table","Expected a table")
    for k,v in pairs(tab) do er.variables[k] = v end
  end
  function er.reverseMapDef(_) end
  function er.reverseVar(id) return id end
end

MODULES[#MODULES+1]={name='ER5_compatibility',prio=-5,loader=funs}