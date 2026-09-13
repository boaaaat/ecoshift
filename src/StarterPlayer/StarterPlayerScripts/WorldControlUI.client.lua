local RS=game:GetService("ReplicatedStorage")
if require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode()~="Expedition" then return end
local Players=game:GetService("Players");local UIS=game:GetService("UserInputService")
local Theme=require(RS.Shared.UI.UITheme);local Settings=require(RS.Shared.ClientSettings)
local Config=require(RS.Shared.WorldControlConfig);local Catalog=require(RS.Shared.OverhaulCatalog);local Biomes=require(RS.Shared.OverhaulBiomes)
local player=Players.LocalPlayer;local remotes=RS:WaitForChild("Remotes")
local remote=remotes:WaitForChild("WorldControl");local instruments=remotes:WaitForChild("InstrumentAction");local C=Theme.Colors
local snapshot,world,intel={},{},{};local selected={};local weatherChoice;local extend=false;local journalIndex=1;local moduleIndex=1
local gui=Instance.new("ScreenGui");gui.Name="WorldControlUI";gui.ResetOnSpawn=false;gui.DisplayOrder=85;gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame");panel.Name="SurveyInstrument";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromScale(.94,.87);panel.Visible=false;panel.Parent=gui;Theme.Panel(panel,true)
local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(920,850);limit.Parent=panel;Theme.CaptureCursor(panel);Theme.AnimatePanel(panel)
local function label(parent,value,y,h,size)
 local t=Theme.Label(parent,value,UDim2.new(1,-28,0,h),UDim2.fromOffset(14,y),size or 17,C.Paper,false);t.TextWrapped=true;return t
end
local function button(parent,value,y)
 local b=Instance.new("TextButton");b.Text=value;b.TextSize=16;b.Font=Enum.Font.GothamBold;b.TextWrapped=true;b.Position=UDim2.fromOffset(14,y);b.Size=UDim2.new(1,-28,0,42);b.Parent=parent;Theme.Button(b,true);return b
end
label(panel,"FIELD INSTRUMENTS",12,30,22)
local close=button(panel,"X",8);close.Position=UDim2.new(1,-52,0,8);close.Size=UDim2.fromOffset(42,42);close.Activated:Connect(function()panel.Visible=false end)
local a=button(panel,"World controls",54);a.Size=UDim2.new(.5,-20,0,40)
local b=button(panel,"Instruments",54);b.Position=UDim2.new(.5,6,0,54);b.Size=UDim2.new(.5,-20,0,40)
local function page(name)
 local f=Instance.new("ScrollingFrame");f.Name=name;f.Position=UDim2.fromOffset(4,100);f.Size=UDim2.new(1,-8,1,-106);f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ScrollBarThickness=5;f.AutomaticCanvasSize=Enum.AutomaticSize.Y;f.CanvasSize=UDim2.new();f.ScrollingDirection=Enum.ScrollingDirection.Y;f.Parent=panel
 local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,10);l.Parent=f;local p=Instance.new("UIPadding");p.PaddingLeft=UDim.new(0,6);p.PaddingRight=UDim.new(0,6);p.PaddingBottom=UDim.new(0,10);p.Parent=f;return f
