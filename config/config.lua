return {
    DefaultImage = 'https://avatars.steamstatic.com/b5bd56c1aa4644a474a2e4972be27ef9e82e517e_full.jpg',
    DeletePlayer = '2 MONTH',

    PlateFormat = '........',
    CodeFormat = '........',
    Commands = {
        battlepass = {
            name = 'battlepass',
            help = 'Open Battlepass Menu',
        },
        givecoins = {
            name = 'givecoins',
            help = 'Gives coins to a player',
            restricted = 'admin'
        },
        removecoins = {
            name = 'removecoins',
            help = 'Removes coins from a player',
            restricted = 'admin'
        },
        givepass = {
            name = 'givepremium',
            help = 'Gives premium pass to a player',
            restricted = 'admin'
        },
        wipe = {
            name = 'wipeplayer',
            help = 'Wipes a player\'s Battle Pass progress (including premium pass status)',
            restricted = 'admin'
        },
        givexp = {
            name = 'givexp',
            help = 'Gives XP to a player',
            restricted = 'admin'
        },
        removexp = {
            name = 'removexp',
            help = 'Remove XP from player',
            restricted = 'admin'
        },
        wipeall = {
            name = 'wipeall',
            help = 'Wipes Battle Pass progress of all players (online & offline)',
            restricted = 'admin'
        },
        premiumDuration = {
            name = 'checkpremium',
            help = 'Shows you how long your battlepass will last'
        }
    },

    XPPerLevel = 1000,
    PlayTimeReward = {
        enable = true,
        interval = 5,
        xp = 250,
        notify = true
    },

    Rewards = {
        FreePass = {
            [1] = { --primeiro semana do mês
                { name = 'water', label = 'Agua', requirements = { tier = 0, xp = 150 }, amount = 10, metadata = { description = 'This is metadata' } },
                { name = 'money', label = 'Dinheiro', requirements = { tier = 1, xp = 150 }, amount = 150 },
                { name = 'kitfac', label = 'Kit Fac', requirements = { tier = 2, xp = 150 }, amount = 1 },
                {
                    name = 't20',
                    label = 'T20',
                    requirements = { tier = 3, xp = 150 },
                    vehicle = { type = 'car', stored = 1, garage = 'SanAndreasAvenue', properties = { color1 = 0, color2 = 27, neonEnabled = { 1, 2, 3, 4 } } }
                },
                {
                    name = 'xlr35sakura',
                    label = 'XLR35 Sakura',
                    requirements = { tier = 3, xp = 150 },
                    vehicle = { type = 'car', stored = 1, garage = 'SanAndreasAvenue', properties = { color1 = 0, color2 = 27, neonEnabled = { 1, 2, 3, 4 } } }
                },
            },
            [2] = { --segunda semana do mês
                { name = 'money', label = 'Dinheiro', requirements = { tier = 1, xp = 150 }, amount = 150 },
            },
            [3] = { --terceira semana do mês
                {
                    name = 't20',
                    label = 'T20',
                    requirements = { tier = 5, xp = 150 },
                    vehicle = { type = 'car', stored = 1, garage = 'SanAndreasAvenue', properties = { color1 = 0, color2 = 27, neonEnabled = { 1, 2, 3, 4 } } }
                },
            },
            [4] = { --quarta semana do mês
                { name = 'money', label = 'Dinheiro', requirements = { tier = 1, xp = 150 }, amount = 150 },
            },
        },

        PremiumPass = {
            [1] = { --primeiro semana do mês
                { name = 'WEAPON_PISTOL_MK2', label = 'FiveSeven', requirements = { tier = 0, xp = 150 }, amount = 1 },
            },
            [2] = { --segunda semana do mês
                { name = 'WEAPON_ASSAULTRIFLE_MK2', label = 'AK47', requirements = { tier = 0, xp = 150 }, amount = 1 },
            },
            [3] = { --terceira semana do mês
                {
                    name = 't20',
                    label = 'T20',
                    requirements = { tier = 5, xp = 150 },
                    vehicle = { type = 'car', stored = 1, garage = 'SanAndreasAvenue', properties = { color1 = 0, color2 = 27, neonEnabled = { 1, 2, 3, 4 } }}
                },
            },
            [4] = { --quarta semana do mês
                { name = 'WEAPON_PISTOL', label = 'Pistol', requirements = { tier = 0, xp = 150 }, amount = 1 },
            },
        }
    },

    BattleShop = {
        [1] = { --primeiro semana do mês
            { name = 'WEAPON_PISTOL_MK2', label = 'FiveSeven', coins = 50, amount = 10, metadata = { description = 'This is metadata' } },
            { name = 'WEAPON_ASSAULTRIFLE_MK2', label = 'AK47', coins = 50, amount = 10, metadata = { description = 'This is metadata' } },
        },
        [2] = { --segunda semana do mês
            { name = 'WEAPON_SLEDGEHAMMER', label = 'Sledgehammer', coins = 50, amount = 10, metadata = { description = 'This is metadata' } },
        },
        [3] = { --terceira semana do mês
            { name = 'WEAPON_PISTOL_MK2', label = 'FiveSeven', coins = 50, amount = 10, metadata = { description = 'This is metadata' } },
            {
                name = 'xlr35sakura',
                label = 'XLR35 Sakura',
                coins = 50,
            },

        },
        [4] = { --quarta semana do mês
            { name = 'WEAPON_PISTOL', label = 'Pistol', coins = 50, amount = 10, metadata = { description = 'This is metadata' } },
        },
    },

    BuyCoinsCommand = 'purchase_coins_for_battlepass',

    BuyPremiumPassCommand = 'buy_premium_pass',
    
    PremiumDuration = 30,

    -- quando reiniciar as tarefas diárias, atualmente todo dia às 00, https://crontab.guru/
    DailyReset = '0 0 * * *',

    -- quando reiniciar as tarefas semanais, atualmente todo domingo às 00
    WeeklyRestart = '0 0 * * 1',


    -- O agendamento para reiniciar todas as estatísticas do Battle Pass. 
    -- Atualmente configurado para reiniciar às 00:00 no 1º dia de cada mês.
    -- Se o servidor estiver offline nesse horário, você pode reiniciar manualmente usando o comando /wipeall.
    MonthlyRestart = {
        enabled = true,
        cron = '0 0 1 * *' -- every 1st day of month at 00:00
    },

    ResetPlaytime = true,

    TaskList = {
        Daily = {
            ['SignIn'] = { -- se quiser manter este, nao renomeie a chave
                title = 'Boas vindas',
                description = 'Entre na cidade: <br> recompensa: 300xp',
                xp = 300,
            },

            ['Play60'] = { -- nao renomeie daily e weekly tarefas com a mesma chave
                title = 'Seu tempo online',
                description = 'Jogue por 60 min no servidor <br> recompensa: 600XP', -- supports HTML elements
                xp = 600,
                repeatTillFinish = 12 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            },

            ['Play120'] = {
                title = 'Jogue por 120 min',
                description = 'Jogue por 120 min no servidor <br> recompensa: 1200XP', -- supports HTML elements
                xp = 1200,
                repeatTillFinish = 24 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            },

            ['Play180'] = {
                title = 'Jogue por 180 min',
                description = 'Jogue por 180 min no servidor <br> recompensa: 1800XP', -- supports HTML elements
                xp = 1800,
                repeatTillFinish = 36 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            },

            ['Play240'] = {
                title = 'Jogue por 240 min',
                description = 'Jogue por 240 min no servidor <br> recompensa: 2400XP', -- supports HTML elements
                xp = 2400,
                repeatTillFinish = 48 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            },
            ['Play300'] = {
                title = 'Jogue por 300 min',
                description = 'Jogue por 300 min no servidor <br> recompensa: 3000XP', -- supports HTML elements
                xp = 3000,
                repeatTillFinish = 60 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            }
        },
        Weekly = {
            ['Play120'] = {
                title = 'Jogue por 120 min',
                description = 'Jogue por 120 min no servidor <br> recompensa: 1200XP', -- supports HTML elements
                xp = 1200,
                repeatTillFinish = 24 -- quantas vezes o intervalo precisa repetir para finalizar esta (seu tempo desejado / PlayTimeReward.interval | 60 / 5 = 12)
            }
        }
    }
}