--[[ Tabletop Simulator Cast Loader Script
     Written for Monumentum Cast Recruiter
     Date: Sunday, 7 June 2026
     
     INSTRUCTIONS:
     1. Right-click your scripting token in TTS and select Scripting > Scripting Editor.
     2. Paste this entire LUA code into the editor.
     3. Create one Scripting Trigger Zone (Tools > Scripting Trigger Zone) on your table and
        place it where the single Cast deck is kept. That one deck now holds all 200 cards:
        champions, companions, familiars, minions, talismans, signatures and special actions.
     4. Paste the GUID of that trigger zone below in CAST_ZONE_GUID.
     5. Click Save & Play!
--]]

-- =============== CONFIGURATION GUIDs (REQUIRED) ===============
-- Place scripting zones over your decks on the table and enter their GUIDs below.
CAST_ZONE_GUID       = "83f62b" -- Zone containing the single Cast deck (all 200 cards)
MODELS_ZONE_GUID     = "fe2114" -- Zone containing the 3D Models Bag (Task 3)

-- =============== MAP DEPLOYMENT CONFIGURATION (ONBOARDING) ===============
-- GUIDs for the Path Tiles and Font Tiles scripting zones on your table.
MAP_TILE_ZONE_GUID   = "193b90" -- Zone containing the Path/Grid tile deck
MAP_FONT_ZONE_GUID   = "547581" -- Zone containing the Font tile deck

MAP_SPACING          = 4.0      -- Physical spacing distance between tiles
MAP_START_POS        = { x = -10, y = 0.21, z = 10 } -- Top-left corner spawn coordinate


-- =============== PLAYER LAYOUT CONFIGURATION ===============
-- [Zones Option] You can specify scripting zones where each player's characters should spawn on the table!
-- Leave them as "XXXXXX" and "YYYYYY" to use the fallback raw coordinates instead.
PLAYER_CONFIG = {
    [1] = { -- Player 1 (Red / Bottom)
        character_zone_guid = "e493d9", -- Zone where characters are spawned face up (DO NOT EDIT)
        special_zone_guid   = "XXXXXX", -- Zone where Special Actions are placed (Leave as "XXXXXX" to deal to hand instead)
        table_zone = { x = -15, y = 1.5, z = -5 },   -- Fallback coordinates if zone is not set
        special_dest = { x = -25, y = 2.0, z = -15 }, -- Fallback specials hand/dest area
        color = "Red"                                 -- TTS Player Seat color
    },
    [2] = { -- Player 2 (Blue / Top)
        character_zone_guid = "7faf07", -- Zone where characters are spawned face up (DO NOT EDIT)
        special_zone_guid   = "YYYYYY", -- Zone where Special Actions are placed
        table_zone = { x = 15, y = 1.5, z = 5 },
        special_dest = { x = 25, y = 2.0, z = 15 },
        color = "Blue"
    }
}

-- Temp spawning height offset to prevent collisions
SPAWN_HEIGHT_OFFSET = 3.0

-- Time (in seconds) to wait between card spawns inside active layout zones
ZONE_LAYOUT_DELAY = 0.3

-- =============== ONBOARDING SCENARIOS CONFIGURATION ===============
-- Pre-configured cast lists for the learning scenarios (Task 5).
-- You can modify these lists of IDs to customize the onboarding scenarios.
ONBOARDING_SCENARIOS = {
    ["Flint"] = { -- Rhavlika Dominion
        [1] = {
            championId = "",
            unitIdsRecruited = { ["01RHA-03FAM-0005"] = 1, ["01RHA-03FAM-0006"] = 1 },
            talismanIdsEquipped = {},
            specialIds = {},
            dominion = "Rhavlika",
            champion = "Flint Dross"
        },
        [2] = {
            championId = "",
            unitIdsRecruited = { ["01RHA-03FAM-0005"] = 1, ["01RHA-03FAM-0006"] = 1 },
            talismanIdsEquipped = {},
            specialIds = { "01RHA-07SPA-0023", "01RHA-07SPA-0025" },
            dominion = "Rhavlika",
            champion = "Flint Dross"
        },
        [3] = {
            championId = "01RHA-01CHP-0001",
            unitIdsRecruited = { ["01RHA-03FAM-0005"] = 1, ["01RHA-03FAM-0006"] = 1, ["01RHA-03FAM-0007"] = 2 },
            talismanIdsEquipped = {},
            specialIds = { "01RHA-07SPA-0023", "01RHA-07SPA-0025", "01RHA-07SPA-0022", "01RHA-07SPA-0030" },
            dominion = "Rhavlika",
            champion = "Flint Dross"
        },
        [4] = {
            championId = "01RHA-01CHP-0001",
            unitIdsRecruited = { ["01RHA-03FAM-0005"] = 2, ["01RHA-03FAM-0006"] = 3, ["01RHA-03FAM-0007"] = 3 },
            talismanIdsEquipped = {},
            specialIds = { "01RHA-07SPA-0023", "01RHA-07SPA-0025", "01RHA-07SPA-0022", "01RHA-07SPA-0030", "01RHA-07SPA-0019", "01RHA-07SPA-0021" },
            dominion = "Rhavlika",
            champion = "Flint Dross"
        }
    },
    ["Ripple"] = { -- Iro-Si-Khar Dominion
        [1] = {
            championId = "",
            unitIdsRecruited = { ["02IRO-03FAM-0038"] = 1, ["02IRO-03FAM-0039"] = 1 },
            talismanIdsEquipped = {},
            specialIds = {},
            dominion = "Iro-Si-Khar",
            champion = "Ripple Elshara"
        },
        [2] = {
            championId = "",
            unitIdsRecruited = { ["02IRO-03FAM-0038"] = 1, ["02IRO-03FAM-0039"] = 1 },
            talismanIdsEquipped = {},
            specialIds = { "02IRO-07SPA-0055", "02IRO-07SPA-0058" },
            dominion = "Iro-Si-Khar",
            champion = "Ripple Elshara"
        },
        [3] = {
            championId = "02IRO-01CHP-0034",
            unitIdsRecruited = { ["02IRO-03FAM-0038"] = 1, ["02IRO-03FAM-0039"] = 1, ["02IRO-03FAM-0040"] = 2 },
            talismanIdsEquipped = {},
            specialIds = { "02IRO-07SPA-0055", "02IRO-07SPA-0058", "02IRO-07SPA-0057", "02IRO-07SPA-0064"},
            dominion = "Iro-Si-Khar",
            champion = "Ripple Elshara"
        },
        [4] = {
            championId = "02IRO-01CHP-0034",
            unitIdsRecruited = { ["02IRO-03FAM-0038"] = 3, ["02IRO-03FAM-0039"] = 3, ["02IRO-03FAM-0040"] = 3 },
            talismanIdsEquipped = {},
            specialIds = { "02IRO-07SPA-0055", "02IRO-07SPA-0058", "02IRO-07SPA-0057", "02IRO-07SPA-0064", "02IRO-07SPA-0056", "02IRO-07SPA-0062" },
            dominion = "Iro-Si-Khar",
            champion = "Ripple Elshara"
        }
    },
    ["Lark"] = { -- Voisira Dominion
        [1] = {
            championId = "",
            unitIdsRecruited = { ["03VOI-03FAM-0073"] = 1, ["03VOI-03FAM-0078"] = 1 },
            talismanIdsEquipped = {},
            specialIds = {},
            dominion = "Voisira",
            champion = "Lark"
        },
        [2] = {
            championId = "",
            unitIdsRecruited = { ["03VOI-03FAM-0073"] = 1, ["03VOI-03FAM-0078"] = 1 },
            talismanIdsEquipped = {},
            specialIds = { "03VOI-07SPA-0095", "03VOI-07SPA-0090"  },
            dominion = "Voisira",
            champion = "Lark"
        },
        [3] = {
            championId = "03VOI-01CHP-0068",
            unitIdsRecruited = { ["03VOI-03FAM-0072"] = 1, ["03VOI-03FAM-0073"] = 2, ["03VOI-03FAM-0078"] = 1 },
            talismanIdsEquipped = {},
            specialIds = { "03VOI-07SPA-0095", "03VOI-07SPA-0090", "03VOI-07SPA-0087", "03VOI-07SPA-0091"  },
            dominion = "Voisira",
            champion = "Lark"
        },
        [4] = {
            championId = "03VOI-01CHP-0068",
            unitIdsRecruited = { ["03VOI-03FAM-0072"] = 3, ["03VOI-03FAM-0073"] = 3, ["03VOI-03FAM-0078"] = 3 },
            talismanIdsEquipped = {},
            specialIds = { "03VOI-07SPA-0095", "03VOI-07SPA-0090", "03VOI-07SPA-0087", "03VOI-07SPA-0091", "03VOI-07SPA-0086", "03VOI-07SPA-0089"  },
            dominion = "Voisira",
            champion = "Lark"
        }
    }
}


