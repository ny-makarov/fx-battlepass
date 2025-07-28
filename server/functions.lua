vRP.prepare("llimao/getallvehiclesbyuser","SELECT * FROM vrp_user_veiculos WHERE user_id = @user_id")


if not table.count then
    function table.count(tbl)
        local count = 0
        for _ in pairs(tbl) do
            count = count + 1
        end
        return count
    end
end

function AddItem(playerId, item, amount)
    local Passport = vRP.getUserId(playerId)
    if Passport then
        return vRP.giveInventoryItem(Passport, item, amount, true)
    end
    return false
end

local PlateFormat = lib.load('config.config').PlateFormat
local steamAPI = GetConvar('steam_webApiKey', '')

function GetIdentifier(playerId)
    if not playerId or playerId <= 0 then
        return nil
    end
    
    local id = vRP.getUserId(playerId)
    if id then
        local identity = vRP.getUserIdentity(id)
        if identity and identity.registration then
            return identity.registration
        end
    end
    
    if vRP.getUserId then
        local passport = vRP.getUserId(playerId)
        if passport then
            local identity = vRP.getIdentity(passport)
            if identity and identity.registration then
                return identity.registration
            end
        end
    end
    
    local steamID = GetPlayerIdentifierByType(playerId, 'steam')
    if steamID then
        return steamID
    end
    
    local license = GetPlayerIdentifierByType(playerId, 'license')
    if license then
        return license
    end
    return nil
end

function GetAllPlayers()
    return vRP.getUsers()
end

function GetName(playerId)
    local id = vRP.getUserId(playerId)
    if id then
        local identity = vRP.getUserIdentity(id)
        if identity then
            return identity.nome.." "..identity.sobrenome
        end
    end
    return "Desconhecido"
end

function GetAvatar(playerId)
    local user_id = vRP.getUserId(playerId)
    local var = MySQL.query.await('SELECT `avatarURL` FROM `smartphone_instagram` WHERE `user_id` = ?', { user_id })
    if var[1] then
        return var[1].avatarURL or ""
    end
    return ""
end

function Permission(source, perm)
    -- local id = vRP.getUserId(source)
    -- if id == nil then return false end
    return true
end

local function IsPlateAvailable(plate)
	return not MySQL.scalar.await('SELECT 1 FROM `vrp_user_veiculos` WHERE `placa` = ?', { plate })
end

local function IsCodeAvailable(code)
	return not MySQL.scalar.await('SELECT 1 FROM `battlepass_codes` WHERE `code` = ?', { code })
end

function GeneratePlate()
    local plate
    while true do
        plate = lib.string.random(PlateFormat)
        if IsPlateAvailable(plate) then return plate end
        Wait(0)
    end
end

function GenerateCode()
    local code
    while true do
        code = lib.string.random("........")
        if IsCodeAvailable(code) then return code end
        Wait(0)
    end
end

function InsertInGarage(model, identifier, vehicle, playerId)
    local plate = GeneratePlate()
    local Player = vRP.getUserId(playerId)
    
    if not Player then
        return false
    end

    local success = vRP.execute("vRP/inserir_veh", { veiculo = model, user_id = tonumber(Player), placa = plate, ipva = os.time(), expired = "{}" })

    if not success then
        return false
    end

    return success
end

function IsPlayerConnected(playerId)
    return GetPlayerPing(playerId) > 0
end

function CheckPremiumStatus(playerId)
    if not Players[playerId] then return false end
    
    if Players[playerId].battlepass.premium then
        local purchaseDate = Players[playerId].battlepass.purchasedate
        local currentTime = os.time()
        local DaysToSec = lib.load('config.config').PremiumDuration * 86400
        
        if purchaseDate < (currentTime - DaysToSec) then
            Players[playerId].battlepass.premium = false
            TriggerClientEvent('battlepass:Notify', playerId, locale('notify_premium_expired'), 'error')
            return false
        end
        return true
    end
    return false
end

function ExtendPremium(playerId, days)
    if not Players[playerId] then return false end
    
    local DaysToSec = days * 86400
    
    if Players[playerId].battlepass.premium then
        Players[playerId].battlepass.purchasedate = Players[playerId].battlepass.purchasedate + DaysToSec
    else
        Players[playerId].battlepass.premium = true
        Players[playerId].battlepass.purchasedate = os.time()
    end
    
    TriggerClientEvent('battlepass:Notify', playerId, locale('notify_premium_extended', days), 'success')
    return true
end