end
local controls=page("Controls");local readings=page("Readings");readings.Visible=false
a.Activated:Connect(function()controls.Visible=true;readings.Visible=false end);b.Activated:Connect(function()controls.Visible=false;readings.Visible=true end)
local function card(parent,h)local f=Instance.new("Frame");f.Size=UDim2.new(1,-12,0,h);f.Parent=parent;Theme.Panel(f,false);return f end
local forecast=label(card(controls,100),"",8,84,16);local cards={}
local function name(id)return Biomes.Biomes[id] and Biomes.Biomes[id].DisplayName or id or "Unknown" end
local function choices(action)local result={};for _,id in ipairs((action=="Select" and snapshot.VisitedBiomes or snapshot.EligibleBiomes) or {}) do if id~=world.Biome then table.insert(result,id) end end;return result end
local render
for _,action in ipairs(Config.Order) do
 local def=Config.Actions[action];local targeted=action=="Select" or action=="Anchor";local f=card(controls,action=="Anchor" and 396 or targeted and 300 or 244)
 label(f,def.Name,8,28,20);label(f,def.Description,40,56,16);local fuel=label(f,"",99,45,15);local reason=label(f,"",146,40,14)
 local target,weather,extension
 if targeted then target=button(f,"Choose destination",188);target.Activated:Connect(function()local list=choices(action);if #list>0 then selected[action]=list[((table.find(list,selected[action]) or 0)%#list)+1];weatherChoice=nil;render() end end) end
 if action=="Anchor" then
  weather=button(f,"Base weather",236);extension=button(f,"Extend: off",284)
  weather.Activated:Connect(function()local list=(snapshot.WeatherChoices or {})[selected.Anchor] or {};if #list>0 then local index=1;for i,v in ipairs(list) do if v.Id==weatherChoice then index=i end end;weatherChoice=list[index%#list+1].Id;render() end end)
  extension.Activated:Connect(function()extend=not extend;render() end)
 end
 local propose=button(f,"Propose team vote",action=="Anchor" and 338 or targeted and 244 or 190)
 propose.Activated:Connect(function()local state=snapshot.Actions and snapshot.Actions[action];if not state or not state.CanPropose or targeted and not selected[action] or action=="Anchor" and not weatherChoice then return end;propose.Text="Sending proposal...";remote:FireServer("Propose",{Action=action,Biome=action=="Anchor" and {Biome=selected.Anchor,Weather=weatherChoice,Extend=extend} or selected[action]}) end)
 cards[action]={Fuel=fuel,Reason=reason,Target=target,Weather=weather,Extension=extension,Propose=propose}
end
local journey=label(card(readings,236),"",8,220,16)
local unlocked=label(card(readings,155),"",8,138,16);local threat=label(card(readings,90),"",10,70,17);local hazards=label(card(readings,170),"",10,150,16)
local compass=card(readings,185);label(compass,"RESOURCE COMPASS",8,26,19);local resourcePick=button(compass,"Choose a known resource",42);local direction=label(compass,"",90,80,16)
resourcePick.Activated:Connect(function()local list=intel.KnownResources or {};if #list>0 then local index=0;for i,v in ipairs(list) do if v.Id==intel.SelectedResource then index=i end end;instruments:FireServer("SelectResource",list[index%#list+1].Id) end end)
local event=label(card(readings,90),"",10,70,16)
local journal=card(readings,208);label(journal,"FIELD JOURNAL MODULES",8,28,19);local journalPick=button(journal,"Choose journal",43);local modulePick=button(journal,"Choose module",91);local install=button(journal,"Install at grade 5 Survey Desk",145);local moduleOptions={}
journalPick.Activated:Connect(function()journalIndex=journalIndex%math.max(1,#(intel.Journals or {}))+1;render() end)
modulePick.Activated:Connect(function()moduleIndex=moduleIndex%math.max(1,#moduleOptions)+1;render() end)
install.Activated:Connect(function()local chosen=(intel.Journals or {})[journalIndex];if chosen and moduleOptions[moduleIndex] then instruments:FireServer("InstallModule",{Uid=chosen.Uid,Module=moduleOptions[moduleIndex]});install.Text="Installing..." end end)
local beacon=card(readings,142);label(beacon,"TRAIL BEACON / 15-minute return marker",8,28,17)
local beaconName=Instance.new("TextBox");beaconName.PlaceholderText="Name this return point";beaconName.Text="";beaconName.ClearTextOnFocus=false;beaconName.TextSize=17;beaconName.Size=UDim2.new(1,-28,0,40);beaconName.Position=UDim2.fromOffset(14,44);beaconName.Parent=beacon;Theme.Button(beaconName,false)
button(beacon,"Place beacon at your feet",92).Activated:Connect(function()instruments:FireServer("PlaceBeacon",beaconName.Text~="" and beaconName.Text or "Return point") end)
local vg=Instance.new("ScreenGui");vg.Name="WorldControlBallots";vg.ResetOnSpawn=false;vg.DisplayOrder=105;vg.Parent=player.PlayerGui
local ballot=Instance.new("Frame");ballot.Name="TeamBallot";ballot.AnchorPoint=Vector2.new(.5,1);ballot.Position=UDim2.new(.5,0,1,-16);ballot.Size=UDim2.fromOffset(460,220);ballot.Visible=false;ballot.Parent=vg;Theme.Panel(ballot,true);Theme.Fit(ballot,460,220);Theme.CaptureCursor(ballot)
local ballotLabel=label(ballot,"",10,140,17);local yes=button(ballot,"Approve",158);yes.Size=UDim2.new(.5,-20,0,48);local no=button(ballot,"Decline",158);no.Position=UDim2.new(.5,6,0,158);no.Size=UDim2.new(.5,-20,0,48)
local function vote(value)if snapshot.Ballot and snapshot.Ballot.CanVote then remote:FireServer("Vote",{Id=snapshot.Ballot.Id,Approve=value}) end end
yes.Activated:Connect(function()vote(true) end);no.Activated:Connect(function()vote(false) end)
local notice=label(panel,"",0,48,17);notice.Position=UDim2.new(0,14,1,-58);notice.BackgroundTransparency=.08;notice.BackgroundColor3=C.Panel;notice.Visible=false;notice.ZIndex=20
local token=0;local function feedback(data)token+=1;local current=token;notice.Text=data.Message or "";notice.Visible=true;task.delay(5,function()if current==token then notice.Visible=false end end) end
render=function()
 local guide=intel.Journey
 if guide then
  local depths={};for _,depth in ipairs(guide.KnownDepths or {}) do table.insert(depths,string.char(64+depth)) end
  local station=guide.NextStation
  journey.Text="JOURNEY / TIER "..guide.Tier.."\n"..(guide.Complete and "Campaign complete" or "Milestone: "..guide.Milestone)
   .."\nBiome maturity: "..math.floor(guide.Maturity*100).."% / previous visits: "..guide.PreviousVisits
   .."\nDiscovered depths: "..(#depths>0 and table.concat(depths,", ") or "None explored yet")
   .."\n"..(station and ("Next station: "..station.Action.." "..station.Name.." / grade "..station.Grade) or "Camp stations are prepared for this tier")
   .."\n"..guide.Advice
 else journey.Text="Loading your expedition journal..." end
 forecast.Text=(world.ShiftRemaining and string.format("SHIFT %02d:%02d",math.floor(world.ShiftRemaining/60),math.floor(world.ShiftRemaining%60)) or "SHIFT / Field Clock required").."\nNEXT / "..(world.UpcomingBiome and name(world.UpcomingBiome) or "Biome Predictor required").."\nWEATHER / "..(world.UpcomingWeather or "Weather Predictor required")
 for action,refs in pairs(cards) do
  local status=snapshot.Actions and snapshot.Actions[action];local list=choices(action);if not table.find(list,selected[action]) then selected[action]=list[1] end
  if refs.Target then refs.Target.Text=selected[action] and name(selected[action]).." >" or "No eligible destination" end
  if refs.Weather then local options=(snapshot.WeatherChoices or {})[selected.Anchor] or {};local chosen;for _,v in ipairs(options) do if v.Id==weatherChoice then chosen=v end end;chosen=chosen or options[1];weatherChoice=chosen and chosen.Id;refs.Weather.Text=chosen and chosen.Name.." >" or "No base weather";refs.Extension.Text=extend and "Extend to 600s: ON" or "Extend: OFF" end
  if status then local fuel={};for _,cost in ipairs(status.Fuel) do table.insert(fuel,(Catalog.Items[cost.Id] and Catalog.Items[cost.Id].Name or cost.Id).." "..cost.Owned.."/"..cost.N) end;refs.Fuel.Text="Fuel: "..table.concat(fuel," / ");refs.Reason.Text=status.Reason or "Reusable device / fuel spent after approval";refs.Propose.Text="Propose team vote";refs.Propose.TextTransparency=status.CanPropose and 0 or .5 end
 end
 local caps=intel.Capabilities or {};local active={};for _,id in ipairs({"FieldClock","ThreatGauge","ResourceCompass","WeatherScanner","BiomePredictor","WeatherPredictor","EventDetector"}) do if caps[id] then table.insert(active,Catalog.Items[id].Name) end end
 unlocked.Text="UNLOCKED INFORMATION\n"..(#active>0 and table.concat(active," / ") or "Carry instruments to unlock readings. A journal carries only the modules actually installed.")
 threat.Text=intel.Threat and string.format("Tier %d / pressure %d%%\n%s / region depth %s",intel.Threat.Tier,math.floor(intel.Threat.Pressure*100),intel.Threat.Region,string.char(64+intel.Threat.Depth)) or "THREAT GAUGE REQUIRED"
 hazards.Text=intel.Hazards and string.format("Temperature %d / exposure %d / toxin %d\n%s",math.floor(intel.Hazards.Temperature),math.floor(intel.Hazards.Exposure),math.floor(intel.Hazards.Toxin),intel.Advice or "") or "WEATHER SCANNER REQUIRED\nMeasures local hazards and suggests recovery. Does not reveal forecasts."
 resourcePick.Text=intel.SelectedResource and Catalog.Items[intel.SelectedResource].Name.." >" or "Choose a known resource >";direction.Text=caps.ResourceCompass and (intel.ResourceStatus or "Select a resource") or "RESOURCE COMPASS REQUIRED"
 if intel.ResourceTarget then direction.Text=intel.ResourceTarget.Name.." / "..math.floor(intel.ResourceTarget.Distance).." studs / marked on map" end
 event.Text=intel.Event and (intel.Event.Name.." in "..intel.Event.StartsIn.."s"..(intel.Event.Position and " / origin marked on map" or " / origin undiscovered")) or caps.EventDetector and "No major event warning in the next 45 seconds." or "EVENT DETECTOR REQUIRED"
 local journals=intel.Journals or {};journalIndex=math.clamp(journalIndex,1,math.max(1,#journals));local chosen=journals[journalIndex];journalPick.Text=chosen and ("Journal "..journalIndex.." / "..#journals.." >") or "Carry a Field Journal"
 moduleOptions={};for id in pairs(intel.Modules or {}) do if not chosen or not chosen.InstalledModules[id] then table.insert(moduleOptions,id) end end;table.sort(moduleOptions);moduleIndex=math.clamp(moduleIndex,1,math.max(1,#moduleOptions));modulePick.Text=moduleOptions[moduleIndex] and Catalog.Items[moduleOptions[moduleIndex]].Name.." >" or "No uninstalled carried modules";install.Text="Install at grade 5 Survey Desk"
 local voteState=snapshot.Ballot;ballot.Visible=voteState~=nil and not snapshot.GameOver
 if voteState then local v=voteState;ballotLabel.Text=Config.Actions[v.Action].Name..(v.Biome and " -> "..name(v.Biome) or "")..(v.Weather and " / "..v.Weather or "")..(v.Extend and " / extend to 600s" or "").."\n"..v.Proposer.." provides fuel\n"..v.Yes.." / "..v.Required.." approvals / "..v.ExpiresIn.."s";yes.Text=v.Vote~=nil and "Vote recorded" or "Approve";yes.TextTransparency=v.CanVote and 0 or .5;no.TextTransparency=yes.TextTransparency end
end
local function toggle()panel.Visible=not panel.Visible;if panel.Visible then remote:FireServer("RequestSnapshot");instruments:FireServer("RequestSnapshot") end end
player:GetAttributeChangedSignal("FieldKitSurvey"):Connect(toggle)
UIS.InputBegan:Connect(function(input,processed)if processed or UIS:GetFocusedTextBox() then return end;if Settings.Matches(input,"Survey") then toggle() elseif input.KeyCode==Enum.KeyCode.Escape then panel.Visible=false end end)
remote.OnClientEvent:Connect(function(action,data)if action=="Snapshot" then snapshot=data;render() elseif action=="Feedback" then feedback(data) end end)
instruments.OnClientEvent:Connect(function(action,data)if action=="Snapshot" then intel=data;render() elseif action=="Feedback" then feedback(data) end end)
remotes:WaitForChild("GameStateUpdate").OnClientEvent:Connect(function(data)world=data;render() end)
remote:FireServer("RequestSnapshot");instruments:FireServer("RequestSnapshot");render();Theme.TrackRoot(gui)

-- A bearing is useful while travelling without reopening the atlas.
local bearing=Instance.new("Frame");bearing.Name="ResourceBearing";bearing.Size=UDim2.fromOffset(242,44);bearing.AnchorPoint=Vector2.new(.5,0);bearing.Position=UDim2.new(.5,0,0,62);bearing.Visible=false;bearing.Parent=gui;Theme.Panel(bearing,false)
local arrow=Instance.new("TextLabel");arrow.BackgroundTransparency=1;arrow.Size=UDim2.fromOffset(40,40);arrow.Text="▲";arrow.TextColor3=C.Amber;arrow.TextSize=26;arrow.Parent=bearing
local bearingText=label(bearing,"",2,40,14);bearingText.Position=UDim2.fromOffset(44,2);bearingText.Size=UDim2.new(1,-52,0,40)
game:GetService("RunService").RenderStepped:Connect(function()
 local target=intel.ResourceTarget;local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart");local camera=workspace.CurrentCamera
 bearing.Visible=target~=nil and root~=nil and camera~=nil and not player:GetAttribute("IsDead") and not player.PlayerGui:GetAttribute("MenuCursorOpen")
 if bearing.Visible then
  local delta=target.Position-root.Position;local forward=camera.CFrame.LookVector
  arrow.Rotation=math.deg(math.atan2(delta.X,-delta.Z)-math.atan2(forward.X,-forward.Z))
  bearingText.Text=target.Name.." / "..math.floor(delta.Magnitude).." studs"
 end
end)