-- =============== WEBHOOK & GAME RECORD CONFIGURATION ===============
-- Global tables for tracking match state and logged actions
loadedCasts = {}          -- Loaded cast configurations keyed by player colour
specialActionsLog = {}    -- Chronological record of Special Actions played

-- Global tracking tables and JSON snapshots for map auto-deployment
deployedMapTiles = {}
deployedMapFonts = {}
savedTileDeckJSON = nil
savedFontDeckJSON = nil

-- Global parameter storage to pass arguments safely into the coroutine
local activeCoroutineParams = nil

-- Global lock to synchronize asynchronous card-cloning operations
local isCloning = false

-- Global lock preventing overlapping loadCastCoroutine runs (TTS allows only one active
-- coroutine per object, but a second click while loading fails silently without this check)
local isLoadingCast = false

function onLoad()
    print("Monumentum Cast Loader initialised.")
    self.setName("Monumentum Cast Loader")
    self.setDescription("Drafts your Cast lists on the table using zones.")
    
    -- Seed random number generator
    math.randomseed(os.time())
    
    -- Setup Onboarding XML UI dynamically (Task 5)
    setupXmlUi()
    
    -- Draw classic 3D Lua buttons flat on the token surface (Matching your exact tile style!)
    drawButtons()
    
    -- Proactively cache the map decks after a brief moment to allow physics to settle
    Wait.time(function() captureMapDecks() end, 1.5)
end

function drawButtons()
    self.clearButtons()
    
    -- Load Player 1 Button (Red / Top) - Shifted forward (Z = -0.7)
    self.createButton({
        click_function = "btnLoadPlayer1",
        function_owner = self,
        label          = "Load Red Player",
        position       = {0, 0.2, -0.7},
        rotation       = {0, 0, 0},
        width          = 1600,
        height         = 350,
        font_size      = 170,
        color          = {192/255, 57/255, 43/255}, -- Red color
        font_color     = {1, 1, 1}
    })

    -- Load Player 2 Button (Blue / Middle) - Shifted backward (Z = 0)
    self.createButton({
        click_function = "btnLoadPlayer2",
        function_owner = self,
        label          = "Load Blue Player",
        position       = {0, 0.2, 0},
        rotation       = {0, 0, 0},
        width          = 1600,
        height         = 350,
        font_size      = 170,
        color          = {41/255, 128/255, 185/255}, -- Blue color
        font_color     = {1, 1, 1}
    })

    -- Launch Onboarding Menu Button (Purple / Bottom-most) - Shifted further backward (Z = 0.7)
    self.createButton({
        click_function = "btnToggleOnboarding",
        function_owner = self,
        label          = "Onboarding Menu",
        position       = {0, 0.2, 0.7},
        rotation       = {0, 0, 0},
        width          = 1600,
        height         = 350,
        font_size      = 170,
        color          = {155/255, 89/255, 182/255}, -- Purple color
        font_color     = {1, 1, 1}
    })
end

-- Load Player 1 (Red) Trigger
function btnLoadPlayer1(obj, player_color, alt_click)
    -- Native TTS Player Input Prompt Box (using Lua function callbacks)
    Player[player_color].showInputDialog("Player 1 (Red): Paste Cast JSON", "", function(text, color)
        submitCast1(text, color)
    end)
end

-- Load Player 2 (Blue) Trigger
function btnLoadPlayer2(obj, player_color, alt_click)
    Player[player_color].showInputDialog("Player 2 (Blue): Paste Cast JSON", "", function(text, color)
        submitCast2(text, color)
    end)
