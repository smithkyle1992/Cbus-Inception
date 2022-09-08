-- Inner Range Inception Script for Long Polling Status --

------------------------------
     -- User Settings --
------------------------------

-- Inception URL and Credentials
local api_token = "#"
local API_ROOT = "http://192.168.1.112/api/v1"

-- Inception IDs for querying APIs
local area_id = "##"
local front_door_id = "##"
local rear_door_id = "##"

-- NAC User Parameters
local CBUS_USERPARAM_NAME_ALARMSTATE = "alarmstate"
local CBUS_USERPARAM_NAME_FRONTDOOR = "frontdoor"
local CBUS_USERPARAM_NAME_REARDOOR = "reardoor"

------------------------------
       -- Utilities --
------------------------------

-- Utility Function to check if variable is empty
local function isempty(s)
  return s == nil or s == ''
end

-- Initialise the Time Since Update variable (tsu)
if isempty(tsuarea) then
  tsuarea = "0"
end

if isempty(tsudoors) then
  tsudoors = "0"
end

-- function to return the correct door/area to update
local function whichid(id)
if id == area_id then result = CBUS_USERPARAM_NAME_ALARMSTATE
elseif id == front_door_id then result = CBUS_USERPARAM_NAME_FRONTDOOR
elseif id == rear_door_id then result = CBUS_USERPARAM_NAME_REARDOOR
else result = "no"
end
return result
end

------------------------------
-- Inception Array Decoding --
------------------------------

-- Area Decode Function
local function areaeval(res)
--log("Number coming in is... " .. res)
string = ""

vals = {
'Armed',
'Alarm',
'Entry Delay',
'Exit Delay',
'Arm Warning',
'Defer Disarmed',
'Detecting Active Inputs',
'Walk Test Active',
'Away Arm',
'Stay Arm',
'Sleep Arm',
' Disarmed',
'Arm Ready'
}

