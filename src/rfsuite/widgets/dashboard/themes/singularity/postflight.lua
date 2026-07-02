local rfsuite = require("rfsuite")
local lcd = lcd
local floor, min, max = math.floor, math.min, math.max
local cos, sin, rad = math.cos, math.sin, math.rad
local tonumber, tostring, type = tonumber, tostring, type
local format = string.format
local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
local header_layout = utils.standardHeaderLayout(headeropts)

local C = {
  bg=lcd.RGB(3,5,12), panel=lcd.RGB(8,12,24), line=lcd.RGB(37,57,87), line2=lcd.RGB(75,101,140),
  white=lcd.RGB(228,240,255), muted=lcd.RGB(122,147,177), cyan=lcd.RGB(58,236,255),
  violet=lcd.RGB(170,97,255), green=lcd.RGB(98,255,165), amber=lcd.RGB(255,190,70),
  red=lcd.RGB(255,72,110), magenta=lcd.RGB(255,74,235)
}
local THEME_SECTION="system/singularity"
local DEFAULTS={bec_min=6.5,bec_warn=7.0,esc_warn=110,esc_max=150,fuel_warn=25,link_warn=50,current_warn=120,watts_warn=3500}
local STARS={{3,8},{9,23},{14,13},{21,31},{28,7},{35,20},{43,11},{51,27},{59,6},{67,21},{75,14},{83,30},{91,9},{97,24},{6,49},{17,61},{29,43},{41,70},{54,52},{66,67},{78,47},{89,73},{12,88},{32,91},{49,82},{71,94},{94,85}}

local function pref(k)
  local s=rfsuite and rfsuite.session
  local p=s and s.modelPreferences and s.modelPreferences[THEME_SECTION]
  return (p and tonumber(p[k])) or DEFAULTS[k]
end
local function stat(t,n,mode,a)
  t=t or (rfsuite.tasks and rfsuite.tasks.telemetry)
  local s=t and t.sensorStats
  local d=s and s[n]
  local v=d and d[mode]
  if v~=nil then return tonumber(v) end
  if a then d=s and s[a]; v=d and d[mode]; if v~=nil then return tonumber(v) end end
end
local function fmt(v,d,u)
  if v==nil then return "--" end
  local q=d==1 and format("%.1f",v) or d==2 and format("%.2f",v) or tostring(floor(v+0.5))
  return q..(u or "")
end
local function font(n) return utils.resolveFont(n,nil) end
local function text(x,y,w,s,f,c,a)
  local ft=font(f); if type(ft)~="number" then return end
  lcd.font(ft); lcd.color(c); local tw=lcd.getTextSize(s); local tx=x
  if a=="center" then tx=x+(w-tw)/2 elseif a=="right" then tx=x+w-tw end
  lcd.drawText(floor(tx),floor(y),s)
end
local function stars(x,y,w,h)
  lcd.color(C.line)
  for i=1,#STARS do local s=STARS[i]; lcd.drawFilledRectangle(floor(x+w*s[1]/100),floor(y+h*s[2]/100),1+(i%7==0 and 1 or 0),1+(i%7==0 and 1 or 0)) end
end
local function hex(cx,cy,r,c)
  lcd.color(c); local px,py
  for i=0,6 do local a=rad(30+(i%6)*60); local x=floor(cx+cos(a)*r); local y=floor(cy+sin(a)*r); if px then lcd.drawLine(px,py,x,y) end; px,py=x,y end
end
local function ring(cx,cy,r,p,c)
  local n=32; local active=floor(max(0,min(100,p or 0))*n/100+0.5)
  for i=0,n-1 do local a=rad(i*360/n); local r1=r-10; lcd.color(i<active and c or C.line); lcd.drawLine(floor(cx+cos(a)*r1),floor(cy+sin(a)*r1),floor(cx+cos(a)*r),floor(cy+sin(a)*r)) end
end
local function panel(x,y,w,h,title,value,c,sub)
  lcd.color(C.panel); lcd.drawFilledRectangle(floor(x),floor(y),floor(w),floor(h)); lcd.color(C.line2); lcd.drawRectangle(floor(x),floor(y),floor(w),floor(h),1); lcd.color(c); lcd.drawFilledRectangle(floor(x),floor(y),3,floor(h))
  text(x+11,y+7,w-22,title,"FONT_XXS",C.muted,"left"); text(x+11,y+30,w-22,value,"FONT_L",C.white,"left"); text(x+11,y+h-22,w-22,sub,"FONT_XXS",C.muted,"left")
