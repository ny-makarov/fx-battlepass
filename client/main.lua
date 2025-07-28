if not lib then return end
local FreeItems = lib.load('config.config').Rewards.FreePass
local PaidItems = lib.load('config.config').Rewards.PremiumPass
local BattleShop = lib.load('config.config').BattleShop
local XPPerLevel = lib.load('config.config').XPPerLevel
local TaskList = lib.load('config.config').TaskList
local UI = false

-- Função para processar imagens dos itens
local function ProcessItems(items)
    if not items then return items end
    
    local processedItems = {}
    for i, item in ipairs(items) do
        local newItem = table.clone(item)
        
        -- Se for um veículo e não tiver imagem específica, usar o path do config.js
        if item.vehicle and not item.img then
            -- Envia apenas o nome do veículo para a NUI, que usará vehiclesPath do config.js
            newItem.vehicle_name = item.name
            -- Remover qualquer imagem existente para garantir que o frontend use o vehiclesPath
            newItem.img = nil
        end
        
        table.insert(processedItems, newItem)
    end
    
    return processedItems
end

-- Função para clonar tabelas
function table.clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

RegisterNetEvent('battlepass:Notify', function(description, type)
    lib.notify({
        title = 'Passe de Batalha',
        description = description,
        type = type,
        duration = 3500,
        position = 'bottom'
    })
end)

RegisterNetEvent('battlepass:client:OpenMenu', function(data, week)
    if source == '' then return end

    if not UI then
        UI = true
        SetNuiFocus(true, true)
        
        -- Processar imagens antes de enviar para a interface
        local freeItems = ProcessItems(FreeItems[week])
        local paidItems = ProcessItems(PaidItems[week])
        
        SendNUIMessage({
            enable = true, 
            PlayerData = data, 
            FreeItems = freeItems, 
            PaidItems = paidItems, 
            XPPerLevel = XPPerLevel
        })
    end
end)

RegisterNUICallback('quit', function(data, cb)
	SetNuiFocus(false, false)
    UI = false
    cb(1)
end)

RegisterNUICallback('OpenScoreboard', function(data, cb)
    local players = lib.callback.await('battlepass:server:GetScoreboardData', 100)
    cb(players)
end)

RegisterNUICallback('claimReward', function(data, cb)
    local resp, item = lib.callback.await('battlepass:ClaimReward', 100, data)
    cb({ resp = resp, item = item })
end)

RegisterNUICallback('OpenBattleShop', function(data, cb)
    local coins, week = lib.callback.await('battlepass:GetCoins', 100)
    
    -- Processar imagens dos itens da loja
    local processedShopItems = ProcessItems(BattleShop[week])
    
    cb({ BattleShop = processedShopItems, coins = coins })
end)

RegisterNUICallback('BattleShopPurchase', function (data, cb)
    local resp, coins, item = lib.callback.await('battlepass:BuyItem', 100, data)
    cb({ resp = resp, coins = coins and coins or nil, item = item and item or nil })
end)

RegisterNUICallback('ReedemCode', function(data, cb)
    local resp = lib.callback.await('battlepass:ReedemCode', 100, data.code)
    cb(resp)
end)

RegisterNUICallback('GetTasks', function (data, cb)
    local daily, weekly = lib.callback.await('battlepass:TaskList', 100)
    local day, week = {}, {}

    for taskName, v in pairs(TaskList.Daily) do
        day[#day + 1] = { title = v.title, xp = v.xp, desc = v.description, done = lib.table.contains(daily, taskName) and true or false }
    end

    for taskName, v in pairs(TaskList.Weekly) do
        week[#week + 1] = { title = v.title, xp = v.xp, desc = v.description, done = lib.table.contains(weekly, taskName) and true or false }
    end

    cb({ day = day, week = week })
end)

-- Sistema de comandos no lado do cliente
RegisterCommand(lib.load('config.config').Commands.battlepass.name, function()
    TriggerServerEvent('battlepass:server:OpenMenu')
end)

-- Sistemas de notificações de progressão
RegisterNetEvent('battlepass:client:UpdateProgress', function(xp, level)
    lib.notify({
        title = 'Progressão',
        description = 'Você ganhou ' .. xp .. ' XP e está no nível ' .. level,
        type = 'success',
        duration = 3500,
        position = 'bottom'
    })
end)

-- Sistema que detecta tempo online do jogador
CreateThread(function()
    while true do
        Wait(60000) -- Verifica a cada minuto
        TriggerServerEvent('battlepass:server:UpdatePlaytime')
    end
end)