end

-- Native Submit Callbacks
function submitCast1(text, color)
    processPastedCast(1, Player[color], text)
end

-- Native Submit Callbacks
function submitCast2(text, color)
    processPastedCast(2, Player[color], text)
end

function processPastedCast(playerNum, player, jsonText)
    if isLoadingCast then
        broadcastToColor("A cast is already loading — please wait for it to finish.", player.color, {1, 0, 0})
        return
    end

    if jsonText == nil or jsonText == "" then
        broadcastToColor("Paste field was empty! Please copy the exported JSON from your cast builder.", player.color, {1,0,0})
        return
    end

    -- Parse JSON
    local success, castData = pcall(function() return JSON.decode(jsonText) end)
    if not success or not castData then
        broadcastToColor("Error: Invalid JSON format. Make sure you copied the entire exported text from your browser.", player.color, {1,0,0})
        return
    end

    -- Store the parsed cast data into our global tracking table
    local playerColour = PLAYER_CONFIG[playerNum].color
    loadedCasts[playerColour] = castData

    -- Store arguments in global parameter storage before running coroutine
    activeCoroutineParams = {playerNum = playerNum, clickerColor = player.color, castData = castData}

    -- Run Loader Coroutine
    isLoadingCast = true
    startLuaCoroutine(self, "loadCastCoroutine")
end

-- Clears previous cards in hand and models in zone for the given player to allow fresh redraws
function clearPlayerWorkspace(playerNum)
    local config = PLAYER_CONFIG[playerNum]
    if not config then return end
    
    local color = config.color
    
    -- 1. Clear Player's Hand
    if Player[color] then
        local handObjects = Player[color].getHandObjects()
        if handObjects then
            for _, obj in ipairs(handObjects) do
                if obj and not obj.isDestroyed() then
                    destroyObject(obj)
                end
            end
        end
    end
    
    -- 2. Clear character scripting zone
    if config.character_zone_guid and config.character_zone_guid ~= "XXXXXX" and config.character_zone_guid ~= "" then
        local zone = getObjectFromGUID(config.character_zone_guid)
        if zone then
            for _, obj in ipairs(zone.getObjects()) do
                -- Prevent destroying the zone itself or other vital objects
                if obj and obj.getGUID() ~= config.character_zone_guid then
                    if obj ~= self and obj.type ~= "Table" and obj.type ~= "Zone" then
                        destroyObject(obj)
                    end
                end
            end
        end
    end
end

