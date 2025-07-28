---@diagnostic disable: param-type-mismatch
if not lib then return end
lib.locale()
Players, InProgress = {}, {}
local steamAPI = GetConvar('steam_webApiKey', '')
local week = math.ceil(tonumber(os.date("%d")) / 7)
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
local Query = {
    INSERT = 'INSERT INTO `battlepass` (owner, battlepass) VALUES (?, ?) ON DUPLICATE KEY UPDATE battlepass = VALUES(battlepass)'
}

local function AddXP(playerId, xp)
    xp = tonumber(xp)
    if Players[playerId] then
        Players[playerId].battlepass.xp += xp

        while Players[playerId].battlepass.xp >= Config.XPPerLevel do
            Players[playerId].battlepass.xp -= Config.XPPerLevel
            Players[playerId].battlepass.tier += 1
        end
        
        TriggerClientEvent('battlepass:client:UpdateProgress', playerId, xp, Players[playerId].battlepass.tier)
    end
end

local function RemoveXP(playerId, xp)
    xp = tonumber(xp)
    if Players[playerId] then
        Players[playerId].battlepass.xp -= xp

        if 0 > Players[playerId].battlepass.xp then
            Players[playerId].battlepass.xp = 0
            Players[playerId].battlepass.tier -= 1
        end
    end
end

local function FinishTask(playerId, task)
    if Players[playerId] then
        local daytask = Config.TaskList.Daily[task]

        if daytask then
            if not lib.table.contains(Players[playerId].battlepass.daily, task) then
                table.insert(Players[playerId].battlepass.daily, task)
                AddXP(playerId, daytask.xp or 0)
                TriggerClientEvent('battlepass:Notify', playerId, locale('notify_finished_task', daytask.title, daytask.xp or 0))
                return true
            end
        end

        local weektask = Config.TaskList.Weekly[task]

        if weektask then
            if not lib.table.contains(Players[playerId].battlepass.weekly, task) then
                table.insert(Players[playerId].battlepass.weekly, task)
                AddXP(playerId, weektask.xp or 0)
                TriggerClientEvent('battlepass:Notify', playerId, locale('notify_finished_task', weektask.title, weektask.xp or 0))
                return true
            end
        end
    end

    return false
end

local function HasPremium(playerId)
    if Players[playerId] then
        return Players[playerId].battlepass.premium
    end

    return false
end


local function CreatePlayer(playerId, bp)
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
end