function GetSourceFromUserId(user_id)
    user_id = tonumber(user_id)
    if not user_id then return nil end
    
    if vRP.getUserSource then
        local source = vRP.getUserSource(user_id)
        if source and tonumber(source) > 0 then return tonumber(source) end
    end
    
    if vRP.Source then
        local source = vRP.Source(user_id)
        if source and tonumber(source) > 0 then return tonumber(source) end
    end
    
    if vRP.getSourceById then
        local source = vRP.getSourceById(user_id)
        if source and tonumber(source) > 0 then return tonumber(source) end
    end
    
    local users = vRP.getUsers() or {}
    local source = users[user_id]
    if source and tonumber(source) > 0 then return tonumber(source) end
    
    for id, src in pairs(users) do
        if tonumber(id) == user_id then
            return tonumber(src)
        end
    end
    return nil
end

function GetUserIdBySource(source)
    if not source or source <= 0 then return nil end
    
    if vRP.getUserId then
        local id = vRP.getUserId(source)
        if id then return id end
    end
    
    if vRP.getUserId then
        local passport = vRP.getUserId(source)
        if passport then return passport end
    end
    
    if vRP.Source then
        for i = 1, 1000 do
            if vRP.Source(i) == source then
                return i
            end
        end
    end
    
    local users = vRP.getUsers() or {}
    for id, src in pairs(users) do
        if tonumber(src) == tonumber(source) then
            return id
        end
    end
    
    return nil
end

function GetAllOnlinePlayers()
    local players = {}
    
    local users = vRP.getUsers() or {}
    for id, source in pairs(users) do
        if source and tonumber(source) > 0 then
            local name = GetPlayerName(source) or "Desconhecido"
            players[#players + 1] = {
                source = source,
                user_id = id,
                name = name,
                method = "vRP.getUsers"
            }
        end
    end
    
    local onlinePlayers = GetPlayers()
    for i, source in ipairs(onlinePlayers) do
        source = tonumber(source)
        local id = GetUserIdBySource(source)
        local alreadyAdded = false
        
        for _, player in ipairs(players) do
            if player.source == source then
                alreadyAdded = true
                break
            end
        end
        
        if not alreadyAdded and id then
            local name = GetPlayerName(source) or "Desconhecido"
            players[#players + 1] = {
                source = source,
                user_id = id,
                name = name,
                method = "GetPlayers"
            }
        end
    end
    
    return players
end

-- Atualizar a função SyncAllPlayers para usar GetAllOnlinePlayers
function SyncAllPlayers()
    local count = 0
    local syncedPlayers = {}
    
    -- Verificar se a tabela Players está definida
    if not Players then
        Players = {} -- Criar a tabela se não existir
    end
    
    -- Obter todos os jogadores online
    local onlinePlayers = GetAllOnlinePlayers()
    
    for _, player in ipairs(onlinePlayers) do
        local source = player.source
        
        if source and not Players[source] then
            local identifier = GetIdentifier(source)
            
            if identifier then
                local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
                CreatePlayer(source, battlepass and json.decode(battlepass))
                count = count + 1
                
                TriggerClientEvent('battlepass:Notify', source, locale('notify_player_synced'), 'success')
                table.insert(syncedPlayers, source)
            end
        end
    end
    return count, syncedPlayers
end

RegisterCommand("syncbattlepass", function(source)
    if source == 0 or Permission(source, "admin") then
        local count, syncedPlayers = SyncAllPlayers()
        
        if source > 0 then
            TriggerClientEvent('battlepass:Notify', source, locale('notify_synced_players', count), 'success')
        end
    end
end, false)

if not CreatePlayer then
    function CreatePlayer(playerId, bp)
        local Config = lib.load('config.config')
        local DaysToSec = Config.PremiumDuration * 86400
        local defaultStats = {
            coins = 0,
            xp = 0,
            tier = 0,
            premium = false,
            freeClaims = {},
            premiumClaims = {},
            purchasedate = 0,
            daily = {},
            weekly = {},
            playtime = {}
        }
        
        if bp and table.type(bp) ~= 'empty' then
            if tonumber(bp.purchasedate) < (os.time() - DaysToSec) then
                bp.premium = false
            end
        end

        local self = {
            id = playerId,
            name = GetName(playerId),
            identifier = GetIdentifier(playerId),
            avatar = GetAvatar(playerId),
            battlepass = (bp == nil or type(bp) == 'empty') and lib.table.deepclone(defaultStats) or bp
        }

        Players[playerId] = self
        return self
    end
end