end
local function header(x,y,w,h)
  lcd.color(C.bg); lcd.drawFilledRectangle(floor(x),floor(y),floor(w),floor(h))
  local f=font("FONT_L"); if type(f)~="number" then return end; lcd.font(f)
  local a,b,c="ETHOS ","// ","ROTORFLIGHT"; local wa,th=lcd.getTextSize(a); local wb=lcd.getTextSize(b); local wc=lcd.getTextSize(c)
  local wf=font("FONT_XS"); local wm="MWRC"; local ww,wh=0,0; if type(wf)=="number" then lcd.font(wf); ww,wh=lcd.getTextSize(wm); lcd.font(f) end
  local tw=wa+wb+wc; local tx=floor(x+(w-tw-ww-14)/2); local ty=floor(y+(h-th)/2)
  lcd.color(C.violet); lcd.drawText(tx,ty,a); lcd.color(C.cyan); lcd.drawText(tx+wa,ty,b); lcd.color(C.white); lcd.drawText(tx+wa+wb,ty,c)
  if ww>0 then local dx=tx+tw+6; lcd.color(C.line2); lcd.drawLine(dx,y+7,dx,y+h-7); lcd.font(wf); lcd.color(C.magenta); lcd.drawText(dx+7,floor(y+(h-wh)/2),wm) end
end
local hb,last=nil,nil
local function header_boxes()
  local t=0; if rfsuite and rfsuite.preferences and rfsuite.preferences.general then t=rfsuite.preferences.general.txbatt_type or 0 end
  if not hb or last~=t then hb=utils.standardHeaderBoxes(i18n,colorMode,headeropts,t); for _,b in ipairs(hb) do b.bgcolor=C.bg; if b.type=="image" then b.type="func"; b.subtype="func"; b.paint=header end end; last=t end
  return hb
end

local function wake(box,t)
  local c=box._cache or {}; box._cache=c
  c.rpm=stat(t,"rpm","max","headspeed"); c.esc=stat(t,"temp_esc","max","esc_temp"); c.current=stat(t,"current","max"); c.watts=stat(t,"watts","max")
  c.bec=stat(t,"bec_voltage","min","bec"); c.link=stat(t,"link","min","vfr"); c.fuel=stat(t,"smartfuel","min"); c.consumed=stat(t,"smartconsumption","max","consumption")
  local items=0
  if c.esc and c.esc>=pref("esc_warn") then items=items+1 end; if c.bec and c.bec<pref("bec_warn") then items=items+1 end; if c.link and c.link<pref("link_warn") then items=items+1 end; if c.fuel and c.fuel<=pref("fuel_warn") then items=items+1 end
  if items==0 then c.state,c.color,c.integrity="MISSION NOMINAL",C.green,100 else c.state,c.color,c.integrity="MISSION REVIEW",C.amber,max(55,100-items*11) end
  local s=rfsuite and rfsuite.session; local sec=s and s.timer and tonumber(s.timer.live) or 0; c.time=format("%02d:%02d",floor(sec/60),floor(sec%60)); return c
end
local function paint(x,y,w,h,box,c)
  x,y=utils.applyOffset(x,y,box); c=c or box._cache or {}; lcd.color(C.bg); lcd.drawFilledRectangle(floor(x),floor(y),floor(w),floor(h)); stars(x,y,w,h)
  text(x+14,y+8,w*0.5,"SINGULARITY // MISSION DEBRIEF","FONT_STD",C.violet,"left"); text(x+w-260,y+8,246,c.state or "MISSION NOMINAL","FONT_STD",c.color or C.green,"right")
  local cx=x+w*0.5; local cy=y+h*0.49; local r=min(w,h)*0.18; ring(cx,cy,r,c.integrity or 0,c.color or C.green); hex(cx,cy,r*0.72,C.line2); hex(cx,cy,r*0.48,c.color or C.green)
  text(cx-r,cy-48,r*2,fmt(c.integrity,0,"%"),"FONT_XXL",C.white,"center"); text(cx-r,cy+12,r*2,"SYSTEM INTEGRITY","FONT_XS",C.muted,"center"); text(cx-r,cy+43,r*2,"FLIGHT TIME "..(c.time or "00:00"),"FONT_XS",C.cyan,"center")
  local nw=floor(w*0.20); local nh=floor(h*0.17); local lx=x+14; local rx=x+w-nw-14; local y1=y+55; local y2=y+h*0.42; local y3=y+h-nh-14
  panel(lx,y1,nw,nh,"MAX HEADSPEED",fmt(c.rpm,0," RPM"),C.violet,"ORBITAL VELOCITY"); panel(lx,y2,nw,nh,"PEAK CURRENT",fmt(c.current,1," A"),C.cyan,"REACTOR LOAD"); panel(lx,y3,nw,nh,"MIN BEC",fmt(c.bec,2," V"),C.cyan,"POWER CORE")
  panel(rx,y1,nw,nh,"MAX ESC TEMP",fmt(c.esc,0," C"),C.green,"THERMAL PLUME"); panel(rx,y2,nw,nh,"PEAK POWER",fmt(c.watts,0," W"),C.magenta,"ENERGY RELEASE"); panel(rx,y3,nw,nh,"MIN LINK",fmt(c.link,0,"%"),C.cyan,"SIGNAL LOCK")
  text(cx-r*2,y+h-36,r*4,"ENERGY "..fmt(c.fuel,0,"%").."    CONSUMED "..fmt(c.consumed,0," mAh"),"FONT_XS",C.green,"center")
end
local box
local function boxes() if not box then box={{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=wake,paint=paint,bgcolor="transparent"}} end return box end
return {layout={cols=12,rows=12,padding=0},boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle={enabled=false},scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