-- Coroutine to handle step-by-step take, clone, and return operations smoothly
function loadCastCoroutine()
    -- Safely retrieve parameters from global storage (TTS coroutines do not accept arguments)
    local params = activeCoroutineParams
    activeCoroutineParams = nil -- Clear immediately
    
    if not params then isLoadingCast = false; return 1 end
    
    local playerNum = params.playerNum
    local clickerColor = params.clickerColor
    local castData = params.castData
    
    local config = PLAYER_CONFIG[playerNum]
    local spawnPos = config.special_dest -- Safe temporary spawn coordinates before dealing to hand
    local targetModelRot = (config.color == "Red") and {0, 270, 0} or {0, 90, 0}
    
    -- Clear previous cards in hand and models in zone for a clean fresh redraw (Tweak 1)
    clearPlayerWorkspace(playerNum)
    yieldSeconds(0.4) -- Wait a brief moment for the physics engine to register removals
    
    -- If Player 1 (Red / Bottom) loads their cast, automatically handle map deployment in parallel
    if playerNum == 1 then
        local scenarioNum = castData.scenarioNum or 4 -- Default to Scenario 4 (Full standard game)
        deployScenarioMap(scenarioNum, clickerColor)
    end
    
    broadcastToAll("Loading Cast for Player " .. playerNum .. " (" .. (castData.dominion or "Unknown") .. " - " .. (castData.champion or "Unknown") .. ")...", {0.1, 0.8, 0.1})
    
    -- Initial verification: Verify decks are strictly present in trigger zones before loading
    local initialCastDeck = findCastDeck()
    if not initialCastDeck then
        broadcastToColor("Error: Could not find any Deck/Card in the Cast Trigger Zone. Check your CAST_ZONE_GUID.", clickerColor, {1,0,0})
        isLoadingCast = false
        return 1
    end
    
    -- Reduced onboarding scenarios (Scenarios 1 & 2) should not load the Champion card/standee, or minion tokens (Tweak 2)
    local isReducedScenario = (castData.scenarioNum ~= nil and (castData.scenarioNum == 1 or castData.scenarioNum == 2))
    
    -- 2. Extract and deal Champion to Hand
    local champName = castData.champion
    local champId = castData.championId
    if (champName or champId) and not isReducedScenario then
        -- Fresh lookup to ensure valid Unity object references
        local castDeck = findCastDeck()
        if not castDeck then
            broadcastToColor("Error: Cast deck vanished or was moved during loading.", clickerColor, {1,0,0})
            isLoadingCast = false
            return 1
        end

        isCloning = true
        local success = cloneCardFromDeck(castDeck, champName, champId, spawnPos, {0, 180, 180}, config.color)
        if success then
            -- Wait for the asynchronous clone callback to finish returning the card before proceeding!
            while isCloning do
                coroutine.yield(0)
            end
            yieldSeconds(0.2)
        else
            isCloning = false
            print("Warning: Champion card not found: " .. (champName or "Unnamed") .. " / " .. (champId or "No ID"))
        end
    end
    
    -- 3. Extract Units, deal 1 Card to Hand, and spawn recruited Models
    local modelsBag = getBagFromZone(MODELS_ZONE_GUID)
    if not modelsBag then
        print("Warning: Models Bag not found in trigger zone " .. MODELS_ZONE_GUID .. ". Models will not be spawned.")
    end

    local unitIndex = 0

    -- 3a. Spawn Champion Standee (Task 3 Improvement - Champion as Character 1)
    local champId = castData.championId
    if champId and champId ~= "" and not isReducedScenario and modelsBag then
        unitIndex = unitIndex + 1
        local spawnTarget = getSpawnPositionForModels(config)
        
        local xStart = (config.color == "Red") and -23.5 or 23.5
        local zStart = (config.color == "Red") and -5.0 or 5.0
        local xDirection = (config.color == "Red") and 1 or -1
        local zDirection = (config.color == "Red") and -1 or 1
        local zSpacing = 2.5
        
        local unitSpawnPos = {
            x = xStart,
            y = spawnTarget.y,
            z = zStart + (unitIndex * zSpacing * zDirection)
        }

        isCloning = true
        -- Spawn exactly 1 copy of the Champion standee
        local modelSuccess = cloneModelFromBag(modelsBag, champId, 1, unitSpawnPos, targetModelRot, xDirection, false, config.color)
        if modelSuccess then
            while isCloning do
                coroutine.yield(0)
            end
            yieldSeconds(0.2)
        else
            isCloning = false
            print("Warning: Champion model not found in bag for ID: " .. champId .. " (has the bag been re-run through Model_ID_Injector since the ID format changed?)")
        end
    end

    -- 3b. Loop and spawn recruited Unit Standees
    if castData.unitIdsRecruited and next(castData.unitIdsRecruited) then
        for unitId, qty in pairs(castData.unitIdsRecruited) do
            unitIndex = unitIndex + 1
            local castDeck = findCastDeck()
            if not castDeck then
                print("Error: Cast deck vanished during units loop.")
                break
            end

            -- Clone Card to Hand
            isCloning = true
            local success = cloneCardFromDeck(castDeck, "", unitId, spawnPos, {0, 180, 180}, config.color)
            if success then
                while isCloning do
                    coroutine.yield(0)
                end
                yieldSeconds(0.2)
            else
                isCloning = false
                print("Warning: Unit card ID not found: " .. unitId)
            end

            -- Clone 3D Models to Layout Zone
            if modelsBag and qty and qty > 0 then
                local spawnTarget = getSpawnPositionForModels(config)
                
                local xStart = (config.color == "Red") and -23.5 or 23.5
                local zStart = (config.color == "Red") and -5.0 or 5.0
                local xDirection = (config.color == "Red") and 1 or -1
                local zDirection = (config.color == "Red") and -1 or 1
                local zSpacing = 2.5
                
                local unitSpawnPos = {
                    x = xStart,
                    y = spawnTarget.y,
                    z = zStart + (unitIndex * zSpacing * zDirection)
                }

                isCloning = true
                -- Rotate standees around Y so they face the players directly
                local modelSuccess = cloneModelFromBag(modelsBag, unitId, qty, unitSpawnPos, targetModelRot, xDirection, false, config.color)
                if modelSuccess then
                    while isCloning do
                        coroutine.yield(0)
                    end
                    yieldSeconds(0.2)
                else
                    isCloning = false
                    print("Warning: Unit model not found in bag for ID: " .. unitId .. " (has the bag been re-run through Model_ID_Injector since the ID format changed?)")
                end
            end
        end
    end

    -- 3c. Auto-Spawn 12 Stacked Minions (Driplet / Huskling Lot for Iro-Si-Khar & Ahèserec) (Tweak 2)
    if (castData.dominion == "Iro-Si-Khar" or castData.dominion == "Ahèserec") and not isReducedScenario then
        if modelsBag then
            unitIndex = unitIndex + 1
            local minionId = (castData.dominion == "Iro-Si-Khar") and "02IRO-04MIN-0048" or "05AHE-04MIN-0148"
            local spawnTarget = getSpawnPositionForModels(config)
            
            local xStart = (config.color == "Red") and -23.5 or 23.5
            local zStart = (config.color == "Red") and -5.0 or 5.0
            local xDirection = (config.color == "Red") and 1 or -1
            local zDirection = (config.color == "Red") and -1 or 1
            local zSpacing = 2.5
            
            local minionSpawnPos = {
                x = xStart,
                y = spawnTarget.y,
                z = zStart + (unitIndex * zSpacing * zDirection)
            }

            isCloning = true
            -- Spawn exactly 12 copies and stack them vertically (isStacked = true)
            local modelSuccess = cloneModelFromBag(modelsBag, minionId, 12, minionSpawnPos, targetModelRot, xDirection, true, config.color)
            if modelSuccess then
                while isCloning do
                    coroutine.yield(0)
                end
                yieldSeconds(0.2)
            else
                isCloning = false
                print("Warning: Minion model not found in bag for ID: " .. minionId .. " (has the bag been re-run through Model_ID_Injector since the ID format changed?)")
            end
        end
    end
    
    -- 4. Extract and deal Talismans to Hand (Task 4)
    if castData.talismanIdsEquipped and next(castData.talismanIdsEquipped) then
        for talId, attachment in pairs(castData.talismanIdsEquipped) do
            local castDeck = findCastDeck()
            if not castDeck then
                print("Error: Cast deck vanished during talismans loop.")
                break
            end

            isCloning = true
            local success = cloneCardFromDeck(castDeck, "", talId, spawnPos, {0, 180, 180}, config.color)
            if success then
                while isCloning do
                    coroutine.yield(0)
                end
                yieldSeconds(0.2)
            else
                isCloning = false
                print("Warning: Talisman card ID not found: " .. talId)
            end
        end
    end
    
    -- 4.5 Auto-Summon Minions (Task 1)
    if (castData.dominion == "Iro-Si-Khar" or castData.dominion == "Ahèserec") and not isReducedScenario then
        local minionName = (castData.dominion == "Iro-Si-Khar") and "Driplet" or "Huskling"
        local minionId = (castData.dominion == "Iro-Si-Khar") and "02IRO-04MIN-0048" or "05AHE-04MIN-0148"
        local castDeck = findCastDeck()
        if castDeck then
            isCloning = true
            local success = cloneCardFromDeck(castDeck, minionName, minionId, spawnPos, {0, 180, 180}, config.color)
            if success then
                while isCloning do
                    coroutine.yield(0)
                end
                yieldSeconds(0.2)
            else
                isCloning = false
                print("Warning: Auto-summon minion card not found: " .. minionName .. " (" .. minionId .. ")")
            end
        end
    end
    
    -- 5. Extract and deal Special Action cards to player's Hand (Task 4)
    if castData.specialIds and #castData.specialIds > 0 then
        for i, specId in ipairs(castData.specialIds) do
            local castDeck = findCastDeck()
            if not castDeck then
                print("Error: Cast deck vanished during specials loop.")
                break
            end

            isCloning = true
            local success = cloneCardFromDeck(castDeck, "", specId, spawnPos, {0, 180, 180}, config.color)
            if success then
                while isCloning do
                    coroutine.yield(0)
                end
                yieldSeconds(0.2)
            else
                isCloning = false
                print("Warning: Special card ID not found: " .. specId)
            end
        end
    end
    
    broadcastToAll("Cast for Player " .. playerNum .. " loaded successfully!", {0.1, 0.9, 0.1})
    isLoadingCast = false
    return 1
