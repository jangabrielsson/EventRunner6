local function module(er)
  print("My rule")
  er.rule("@sunset => log('Sunset reached!')")
end

setTimeout(function()
  fibaro.registerModule("Lighting", -10, module)
end,0)
