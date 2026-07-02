local rfsuite = require("rfsuite")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local tonumber = tonumber
local tostring = tostring
local type = type
local format = string.format
local ipairs = ipairs

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
local header_layout = utils.standardHeaderLayout(headeropts)

local C = {
    space = lcd.RGB(3, 5, 12), void = lcd.RGB(0, 0, 3), panel = lcd.RGB(8, 12, 24), panel2 = lcd.RGB(13, 18, 34),
    line = lcd.RGB(37, 57, 87), line2 = lcd.RGB(75, 101, 140), white = lcd.RGB(228, 240, 255), muted = lcd.RGB(122, 147, 177),
    cyan = lcd.RGB(58, 236, 255), cyanDim = lcd.RGB(16, 74, 92), violet = lcd.RGB(170, 97, 255), violetDim = lcd.RGB(53, 27, 89),
    blue = lcd.RGB(58, 111, 255), blueDim = lcd.RGB(18, 38, 91), green = lcd.RGB(98, 255, 165), greenDim = lcd.RGB(21, 87, 59),
    amber = lcd.RGB(255, 190, 70), amberDim = lcd.RGB(94, 64, 17), red = lcd.RGB(255, 72, 110), redDim = lcd.RGB(90, 19, 38), magenta = lcd.RGB(255, 74, 235)
}

local THEME_SECTION = "system/singularity"
local DEFAULTS = {rpm_max=2500,bec_min=6.5,bec_warn=7.0,esc_warn=110,esc_max=150,fuel_warn=25,link_warn=50,current_warn=120,watts_warn=3500}
local STARFIELD = {{2,6,1},{7,18,1},{11,9,2},{15,29,1},{19,14,1},{23,5,1},{27,24,2},{31,12,1},{35,32,1},{39,20,1},{43,7,2},{47,27,1},{51,16,1},{55,4,1},{59,31,2},{63,11,1},{67,23,1},{71,6,1},{75,18,2},{79,29,1},{83,13,1},{87,2,1},{91,24,2},{95,9,1},{5,38,1},{13,44,2},{21,36,1},{29,48,1},{37,40,2},{45,50,1},{53,37,1},{61,46,2},{69,39,1},{77,49,1},{85,35,2},{93,45,1},{9,58,1},{18,67,2},{26,56,1},{34,71,1},{42,62,2},{50,75,1},{58,59,1},{66,69,2},{74,55,1},{82,73,1},{90,61,2},{97,76,1},{4,85,1},{12,94,2},{24,82,1},{32,91,1},{40,79,2},{48,96,1},{56,84,1},{64,93,2},{72,81,1},{80,97,1},{88,86,2},{96,92,1}}