end

-- Retrieve Deck/Card from Scripting Zone
function getDeckFromZone(zoneGuid)
    if zoneGuid == "XXXXXX" or zoneGuid == "" or zoneGuid == nil then return nil end
    local zone = getObjectFromGUID(zoneGuid)
    if not zone then return nil end
    
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Deck" or obj.type == "Card" then
            return obj
        end
    end
    return nil
end

-- Find the single Cast deck strictly from the designated Scripting Zone
function findCastDeck()
    local castDeck = getDeckFromZone(CAST_ZONE_GUID)
    
    if not castDeck then
        print("Error: Could not find any Deck or Card inside the Cast Trigger Zone (" .. CAST_ZONE_GUID .. ").")
    end
    
    return castDeck
end

-- Core Function: Clones a specific card by name OR unique ID (GM Notes) from a deck, and drops original back
function cloneCardFromDeck(deck, cardName, cardId, targetPos, targetRot, playerColor)
    -- Handle single Card container vs Deck container
    if deck.type == "Card" then
        local matched = false
        local objId = deck.getGMNotes()
        if cardId ~= nil and cardId ~= "" and objId == cardId then
            matched = true
        else
            local objName = deck.getName()
            if objName == "" or objName == nil then objName = deck.getDescription() end
            if objName:lower() == cardName:lower() then
                matched = true
            end
        end
        
        if matched then
            local clonedObj = deck.clone({
                position = {x = targetPos.x, y = targetPos.y, z = targetPos.z},
                rotation = targetRot
            })
            Wait.frames(function()
                if clonedObj ~= nil and not clonedObj.isDestroyed() then
                    clonedObj.deal(1, playerColor)
                end
            end, 2)
            -- Release coroutine immediately for single cards
            isCloning = false
            return true
        end
        isCloning = false
        return false
    end

    -- Standard Deck search
    for _, objInfo in ipairs(deck.getObjects()) do
        local matched = false
        local objId = objInfo.gm_notes
        
        if cardId ~= nil and cardId ~= "" and objId == cardId then
            matched = true
        else
            local objName = objInfo.nickname
            if objName == "" or objName == nil then objName = objInfo.name end
            if objName:lower() == cardName:lower() then
                matched = true
            end
        end
        
        if matched then
            -- Take original card out briefly
            local spawnedCard = deck.takeObject({
                index = objInfo.index,
                position = {x = targetPos.x, y = targetPos.y + SPAWN_HEIGHT_OFFSET, z = targetPos.z},
                rotation = targetRot,
                smooth = false,
                callback_function = function(cardObj)
                    -- Clone it to its exact destination
                    local clonedObj = cardObj.clone({
                        position = {x = targetPos.x, y = targetPos.y, z = targetPos.z},
                        rotation = targetRot
                    })
                    
                    -- Deal the clone directly into the player's Hand after a small frame delay
                    Wait.frames(function()
                        if clonedObj ~= nil and not clonedObj.isDestroyed() then
                            clonedObj.deal(1, playerColor)
                        end
                    end, 2)
                    
                    -- Return original card to the deck after a 3-frame delay to let clone spawn safely first
                    Wait.frames(function()
                        local ok, err = pcall(function()
                            if cardObj ~= nil and not cardObj.isDestroyed() and deck ~= nil and not deck.isDestroyed() then
                                -- Instant teleport back to the deck's physical position to prevent physical drift/clashing across the table!
                                cardObj.setPosition(deck.getPosition())
                                deck.putObject(cardObj)
                            end
                        end)
                        if not ok then
                            print("Error returning card to deck: " .. tostring(err))
                        end
                        -- ALWAYS release the coroutine thread lock, even if putObject failed!
                        isCloning = false
                    end, 3)
                end
            })
            return true
        end
    end
    isCloning = false
    return false
end

-- Helper function to yield coroutine execution for TTS
function yieldSeconds(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do
        coroutine.yield(0)
    end
end

-- ================= END GAME API & WEBHOOK SUPPORT =================

-- Global function to record a Special Action played during the game
-- This can be called from individual card scripts, trigger zones, or manual inputs
function logSpecialAction(playerColour, cardName, cardId)
    local entry = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"), -- UTC timestamp in ISO 8601 format
        player = playerColour,
        name = cardName,
        id = cardId
    }
    table.insert(specialActionsLog, entry)
    print("Logged Special Action: " .. tostring(cardName) .. " (" .. tostring(cardId) .. ") played by " .. tostring(playerColour))
end

-- Exposes match data as a JSON string to avoid Tabletop Simulator cross-script sandboxing/ownership errors
function getMatchDataJson()
    local matchData = {
        loadedCasts = loadedCasts,
        specialActionsLog = specialActionsLog
    }
    return JSON.encode(matchData)
end

-- ================= TASK 3 MODEL SPAWNING HELPERS =================

-- Retrieve Bag from Scripting Zone
function getBagFromZone(zoneGuid)
    if zoneGuid == "XXXXXX" or zoneGuid == "" or zoneGuid == nil then return nil end
    local zone = getObjectFromGUID(zoneGuid)
    if not zone then return nil end
    
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Bag" or obj.type == "Infinite" then
            return obj
        end
    end
    return nil
end

-- Get central physical spawn position for models
function getSpawnPositionForModels(config)
    if config.character_zone_guid and config.character_zone_guid ~= "XXXXXX" and config.character_zone_guid ~= "" then
        local zone = getObjectFromGUID(config.character_zone_guid)
        if zone then
            return zone.getPosition()
        end
    end
    return config.table_zone
end

