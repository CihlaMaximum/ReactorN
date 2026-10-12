local component=require("component")
local computer=require("computer")
local config=require("config.config")
local M={last=-1e9,fluid=0,cpu={processors={},idle=0,busy=0,total=0}}
function M.update(force)
 local now=computer.uptime(); if not force and now-M.last<config.meInterval then return nil end; M.last=now
 if not component.isAvailable("me_controller") then M.fluid=0; return {fluid=0,cpu=M.cpu,available=false} end
 local c=component.me_controller
 local ok,cpus=pcall(function() return c.getCpus() end); cpus=ok and cpus or {}; local data={processors={},idle=0,busy=0,total=#cpus}
 for i,cpu in ipairs(cpus) do data.processors[i]={busy=cpu.busy==true}; if cpu.busy then data.busy=data.busy+1 else data.idle=data.idle+1 end end
 local ok2,items=pcall(function() return c.getItemsInNetwork({name=config.fluidItemName}) end); local total=0
 if ok2 and type(items)=="table" then for _,item in ipairs(items) do if item and item.size and (not item.label or item.label:find(config.fluidLabel,1,true)) then total=total+(tonumber(item.size) or 0) end end end
 M.fluid=total; M.cpu=data; return {fluid=total,cpu=data,available=true}
end
function M.getFluid() return M.fluid end
function M.getCPU() return M.cpu end
return M
