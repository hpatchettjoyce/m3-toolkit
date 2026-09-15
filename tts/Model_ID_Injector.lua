--[[ Tabletop Simulator Model ID Injector Script
     Written for Monumentum Cast Recruiter
     Date: Sunday, 7 June 2026
     
     INSTRUCTIONS:
     1. Attach this script to a dedicated token or object on your table.
     2. Create two Scripting Trigger Zones on your table:
        - Zone 1: Over the Cast Deck (that has IDs in GMNotes and the class in Description).
        - Zone 2: Over the Bag containing the raw 3D Models.
     3. Enter their GUIDs in CHARACTERS_ZONE_GUID and MODELS_BAG_ZONE_GUID below.
     4. Click the "Inject IDs to Models" button.
     5. The script will take each model out of the bag, clean its name, stamp its card class into
        its description, assign its GMNotes, and return it.
     6. Once complete, you can right-click and save the Bag as a customized game component!
--]]

-- The classes the deck is expected to carry in each card's Description (written by
-- generate_card_images.py). Used only to warn when a deck looks stale -- see checkClassCoverage().
KNOWN_CLASSES = {
    ["CHAMPION"] = true,
    ["FAMILIAR"] = true,
    ["MINION"] = true,
    ["TALISMAN"] = true,
    ["SPECIAL ACTION"] = true
}

-- =============== CONFIGURATION GUIDs (REQUIRED) ===============
CHARACTERS_ZONE_GUID = "83f62b"  -- Zone containing the Cast Deck (same physical zone as before)
MODELS_BAG_ZONE_GUID = "fe2114"  -- Zone containing the Raw Models Bag


local isProcessing = false

function onLoad()
    self.setName("Monumentum Model ID Injector")
    self.setDescription("Standalone utility to permanently inject Card IDs, clean nicknames, and stamp card classes onto 3D models in a bag.")
    
    -- Render Inject Button
    self.createButton({
        click_function = "btnStartInjection",
        function_owner = self,
        label          = "Inject IDs to Models",
        position       = {0, 0.2, 0},
        rotation       = {0, 0, 0},
        width          = 2200,
        height         = 450,
        font_size      = 180,
        color          = {155/255, 89/255, 182/255}, -- Purple
        font_color     = {1, 1, 1}
    })
end

-- Trigger Injection Process
function btnStartInjection(obj, player_color, alt_click)
    local player = Player[player_color]
    if not player.host then
        broadcastToColor("Only the Host can run this utility.", player_color, {1, 0, 0})
        return
    end
    
    if isProcessing then
        broadcastToColor("An injection process is already running!", player_color, {1, 0, 0})
        return
    end
    
    startLuaCoroutine(self, "injectIdsCoroutine")
end

-- Helper: Clean model nickname by stripping trailing parenthesized numbers (e.g. "Obduron (6)" -> "Obduron")
function cleanModelName(name)
    if not name then return "" end
    -- Remove optional whitespace and trailing parentheses containing numbers
    local cleaned = name:gsub("%s*%(%d+%)", "")
    -- Trim any leading or trailing spaces
    cleaned = cleaned:match("^%s*(.-)%s*$") or cleaned
    return cleaned
end