-- Core Function: Clones a specific model by ID from a bag N times, arranging them to the right, and returns original to the bag
function cloneModelFromBag(bag, modelId, qty, targetPos, targetRot, xDirection, isStacked, playerColor)
    if not bag then return false end
    
    for _, objInfo in ipairs(bag.getObjects()) do
        if objInfo.gm_notes == modelId then
            -- Take original model out briefly
            local spawnedModel = bag.takeObject({
                guid = objInfo.guid,
                position = {x = targetPos.x, y = targetPos.y + SPAWN_HEIGHT_OFFSET, z = targetPos.z},
                rotation = targetRot,
                smooth = false,
                callback_function = function(modelObj)
                    -- Clone it qty times
                    for q = 1, qty do
                        local modelPos
                        if isStacked then
                            -- Stack vertically: same X and Z, increased Y height per copy
                            modelPos = {
                                x = targetPos.x,
                                y = targetPos.y + ((q - 1) * 0.4), -- perfect vertical stack height spacing
                                z = targetPos.z
                            }
                        else
                            -- Place models: first copy at targetPos.x, subsequent copies build inwards
                            modelPos = {
                                x = targetPos.x + ((q - 1) * 1.8 * xDirection),
                                y = targetPos.y,
                                z = targetPos.z
                            }
                        end
                        
                        local clonedObj = modelObj.clone({
                            position = modelPos,
                            rotation = targetRot
                        })
                        
                        if playerColor and clonedObj ~= nil then
                            clonedObj.setColorTint(playerColor)
                        end
                    end
                    
                    -- Return original model to the bag after a small frame delay to let clones spawn safely first
                    Wait.frames(function()
                        local ok, err = pcall(function()
                            if modelObj ~= nil and not modelObj.isDestroyed() and bag ~= nil and not bag.isDestroyed() then
                                modelObj.setPosition(bag.getPosition())
                                bag.putObject(modelObj)
                            end
                        end)
                        if not ok then
                            print("Error returning model to bag: " .. tostring(err))
                        end
                        isCloning = false
                    end, 3)
                end
            })
            return true
        end
    end
    isCloning = false
    return false
end

-- ================= TASK 5 NATIVE ONBOARDING FEATURES =================

-- Onboarding XML UI State
selectedChamp = "Flint"
selectedScenario = 1
selectedPlayer = 1

-- Global tracking of the active End Game Controller GUID for cross-script callbacks
activeControllerGuid = nil

-- Build the screen-space XML panels dynamically on load (Task 5 Improvements - Global Screen Space)
function setupXmlUi()
    local myGuid = self.getGUID()
    local xml = string.format([[
<Defaults>
    <Button class="start-btn" width="180" height="40" fontSize="16" color="#2ecc71" textColor="#ffffff" fontStyle="Bold" />
    <Button class="close-btn" width="100" height="40" fontSize="16" color="#95a5a6" textColor="#ffffff" />
    <Text class="header" fontSize="18" fontStyle="Bold" color="#ffffff" alignment="Inferred" />
    
    <Button class="menu-btn" width="220" height="42" fontSize="16" textColor="#ffffff" fontStyle="Bold" />
    <Button class="cancel-btn" width="120" height="40" fontSize="15" color="#7f8c8d" textColor="#ffffff" />
    <Text class="header-game" fontSize="20" fontStyle="Bold" color="#ffffff" alignment="MiddleCenter" />
</Defaults>

<!-- Onboarding Panel -->
<Panel id="onboardPanel" active="false" width="450" height="300" color="#2c3e50" rectAlignment="MiddleCenter" padding="20" showAnimation="SlideIn_Bottom" hideAnimation="SlideOut_Bottom">
    <VerticalLayout spacing="15">
        <Text class="header" alignment="MiddleCenter">Monumentum Onboarding Setup</Text>
        
        <HorizontalLayout spacing="10" height="35">
            <Text color="#ffffff" fontSize="15" alignment="MiddleLeft">Champion:</Text>
            <Dropdown id="ddChamp" onValueChanged="%s/onChampSelected" width="220" height="30">
                <option selected="true">Flint</option>
                <option>Ripple</option>
                <option>Lark</option>
            </Dropdown>
        </HorizontalLayout>
        
        <HorizontalLayout spacing="10" height="35">
            <Text color="#ffffff" fontSize="15" alignment="MiddleLeft">Scenario:</Text>
            <Dropdown id="ddScenario" onValueChanged="%s/onScenarioSelected" width="220" height="30">
                <option selected="true">Scenario 1</option>
                <option>Scenario 2</option>
                <option>Scenario 3</option>
                <option>Scenario 4</option>
            </Dropdown>
        </HorizontalLayout>

        <HorizontalLayout spacing="10" height="35">
            <Text color="#ffffff" fontSize="15" alignment="MiddleLeft">Load For:</Text>
            <Dropdown id="ddPlayer" onValueChanged="%s/onPlayerSelected" width="220" height="30">
                <option selected="true">Red Player</option>
                <option>Blue Player</option>
            </Dropdown>
        </HorizontalLayout>
        
        <HorizontalLayout spacing="20" height="50" alignment="MiddleCenter">
            <Button class="start-btn" onClick="%s/btnSpawnOnboarding">LOAD SCENARIO</Button>
            <Button class="close-btn" onClick="%s/btnHideOnboard">CLOSE</Button>
        </HorizontalLayout>
    </VerticalLayout>
</Panel>

<!-- Screen-Space End Game Winner Selection Modal -->
<Panel id="endGamePanel" active="false" width="400" height="280" color="#2c3e50" rectAlignment="MiddleCenter" padding="20" showAnimation="SlideIn_Bottom" hideAnimation="SlideOut_Bottom">
    <VerticalLayout spacing="15">
        <Text class="header-game">Declare Game Winner</Text>
        
        <VerticalLayout spacing="10" alignment="MiddleCenter">
            <Button class="menu-btn" onClick="%s/btnSelectRedXml" color="#e74c3c">Red Won</Button>
            <Button class="menu-btn" onClick="%s/btnSelectBlueXml" color="#3498db">Blue Won</Button>
            <Button class="menu-btn" onClick="%s/btnSelectDrawXml" color="#95a5a6">Draw</Button>
        </VerticalLayout>
        
        <HorizontalLayout alignment="MiddleCenter" height="40">
            <Button class="cancel-btn" onClick="%s/btnCancelXml">Cancel</Button>
        </HorizontalLayout>
    </VerticalLayout>
</Panel>
]], myGuid, myGuid, myGuid, myGuid, myGuid, myGuid, myGuid, myGuid, myGuid)
    UI.setXml(xml)