s = ''
for i=0,#vals-1 do
  if bit.band(res, 2^i) > 0 then
    s = (#s>0 and s..' - '..vals[i+1]) or vals[i+1]
  end
end
--log("string going out is... ".. string)
return(s)
end	
	
-- Door Decode Function
local function dooreval(res)
vals = {
'Unlocked',
'Open',
'Locked Out',
'Forced',
'Held Open Warning',
'Held Open Too Long',
'Breakglass',
'Reader Tamper',
'Locked',
'Closed',
'Held Response Muted'
}

s = ''
for i=0,#vals-1 do
  if bit.band(res, 2^i) > 0 then
    s = (#s>0 and s..' - '..vals[i+1]) or vals[i+1]
  end
end
--log("string going out is... ".. string)
return(s)
end	

------------------------------
    -- C-Bus Functions --
------------------------------


------------------------------
--  INCEPTION API Functions --
------------------------------

local function inceptionapi(payload,endpoint)
local http = require("socket.http")
local json = require("json")
	
	local body, code, headers, status = http.request {
	method = "POST",
	url = API_ROOT .. "/" .. endpoint,
	headers  =
			{
			["Accept"] = "application/json";
			["Authorization"] = "APIToken " .. api_token;
			},
	body = payload,
	timeout = 30,
	}
--log("Getting Data from Endpoint URL " .. API_ROOT .. '/' .. endpoint .. '\n' .. "tsuarea is " ..tsuarea .. '\n' .."TSUdoors is " .. tsudoors .. '\n'.. 'body:' .. tostring(body) .. '\n' .. 'code:' .. tostring(code) .. '\n' .. 'status:' .. tostring(status))

if (code ~= 200) then
    log("Inception post error : "..tostring(code)..","..tostring(body))
    return
elseif (body == nil) then
    log("Inception post error : "..tostring(code)..","..tostring(body))
    return
else return body

end
end

------------------------------
	--  Resident Code  --
------------------------------

local endpoint = "monitor-updates"
	
local payload = json.encode(
{
	{
	ID = "CBUS-Areas-Monitor",
	RequestType = "MonitorEntityStates",
	InputData = {
		stateType = "AreaState",
		timeSinceUpdate = tsuarea 
	}
},
{
	ID = "CBUS-Doors-Monitor",
	RequestType = "MonitorEntityStates",
	InputData = {
		stateType = "DoorState",
		timeSinceUpdate = tsudoors
	}
}
})	

local body = inceptionapi(payload,endpoint)

    if body then
      local httptable = json.pdecode(body)
      -- log(httptable)
      -- check if the response was related to areas?
      if tostring(httptable["ID"]) == "CBUS-Areas-Monitor" then
        tsuarea = tostring(httptable["Result"]["updateTime"])
        -- Find the matching area ID and translate it to a string
        local numUpdates = table.getn(httptable["Result"]["stateData"])
        for httptableindex = 1,numUpdates,1
        do
          if httptable["Result"]["stateData"][httptableindex]["ID"] == area_id then
            local PublicState = httptable["Result"]["stateData"][httptableindex]["PublicState"]
            local AlarmAreaStatus = areaeval(PublicState)
            log("Alarm Area Status is: " .. AlarmAreaStatus .. " which was calculated from a Public State ID of " .. PublicState)						
              -- Set the C-Bus User Parameter
            SetUserParam(0, CBUS_USERPARAM_NAME_ALARMSTATE, AlarmAreaStatus)
              --	log("We have a match! " .. tostring(httptable["Result"]["stateData"][httptableindex]["ID"]) .. " The Status is now set to " .. tostring(httptable["Result"]["stateData"][httptableindex]["PublicState"]))
          end
        end
end
    -- check if the response was related to doors?

	if tostring(httptable["ID"]) == "CBUS-Doors-Monitor" then
		tsudoors = tostring(httptable["Result"]["updateTime"])    
		-- Find the matching ID and translate it to a string
		local numUpdates = table.getn(httptable["Result"]["stateData"])
		for httptableindex = 1,numUpdates,1
		do
			if httptable["Result"]["stateData"][httptableindex]["ID"] == front_door_id then
				local PublicState = httptable["Result"]["stateData"][httptableindex]["PublicState"]
				local FrontDoorStatus = dooreval(PublicState)
				log("Front Door Status is: " .. FrontDoorStatus .. " which was calculated from a Public State ID of " .. PublicState)						
    		-- Set the C-Bus User Parameter
      	SetUserParam(0, CBUS_USERPARAM_NAME_FRONTDOOR, FrontDoorStatus)
        local strn = string.split(FrontDoorStatus, "-")
        local DoorScreenLabel = tostring(strn[1])
        SetCBusLabel(0,56,122,1,'Variant 1',string.sub(DoorScreenLabel, 1, 13))
        log("Setting C-Bus Label to: " .. tostring(DoorScreenLabel))
        --	log("We have a match! " .. tostring(httptable["Result"]["stateData"][httptableindex]["ID"]) .. " The Status is now set to " .. tostring(httptable["Result"]["stateData"][httptableindex]["PublicState"]))
			end
			if httptable["Result"]["stateData"][httptableindex]["ID"] == rear_door_id then
				local PublicState = httptable["Result"]["stateData"][httptableindex]["PublicState"]
				local RearDoorStatus = dooreval(PublicState)
				log("Rear Door Status is: " .. RearDoorStatus .. " which was calculated from a Public State ID of " .. PublicState)						
   			-- Set the C-Bus User Parameter
				SetUserParam(0, CBUS_USERPARAM_NAME_REARDOOR, RearDoorStatus)
	  		--	log("We have a match! " .. tostring(httptable["Result"]["stateData"][httptableindex]["ID"]) .. " The Status is now set to " .. tostring(httptable["Result"]["stateData"][httptableindex]["PublicState"]))
			end
  	end
  end
end