-- Coroutine to safely handle async taking, updating, and returning
function injectIdsCoroutine()
    isProcessing = true
    
    local deck = getObjectFromZone(CHARACTERS_ZONE_GUID)
    local bag = getObjectFromZone(MODELS_BAG_ZONE_GUID)
    
    if not deck then
        broadcastToAll("Error: Could not find any Deck or Card in the Characters Trigger Zone.", {1, 0, 0})
        isProcessing = false
        return 1
    end
    
    if not bag or (bag.type ~= "Bag" and bag.type ~= "Infinite") then
        broadcastToAll("Error: Could not find any Bag in the Models Bag Trigger Zone.", {1, 0, 0})
        isProcessing = false
        return 1
    end
    
    broadcastToAll("Extracting Card ID mappings from the Characters Deck...", {0.9, 0.9, 0.2})
    
    -- 1. Extract Name-to-ID mapping from the Deck
    -- Maps lowercased card name -> { id, class }. The class rides along from the deck card's
    -- Description (written by generate_card_images.py) so the model can be stamped with it --
    -- see UPGRADE_PLAN.md S3.2. Note Description is NOT a name fallback any more: it holds the
    -- class now, so falling back to it would map a card under the name "CHAMPION".
    local nameToCard = {}
    if deck.type == "Card" then
        local name = deck.getName()
        local id = deck.getGMNotes()
        if name and name ~= "" and id and id ~= "" then
            nameToCard[name:lower()] = { id = id, class = deck.getDescription() }
        end
    else
        for _, cardInfo in ipairs(deck.getObjects()) do
            local name = cardInfo.nickname
            if name == "" or name == nil then name = cardInfo.name end
            local id = cardInfo.gm_notes
            if name and name ~= "" and id and id ~= "" then
                nameToCard[name:lower()] = { id = id, class = cardInfo.description }
            end
        end
    end
    
    -- 2. Build items list to process from the Bag
    local bagObjects = bag.getObjects()
    local itemsToProcess = {}
    local unmatchedModels = {}
    
    for _, bObj in ipairs(bagObjects) do
        local rawName = bObj.nickname
        if rawName == "" or rawName == nil then rawName = bObj.name end
        
        if rawName and rawName ~= "" then
            local modelName = cleanModelName(rawName)
            local matchedCard = nameToCard[modelName:lower()]
            if matchedCard then
                table.insert(itemsToProcess, { 
                    guid = bObj.guid, 
                    rawName = rawName, 
                    cleanName = modelName, 
                    id = matchedCard.id,
                    class = matchedCard.class
                })
            else
                table.insert(unmatchedModels, rawName)
            end
        end
    end
    
    -- Print out diagnostic information for unmatched models
    if #unmatchedModels > 0 then
        print("Diagnostic: " .. #unmatchedModels .. " models in the bag could not be matched with any card in the Characters Deck:")
        local maxPrint = math.min(#unmatchedModels, 15)
        for idx = 1, maxPrint do
            print("  - [Unmatched]: " .. unmatchedModels[idx])
        end
        if #unmatchedModels > maxPrint then
            print("  - ... and " .. (#unmatchedModels - maxPrint) .. " more unmatched models.")
        end
    end
    
    -- Warn loudly if the deck is not carrying class names. This is the failure that silently
    -- produces "every model has 6 health": an old deck's Description holds prowess/fortitude prose,
    -- gets stamped onto the model, never equals "MINION", and every minion falls back to 6.
    checkClassCoverage(itemsToProcess)
    
    if #itemsToProcess == 0 then
        broadcastToAll("No matching models found in the bag that correspond to cards in the Characters Deck.", {1, 0.5, 0})
        isProcessing = false
        return 1
    end
    
    broadcastToAll("Found " .. #itemsToProcess .. " models inside the bag to update. Starting injection...", {0.1, 0.8, 0.1})
    
    -- 3. Sequentially take each model, clean name, clear description, set GM Notes, and return to Bag
    for i, item in ipairs(itemsToProcess) do
        local spawned = bag.takeObject({
            guid = item.guid,
            position = {x = 0, y = 15, z = 0}, -- High up to avoid clashing
            smooth = false,
            callback_function = function(obj)
                -- 3a. Inject database ID
                obj.setGMNotes(item.id)
                -- 3b. Rename to clean Name (removes "(6)" etc.)
                obj.setName(item.cleanName)
                -- 3c. Replace the description (prowess/fortitude stats) with the card's class.
                -- The health tracker reads its class from here; GMNotes stays the plain ID. S3.2
                obj.setDescription(item.class or "")
                -- 3d. Inject Floating Health Tracker script
                obj.script_code = HEALTH_TRACKER_SCRIPT
                local reloadedObj = obj.reload()
                
                Wait.frames(function()
                    if reloadedObj ~= nil and not reloadedObj.isDestroyed() and bag ~= nil and not bag.isDestroyed() then
                        bag.putObject(reloadedObj)
                    end
                end, 10) -- Wait 10 frames to let the reload settle before returning to bag
            end
        })
        
        -- Yield execution to allow physics, callbacks, and reloads to settle
        for f = 1, 30 do
            coroutine.yield(0)
        end
    end
    
    broadcastToAll("Success: " .. #itemsToProcess .. " models successfully updated! Re-named to clean names, stamped with their card class, injected with Database IDs, and loaded with the Floating Health Tracker script. Please save the updated Bag.", {0.1, 0.9, 0.1})
    isProcessing = false
    return 1
end

-- Reports how many matched cards carry a usable class in their Description. A deck that has not
-- been re-imported since the class was added will score zero here, which is the single most likely
-- cause of every model defaulting to 6 health.
function checkClassCoverage(items)
    local missing = 0
    local minions = 0
    local samples = {}
    for _, item in ipairs(items) do
        local class = item.class
        if class == nil or class == "" or not KNOWN_CLASSES[string.upper(class)] then
            missing = missing + 1
            if #samples < 3 then
                table.insert(samples, item.cleanName .. " -> " .. tostring(class))
            end
        elseif string.upper(class) == "MINION" then
            minions = minions + 1
        end
    end
    
    if missing > 0 then
        broadcastToAll("WARNING: " .. missing .. " of " .. #items .. " cards carry no recognisable class in their Description. Those models will default to 6 health. Re-import the Cast deck.", {1, 0.3, 0.3})
        print("Class check FAILED for " .. missing .. " of " .. #items .. " cards. Examples (card -> Description):")
        for _, sample in ipairs(samples) do
            print("  - " .. sample)
        end
    else
        print("Class check passed: all " .. #items .. " matched cards carry a known class (" .. minions .. " Minion).")
    end
end

-- Helper: Retrieve Object from Trigger Zone
function getObjectFromZone(zoneGuid)
    if zoneGuid == "XXXXXX" or zoneGuid == "" or zoneGuid == nil then return nil end
    local zone = getObjectFromGUID(zoneGuid)
    if not zone then return nil end
    
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Deck" or obj.type == "Card" or obj.type == "Bag" or obj.type == "Infinite" then
            return obj
        end
    end
    return nil
end

-- =============== FLOATING HEALTH TRACKER SCRIPT EMBEDDED ===============
-- This script is injected into each model as it is processed.
HEALTH_TRACKER_SCRIPT = [===[--[[ Tabletop Simulator Floating Health Tracker Script
     Written for Monumentum Components (Standees and Double-Sided Tiles)
     Date: Monday, 8 June 2026
     
     INSTRUCTIONS:
     1. Copy this entire script.
     2. In Tabletop Simulator, right-click the target Custom Standee or Custom Tile.
     3. Select Scripting > Scripting Editor.
     4. Paste the script into the editor.
     5. Click "Save & Play" at the top of the Scripting Editor.
     
     That's it! The script will automatically generate the 3D floating UI,
     manage its placement, and handle its visibility when flipped.
--]]

-- ============================================================================
-- =============== CONFIGURATION (ADJUST TO FIT YOUR MODELS) ==================
-- ============================================================================

-- Starting/Default health values
DEFAULT_HEALTH        = 6   -- Fallback default for any non-Minion card (Champion/Familiar/Talisman)
MINION_DEFAULT_HEALTH = 2   -- Default for any model whose card "class" is Minion, regardless of
                             -- whether it's physically a Tile or a Standee.

-- Object type detection:
--   "auto"    - Dynamically detects type (Uses "Tile" settings if the object tag is "Tile", else "Standee")
--   "tile"    - Forces Double-Sided Tile behavior (Hides UI when flipped face-down)
--   "standee" - Forces Custom Standee behavior (UI is always visible)
OBJECT_TYPE = "auto"

-- Card "class" is stamped onto this model's Description by the Model ID Injector, which copies it
-- from the matching deck card. The ID in GMNotes is for sorting only and is NEVER parsed for
-- meaning -- see UPGRADE_PLAN.md S3.2. Parsing the ID was the old approach and it was wrong: 4 of
-- the 6 Minion cards carry a "COM" segment, so they classified as non-Minions.
-- The deck writes the class in upper case ("MINION"), so compare case-insensitively.
MINION_CLASS = "MINION"

-- Height of the floating panel above the model, shared by BOTH shapes so the dials read at one
-- uniform level across the table. Tokens lie flat and standees stand upright, but the panel is
-- positioned in the object's local space along -Z, which is "up" for both -- so the same value
-- gives the same height. Tokens drifted to -175 in 31d8ebf (2026-07-27), which is what made their
-- dial sit lower than the standees'. Change this ONE value to raise or lower every dial together.
UI_HEIGHT_OFFSET = "0 0 -300"   -- -300 corresponds to 3.0 world units above the model

-- 1. CONFIGURATION FOR CUSTOM TILES (Lying flat on the table)
TILE_CONFIG = {
    position     = UI_HEIGHT_OFFSET,
    rotation     = "0 0 180",         -- Lying flat parallel to the tile's face
    scale        = "1.0 1.0 1.0",   -- Crisp 1.0 scale as preferred by the user
    width        = "320",           -- Resolution width (pixel space)
    height       = "100"            -- Resolution height (pixel space)
}

-- 2. CONFIGURATION FOR CUSTOM STANDEES (Upright 3D models/figures)
-- Lays flat horizontally above the head, making it fully readable to players sitting at any angle around the table.
STANDEE_CONFIG = {
    position     = UI_HEIGHT_OFFSET,
    rotation     = "0 0 180",         -- Lying flat horizontally parallel to the table
    scale        = "1.0 1.0 1.0",   -- Crisp 1.0 scale
    width        = "320",           -- Resolution width
    height       = "100"            -- Resolution height
}

-- 3. NOTIFICATION PREFERENCES
ENABLE_CHAT_NOTIFICATIONS = true    -- Set to true to broadcast health changes in the global game chat


-- ============================================================================
-- =============== STATE & WORKSPACE INITIALISATION ===========================
-- ============================================================================

currentHealth = DEFAULT_HEALTH      -- Active health tracker value
isUIVisible = true                  -- Tracking current visibility state of the panel
checkTimerID = nil                  -- Internal timer ID for motion checks
isTileObject = false                -- Cached classification of this object's shape (Tile vs Standee)
isMinion = false                    -- Cached classification of this object's card class


-- =============== CORE EVENT HOOKS ===============

function onLoad()
    -- Classify object shape and card class
    classifyObject()

    -- Sync health to the appropriate default for this object
    currentHealth = resolveDefaultHealth()

    -- Dynamically generate and inject the XML UI
    setupXmlUi()
    
    -- Initialise visibility state based on current orientation
    updateUIVisibility()
    
    -- Start monitoring for any player picks/moves/flips
    startCheckingVisibility()
    
    logMessage("Floating Health Tracker loaded on " .. (self.getName() ~= "" and self.getName() or "Object") .. ".")
end

-- Triggers when a player rotates or flips this object
function onRotate(spin, flip, player_color, old_spin, old_flip)
    startCheckingVisibility()
end

-- Triggers when a player picks up and drops this object
function onDrop(player_color)
    startCheckingVisibility()
end

-- Clean up any active timers when the object is destroyed
function onDestroy()
    if checkTimerID then
        Wait.stop(checkTimerID)
    end
end


-- =============== INTERNAL FUNCTIONS & CALLBACKS ===============

-- Classifies whether this object is behaving as a Tile or Standee, and whether
-- its card class is a Minion (shape and class are independent - not all Minions
-- are flat Custom Tiles).
function classifyObject()
    if OBJECT_TYPE == "tile" then
        isTileObject = true
    elseif OBJECT_TYPE == "standee" then
        isTileObject = false
    else
        -- "auto" mode: Custom Tiles have tag == "Tile"
        isTileObject = (self.tag == "Tile")
    end

    local class = self.getDescription()
    isMinion = (class ~= nil and class:upper() == MINION_CLASS)
end

-- Resolves the starting health for this object based on card class alone
-- (independent of whether it's rendered as a Tile or a Standee).
function resolveDefaultHealth()
    if isMinion then
        return MINION_DEFAULT_HEALTH
    else
        return DEFAULT_HEALTH
    end
end

-- Builds the XML UI string dynamically based on configuration and orientation
function setupXmlUi()
    local config = isTileObject and TILE_CONFIG or STANDEE_CONFIG

    -- Pre-calculate if the UI should be active immediately on load
    -- This prevents the UI from "flickering" on for a frame before being hidden
    local initialActiveState = "true"
    local isCurrentlyFaceDown = checkIsFaceDown()
    if isTileObject and isCurrentlyFaceDown then
        initialActiveState = "false"
        isUIVisible = false
    else
        isUIVisible = true
    end

    -- Construction of a single, clean flat-lying panel
    local xml = string.format([[
<Defaults>
    <!-- Standardized styles for buttons and texts -->
    <Button class="health-btn" fontStyle="Bold" textColor="#ffffff" />
    <Text class="health-val" fontStyle="Bold" color="#ffffff" alignment="MiddleCenter" />
</Defaults>
<Panel id="healthTrackerPanel" 
       width="%s" 
       height="%s" 
       position="%s" 
       rotation="%s" 
       scale="%s"
       color="#111c24e6" 
       outline="#2c3e50" 
       outlineSize="2" 
       padding="10" 
       active="%s" 
       rectAlignment="MiddleCenter">
    <HorizontalLayout spacing="15" alignment="MiddleCenter">
        <!-- Minus Button -->
        <Button class="health-btn" onClick="decrementHealth" fontSize="36" color="#c0392b" width="60" height="60">-</Button>
        
        <!-- Numerical Display -->
        <Text id="healthText" class="health-val" fontSize="48">%d</Text>
        
        <!-- Plus Button -->
        <Button class="health-btn" onClick="incrementHealth" fontSize="36" color="#27ae60" width="60" height="60">+</Button>
    </HorizontalLayout>
</Panel>
]], 
    config.width, 
    config.height, 
    config.position, 
    config.rotation, 
    config.scale,
    initialActiveState,
    currentHealth
    )

    -- Inject XML into the object's UI component
    self.UI.setXml(xml)
end

-- Click handler to increment health
function incrementHealth(player, value, id)
    local oldHealth = currentHealth
    currentHealth = currentHealth + 1
    updateHealthText()
    notifyHealthChange(player, oldHealth, currentHealth)
end

-- Click handler to decrement health
function decrementHealth(player, value, id)
    if currentHealth > 0 then
        local oldHealth = currentHealth
        currentHealth = currentHealth - 1
        updateHealthText()
        notifyHealthChange(player, oldHealth, currentHealth)
    end
end

-- Updates the 3D text display to show the current health value
function updateHealthText()
    self.UI.setAttribute("healthText", "text", tostring(currentHealth))
end

-- Checks if the object is currently face-down (spawner-side up for Tiles)
function checkIsFaceDown()
    if self.is_face_down ~= nil then
        return self.is_face_down
    else
        -- Fallback rotation calculation (Z-axis around 180 degrees)
        local rot = self.getRotation()
        return (rot.z > 90 and rot.z < 270)
    end
end

-- Checks orientation and manages showing/hiding the XML panel
function updateUIVisibility()
    if isTileObject then
        local faceDown = checkIsFaceDown()
        local shouldShow = not faceDown

        if shouldShow ~= isUIVisible then
            isUIVisible = shouldShow
            local activeState = shouldShow and "true" or "false"
            self.UI.setAttribute("healthTrackerPanel", "active", activeState)
            
            -- Debug log output to help design/verify
            if not shouldShow then
                logMessage("Flipped to Spawner-side: Hiding Health Tracker.")
            else
                logMessage("Flipped to Character-side: Displaying Health Tracker.")
            end
        end
    else
        -- Standees remain visible at all times
        if not isUIVisible then
            isUIVisible = true
            self.UI.setAttribute("healthTrackerPanel", "active", "true")
        end
    end
end

-- Starts a dynamic, optimized check to update UI visibility once physical movement settles
function startCheckingVisibility()
    if checkTimerID then
        Wait.stop(checkTimerID)
    end

    -- Dynamically check every 0.1s up to 2.5s until the object stops moving/holding
    local elapsed = 0
    local checkFunc
    checkFunc = function()
        if not self.isSmoothMoving() or elapsed >= 2.5 then
            updateUIVisibility()
        else
            elapsed = elapsed + 0.1
            checkTimerID = Wait.time(checkFunc, 0.1)
        end
    end

    checkTimerID = Wait.time(checkFunc, 0.1)
end

-- Helper: Broadcasts health changes to the game chat
function notifyHealthChange(player, oldVal, newVal)
    if not ENABLE_CHAT_NOTIFICATIONS then return end
    
    local playerName = player.steam_name or player.color
    local playerColor = stringColorToHex(player.color)
    local objName = self.getName()
    if objName == "" then objName = "Object" end
    
    broadcastToAll(string.format("[%s]%s[-] adjusted %s health: %d -> %d", 
        playerColor, playerName, objName, oldVal, newVal), {0.9, 0.9, 0.9})
end

-- Helper: Translates standard Tabletop Simulator player colors into Hex tags for chat
function stringColorToHex(colorName)
    local colors = {
        Red    = "FF1A1A",
        Blue   = "1A75FF",
        Green  = "1AFF1A",
        Yellow = "FFFF1A",
        Orange = "FF991A",
        Purple = "991AFF",
        Pink   = "FF1A99",
        White  = "FFFFFF",
        Grey   = "808080",
        Black  = "303030",
        Brown  = "704010"
    }
    return colors[colorName] or "FFFFFF"
end

-- Helper: Standardized debug console logger
function logMessage(msg)
    print("<HealthTracker> " .. msg)
end
]===]