end

-- API function called by End Game Controller to trigger the screen-space picker panel
function showScreenSpaceEndGamePanel(params)
    if params and params.controller_guid then
        activeControllerGuid = params.controller_guid
    end
    UI.setAttribute("endGamePanel", "active", "true")
end

-- Screen Space End Game Callback Event Handlers
function btnCancelXml(player, value, id)
    if not player.host then
        broadcastToColor("Only the Host can cancel.", player.color, {1, 0, 0})
        return
    end
    UI.setAttribute("endGamePanel", "active", "false")
    activeControllerGuid = nil
end

function btnSelectRedXml(player, value, id)
    if not player.host then
        broadcastToColor("Only the Host can declare the winner.", player.color, {1, 0, 0})
        return
    end
    UI.setAttribute("endGamePanel", "active", "false")
    if activeControllerGuid then
        local controller = getObjectFromGUID(activeControllerGuid)
        if controller then
            controller.call("declareWinnerAndSubmit", { winner = "Red", player_color = player.color })
        end
    end
end

function btnSelectBlueXml(player, value, id)
    if not player.host then
        broadcastToColor("Only the Host can declare the winner.", player.color, {1, 0, 0})
        return
    end
    UI.setAttribute("endGamePanel", "active", "false")
    if activeControllerGuid then
        local controller = getObjectFromGUID(activeControllerGuid)
        if controller then
            controller.call("declareWinnerAndSubmit", { winner = "Blue", player_color = player.color })
        end
    end
end

function btnSelectDrawXml(player, value, id)
    if not player.host then
        broadcastToColor("Only the Host can declare the winner.", player.color, {1, 0, 0})
        return
    end
    UI.setAttribute("endGamePanel", "active", "false")
    if activeControllerGuid then
        local controller = getObjectFromGUID(activeControllerGuid)
        if controller then
            controller.call("declareWinnerAndSubmit", { winner = "Draw", player_color = player.color })
        end
    end
end

-- Toggles Onboarding UI visibility (using global UI)
function btnToggleOnboarding(obj, player_color, alt_click)
    local active = UI.getAttribute("onboardPanel", "active")
    if active == "true" then
        UI.setAttribute("onboardPanel", "active", "false")
    else
        UI.setAttribute("onboardPanel", "active", "true")
    end
end

-- Closes Onboarding UI
function btnHideOnboard(player, value, id)
    UI.setAttribute("onboardPanel", "active", "false")
end

-- Dropdown Selection Callbacks
function onChampSelected(player, value, id)
    selectedChamp = value
end

function onScenarioSelected(player, value, id)
    local num = value:match("%d+")
    selectedScenario = tonumber(num) or 1
end

function onPlayerSelected(player, value, id)
    if value == "Red Player" then
        selectedPlayer = 1
    else
        selectedPlayer = 2
    end
end

-- Helper function to deep copy tables to prevent side-effects from mutating shared configs
function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Submits selected onboarding configurations to the main coroutine loader
function btnSpawnOnboarding(player, value, id)
    if not player.host then
        broadcastToColor("Only the Host can load onboarding scenarios.", player.color, {1, 0, 0})
        return
    end
    
    local scenarioDataRaw = ONBOARDING_SCENARIOS[selectedChamp][selectedScenario]
    if not scenarioDataRaw then
        broadcastToColor("Error: Scenario not configured yet.", player.color, {1, 0, 0})
        return
    end
    
    -- Hide Onboarding Menu
    UI.setAttribute("onboardPanel", "active", "false")
    
    -- Create a deep copy to avoid mutating the original configuration table
    local scenarioData = deepCopy(scenarioDataRaw)
    
    -- Dynamically inject scenarioNum so the loader knows which scenario is active (Tweak 2)
    scenarioData.scenarioNum = selectedScenario
    
    -- Pass scenario serialized configuration directly into our robust loading pipeline!
    processPastedCast(selectedPlayer, player, JSON.encode(scenarioData))
end

-- ================= MAP AUTO-DEPLOYMENT NATIVE SUPPORT =================

-- Pre-configured grid sizes, offsets, and relative font coordinates for each scenario.
-- Scenario 4 represents the full standard game (6x6 grid with manual font deployment).
MAP_SCENARIOS = {
    [1] = {
        gridCols = 2,
        gridRows = 2,
        startCol = 3, -- Starts at column 3 to centralise the 2x2 grid in a 6x6 area
        startRow = 3, -- Starts at row 3 to centralise the 2x2 grid in a 6x6 area
        fonts = { {0.5, 0.5} }
    },
    [2] = {
        gridCols = 2,
        gridRows = 2,
        startCol = 3,
        startRow = 3,
        fonts = { {0.5, 0.5} }
    },
    [3] = {
        gridCols = 4,
        gridRows = 4,
        startCol = 2, -- Starts at column 2 to centralise the 4x4 grid in a 6x6 area
        startRow = 2, -- Starts at row 2 to centralise the 4x4 grid in a 6x6 area
        fonts = { {2.5, 0.5}, {1.5, 1.5}, {0.5, 2.5} }
    },
    [4] = {
        gridCols = 6,
        gridRows = 6,
        startCol = 1,
        startRow = 1,
        fonts = {} -- Scenario 4 does not auto-deploy fonts; players use Font Controller
    }
}

