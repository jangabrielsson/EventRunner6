---MODULES[#MODULES+1]={name='myName',prio=1,loader=rules}
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