local function clamp(v,lo,hi) if v<lo then return lo end if v>hi then return hi end return v end
local function getThemeValue(key) local s=rfsuite and rfsuite.session local p=s and s.modelPreferences and s.modelPreferences[THEME_SECTION] local v=p and tonumber(p[key]) return v or DEFAULTS[key] end
local function sensor(t,n,a1,a2) t=t or (rfsuite.tasks and rfsuite.tasks.telemetry) if not(t and t.getSensor) then return nil end local v=t.getSensor(n) if v~=nil then return tonumber(v) end if a1 then v=t.getSensor(a1) if v~=nil then return tonumber(v) end end if a2 then v=t.getSensor(a2) if v~=nil then return tonumber(v) end end return nil end
local function fmt(v,d,s,m) if v==nil then return m or "--" end local q if d==1 then q=format("%.1f",v) elseif d==2 then q=format("%.2f",v) else q=tostring(floor(v+0.5)) end return q..(s or "") end
local function resolveFont(n) return utils.resolveFont(n,nil) end
local function drawTextAligned(x,y,w,t,f,c,a) local q=resolveFont(f) if type(q)~="number" then return 0,0 end lcd.font(q) lcd.color(c) local tw,th=lcd.getTextSize(t) local tx=x if a=="center" then tx=x+(w-tw)/2 elseif a=="right" then tx=x+w-tw end lcd.drawText(floor(tx+0.5),floor(y+0.5),t) return tw,th end
local function drawStars(x,y,w,h) for i=1,#STARFIELD do local s=STARFIELD[i] local sx=floor(x+w*s[1]/100) local sy=floor(y+h*s[2]/100) local z=s[3] lcd.color(z==2 and C.line2 or C.line) lcd.drawFilledRectangle(sx,sy,z,z) end end
local function drawPanel(x,y,w,h,a,t) x,y,w,h=floor(x),floor(y),floor(w),floor(h) lcd.color(C.panel) lcd.drawFilledRectangle(x,y,w,h) lcd.color(C.line) lcd.drawRectangle(x,y,w,h,1) lcd.color(a or C.cyan) lcd.drawFilledRectangle(x,y,3,h) if t then drawTextAligned(x+11,y+7,w-20,t,"FONT_XXS",C.muted,"left") end end
local function drawNode(x,y,w,h,t,v,a,s) drawPanel(x,y,w,h,a,t) drawTextAligned(x+11,y+28,w-22,v,"FONT_L",C.white,"left") if s then drawTextAligned(x+11,y+h-22,w-22,s,"FONT_XXS",C.muted,"left") end end
local function drawHex(cx,cy,r,c) local px,py,fx,fy=nil,nil,nil,nil lcd.color(c) for i=0,6 do local a=rad(30+(i%6)*60) local x=floor(cx+cos(a)*r) local y=floor(cy+sin(a)*r) if i==0 then fx,fy=x,y else lcd.drawLine(px,py,x,y) end px,py=x,y end if px and fx then lcd.drawLine(px,py,fx,fy) end end
local function drawRingSegments(cx,cy,r,n,p,ac,dc,th,sa,sw) n=n or 24 p=clamp(p or 0,0,100) th=th or 8 sa=sa or 0 sw=sw or 360 local active=p>0 and max(1,min(n,floor(p*n/100+0.999))) or 0 for i=0,n-1 do local a=rad(sa+sw*i/n) local r1=r-th lcd.color(i<active and ac or dc) lcd.drawLine(floor(cx+cos(a)*r1),floor(cy+sin(a)*r1),floor(cx+cos(a)*r),floor(cy+sin(a)*r)) end end
local function drawOrbit(cx,cy,rx,ry,c,n) n=n or 48 local lx,ly lcd.color(c) for i=0,n do local a=rad(360*i/n) local x=floor(cx+cos(a)*rx) local y=floor(cy+sin(a)*ry) if lx then lcd.drawLine(lx,ly,x,y) end lx,ly=x,y end end
local function drawHeaderTitle(x,y,w,h) lcd.color(C.space) lcd.drawFilledRectangle(floor(x),floor(y),floor(w),floor(h)) local t1,t2,t3="ETHOS ","// ","ROTORFLIGHT" local f=resolveFont("FONT_L") if type(f)~="number" then return end lcd.font(f) local w1,th=lcd.getTextSize(t1) local w2=lcd.getTextSize(t2) local w3=lcd.getTextSize(t3) local wf=resolveFont("FONT_XS") local wt="MWRC" local ww,wh=0,0 if type(wf)=="number" then lcd.font(wf) ww,wh=lcd.getTextSize(wt) lcd.font(f) end local tw=w1+w2+w3 local gap=ww>0 and 14 or 0 local tx=floor(x+(w-tw-gap-ww)/2) local ty=floor(y+(h-th)/2) lcd.color(C.violet) lcd.drawText(tx,ty,t1) lcd.color(C.cyan) lcd.drawText(tx+w1,ty,t2) lcd.color(C.white) lcd.drawText(tx+w1+w2,ty,t3) if ww>0 then local dx=tx+tw+6 lcd.color(C.line2) lcd.drawLine(dx,y+7,dx,y+h-7) lcd.font(wf) lcd.color(C.magenta) lcd.drawText(dx+7,floor(y+(h-wh)/2),wt) end end
local header_boxes_cache,last_txbatt_type=nil,nil
local function header_boxes() local tb=0 if rfsuite and rfsuite.preferences and rfsuite.preferences.general then tb=rfsuite.preferences.general.txbatt_type or 0 end if header_boxes_cache==nil or last_txbatt_type~=tb then local b=utils.standardHeaderBoxes(i18n,colorMode,headeropts,tb) for _,v in ipairs(b) do v.bgcolor=C.space if v.type=="image" then v.type="func" v.subtype="func" v.paint=drawHeaderTitle end end header_boxes_cache=b last_txbatt_type=tb end return header_boxes_cache end
local function flightTimeText() local s=rfsuite and rfsuite.session local sec=s and s.timer and tonumber(s.timer.live) or 0 sec=max(0,sec) return format("%02d:%02d",floor(sec/60),floor(sec%60)) end
local STATE_LABELS={[0]="OFFLINE",[1]="IDLE",[2]="IGNITION",[3]="RECOVERY",[4]="STABLE ORBIT",[5]="THRUST CUT",[6]="LINK DOWN",[7]="AUTOROTATION",[8]="BOOST",[100]="GOV DISABLED",[101]="COLD"}
local STATE_COLORS={[0]=C.amber,[1]=C.amber,[2]=C.magenta,[3]=C.amber,[4]=C.green,[5]=C.green,[6]=C.red,[7]=C.amber,[8]=C.red,[100]=C.muted,[101]=C.cyan}
local function getReactorState(t) local af=sensor(t,"armflags") local g=sensor(t,"governor") local armed=nil if rfsuite.utils and rfsuite.utils.armFlagsToIsArmed then armed=rfsuite.utils.armFlagsToIsArmed(af) end if armed==nil and af==nil and g==nil then local s=rfsuite and rfsuite.session if s and s.telemetryState then armed=s.isArmed==true end end if armed==false then return "COLD",C.cyan end local code=g and floor(g+0.5) or nil if code==101 then return "COLD",C.cyan end if armed==true then if code and STATE_LABELS[code] then return STATE_LABELS[code],STATE_COLORS[code] or C.red end return "ARMED",C.red end if code and STATE_LABELS[code] then return STATE_LABELS[code],STATE_COLORS[code] or C.cyan end return "STATE --",C.muted end
local layout={cols=12,rows=12,padding=0} local screenBorderStyle={enabled=false}
local function inflightWakeup(box,t) local c=box._cache or {maxRpm=0} box._cache=c c.rpm=sensor(t,"rpm","headspeed","erpm") or 0 c.maxRpm=max(c.maxRpm or 0,c.rpm) c.throttle=sensor(t,"throttle_percent","throttle") or 0 c.esc=sensor(t,"temp_esc","esc_temp") c.fuel=sensor(t,"smartfuel") c.current=sensor(t,"current") c.watts=sensor(t,"watts") c.bec=sensor(t,"bec_voltage","bec") c.link=sensor(t,"link","vfr") c.consumed=sensor(t,"smartconsumption","consumption") c.reactorState,c.reactorColor=getReactorState(t) c.timer=flightTimeText() return c end
local function drawThermalPlume(x,y,w,h,v,m,c) drawPanel(x,y,w,h,c,"THERMAL PLUME") local p=m>0 and clamp((v or 0)/m,0,1) or 0 local by=y+h-28 local ce=x+w*0.5 for i=0,7 do local bh=floor((h-68)*p*(0.48+i/15)) local bw=5+(i%3)*2 local bx=floor(ce-32+i*9) lcd.color(i<3 and C.cyanDim or c) lcd.drawFilledRectangle(bx,floor(by-bh),bw,bh) end drawTextAligned(x+10,y+30,w-20,fmt(v,0," C"),"FONT_L",C.white,"center") end
local function drawThrustArray(x,y,w,h,t) drawPanel(x,y,w,h,C.cyan,"THRUST ARRAY") local p=clamp((t or 0)/100,0,1) local n=10 local gap=4 local bw=floor((w-24-gap*(n-1))/n) for i=0,n-1 do local bh=14+i*5 local bx=x+12+i*(bw+gap) local by=y+h-20-bh lcd.color(i<floor(p*n+0.999) and C.cyan or C.line) lcd.drawFilledRectangle(floor(bx),floor(by),bw,bh) end drawTextAligned(x+10,y+30,w-20,fmt(t,0,"%"),"FONT_L",C.white,"center") end
local function inflightPaint(x,y,w,h,box,c) x,y=utils.applyOffset(x,y,box) c=c or box._cache or {} lcd.color(C.space) lcd.drawFilledRectangle(floor(x),floor(y),floor(w),floor(h)) drawStars(x,y,w,h) drawTextAligned(x+14,y+8,w*0.45,"SINGULARITY // FLIGHT","FONT_STD",C.violet,"left") drawTextAligned(x+w*0.35,y+3,w*0.30,c.timer or "00:00","FONT_XL",C.white,"center") drawTextAligned(x+w-250,y+9,236,c.reactorState or "STATE --","FONT_STD",c.reactorColor or C.muted,"right")
    local bodyY=y+44 local bodyH=h-56 local sideW=floor(w*0.21) local leftX=x+12 local rightX=x+w-sideW-12 local centerX=leftX+sideW+12 local centerW=w-sideW*2-48 local halfH=floor((bodyH-10)/2)
    local escColor=c.esc and (c.esc>=getThemeValue("esc_max") and C.red or (c.esc>=getThemeValue("esc_warn") and C.amber or C.green)) or C.muted drawThermalPlume(leftX,bodyY,sideW,halfH,c.esc,getThemeValue("esc_max"),escColor) drawThrustArray(leftX,bodyY+halfH+10,sideW,halfH,c.throttle)
    drawPanel(centerX,bodyY,centerW,bodyH,C.violet,nil) local cx=centerX+centerW*0.5 local cy=bodyY+bodyH*0.47 local radius=min(centerW,bodyH)*0.40 local rpmMax=getThemeValue("rpm_max") local rpmPct=rpmMax>0 and clamp((c.rpm or 0)/rpmMax*100,0,100) or 0 local fuel=c.fuel or 0 local fuelColor=fuel<=getThemeValue("fuel_warn") and C.red or (fuel<=50 and C.amber or C.green) local rpmColor=(c.rpm or 0)>rpmMax and C.red or C.violet
    drawOrbit(cx,cy,radius*1.12,radius*0.54,C.line,64) drawOrbit(cx,cy,radius*0.78,radius*1.10,C.line,64) drawRingSegments(cx,cy,radius*1.05,36,rpmPct,rpmColor,C.line,13,145,250) drawRingSegments(cx,cy,radius*0.86,30,fuel,fuelColor,C.line,10,0,360) drawHex(cx,cy,radius*0.62,C.line2) drawHex(cx,cy,radius*0.44,c.reactorColor or C.muted) drawHex(cx,cy,radius*0.26,C.violet)
    drawTextAligned(cx-radius,cy-58,radius*2,fmt(c.rpm,0,""),"FONT_XXL",C.white,"center") drawTextAligned(cx-radius,cy-2,radius*2,"HEADSPEED","FONT_XS",C.muted,"center") drawTextAligned(cx-radius,cy+24,radius*2,c.reactorState or "STATE --","FONT_S",c.reactorColor or C.muted,"center") drawTextAligned(cx-radius,cy+52,radius*2,"EVENT HORIZON","FONT_XXS",C.violet,"center") drawTextAligned(centerX+18,bodyY+bodyH-34,centerW-36,"MAX "..fmt(c.maxRpm,0," RPM"),"FONT_XS",C.amber,"left") drawTextAligned(centerX+18,bodyY+bodyH-34,centerW-36,"ENERGY "..fmt(c.fuel,0,"%"),"FONT_XS",fuelColor,"right")
    local currentColor=c.current and c.current>=getThemeValue("current_warn") and C.red or C.cyan local wattsColor=c.watts and c.watts>=getThemeValue("watts_warn") and C.red or C.violet local becColor=c.bec and (c.bec<getThemeValue("bec_min") and C.red or (c.bec<getThemeValue("bec_warn") and C.amber or C.cyan)) or C.muted local linkColor=c.link and (c.link<getThemeValue("link_warn") and C.amber or C.cyan) or C.muted local nodeH=floor((bodyH-30)/4)
    drawNode(rightX,bodyY,sideW,nodeH,"REACTOR LOAD",fmt(c.current,1," A"),currentColor,fmt(c.watts,0," W")) drawNode(rightX,bodyY+nodeH+10,sideW,nodeH,"POWER CORE",fmt(c.bec,1," V"),becColor,"BEC STABILITY") drawNode(rightX,bodyY+(nodeH+10)*2,sideW,nodeH,"SIGNAL CONSTELLATION",fmt(c.link,0,"%"),linkColor,"LINK LOCK") drawNode(rightX,bodyY+(nodeH+10)*3,sideW,nodeH,"MATTER CONSUMED",fmt(c.consumed,0," mAh"),wattsColor,"FLIGHT ENERGY")
end
local boxes_cache
local function boxes() if not boxes_cache then boxes_cache={{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=inflightWakeup,paint=inflightPaint,bgcolor="transparent"}} end return boxes_cache end
return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