-- Natively deploys the appropriate scenario grid and fonts on the table
function deployScenarioMap(scenarioNum, clickerColor)
    -- Determine scenario configuration
    local scenario = MAP_SCENARIOS[scenarioNum]
    if not scenario then
        print("Warning: Scenario " .. tostring(scenarioNum) .. " has no map configuration. Defaulting to Scenario 4.")
        scenario = MAP_SCENARIOS[4]
        scenarioNum = 4
    end

    -- 1. Recall any currently active map elements to start fresh
    recallMapDeployed()
    
    -- 2. Capture pristine decks if not done already
    captureMapDecks()

    local tileDeck = findDeckInMapZone(MAP_TILE_ZONE_GUID)
    local fontDeck = findDeckInMapZone(MAP_FONT_ZONE_GUID)

    if tileDeck == nil then
        broadcastToColor("Warning: Map Path Deck missing from zone " .. MAP_TILE_ZONE_GUID .. ". Board cannot be auto-constructed.", clickerColor, {1, 0.5, 0})
        return
    end

    -- 3. Deploy Path Tiles
    local tilesNeeded = scenario.gridCols * scenario.gridRows
    if #tileDeck.getObjects() < tilesNeeded then
        broadcastToColor("Warning: Not enough tiles in deck (" .. #tileDeck.getObjects() .. " / " .. tilesNeeded .. ") to deploy Scenario " .. scenarioNum, clickerColor, {1, 0.5, 0})
        return
    end

    broadcastToAll("Auto-Deploying Scenario " .. scenarioNum .. " Board (" .. scenario.gridCols .. "x" .. scenario.gridRows .. ")...", {0.1, 0.8, 0.1})

    for row = 0, scenario.gridRows - 1 do
        for col = 0, scenario.gridCols - 1 do
            -- Apply the centralising offset (-1 translates 1-based config to 0-based math)
            local actualCol = (scenario.startCol - 1) + col
            local actualRow = (scenario.startRow - 1) + row

            local targetPos = {
                x = MAP_START_POS.x + (actualCol * MAP_SPACING),
                y = MAP_START_POS.y,
                z = MAP_START_POS.z - (actualRow * MAP_SPACING)
            }

            -- Randomize tile orientation (0, 90, 180, 270 degrees)
            local randomMultiplier = math.random(0, 3)
            local currentRot = tileDeck.getRotation()
            local targetRot = {x = currentRot.x, y = randomMultiplier * 90, z = currentRot.z}

            tileDeck.takeObject({
                position = targetPos,
                rotation = targetRot,
                smooth   = true,
                callback_function = function(obj)
                    if obj ~= nil and not obj.isDestroyed() then
                        obj.setLock(true)
                        table.insert(deployedMapTiles, obj)
                    end
                end
            })
        end
    end

    -- 4. Deploy Font Tiles (If required for this scenario)
    local fontsNeeded = #scenario.fonts
    if fontsNeeded > 0 then
        if fontDeck == nil then
            broadcastToColor("Warning: Font Deck missing from zone " .. MAP_FONT_ZONE_GUID .. ". Scenario Fonts cannot be auto-deployed.", clickerColor, {1, 0.5, 0})
            return
        end

        if #fontDeck.getObjects() < fontsNeeded then
            broadcastToColor("Warning: Not enough font tiles in deck to deploy Scenario " .. scenarioNum, clickerColor, {1, 0.5, 0})
            return
        end

        for i = 1, fontsNeeded do
            local coord = scenario.fonts[i]
            
            -- Shift font coordinates by the exact same centralized offset as the tile grid
            local actualX = (scenario.startCol - 1) + coord[1]
            local actualZ = (scenario.startRow - 1) + coord[2]

            local targetPos = {
                x = MAP_START_POS.x + (actualX * MAP_SPACING),
                y = MAP_START_POS.y + 0.05,
                z = MAP_START_POS.z - (actualZ * MAP_SPACING)
            }

            local currentRot = fontDeck.getRotation()

            fontDeck.takeObject({
                position = targetPos,
                rotation = currentRot,
                smooth   = true,
                callback_function = function(obj)
                    if obj ~= nil and not obj.isDestroyed() then
                        obj.setLock(true)
                        table.insert(deployedMapFonts, obj)
                    end
                end
            })
        end
    end
end

-- Helper: Locates a Deck container inside a Scripting Zone GUID
function findDeckInMapZone(zoneGuid)
    local zone = getObjectFromGUID(zoneGuid)
    if zone == nil then return nil end
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Deck" then return obj end
    end
    return nil
end

-- Helper: Deletes any Decks/Cards inside a Scripting Zone GUID
function clearMapZone(zoneGuid)
    local zone = getObjectFromGUID(zoneGuid)
    if zone == nil then return end
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Deck" or obj.type == "Card" then
            destroyObject(obj)
        end
    end
end

-- Captures pristine snapshots of the map and font decks if present in their zones
function captureMapDecks()
    if savedTileDeckJSON == nil then
        local tDeck = findDeckInMapZone(MAP_TILE_ZONE_GUID)
        if tDeck then savedTileDeckJSON = tDeck.getJSON() end
    end

    if savedFontDeckJSON == nil then
        local fDeck = findDeckInMapZone(MAP_FONT_ZONE_GUID)
        if fDeck then savedFontDeckJSON = fDeck.getJSON() end
    end
end

-- Clears any deployed map elements and restores decks in their scripting zones
function recallMapDeployed()
    -- 1. Destroy all deployed tiles
    for _, obj in ipairs(deployedMapTiles) do
        if obj ~= nil and not obj.isDestroyed() then destroyObject(obj) end
    end
    deployedMapTiles = {}

    -- 2. Destroy all deployed fonts
    for _, obj in ipairs(deployedMapFonts) do
        if obj ~= nil and not obj.isDestroyed() then destroyObject(obj) end
    end
    deployedMapFonts = {}

    -- 3. Clear trigger zones of leftover singles
    clearMapZone(MAP_TILE_ZONE_GUID)
    clearMapZone(MAP_FONT_ZONE_GUID)

    -- 4. Respawn pristine decks slightly above the table surface
    local tZone = getObjectFromGUID(MAP_TILE_ZONE_GUID)
    if savedTileDeckJSON and tZone then
        local pos = tZone.getPosition()
        spawnObjectJSON({
            json = savedTileDeckJSON,
            position = {pos.x, MAP_START_POS.y + 0.2, pos.z}
        })
    end

    local fZone = getObjectFromGUID(MAP_FONT_ZONE_GUID)
    if savedFontDeckJSON and fZone then
        local pos = fZone.getPosition()
        spawnObjectJSON({
            json = savedFontDeckJSON,
            position = {pos.x, MAP_START_POS.y + 0.2, pos.z}
        })
    end
end
