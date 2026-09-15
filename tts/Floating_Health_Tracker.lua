--[[ Tabletop Simulator Floating Health Tracker Script
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

-- 1. CONFIGURATION FOR CUSTOM TILES (Lying flat on the table)
TILE_CONFIG = {
    position     = "0 0 -175",       -- XML coordinates: Negative Z moves the UI "up" above the tile's face. -125 corresponds to 1.25 world units.
    rotation     = "0 0 180",         -- Lying flat parallel to the tile's face
    scale        = "1.0 1.0 1.0",   -- Crisp 1.0 scale as preferred by the user
    width        = "320",           -- Resolution width (pixel space)
    height       = "100"            -- Resolution height (pixel space)
}

-- 2. CONFIGURATION FOR CUSTOM STANDEES (Upright 3D models/figures)
-- Lays flat horizontally above the head, making it fully readable to players sitting at any angle around the table.
STANDEE_CONFIG = {
    position     = "0 0 -300",      -- XML coordinates: Negative Z moves the UI "up" above the head. -300 corresponds to 3.0 world units.
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