MySQL.ready(function()
    local success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `battlepass`')

    if not success then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `battlepass` (
                `owner` varchar(72) DEFAULT NULL,
                `battlepass` longtext DEFAULT NULL,
                `lastupdated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY `owner` (`owner`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])

        print('^2Successfully added table battlepass to database^0')
    end

    success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `battlepass_codes`')

    if not success then
        MySQL.query([[
            CREATE TABLE `battlepass_codes` (
                `identifier` varchar(72) DEFAULT NULL,
                `code` varchar(100) DEFAULT NULL,
                `amount` int(11) DEFAULT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])

        print('^2Successfully added battlepass_codes table to SQL^0')
    end


    pcall(MySQL.query.await, ('DELETE FROM `battlepass` WHERE lastupdated < (NOW() - INTERVAL %s)'):format(Config.DeletePlayer))

    -- Garantir que a tabela Players esteja inicializada
    if type(Players) ~= 'table' then 
        Players = {}
    end
    
    -- Inicializar jogadores
    Wait(1000) -- Aguardar um pouco para garantir que vRP está totalmente iniciado
    
    -- Usar pcall para capturar qualquer erro
    local syncSuccess, syncCount = pcall(function()
        return SyncAllPlayers()
    end)
    
    if not syncSuccess then
        print("^1[BattlePass] Erro ao sincronizar jogadores: " .. tostring(syncCount) .. "^0")
    end
    
    -- Sincronizar periodicamente jogadores que podem não ter sido adicionados
    CreateThread(function()
        while true do
            Wait(60000) -- A cada minuto verifica jogadores não sincronizados
            pcall(SyncAllPlayers) -- Usar pcall para evitar que erros derrubem o thread
        end
    end)
end)


lib.callback.register('battlepass:server:GetScoreboardData', function(source)
    local options = {}

    for k,v in pairs(Players) do
        options[#options + 1] = {
            name = v.name,
            tier = v.battlepass.tier,
            xp = v.battlepass.xp,
            premium = v.battlepass.premium,
            taskdone = #v.battlepass.daily + #v.battlepass.weekly,
            avatar = v.avatar
        }
    end

    return options
end)

lib.callback.register('battlepass:GetCoins', function(source)
    if Players[source] then
        return Players[source].battlepass.coins, week
    end

    return 0, week
end)


lib.callback.register('battlepass:BuyItem', function(playerId, data)
    print(json.encode(data, { indent = true }))
    if data.index then
        data.index = tonumber(data.index)
        if Config.BattleShop[week][data.index] then
            local item = Config.BattleShop[week][data.index]

            if Players[playerId].battlepass.coins >= item.coins then
                if item.vehicle then
                    local identifier = GetIdentifier(playerId)
                    local cb = InsertInGarage(item.name, identifier, item.vehicle, playerId)

                    if cb then
                        Players[playerId].battlepass.coins -= item.coins

                        if 0 > Players[playerId].battlepass.coins then
                            Players[playerId].battlepass.coins = 0
                        end

                        return cb, Players[playerId].battlepass.coins, item
                    end
                else
                    AddItem(playerId, item.name, item.amount * data.quantity)
                    Players[playerId].battlepass.coins -= item.coins * data.quantity

                    if 0 > Players[playerId].battlepass.coins then
                        Players[playerId].battlepass.coins = 0
                    end

                    return true, Players[playerId].battlepass.coins, item
                end
            end

            return false
        end
    end

    return false
end)

lib.callback.register('battlepass:ReedemCode', function(source, code)
    local identifier = GetIdentifier(source)
    local cb = MySQL.single.await('SELECT `amount`, `identifier` FROM `battlepass_codes` WHERE `code` = ?', { code })

    if cb and cb.amount and cb.identifier == identifier then
        cb.amount = tonumber(cb.amount)
        Players[source].battlepass.coins += cb.amount
        MySQL.query('DELETE FROM `battlepass_codes` WHERE `code` = ?', { code })

        return cb.amount
    end

    return false
end)


lib.callback.register('battlepass:ClaimReward', function(source, data)
    if data.pass == 'free' then
        data.index = tonumber(data.index)

        if Config.Rewards.FreePass[week][data.index] then
            local item = Config.Rewards.FreePass[week][data.index]
            local currentXP = Players[source].battlepass.xp
            local currentTier = Players[source].battlepass.tier
            local requiredXP = item.requirements.xp
            local requiredTier = item.requirements.tier
            local isTierMet = currentTier >= requiredTier
            local isXPMet = currentXP >= requiredXP
            local isClaimable = isTierMet and (isXPMet or currentTier > requiredTier)

            if isClaimable and not Players[source].battlepass.freeClaims[data.index] then
                if item.vehicle then
                    local identifier = GetIdentifier(source)
                    local cb = InsertInGarage(item.name, identifier, item.vehicle, source)

                    if cb then
                        Players[source].battlepass.freeClaims[data.index] = true
                        return cb, Config.Rewards.FreePass[week][data.index]
                    end
                else
                    AddItem(source, item.name, item.amount)
                    Players[source].battlepass.freeClaims[data.index] = true

                    return true, Config.Rewards.FreePass[week][data.index]
                end
            end
        end
    elseif data.pass == 'premium' then
        data.index = tonumber(data.index)

        if Config.Rewards.PremiumPass[week][data.index] then
            local item = Config.Rewards.PremiumPass[week][data.index]
            local currentXP = Players[source].battlepass.xp
            local currentTier = Players[source].battlepass.tier
            local requiredXP = item.requirements.xp
            local requiredTier = item.requirements.tier
            local isTierMet = currentTier >= requiredTier
            local isXPMet = currentXP >= requiredXP
            local isClaimable = isTierMet and (isXPMet or currentTier > requiredTier)

            if isClaimable and not Players[source].battlepass.premiumClaims[data.index] then
                AddItem(source, item.name, item.amount)
                Players[source].battlepass.premiumClaims[data.index] = true

                return true, Config.Rewards.PremiumPass[week][data.index]
            end
        end
    end

    return false, nil
end)

lib.callback.register('battlepass:TaskList', function(source)
    if Players[source] then
        return Players[source].battlepass.daily, Players[source].battlepass.weekly
    end
end)


local function SaveDB()
    local insertTable = {}
    local size = 0

    for playerId, data in pairs(Players) do
        size += 1

        if Config.ResetPlaytime then
            data.battlepass.playtime = {}
        end

        insertTable[size] = { query = Query.INSERT, values = { data.identifier, json.encode(data.battlepass, { sort_keys = true }) } }
    end

    if size > 0 then
        local success, response = pcall(MySQL.transaction, insertTable)

        if not success then print(response) end
    end
end

RegisterCommand(Config.BuyCoinsCommand, function (source, args, raw)
    if source ~= 0 then return end

    local id = tonumber(args[1])
    local amount = args[2]
    local code = args[3]

    if not id then return end
    if not amount then return end
    if not code then return end

    local identifier = GetIdentifier(id)

    if identifier then
        MySQL.insert.await('INSERT INTO `battlepass_codes` (identifier, code, amount) VALUES (?, ?, ?)', { identifier, code, amount })
        TriggerClientEvent('battlepass:Notify', id, locale('notify_coins', amount), 'success')
    end
end)

RegisterCommand(Config.BuyPremiumPassCommand, function(source, args, raw)
    if source ~= 0 then return end

    local playerId = tonumber(args[1])
    if not playerId then return end

    if Players[playerId] then
        Players[playerId].battlepass.premium = true
        Players[playerId].battlepass.purchasedate = os.time()

        TriggerClientEvent('battlepass:Notify', playerId, locale('notify_premium_purchase', Config.PremiumDuration), 'success')
    end
end)


function SecondsToClock(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    return locale('time', days, hours, mins, secs)
end

RegisterCommand(Config.Commands.premiumDuration.name,function(source,args)
    if Players[source] then
        if Players[source].battlepass.premium == false then
            return TriggerClientEvent('battlepass:Notify', source, locale('notify_no_premium'), 'warning')
        end

        local purchaseDate = Players[source].battlepass.purchasedate
        local currentTime = os.time()

        local expirationTime = purchaseDate + DaysToSec
        local timeLeft = expirationTime - currentTime

        local time = SecondsToClock(timeLeft)
        TriggerClientEvent('battlepass:Notify', source, locale('notify_expiress', time), 'inform')
    end
end,false)

RegisterCommand(Config.Commands.givecoins.name,function(source,args)
    if not Permission(source, Config.Commands.givecoins.restricted) then return end
    
    local target = tonumber(args[1])
    local amount = tonumber(args[2]) or 10
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            -- Criar jogador com dados padrão
            CreatePlayer(target, nil)
        end
    end
    
    if Players[target] then
        Players[target].battlepass.coins = Players[target].battlepass.coins + amount
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_coins', amount), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu " .. amount .. " moedas para ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

RegisterCommand(Config.Commands.removecoins.name,function(source,args)
    if not Permission(source, Config.Commands.removecoins.restricted) then return end
    
    local target = tonumber(args[1])
    local amount = tonumber(args[2]) or 10
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        Players[target].battlepass.coins = Players[target].battlepass.coins - amount
        
        if Players[target].battlepass.coins < 0 then
            Players[target].battlepass.coins = 0
        end
        
        TriggerClientEvent('battlepass:Notify', target, locale('notify_removed_coins', amount), 'warning')
        TriggerClientEvent('battlepass:Notify', source, "Você removeu " .. amount .. " moedas do ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

RegisterCommand(Config.Commands.battlepass.name,function(source)
    -- Verificar se o jogador está na tabela
    if not Players[source] then
        print("^3[BattlePass] Jogador não encontrado na tabela, tentando recriar: " .. source .. "^0")
        local identifier = GetIdentifier(source)
        
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(source, battlepass and json.decode(battlepass))
            Wait(500) -- Pequeno delay para garantir que o jogador foi criado
        else
            print("^1[BattlePass] Não foi possível obter identificador para: " .. source .. "^0")
        end
        
        -- Se ainda não existir, criar um novo player com stats padrão
        if not Players[source] then
            print("^1[BattlePass] Criando novo jogador com valores padrão: " .. source .. "^0")
            CreatePlayer(source, nil)
        end
    end
    
    TriggerClientEvent('battlepass:client:OpenMenu', source, Players[source], week)
end,false)

RegisterCommand(Config.Commands.givepass.name, function(source, args)
    if not Permission(source, Config.Commands.givepass.restricted) then return end
    
    local target = tonumber(args[1])
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        Players[target].battlepass.premium = true
        Players[target].battlepass.purchasedate = os.time()
        
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_pass_admin', Config.PremiumDuration), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu Premium Pass para ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

RegisterCommand(Config.Commands.wipe.name, function(source, args)
    if not Permission(source, Config.Commands.wipe.restricted) then return end
    
    local target = tonumber(args[1])
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        Players[target].battlepass = lib.table.deepclone(defaultStats)
        
        TriggerClientEvent('battlepass:Notify', target, locale('notify_wiped'), 'warning')
        TriggerClientEvent('battlepass:Notify', source, "Você resetou o progresso do ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

RegisterCommand(Config.Commands.givexp.name, function(source, args)
    if not Permission(source, Config.Commands.givexp.restricted) then return end
    
    local target = tonumber(args[1])
    local amount = tonumber(args[2]) or 100
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        AddXP(target, amount)
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_xp', amount), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu " .. amount .. " XP para ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

RegisterCommand(Config.Commands.removexp.name, function(source, args)
    if not Permission(source, Config.Commands.removexp.restricted) then return end
    
    local target = tonumber(args[1])
    local amount = tonumber(args[2]) or 100
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador inválido", 'error')
        return
    end
    
    -- Converter ID vRP para source se necessário
    if target < 1000 then
        -- Provavelmente é um ID vRP, não um source
        local targetSource = GetSourceFromUserId(target)
        if targetSource then
            target = targetSource
        else
            -- Tentar obter via vRP
            for user_id, src in pairs(vRP.getUsers() or {}) do
                if tonumber(user_id) == target then
                    target = src
                    break
                end
            end
        end
    end
    
    -- Verificar se o jogador existe no sistema
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        RemoveXP(target, amount)
        TriggerClientEvent('battlepass:Notify', target, "Você perdeu " .. amount .. " XP", 'warning')
        TriggerClientEvent('battlepass:Notify', source, "Você removeu " .. amount .. " XP do ID: " .. target, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end,false)

local function WipeAll()
    local targetIds = {}

    for k, v in pairs(Players) do
        targetIds[#targetIds + 1] = v.id

        v.battlepass = lib.table.deepclone(defaultStats)
    end

    if #targetIds > 0 then
        lib.triggerClientEvent('battlepass:Notify', targetIds, locale('notify_wiped'), 'inform')
    end

    MySQL.query('DELETE FROM `battlepass`')
end

RegisterCommand(Config.Commands.wipeall.name, function(source)
    if source == 0 then
        WipeAll()
    end
end,false)

RegisterCommand("code", function(source,args)
    local targetID = vRP.source(tonumber(args[1]))
    local identifier = GetIdentifier(targetID)
    local code = GenerateCode()
    local amount = tonumber(args[2]) or 1
    MySQL.insert('INSERT INTO `battlepass_codes` (`identifier`, `code`, `amount`) VALUES (?, ?, ?)', { identifier, code, amount })
    TriggerClientEvent('battlepass:Notify', source, "Você gerou o codigo " .. code .. " para o ID: " .. targetID, 'success')
end,false)

RegisterCommand("getmycodes", function(source,args)
    local identifier = GetIdentifier(source)
    local codes = MySQL.query.await('SELECT * FROM `battlepass_codes` WHERE `identifier` = ?', { identifier })
    TriggerClientEvent('battlepass:Notify', source, "Você tem " .. #codes .. " códigos", 'success')
    for k, v in pairs(codes) do
        TriggerClientEvent('battlepass:Notify', source, "Código: " .. v.code .. " - Quantidade: " .. v.amount, 'success')
    end
end,false)

if Config.PlayTimeReward.enable then
    CreateThread(function()
        while true do
            local targetIds = {}

            for k, v in pairs(Players) do
                if Config.PlayTimeReward.xp > 0 then AddXP(v.id, Config.PlayTimeReward.xp) end

                if Config.PlayTimeReward.notify then
                    targetIds[#targetIds + 1] = v.id
                end

                for taskName, data in pairs(Config.TaskList.Daily) do
                    if data.repeatTillFinish and not lib.table.contains(v.battlepass.daily, taskName) then
                        if not v.battlepass.playtime[taskName] then
                            v.battlepass.playtime[taskName] = 0
                        end

                        v.battlepass.playtime[taskName] += 1

                        if v.battlepass.playtime[taskName] == data.repeatTillFinish then
                            FinishTask(v.id, taskName)
                        end
                    end
                end

                for taskName, data in pairs(Config.TaskList.Weekly) do
                    if data.repeatTillFinish and not lib.table.contains(v.battlepass.weekly, taskName) then
                        if not v.battlepass.playtime[taskName] then
                            v.battlepass.playtime[taskName] = 0
                        end

                        v.battlepass.playtime[taskName] += 1

                        if v.battlepass.playtime[taskName] == data.repeatTillFinish then
                            FinishTask(v.id, taskName)
                        end
                    end
                end
            end

            if #targetIds > 0 and Config.PlayTimeReward.xp > 0 then
                lib.triggerClientEvent('battlepass:Notify', targetIds, locale('notify_got_xp_playing', Config.PlayTimeReward.xp), 'inform')
            end

            Wait(60000 * Config.PlayTimeReward.interval)
        end
    end)
end

AddEventHandler('onResourceStop', function(name)
    if cache.resource == name then SaveDB() end
end)


AddEventHandler('txAdmin:events:serverShuttingDown', function()
	SaveDB()
end)


AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end

	SaveDB()
end)


lib.cron.new('*/5 * * * *', function()
    SaveDB()
end)

if Config.MonthlyRestart.enabled then
    lib.cron.new(Config.MonthlyRestart.cron, function ()
        WipeAll()
    end)
end

lib.cron.new(Config.DailyReset, function()
    for k,v in pairs(Players) do
        v.battlepass.daily = {}
    end

    local query = MySQL.query.await('SELECT * FROM `battlepass`')

    if query[1] then
        local insertTable = {}

        for k, v in pairs(query) do
            v.battlepass = json.decode(v.battlepass)
            v.battlepass.daily = {}

            insertTable[#insertTable + 1] = { query = Query.INSERT, values = { v.owner, json.encode(v.battlepass, { sort_keys = true }) } }
        end

        local success, response = pcall(MySQL.transaction, insertTable)

        if not success then print(response) end
    end
end)

lib.cron.new(Config.WeeklyRestart, function()
    for k,v in pairs(Players) do
        v.battlepass.weekly = {}
    end

    local query = MySQL.query.await('SELECT * FROM `battlepass`')

    if query[1] then
        local insertTable = {}

        for k, v in pairs(query) do
            v.battlepass = json.decode(v.battlepass)
            v.battlepass.weekly = {}

            insertTable[#insertTable + 1] = { query = Query.INSERT, values = { v.owner, json.encode(v.battlepass, { sort_keys = true }) } }
        end

        local success, response = pcall(MySQL.transaction, insertTable)

        if not success then print(response) end
    end
end)

exports('AddXP', AddXP)
exports('RemoveXP', RemoveXP)
exports('FinishTask', FinishTask)
exports('HasPremium', HasPremium)
exports('GetPlayers', function() return Players end)
exports('CreatePlayer', CreatePlayer)

RegisterNetEvent('battlepass:server:OpenMenu', function()
    local source = source
    if not Players[source] then 
        local identifier = GetIdentifier(source)
        
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(source, battlepass and json.decode(battlepass))
            Wait(500)
        end
        
        if not Players[source] then
            TriggerClientEvent('battlepass:Notify', source, locale('notify_error'), 'error')
            return
        end
    end
    
    TriggerClientEvent('battlepass:client:OpenMenu', source, Players[source], week)
end)

RegisterNetEvent('battlepass:server:UpdatePlaytime', function()
    local source = source
    if not Players[source] then return end
    
    if not Players[source].battlepass.playtime then
        Players[source].battlepass.playtime = {}
    end
    
    -- Incrementa tempo de jogo
    Players[source].battlepass.playtime['count'] = (Players[source].battlepass.playtime['count'] or 0) + 1
    
    if Config.PlayTimeReward.enable then
        if (Players[source].battlepass.playtime['count'] % Config.PlayTimeReward.interval) == 0 then
            AddXP(source, Config.PlayTimeReward.xp)
            
            if Config.PlayTimeReward.notify then
                TriggerClientEvent('battlepass:Notify', source, locale('notify_playtime_reward', Config.PlayTimeReward.xp), 'success')
            end
            
            -- Verifica tarefas de tempo de jogo
            for task, taskData in pairs(Config.TaskList.Daily) do
                if taskData.repeatTillFinish then
                    if Players[source].battlepass.playtime['count'] >= taskData.repeatTillFinish then
                        FinishTask(source, task)
                    end
                end
            end
            
            for task, taskData in pairs(Config.TaskList.Weekly) do
                if taskData.repeatTillFinish then
                    if Players[source].battlepass.playtime['count'] >= taskData.repeatTillFinish then
                        FinishTask(source, task)
                    end
                end
            end
        end
    end
end)

-- Comando para verificar o status do passe de batalha
RegisterCommand('battlepassinfo', function(source)
    if Players[source] then
        local player = Players[source]
        local premium = player.battlepass.premium
        local tier = player.battlepass.tier
        local xp = player.battlepass.xp
        local coins = player.battlepass.coins
        
        local msg = locale('info_battlepass', tier, xp, Config.XPPerLevel, coins)
        
        if premium then
            local purchaseDate = player.battlepass.purchasedate
            local currentTime = os.time()
            local expirationTime = purchaseDate + DaysToSec
            local timeLeft = expirationTime - currentTime
            local time = SecondsToClock(timeLeft)
            
            msg = msg .. '\n' .. locale('info_premium', time)
        else
            msg = msg .. '\n' .. locale('info_no_premium')
        end
        
        TriggerClientEvent('battlepass:Notify', source, msg, 'inform')
    end
end, false)

-- Código que executa quando o jogador entra pela primeira vez no dia
AddEventHandler('playerJoined', function()
    local source = source
    Wait(5000) -- Aguarda um pouco para garantir que outras coisas carreguem
    
    if Players[source] then
        -- Verifica se já completou a tarefa diária de login
        if not lib.table.contains(Players[source].battlepass.daily, 'SignIn') then
            FinishTask(source, 'SignIn')
        end
    end
end)

-- Evento para recompensar jogadores com XP customizado
RegisterNetEvent('battlepass:server:RewardPlayer', function(playerId, xp, reason)
    local source = source
    
    if Permission(source, 'admin') then
        if Players[playerId] then
            AddXP(playerId, xp)
            TriggerClientEvent('battlepass:Notify', playerId, locale('notify_custom_reward', xp, reason), 'success')
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
        end
    end
end)

-- Salvar dados periodicamente
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- A cada 5 minutos
        SaveDB()
    end
end)

-- Agendar reset diário e semanal usando cron do CRON
lib.cron.new(Config.DailyReset, function()
    for k, v in pairs(Players) do
        v.battlepass.daily = {}
    end
end)

lib.cron.new(Config.WeeklyRestart, function()
    for k, v in pairs(Players) do
        v.battlepass.weekly = {}
    end
end)

-- Reset mensal completo
if Config.MonthlyRestart.enabled then
    lib.cron.new(Config.MonthlyRestart.cron, function()
        for k, v in pairs(Players) do
            -- Mantém apenas o status premium e a data de compra
            local premium = v.battlepass.premium
            local purchasedate = v.battlepass.purchasedate
            
            v.battlepass = lib.table.deepclone(defaultStats)
            v.battlepass.premium = premium
            v.battlepass.purchasedate = purchasedate
        end
    end)
end

-- Handler de evento para vRPex
AddEventHandler("vRP:playerSpawn", function(user_id, source, first_spawn)
    if first_spawn then
        Wait(2000) -- Dar tempo para que o vRP carregue completamente
        local identifier = GetIdentifier(source)
        
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(source, battlepass and json.decode(battlepass))
            
            Wait(750)
            
            if Config.TaskList.Daily['SignIn'] then
                if not Players[source] then
                    print("^1[BattlePass] Erro: Players[source] ainda é nil após CreatePlayer em vRP:playerSpawn^0")
                elseif not lib.table.contains(Players[source].battlepass.daily, 'SignIn') then
                    FinishTask(source, 'SignIn')
                end
            end
        else
            print("^1[BattlePass] Não foi possível obter identificador para source: " .. tostring(source) .. "^0")
        end
    end
end)

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local source = source
end)

AddEventHandler("playerJoining", function(source, oldID)
    Wait(5000)
    SyncAllPlayers()
end)

AddEventHandler("baseevents:onPlayerJoined", function()
    local source = source
    Wait(5000)
    SyncAllPlayers()
end)


RegisterCommand("debugbattlepass", function(source, args)
    if source == 0 or Permission(source, "admin") then
        local action = args[1] or "info"
        
        if action == "info" then
            print("Players carregados: " .. table.count(Players))
            print("Semana atual: " .. week)
            
            local onlinePlayers = GetPlayers()
            for i, src in ipairs(onlinePlayers) do
                src = tonumber(src)
                local id = vRP.getUserId(src) or "N/A"
                local name = GetPlayerName(src) or "Desconhecido"
                local loaded = Players[src] and "Sim" or "Não"
            end
            
            local vrpUsers = vRP.getUsers() or {}
            for id, src in pairs(vrpUsers) do
                local name = GetPlayerName(src) or "Desconhecido"
                local loaded = Players[src] and "Sim" or "Não"
            end
        elseif action == "force" then
            local target = tonumber(args[2])
            
            if target then
                local identifier = GetIdentifier(target)
                if identifier then
                    local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
                    CreatePlayer(target, battlepass and json.decode(battlepass))
                end
            end
        elseif action == "sync" then
            SyncAllPlayers()
        end
    end
end, false)


RegisterCommand('pass_givexp', function(source, args)
    if not Permission(source, Config.Commands.givexp.restricted) then return end
    
    local user_id = tonumber(args[1])
    local amount = tonumber(args[2]) or 100
    
    if not user_id then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador vRP inválido", 'error')
        return
    end
    
    local target = GetSourceFromUserId(user_id)
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "Jogador não está online", 'error')
        return
    end
    
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        AddXP(target, amount)
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_xp', amount), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu " .. amount .. " XP para o passaporte #" .. user_id, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end, false)

RegisterCommand('pass_givecoins', function(source, args)
    if not Permission(source, Config.Commands.givecoins.restricted) then return end
    
    local user_id = tonumber(args[1])
    local amount = tonumber(args[2]) or 10
    
    if not user_id then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador vRP inválido", 'error')
        return
    end
    
    local target = GetSourceFromUserId(user_id)
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "Jogador não está online", 'error')
        return
    end
    
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        Players[target].battlepass.coins = Players[target].battlepass.coins + amount
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_coins', amount), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu " .. amount .. " moedas para o passaporte #" .. user_id, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end, false)

RegisterCommand('pass_givepremium', function(source, args)
    if not Permission(source, Config.Commands.givepass.restricted) then return end
    
    local user_id = tonumber(args[1])
    
    if not user_id then
        TriggerClientEvent('battlepass:Notify', source, "ID de jogador vRP inválido", 'error')
        return
    end
    
    local target = GetSourceFromUserId(user_id)
    
    if not target then
        TriggerClientEvent('battlepass:Notify', source, "Jogador não está online", 'error')
        return
    end
    
    if not Players[target] then
        local identifier = GetIdentifier(target)
        if identifier then
            local battlepass = MySQL.prepare.await('SELECT `battlepass` FROM `battlepass` WHERE `owner` = ?', { identifier })
            CreatePlayer(target, battlepass and json.decode(battlepass))
        else
            TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
            return
        end
    end
    
    if Players[target] then
        Players[target].battlepass.premium = true
        Players[target].battlepass.purchasedate = os.time()
        
        TriggerClientEvent('battlepass:Notify', target, locale('notify_got_pass_admin', Config.PremiumDuration), 'success')
        TriggerClientEvent('battlepass:Notify', source, "Você deu Premium Pass para o passaporte #" .. user_id, 'success')
    else
        TriggerClientEvent('battlepass:Notify', source, locale('notify_no_player'), 'error')
    end
end, false)

AddEventHandler('onServerResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    print("/pass_givexp [passaporte] [quantidade] - Dá XP usando ID")
    print("/pass_givecoins [passaporte] [quantidade] - Dá moedas usando ID")
    print("/pass_givepremium [passaporte] - Dá Premium Pass usando ID")
end)