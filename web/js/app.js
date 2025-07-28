const resource = GetParentResourceName();
let PlayerData = {};
let XPPerLevel = 0;
let dict = {};

(async function loadLocale() {
    try {
        const response = await fetch(`../locales/${Config.Locales}.json`);
        
        if (!response.ok) {
            throw new Error(`Could not fetch locale: en.json`);
        }
        
        dict = await response.json();
    } catch (error) {
        console.error('Error loading locale:', error);
        dict = {};
    }
})();

const locale = (str, ...args) => {
    let lstr = dict[str];
    
    if (!lstr) {
        console.warn(`Missing localization for key: ${str}`);
        return str;
    }

    if (typeof lstr !== 'string') {
        return lstr;
    }

    const regExp = new RegExp(/\$\{([^}]+)\}/g);
    const matches = lstr.match(regExp);

    if (matches) {
        matches.forEach((match, index) => {
            const replacement = args[index] || '';
            lstr = lstr.replace(match, replacement);
        });
    }

    return lstr;
};


document.addEventListener('DOMContentLoaded', () => {
    const dailyTasksBtn = document.getElementById('selected-task-btn');
    const weeklyTasksBtn = document.querySelector('.task-btn:nth-child(2)');
    const dailyTasksContainer = document.getElementById('daily-tasks');
    const weeklyTasksContainer = document.getElementById('weekly-tasks');

    dailyTasksBtn.addEventListener('click', function() {
        dailyTasksBtn.classList.add('selected');
        dailyTasksBtn.id = 'selected-task-btn';
        weeklyTasksBtn.classList.remove('selected');
        weeklyTasksBtn.removeAttribute('id'); 
        
        dailyTasksContainer.style.display = 'block';
        weeklyTasksContainer.style.display = 'none';
    });

    weeklyTasksBtn.addEventListener('click', function() {
        dailyTasksBtn.classList.remove('selected');
        dailyTasksBtn.removeAttribute('id'); 
        weeklyTasksBtn.classList.add('selected');
        weeklyTasksBtn.id = 'selected-task-btn'; 
        
        dailyTasksContainer.style.display = 'none';
        weeklyTasksContainer.style.display = 'block';
    });

    // Adicionar event listener para o botão de passe premium
    const premiumPassBtn = document.querySelector('.unlock-premium-pass-btn');
    if (premiumPassBtn) {
        premiumPassBtn.addEventListener('click', function() {
            // Verificar se o passe premium já está desbloqueado
            if (PlayerData && PlayerData.battlepass && PlayerData.battlepass.premium === true) {
                // Se já estiver desbloqueado, apenas mostrar notificação
                Notify(locale('ui_premium_already_title') || 'Passe Premium', 
                       locale('ui_premium_already_desc') || 'Você já possui o Passe Premium!');
            } else {
                // Se não estiver desbloqueado, abrir a URL para compra
                if (Config && Config.PremiumPassPackage) {
                    window.invokeNative('openUrl', Config.PremiumPassPackage);
                } else {
                    Notify('Erro', 'URL de compra do Passe Premium não configurada.');
                }
            }
        });
    }

    // Lógica de Navegação Principal
    const navButtons = document.querySelectorAll('.nav-centered .nav-btn');
    const mainContainers = document.querySelectorAll('.main .container-wrapper'); // Selecionar todos os wrappers principais

    navButtons.forEach((button, index) => {
        button.addEventListener('click', () => {
            // Remover seleção de todos os botões e esconder todos os containers
            navButtons.forEach(btn => btn.removeAttribute('id'));
            mainContainers.forEach(cont => cont.style.display = 'none');

            // Adicionar seleção ao botão clicado e mostrar container correspondente
            button.id = 'selected-btn';
            if (mainContainers[index]) {
                mainContainers[index].style.display = mainContainers[index].classList.contains('container-wrapper-3') ? 'grid' : 'block'; // Manter grid para loja
                // Carregar dados específicos se necessário (Leaderboard/Loja)
                if (index === 2) { // Índice do Leaderboard (0: Overview, 1: Missões, 2: Leaderboard)
                    OpenScoreboard();
                } else if (index === 3) { // Índice da Loja
                    OpenBattleShop();
                }
            }
        });
    });

    window.addEventListener('message', ({ data }) => {
        if (data.enable) {
            PlayerData = data.PlayerData;
            XPPerLevel = data.XPPerLevel;

            Localize();
            LoadAvatar();
            CreateFreePass(data.FreeItems);
            CreatePremiumPass(data.PaidItems);
            CalculateTier()
            LoadTasks()
            document.body.style.display = 'block';

            // Resetar abas principais para a primeira página (Overview)
            const navBtns = document.querySelectorAll('.nav-btn');
            const mainContainers = document.querySelectorAll('.container-wrapper');
            navBtns.forEach((btn, i) => {
                if (i === 0) {
                    btn.id = 'selected-btn';
                } else {
                    btn.removeAttribute('id');
                }
            });
            mainContainers.forEach((container, i) => {
                container.style.display = (i === 0) ? 'block' : 'none';
            });
            // Resetar abas de tarefas (simplificado, já que estão em seu próprio container)
            const taskBtns = document.querySelectorAll('.missions-content .task-btn');
            const dailyContainer = document.getElementById('daily-tasks');
            const weeklyContainer = document.getElementById('weekly-tasks');
            if (taskBtns.length > 0) {
                taskBtns[0].id = 'selected-task-btn';
                if (taskBtns[1]) taskBtns[1].removeAttribute('id');
            }
            if (dailyContainer) dailyContainer.style.display = 'block';
            if (weeklyContainer) weeklyContainer.style.display = 'none';

            if (PlayerData.battlepass.premium === true) {
                document.querySelector('.unlock-premium-pass-btn').disabled = true;
                document.querySelector('#claimed-icon-svg').style.display = 'block';
                
                // Atualizar visual do botão para mostrar que já está desbloqueado
                const premiumBtn = document.querySelector('.unlock-premium-pass-btn');
                if (premiumBtn) {
                    premiumBtn.innerHTML = '<i class="fas fa-check"></i> DESBLOQUEADO';
                    premiumBtn.classList.add('premium-unlocked');
                }
            } else {
                document.querySelector('.unlock-premium-pass-btn').disabled = false;
                document.querySelector('#claimed-icon-svg').style.display = 'none';
                
                // Garantir que o botão mostra o texto correto para desbloquear
                const premiumBtn = document.querySelector('.unlock-premium-pass-btn');
                if (premiumBtn) {
                    premiumBtn.innerHTML = '<i class="fas fa-unlock"></i> DESBLOQUEAR';
                    premiumBtn.classList.remove('premium-unlocked');
                }
            }
        }
    });


    document.querySelector('.exit-btn').addEventListener('click', Exit);

    const actions = {
        '.unlock-tier-btn': ClaimItem,
        '.coins-purchase': HandlePurchase,
        '.redeem-btn': RedeemCode,
    };

    document.addEventListener('click', (event) => {
        Object.keys(actions).some((selector) => {
            if (event.target.matches(selector)) {
                actions[selector](event);
                return;
            }
        });
    });

    document.addEventListener('keyup', (event) => {
        if (event.key === 'Escape') {
            Exit();
        }
    });
});


function LoadTasks() {
    NUICallBack('GetTasks', {}).then((tasks) => {
        const daily = document.getElementById('daily-tasks');
        daily.innerHTML = '';

        for (let i = 0; i < tasks.day.length; i++) {
            const task = tasks.day[i];

            // Adicionando valores padrão para target e progress se estiverem indefinidos
            // Com base no tempo da tarefa (minutos)
            if (task.title.includes('min') && (!task.target || !task.progress)) {
                // Extrair o número de minutos do título ou descrição
                const minutesMatch = task.title.match(/(\d+)\s*min/) || task.desc.match(/(\d+)\s*min/);
                if (minutesMatch && minutesMatch[1]) {
                    task.target = parseInt(minutesMatch[1]);
                    task.progress = task.done ? task.target : 0; // Se concluído, progresso = alvo
                }
            } else if (!task.target && !task.progress && !task.done) {
                // Para tarefas sem alvo específico, definimos valores padrão
                task.target = 1;
                task.progress = 0;
            }

            const taskBox = document.createElement('div');
            taskBox.className = 'task-box';
            taskBox.id = task.done === true ? 'completed-task-box' : 'uncompleted-task-box';

            // Primeiro adicionar o status que ficará no canto
            const taskStatus = document.createElement('h3');
            taskStatus.className = 'task-status';
            taskStatus.id = task.done === true ? 'task-completed' : 'task-uncompleted';
            taskStatus.textContent = task.done === true ? locale('ui_completed') : locale('ui_uncompleted');
            taskBox.appendChild(taskStatus);

            // Depois adicionar o título
            const taskHeading = document.createElement('h2');
            taskHeading.className = 'task-nr-h2';
            taskHeading.textContent = task.title;
            taskBox.appendChild(taskHeading);

            const taskDetails = document.createElement('p');
            taskDetails.className = 'task-details';
            taskDetails.innerHTML = task.desc;
            taskBox.appendChild(taskDetails);

            // Adicionar barra de progresso se aplicável
            if (typeof task.target === 'number' && task.target > 0 && typeof task.progress === 'number' && task.progress >= 0 && !task.done) {
                const progressBar = document.createElement('div');
                progressBar.className = 'task-progress';

                const progressLine = document.createElement('div');
                progressLine.className = 'task-progress-line';
                // Calcular porcentagem, garantindo que não passe de 100
                const percentage = Math.min(100, Math.max(0, (task.progress / task.target) * 100));
                progressLine.style.width = `${percentage}%`;

                progressBar.appendChild(progressLine);
                taskBox.appendChild(progressBar);

                // Opcional: Adicionar texto de progresso (ex: 60/120)
                const progressText = document.createElement('span');
                progressText.className = 'task-progress-text';
                progressText.textContent = `${task.progress || 0} / ${task.target}`;
                taskBox.appendChild(progressText);
            }

            daily.appendChild(taskBox);
        }

        const weekly = document.getElementById('weekly-tasks');
        weekly.innerHTML = '';

        for (let i = 0; i < tasks.week.length; i++) {
            const task = tasks.week[i];

            // Adicionando valores padrão para target e progress se estiverem indefinidos
            // Com base no tempo da tarefa (minutos)
            if (task.title.includes('min') && (!task.target || !task.progress)) {
                // Extrair o número de minutos do título ou descrição
                const minutesMatch = task.title.match(/(\d+)\s*min/) || task.desc.match(/(\d+)\s*min/);
                if (minutesMatch && minutesMatch[1]) {
                    task.target = parseInt(minutesMatch[1]);
                    task.progress = task.done ? task.target : 0; // Se concluído, progresso = alvo
                }
            } else if (!task.target && !task.progress && !task.done) {
                // Para tarefas sem alvo específico, definimos valores padrão
                task.target = 1;
                task.progress = 0;
            }

            const taskBox = document.createElement('div');
            taskBox.className = 'task-box';
            taskBox.id = task.done === true ? 'completed-task-box' : 'uncompleted-task-box';

            // Primeiro adicionar o status que ficará no canto
            const taskStatus = document.createElement('h3');
            taskStatus.className = 'task-status';
            taskStatus.id = task.done === true ? 'task-completed' : 'task-uncompleted';
            taskStatus.textContent = task.done === true ? locale('ui_completed') : locale('ui_uncompleted');
            taskBox.appendChild(taskStatus);

            // Depois adicionar o título
            const taskHeading = document.createElement('h2');
            taskHeading.className = 'task-nr-h2';
            taskHeading.textContent = task.title;
            taskBox.appendChild(taskHeading);

            const taskDetails = document.createElement('p');
            taskDetails.className = 'task-details';
            taskDetails.innerHTML = task.desc;
            taskBox.appendChild(taskDetails);


            // Adicionar barra de progresso se aplicável (para semanais)
            if (typeof task.target === 'number' && task.target > 0 && typeof task.progress === 'number' && task.progress >= 0 && !task.done) {
                const progressBar = document.createElement('div');
                progressBar.className = 'task-progress';

                const progressLine = document.createElement('div');
                progressLine.className = 'task-progress-line';
                const percentage = Math.min(100, Math.max(0, (task.progress / task.target) * 100));
                progressLine.style.width = `${percentage}%`;

                progressBar.appendChild(progressLine);
                taskBox.appendChild(progressBar);

                // Opcional: Adicionar texto de progresso
                const progressText = document.createElement('span');
                progressText.className = 'task-progress-text';
                progressText.textContent = `${task.progress || 0} / ${task.target}`;
                taskBox.appendChild(progressText);
            }

            weekly.appendChild(taskBox);
        }
    });
}


function Localize() {
    const setTextContent = (selector, key) => {
        const element = document.querySelector(selector);
        if (element) {
            element.textContent = locale(key);
        }
    };

    const setTextContentFirst = (selector, key) => {
        const element = document.querySelector(selector);
        if (element) {
            element.firstChild.textContent = locale(key);
        }
    };

    const setInnerHTML = (selector, key) => {
        const element = document.querySelector(selector);
        if (element) {
            element.innerHTML = locale(key);
        }
    };

    setTextContent('.battlepass-heading', 'ui_battlepass');
    setTextContent('#selected-btn', 'ui_overview');
    setTextContent('.nav-centered .nav-btn:nth-child(2)', 'ui_missions');
    setTextContent('.nav-centered .nav-btn:nth-child(3)', 'ui_ranking');
    setTextContent('.exit-btn', 'ui_esc');
    setTextContent('.task-btn', 'ui_tasks');
    setTextContent('.premium-pass-h2', 'ui_premium');
    setTextContent('.premium-pass-span', 'ui_pass');
    setTextContent('.unlock-premium-pass-btn', 'ui_unlock');
    setInnerHTML('.free-pass-h2', 'ui_freepass');
    setInnerHTML('.exit-p', 'ui_battlepass_menu');
    setTextContentFirst('.coins-amount-h2', 'ui_coins')
    setTextContentFirst('.tier-level-h2', 'ui_tier')
    setTextContentFirst('#tier-level-h2', 'ui_tier')

    const tableHeadings = document.querySelectorAll('.table-h2');
    const tableHeadingKeys = [
        'ui_rank', 'ui_player', 'ui_tier',
        'ui_xp', 'ui_battlepass_type', 'ui_tasks_completed'
    ];
    
    tableHeadings.forEach((heading, index) => {
        if (heading && tableHeadingKeys[index]) {
            heading.textContent = locale(tableHeadingKeys[index]);
        }
    });

    const userStats = document.querySelectorAll('.table-user-stats .table-h3');
    const userStatKeys = ['ui_rank_number', 'ui_stat_1', 'ui_stat_2', 'ui_completed_tasks'];
    
    userStats.forEach((stat, index) => {
        if (stat && userStatKeys[index]) {
            stat.textContent = locale(userStatKeys[index]);
        }
    });

    setTextContent('#table-premium-pass', 'ui_premium_type');
    setTextContent('.coins-title', 'ui_coin_shop');
    setTextContent('.coins-info', 'ui_coin_shop_description');
    setTextContent('.purchase-title', 'ui_purchase_more_coins');
    setTextContent('.note', 'ui_purchase_note');
    setTextContent('.redeem-coins-h2', 'ui_redeem_coins');
    setTextContent('.redeem-btn', 'ui_redeem');
}

function CalculateTier() {
    let progress = Math.floor(PlayerData.battlepass.xp / XPPerLevel * 100);

    document.querySelectorAll('.tier-xp').forEach(element => {
        element.textContent = `${PlayerData.battlepass.xp}/${XPPerLevel}xp`;
    });

    document.querySelectorAll('.tier-level-span').forEach(element => {
        element.textContent = PlayerData.battlepass.tier;
    });

    document.querySelectorAll('.tier-progress-line').forEach(element => {
        element.style.width = progress + '%';
    });
}

function Exit() {
    PlayerData = {};
    document.querySelector('.table-wrapper').innerHTML = '';
    document.querySelector('.free-pass-row').innerHTML = '';
    document.body.style.display = 'none';
    NUICallBack('quit');
}

function CreateFreePass(items) {
    const container = document.querySelector('.free-pass-row');
    container.innerHTML = '';

    const fragment = document.createDocumentFragment();

    Object.entries(items).forEach(([key, item]) => {
        const rewardBox = createRewardBox(item, key, PlayerData.battlepass.xp, PlayerData.battlepass.tier, 'free');
        fragment.appendChild(rewardBox);
    });

    container.appendChild(fragment);
}

function CreatePremiumPass(items) {
    const container = document.querySelector('.premium-pass-row');
    container.innerHTML = '';

    const fragment = document.createDocumentFragment();

    Object.entries(items).forEach(([key, item]) => {
        const rewardBox = createRewardBox(item, key, PlayerData.battlepass.xp, PlayerData.battlepass.tier, 'premium');
        fragment.appendChild(rewardBox);
    });

    container.appendChild(fragment);
}

function createRewardBox(item, key, currentXP, currentTier, type) {
    const rewardBoxWrapper = document.createElement('div');
    rewardBoxWrapper.className = 'reward-box-wrapper';

    const rewardBox = document.createElement('div');
    rewardBox.className = 'reward-box';

    const overlay = document.createElement('div');
    overlay.className = type === 'free' ? 'overlay' : 'overlay-premium';

    let xpLabel;
    const hasClaimed = type === 'free' ? PlayerData.battlepass.freeClaims[key] : PlayerData.battlepass.premiumClaims[key];

    const isTierMet = currentTier >= item.requirements.tier;
    const isXPMet = currentXP >= item.requirements.xp;
    const isClaimable = isTierMet && (isXPMet || currentTier > item.requirements.tier);

    if (PlayerData.battlepass.premium === false && type === 'premium') {
        overlay.appendChild(lockSVG());
    } else if (!hasClaimed) {
        xpLabel = document.createElement('div');
        xpLabel.className = 'unlock-tier-btn';
        overlay.className = 'overlay';

        if (isClaimable) {
            xpLabel.textContent = locale('ui_claim');
            xpLabel.classList.add('claimable');
            xpLabel.dataset.index = Number(key) + 1;
            xpLabel.dataset.passtype = type;
            overlay.classList.add('unclaimed-reward-overlay');
        } else {
            xpLabel.textContent = `Level: ${item.requirements.tier} | XP: ${item.requirements.xp}`;
            xpLabel.classList.add('disabled');
        }

        overlay.appendChild(xpLabel);
    }

    const svg = checkmarkSVG();
    rewardBox.appendChild(svg);

    if (!hasClaimed) {
        rewardBox.appendChild(overlay);
    } else {
        svg.style.display = 'block';
    }

    let img;

    if (item.img) {
        img = item.img;
    } else if (item.vehicle || item.vehicle_name) {
        const vehicleName = item.vehicle_name || item.name;
        img = Config.vehiclesPath.replace('%s', vehicleName);
    } else {
        img = Config.ImagePath.replace('%s', item.name);
    }

    rewardBox.append(
        createImageElement(img),
        createTextElement('h4', 'item-count', item.vehicle ? '1x' : `${item.amount}x`)
    );

    rewardBoxWrapper.appendChild(rewardBox);

    return rewardBoxWrapper;
}


function createImageElement(src) {
    const img = document.createElement('img');
    img.className = 'item-image';
    img.src = src;
    return img;
}

function createTextElement(tag, className, textContent) {
    const element = document.createElement(tag);
    element.className = className;
    element.textContent = textContent;
    return element;
}

function ClaimItem(event) {
    const button = event.target;
    button.disabled = true;

    NUICallBack('claimReward', {
        index: button.dataset.index,
        pass: button.dataset.passtype
    }).then((cb) => {
        if (cb.resp === true) {
            if (cb.item.vehicle) {
                Notify(locale('ui_notify_claimed_title'), locale('ui_notify_veh_claimed', cb.item.label, cb.item.vehicle.garage))
            } else {
                Notify(locale('ui_notify_claimed_title'), locale('ui_notify_claimed_desc', cb.item.amount, cb.item.label));
            }

            const btn = button.closest('.reward-box')

            if (!btn) {
                return;
            }

            btn.querySelector('#claimed-icon-svg').style.display = 'block';
            button.closest('.overlay').remove();
            button.remove();
        }
    });
}

function HandlePurchase(event) {
    const button = event.target;
    button.disabled = true;

    // Encontrar o input de quantidade associado a este botão
    const quantityInput = button.closest('.coins-box').querySelector('.quantity-input');
    const quantity = parseInt(quantityInput.value) || 1; // Pegar valor ou default 1

    NUICallBack('BattleShopPurchase', {
        index: button.dataset.index,
        quantity: quantity // Enviar a quantidade selecionada
    }).then((cb) => {
        button.disabled = false; // Re-habilita o botão mais cedo, dentro do .then
        if (cb.resp === false) {
            // A mensagem de erro pode precisar ser ajustada dependendo da causa (sem coins, quantidade inválida etc)
            Notify(locale('ui_notify_error_title') || 'Erro', locale('ui_notify_purchase_failed') || 'Falha na compra');
            // quantityInput.value = 1; // Comentado: Não resetar em caso de erro, pode ser frustrante
            return;
        }

        PlayerData.battlepass.coins = cb.coins;
        document.querySelector('.coins-amount-span').textContent = cb.coins;

        // Verificar se cb.item existe antes de acessá-lo
        if (cb.item) { 
            if (cb.item.vehicle) {
                Notify(locale('ui_notify_purchase_title'), locale('ui_notify_veh_claimed', cb.item.label, cb.item.vehicle.garage))
            } else {
                // Também verificar se amount e label existem para segurança extra
                const amount = cb.item.amount || '?'; 
                const label = cb.item.label || 'item';
                Notify(locale('ui_notify_purchase_title'), locale('ui_notify_purchase_desc', amount, label));
            }
        } else {
            // Se cb.item não veio, mostrar uma notificação genérica
            console.warn('[PURCHASE DEBUG] Backend response missing item details.');
            Notify(locale('ui_notify_purchase_title'), locale('ui_notify_purchase_success_generic') || 'Compra realizada com sucesso!'); 
        }
        
        // Resetar quantidade e preço para 1 após compra bem-sucedida
        const coinsBox = button.closest('.coins-box'); // Encontrar o container pai primeiro
        if (coinsBox) { // Verificar se o container ainda existe
            const quantityInput = coinsBox.querySelector('.quantity-input');
            if (quantityInput) {
                quantityInput.value = 1;
            }
            
            // Atualizar o preço exibido para refletir a quantidade 1 novamente
            const priceElement = coinsBox.querySelector('.coins-price-h3');
            if (priceElement && priceElement.dataset.basePrice) {
                priceElement.textContent = priceElement.dataset.basePrice;
            }
        } else {
             console.warn("[PURCHASE DEBUG] Could not find parent '.coins-box' after successful purchase. UI reset skipped.");
        }

    }, () => {
        // Versão simples do catch usando segundo parâmetro do .then() em vez de .catch()
        // Sem tentar acessar nenhum objeto ou propriedade, apenas habilitando o botão
        try {
            if (button) button.disabled = false;
        } catch (e) {
            // Não fazer nada se não conseguir habilitar o botão
        }
    });

    /* Removido o setTimeout daqui pois o botão será reabilitado no .then() ou .catch()
    setTimeout(() => {
        button.disabled = false;
    }, 500);
    */
}

function LoadAvatar() {
    // Atualizar avatar e nome
    document.querySelector('.steam-nick').textContent = locale('ui_hello', PlayerData.name);
    document.querySelector('.steam-image').src = PlayerData.avatar;
    // Atualizar nível no cartão de perfil
    const levelSpan = document.querySelector('.profile-level-span');
    if (levelSpan) levelSpan.textContent = PlayerData.battlepass.tier;
    // Atualizar quantidade de XP
    const xpSpan = document.querySelector('.profile-xp-span');
    if (xpSpan) xpSpan.textContent = `${PlayerData.battlepass.xp}/${XPPerLevel}`;
    // Atualizar barra de progresso do perfil
    const progressPercent = Math.floor(PlayerData.battlepass.xp / XPPerLevel * 100);
    const profileLine = document.querySelector('.profile-progress-line');
    if (profileLine) profileLine.style.width = progressPercent + '%';
    // Atualizar quantidade de coins
    const coinsSpan = document.querySelector('.profile-coins-span');
    if (coinsSpan) coinsSpan.textContent = PlayerData.battlepass.coins;
}

function OpenScoreboard() {
    try {
        // Verificar se a tabela existe antes de continuar
        const tableWrapper = document.querySelector('.table-wrapper');
        if (!tableWrapper) {
            return;
        }
        
        // Limpar a tabela enquanto carrega
        tableWrapper.innerHTML = '<div class="table-loading">Carregando ranking...</div>';
        
        NUICallBack('OpenScoreboard', {}).then(
            // Callback de sucesso
            (response) => {
                // Verificar se a resposta é válida antes de tentar ordenar
                if (!response || !Array.isArray(response) || response.length === 0) {
                    tableWrapper.innerHTML = '<div class="table-empty">Nenhum jogador encontrado no ranking.</div>';
                    return;
                }
                
                // Ordenar os jogadores por tier e XP
                response.sort((a, b) => {
                    if (b.tier === a.tier) {
                        return b.xp - a.xp;
                    }
                    return b.tier - a.tier;
                });
                
                // Atualizar o scoreboard com dados válidos
                updateScoreboard(response);
                
                // Atualizar estatísticas do jogador no topo, se houver
                if (response.length > 0) {
                    updateTopPlayerStats(response[0]);
                }
            },
            // Callback de erro
            (error) => {
                tableWrapper.innerHTML = '<div class="table-error">Erro ao carregar o ranking. Por favor, tente novamente.</div>';
            }
        );
    } catch (e) {
        // Capturar qualquer erro não esperado
        console.error('[SCOREBOARD ERROR] Erro crítico ao abrir o ranking:', e);
    }
}


function OpenBattleShop() {
    try {
        // Primeiro, verificar se o elemento existe antes de tentar atualizar
        const coinsRightSide = document.querySelector('.coins-right-side');
        if (!coinsRightSide) {
            return;
        }
        
        // Limpar o container antes de fazer a chamada
        coinsRightSide.innerHTML = '';
        
        // Atualizar o texto de coins - com verificação de segurança
        try {
            const coinsAmountSpan = document.querySelector('.coins-amount-span');
            if (coinsAmountSpan && PlayerData && PlayerData.battlepass) {
                coinsAmountSpan.textContent = PlayerData.battlepass.coins || 0;
            }
        } catch (e) {
            console.error('[SHOP ERROR] Erro ao atualizar contador de moedas:', e);
        }
        
        // Fazer a chamada NUI com tratamento de erro seguro
        NUICallBack('OpenBattleShop', {}).then(
            // Primeiro callback - sucesso
            (response) => {
                // Verificações continuam como já implementado
                if (!response || !response.BattleShop) {
                    return;
                }
                
                // Preencher os itens da loja
                Object.entries(response.BattleShop).forEach(([key, item]) => {
                    // Verificar se o item é válido
                    if (!item) {
                        return; // Pular este item e continuar com o próximo
                    }

                    const itemContainer = document.createElement('div');
                    itemContainer.className = 'coins-box';

                    // Usar valores padrão caso propriedades esperadas não existam
                    let img;

                    if (item.img) {
                        img = item.img;
                    } else if (item.vehicle || item.vehicle_name) {
                        const vehicleName = item.vehicle_name || item.name || 'default';
                        img = Config.vehiclesPath ? Config.vehiclesPath.replace('%s', vehicleName) : '';
                    } else if (item.name) {
                        img = Config.ImagePath ? Config.ImagePath.replace('%s', item.name) : '';
                    } else {
                        // Imagem padrão para itens sem informações suficientes
                        img = 'img/unknown.png';
                    }

                    const itemImage = createImageElement(img);
                    itemImage.classList.add('coins-item-image');

                    const coinsBuyWrapper = document.createElement('div');
                    coinsBuyWrapper.className = 'coins-buy-wrapper';

                    const coinsPriceWrapper = document.createElement('div');
                    coinsPriceWrapper.className = 'coins-price-wrapper';

                    // Verificar se item.coins existe e é um valor válido
                    const basePrice = parseInt(item.coins) || 0; // Armazenar o preço base
                    const coinsPriceH3 = createTextElement('h3', 'coins-price-h3', basePrice);
                    // Armazenar o preço base no elemento para fácil acesso
                    coinsPriceH3.dataset.basePrice = basePrice; 

                    // Verificar se coinSVG está definido antes de chamar
                    try {
                        coinsPriceWrapper.append(coinSVG(), coinsPriceH3);
                    } catch (e) {
                        console.error('[SHOP ERROR] Erro ao gerar ícone de moeda:', e);
                        coinsPriceWrapper.append(coinsPriceH3);
                    }

                    // Seletor de Quantidade
                    const quantityWrapper = document.createElement('div');
                    quantityWrapper.className = 'quantity-wrapper';
                    const minusBtn = document.createElement('button');
                    minusBtn.className = 'quantity-btn minus-btn';
                    minusBtn.textContent = '-';
                    const quantityInput = document.createElement('input');
                    quantityInput.className = 'quantity-input';
                    quantityInput.type = 'number';
                    quantityInput.value = '1';
                    quantityInput.min = '1';
                    // Poderia adicionar um max baseado no item.maxAmount se existir
                    if (item.maxAmount) {
                        quantityInput.max = item.maxAmount;
                    }
                    const plusBtn = document.createElement('button');
                    plusBtn.className = 'quantity-btn plus-btn';
                    plusBtn.textContent = '+';

                    // Função para atualizar o preço total
                    const updateTotalPrice = () => {
                        try {
                            const quantity = parseInt(quantityInput.value) || 1;
                            const totalPrice = basePrice * quantity;
                            coinsPriceH3.textContent = totalPrice;
                        } catch (e) {
                            console.error('[SHOP ERROR] Erro ao atualizar preço:', e);
                        }
                    };

                    minusBtn.onclick = () => { 
                        try {
                            quantityInput.stepDown(); 
                            updateTotalPrice(); // Atualizar preço ao clicar no botão
                        } catch (e) {
                            console.error('[SHOP ERROR] Erro ao diminuir quantidade:', e);
                        }
                    };
                    plusBtn.onclick = () => { 
                        try {
                            quantityInput.stepUp(); 
                            updateTotalPrice(); // Atualizar preço ao clicar no botão
                        } catch (e) {
                            console.error('[SHOP ERROR] Erro ao aumentar quantidade:', e);
                        }
                    };
                    // Atualizar preço também quando o valor do input muda diretamente
                    quantityInput.addEventListener('input', updateTotalPrice);

                    try {
                        quantityWrapper.append(minusBtn, quantityInput, plusBtn);
                    } catch (e) {
                        console.error('[SHOP ERROR] Erro ao montar wrapper de quantidade:', e);
                    }

                    const coinsPurchaseBtn = document.createElement('button');
                    coinsPurchaseBtn.className = 'coins-purchase';
                    coinsPurchaseBtn.dataset.index = Number(key) + 1;
                    // Usar locale com fallback seguro
                    try {
                        const purchaseText = locale('ui_purchase');
                        coinsPurchaseBtn.textContent = purchaseText || 'Comprar';
                    } catch (e) {
                        console.error('[SHOP ERROR] Erro ao obter texto do botão:', e);
                        coinsPurchaseBtn.textContent = 'Comprar';
                    }

                    try {
                        coinsBuyWrapper.append(coinsPriceWrapper, quantityWrapper, coinsPurchaseBtn);
                        itemContainer.append("",itemImage, coinsBuyWrapper);
                        coinsRightSide.appendChild(itemContainer);
                    } catch (e) {
                        console.error('[SHOP ERROR] Erro ao montar item na loja:', e, {
                            item: item,
                            key: key
                        });
                    }
                });
            },
            // Segundo callback - tratamento de erro seguro (substitui o .catch)
            (error) => {
                console.error('[SHOP ERROR] Erro ao buscar dados da loja:', error);
                // Opcional: Mostrar uma mensagem de erro para o usuário
                try {
                    const errorMsg = document.createElement('div');
                    errorMsg.className = 'shop-error-message';
                    errorMsg.textContent = 'Não foi possível carregar os itens da loja. Por favor, tente novamente.';
                    coinsRightSide.appendChild(errorMsg);
                } catch (e) {
                    // Não fazer nada se nem conseguir mostrar o erro
                }
            }
        );
    } catch (e) {
        // Capturar qualquer erro não esperado no escopo principal da função
        console.error('[SHOP ERROR] Erro crítico ao abrir a loja:', e);
    }
}

function updateScoreboard(response) {
    try {
        // Verificar se temos dados válidos
        if (!response || !Array.isArray(response)) {
            return;
        }
        
        // Verificar se o elemento existe
        const tableWrapper = document.querySelector('.table-wrapper');
        if (!tableWrapper) {
            return;
        }
        
        // Limpar a tabela
        tableWrapper.innerHTML = '';
        
        // Criar fragment para melhor performance
        const fragment = document.createDocumentFragment();
        
        // Criar linhas para cada jogador
        response.forEach((item, index) => {
            try {
                // Verificar se o item é válido antes de criar uma linha
                if (!item || typeof item !== 'object') {
                    return; // Pular este item
                }
                
                const row = createScoreboardRow(item, index);
                if (row) {
                    fragment.appendChild(row);
                }
            } catch (e) {
                console.error('[SCOREBOARD ERROR] Erro ao criar linha para jogador:', e, item);
            }
        });
        
        // Adicionar todas as linhas de uma vez
        tableWrapper.appendChild(fragment);
        
    } catch (e) {
        console.error('[SCOREBOARD ERROR] Erro ao atualizar scoreboard:', e);
    }
}

function createScoreboardRow(item, index) {
    try {
        // Verificar se o item é válido
        if (!item || typeof item !== 'object') {
            return null;
        }
        
        const row = document.createElement('div');
        row.className = 'table-row';
        
        // Ranking
        try {
            row.appendChild(createTextElement('h3', 'table-h3', locale('ui_ranked', index + 1)));
        } catch (e) {
            row.appendChild(createTextElement('h3', 'table-h3', `#${index + 1}`));
        }
        
        // Informações do usuário (avatar e nome)
        try {
            const userInfo = document.createElement('div');
            userInfo.className = 'table-user-info';
            
            // Avatar - usar um padrão se não existir
            const avatarSrc = item.avatar || 'img/default-avatar.png';
            userInfo.appendChild(createImageElement(avatarSrc));
            
            // Nome - usar "Jogador" se não existir
            const playerName = item.name || `Jogador ${index + 1}`;
            userInfo.appendChild(createTextElement('h3', 'table-h3', playerName));
            
            row.appendChild(userInfo);
        } catch (e) {
            console.error('[SCOREBOARD ERROR] Erro ao criar info do usuário:', e);
            // Adicionar uma célula vazia em caso de erro
            row.appendChild(document.createElement('div'));
        }
        
        // Tier
        try {
            row.appendChild(createTableElement('tier', item.tier || 0));
        } catch (e) {
            row.appendChild(createTableElement('tier', 0));
        }
        
        // XP
        try {
            const xp = typeof item.xp === 'number' ? item.xp.toLocaleString() : '0';
            row.appendChild(createTableElement('xp', xp));
        } catch (e) {
            row.appendChild(createTableElement('xp', '0'));
        }
        
        // Tipo de Passe (Premium/Free)
        try {
            const isPremium = Boolean(item.premium);
            const bpText = isPremium ? locale('ui_premium_type') : locale('ui_free_type');
            const bpId = isPremium ? 'table-premium-pass' : '';
            row.appendChild(createTableElement('bp', bpText, bpId));
        } catch (e) {
            row.appendChild(createTableElement('bp', locale('ui_free_type')));
        }
        
        // Tarefas completadas
        try {
            row.appendChild(createTableElement('taskdone', item.taskdone || 0));
        } catch (e) {
            row.appendChild(createTableElement('taskdone', 0));
        }
        
        return row;
    } catch (e) {
        console.error('[SCOREBOARD ERROR] Erro crítico ao criar linha:', e);
        return null;
    }
}

function createTableElement(className, textContent, id = '') {
    const element = createTextElement('h3', `table-h3 ${className}`, textContent);
    if (id) element.id = id;
    return element;
}

function updateTopPlayerStats(topPlayer) {
    try {
        // Primeiro, verificar se temos um jogador válido
        if (!topPlayer || typeof topPlayer !== 'object') {
            return;
        }
        
        // Verificar se os elementos existem antes de tentar atualizar
        const topPlayerElements = document.querySelectorAll('.table-user-stats h3.table-h3');
        if (!topPlayerElements || topPlayerElements.length < 6) {
            return;
        }
        
        const userInfo = document.querySelector('.table-user-stats .table-user-info');
        if (!userInfo) {
            return;
        }
        
        const steamImg = userInfo.querySelector('.table-steam-img');
        const nameElement = userInfo.querySelector('h3.table-h3');
        
        // Atualizar elementos com segurança
        try {
            // Ranking
            topPlayerElements[0].textContent = locale('ui_ranked', 1);
            
            // Avatar
            if (steamImg && topPlayer.avatar) {
                steamImg.src = topPlayer.avatar;
            }
            
            // Nome
            if (nameElement) {
                nameElement.textContent = topPlayer.name || 'Jogador';
            }
            
            // Tier
            topPlayerElements[2].textContent = topPlayer.tier || 0;
            
            // XP
            if (typeof topPlayer.xp === 'number') {
                topPlayerElements[3].textContent = topPlayer.xp.toLocaleString();
            } else {
                topPlayerElements[3].textContent = '0';
            }
            
            // Tipo de passe (Premium/Free)
            topPlayerElements[4].textContent = topPlayer.premium ? 
                locale('ui_premium_type') : locale('ui_free_type');
            topPlayerElements[4].id = topPlayer.premium ? 
                'table-premium-pass' : 'table-free-pass';
            
            // Tarefas completadas
            topPlayerElements[5].textContent = topPlayer.taskdone || 0;
        } catch (e) {
            console.error('[STATS ERROR] Erro ao atualizar estatísticas do top player:', e);
        }
    } catch (e) {
        console.error('[STATS ERROR] Erro crítico ao atualizar estatísticas do top player:', e);
    }
}

async function NUICallBack(endpoint, data = {}) {
    const response = await fetch(`https://${resource}/${endpoint}`, {
        method: 'POST',
        body: JSON.stringify(data),
        headers: {
            'Content-Type': 'application/json'
        }
    });
    return await response.json();
}

function RedeemCode() {
    const inputElement = document.querySelector('.redeem-input');
    const code = inputElement.value;
    const button = document.querySelector('.redeem-btn');

    button.disabled = true;

    if (code === '') {
        Notify(locale('ui_notify_invalid_title'), locale('ui_notify_invalid_empty'));
        setTimeout(() => {
            button.disabled = false;
        }, 3000);
        return;
    }

    NUICallBack('ReedemCode', {
        code: code,
    }).then((cb) => {
        if (cb === false) {
            Notify(locale('ui_notify_invalid_title'), locale('ui_notify_invalid_not'));
            inputElement.value = '';
            setTimeout(() => {
                button.disabled = false;
            }, 3000);
            return; 
        }

        inputElement.value = '';
        PlayerData.battlepass.coins += Number(cb);
        document.querySelector('.coins-amount-span').textContent = PlayerData.battlepass.coins;
        Notify(locale('ui_notify_purchase_title'), locale('ui_notify_added_coins', cb));
    });

    setTimeout(() => {
        button.disabled = false;
    }, 3000);
}

function Notify(title, message) {
    try {
        // Garantir que temos strings válidas
        const safeTitle = (title || 'Notificação').toString();
        const safeMessage = (message || '').toString();
        
        // Criar elementos
        const notification = document.createElement('div');
        notification.className = `notification info`;
        
        const strong = document.createElement('strong');
        strong.textContent = safeTitle;
        
        const br = document.createElement('br');
        
        const text = document.createElement('span');
        text.textContent = safeMessage;
        
        // Verificar se o container de notificações existe, criar se não
        let container = document.getElementById('notification-container');
        if (!container) {
            console.warn('[NOTIFY] Notification container not found, creating one.');
            container = document.createElement('div');
            container.id = 'notification-container';
            document.body.appendChild(container);
        }
        
        // Montar e adicionar a notificação
        notification.appendChild(strong);
        notification.appendChild(br);
        notification.appendChild(text);
        container.appendChild(notification);

        // Animar a entrada da notificação
        setTimeout(() => {
            notification.classList.add('show');
        }, 10);

        // Animar a saída e remover
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                // Verificar se o elemento ainda existe no DOM antes de tentar remover
                if (notification.parentNode) {
                    notification.remove();
                }
            }, 500);
        }, 3500);
    } catch (error) {
        // Lidar com qualquer erro que ocorra durante a criação da notificação
        console.error('[NOTIFY] Error creating notification:', error);
    }
}

function coinSVG() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.classList.add('coins-price-icon');
    svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    svg.setAttribute('width', '18');
    svg.setAttribute('height', '18');
    svg.setAttribute('viewBox', '0 0 18 18');
    svg.setAttribute('fill', 'none');

    const pathData = "M0 14.2488V15.75C0 16.9893 2.9918 18 6.75 18C10.4449 18 13.5 16.9893 13.5 15.75V14.2471C12.0516 15.2719 9.39375 15.75 6.75 15.75C4.10625 15.75 1.4502 15.2719 0 14.2488ZM11.25 4.5C14.9449 4.5 18 3.48926 18 2.25C18 1.01074 14.9766 0 11.25 0C7.4918 0 4.5 1.01074 4.5 2.25C4.5 3.48926 7.4918 4.5 11.25 4.5ZM0 10.5609V12.375C0 13.6143 2.9918 14.625 6.75 14.625C10.4449 14.625 13.5 13.6143 13.5 12.375V10.5609C12.0516 11.7563 9.39023 12.375 6.75 12.375C4.10977 12.375 1.4502 11.7563 0 10.5609ZM14.625 10.9477C16.6395 10.5539 18 9.83672 18 9V7.49531C17.1826 8.07539 15.9873 8.46668 14.625 8.7082V10.9477ZM6.75 5.625C2.9918 5.625 0 6.88359 0 8.4375C0 9.99141 2.9918 11.25 6.75 11.25C10.4449 11.25 13.5 9.99316 13.5 8.4375C13.5 6.88184 10.4449 5.625 6.75 5.625ZM14.4563 7.60078C16.5691 7.22461 18 6.47578 18 5.625V4.12031C16.752 5.00379 14.6074 5.4784 12.3469 5.59266C13.3875 6.09609 14.1504 6.77109 14.4563 7.60078Z";

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', pathData);
    path.setAttribute('fill', '#35B9C1');

    svg.appendChild(path);

    return svg;
}

function lockSVG() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.classList.add('locked-icon');
    svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    svg.setAttribute('width', '106');
    svg.setAttribute('height', '134');
    svg.setAttribute('viewBox', '0 0 106 134');
    svg.setAttribute('fill', 'none');

    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('filter', 'url(#filter0_d_1_1138)');

    const pathsData = [
        "M77.7626 108.956H28.1406C27.3077 108.956 26.5089 108.626 25.9199 108.037C25.3309 107.448 25 106.649 25 105.816V59.4727C25 58.6397 25.3309 57.8409 25.9199 57.2519C26.5089 56.6629 27.3077 56.332 28.1406 56.332H77.7626C78.5955 56.332 79.3944 56.6629 79.9834 57.2519C80.5723 57.8409 80.9032 58.6397 80.9032 59.4727V105.816C80.9032 106.649 80.5723 107.448 79.9834 108.037C79.3944 108.626 78.5955 108.956 77.7626 108.956ZM31.2813 102.675H74.622V62.6133H31.2813V102.675Z",
        "M71.829 62.6132H34.0891C33.2562 62.6132 32.4573 62.2823 31.8684 61.6933C31.2794 61.1043 30.9485 60.3055 30.9485 59.4725V46.797C31.0051 40.9966 33.3489 35.453 37.4706 31.3713C41.5922 27.2897 47.1584 25 52.9591 25C58.7597 25 64.3259 27.2897 68.4476 31.3713C72.5692 35.453 74.9131 40.9966 74.9697 46.797V59.4725C74.9697 60.3055 74.6388 61.1043 74.0498 61.6933C73.4608 62.2823 72.662 62.6132 71.829 62.6132ZM37.2297 56.3319H68.6884V46.797C68.6406 42.6567 66.9624 38.7023 64.0178 35.7914C61.0732 32.8806 57.0996 31.2481 52.9591 31.2481C48.8186 31.2481 44.845 32.8806 41.9004 35.7914C38.9557 38.7023 37.2775 42.6567 37.2297 46.797V56.3319Z",
        "M52.9601 88.5779C51.0345 88.5779 49.1521 88.0069 47.5511 86.9371C45.95 85.8673 44.7021 84.3467 43.9652 82.5677C43.2283 80.7887 43.0355 78.8311 43.4112 76.9425C43.7869 75.0539 44.7141 73.3192 46.0757 71.9576C47.4373 70.596 49.1721 69.6687 51.0607 69.293C52.9493 68.9174 54.9069 69.1102 56.6859 69.8471C58.4649 70.584 59.9854 71.8318 61.0552 73.4329C62.125 75.034 62.696 76.9163 62.696 78.8419C62.6933 81.4232 61.6666 83.898 59.8414 85.7232C58.0161 87.5485 55.5414 88.5751 52.9601 88.5779ZM52.9601 75.3872C52.2768 75.3872 51.6089 75.5898 51.0408 75.9694C50.4726 76.3491 50.0298 76.8886 49.7684 77.5199C49.5069 78.1511 49.4385 78.8457 49.5718 79.5159C49.7051 80.186 50.0341 80.8016 50.5172 81.2848C51.0004 81.7679 51.616 82.0969 52.2861 82.2302C52.9563 82.3635 53.6509 82.2951 54.2821 82.0336C54.9134 81.7722 55.4529 81.3294 55.8326 80.7612C56.2122 80.1931 56.4148 79.5252 56.4148 78.8419C56.4137 77.926 56.0493 77.0479 55.4017 76.4003C54.7541 75.7527 53.876 75.3883 52.9601 75.3872Z",
        "M52.96 96.1845C52.127 96.1845 51.3282 95.8536 50.7392 95.2646C50.1502 94.6756 49.8193 93.8768 49.8193 93.0439V85.4373C49.8193 84.6043 50.1502 83.8055 50.7392 83.2165C51.3282 82.6275 52.127 82.2966 52.96 82.2966C53.7929 82.2966 54.5917 82.6275 55.1807 83.2165C55.7697 83.8055 56.1006 84.6043 56.1006 85.4373V93.0439C56.1006 93.8768 55.7697 94.6756 55.1807 95.2646C54.5917 95.8536 53.7929 96.1845 52.96 96.1845Z"
    ];

    pathsData.forEach(d => {
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        path.setAttribute('fill', '#2E9BA2');
        g.appendChild(path);
    });

    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    const filter = document.createElementNS('http://www.w3.org/2000/svg', 'filter');
    filter.setAttribute('id', 'filter0_d_1_1138');
    filter.setAttribute('x', '0');
    filter.setAttribute('y', '0');
    filter.setAttribute('width', '105.903');
    filter.setAttribute('height', '133.957');
    filter.setAttribute('filterUnits', 'userSpaceOnUse');
    filter.setAttribute('color-interpolation-filters', 'sRGB');

    const feFlood = document.createElementNS('http://www.w3.org/2000/svg', 'feFlood');
    feFlood.setAttribute('flood-opacity', '0');
    feFlood.setAttribute('result', 'BackgroundImageFix');

    const feColorMatrix = document.createElementNS('http://www.w3.org/2000/svg', 'feColorMatrix');
    feColorMatrix.setAttribute('in', 'SourceAlpha');
    feColorMatrix.setAttribute('type', 'matrix');
    feColorMatrix.setAttribute('values', '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0');
    feColorMatrix.setAttribute('result', 'hardAlpha');

    const feOffset = document.createElementNS('http://www.w3.org/2000/svg', 'feOffset');

    const feGaussianBlur = document.createElementNS('http://www.w3.org/2000/svg', 'feGaussianBlur');
    feGaussianBlur.setAttribute('stdDeviation', '12.5');

    const feComposite = document.createElementNS('http://www.w3.org/2000/svg', 'feComposite');
    feComposite.setAttribute('in2', 'hardAlpha');
    feComposite.setAttribute('operator', 'out');

    const feColorMatrix2 = document.createElementNS('http://www.w3.org/2000/svg', 'feColorMatrix');
    feColorMatrix2.setAttribute('type', 'matrix');
    feColorMatrix2.setAttribute('values', '0 0 0 0 0.207843 0 0 0 0 0.72549 0 0 0 0 0.756863 0 0 0 0.8 0');

    const feBlend = document.createElementNS('http://www.w3.org/2000/svg', 'feBlend');
    feBlend.setAttribute('mode', 'normal');
    feBlend.setAttribute('in2', 'BackgroundImageFix');
    feBlend.setAttribute('result', 'effect1_dropShadow_1_1138');

    const feBlend2 = document.createElementNS('http://www.w3.org/2000/svg', 'feBlend');
    feBlend2.setAttribute('mode', 'normal');
    feBlend2.setAttribute('in', 'SourceGraphic');
    feBlend2.setAttribute('in2', 'effect1_dropShadow_1_1138');
    feBlend2.setAttribute('result', 'shape');

    filter.appendChild(feFlood);
    filter.appendChild(feColorMatrix);
    filter.appendChild(feOffset);
    filter.appendChild(feGaussianBlur);
    filter.appendChild(feComposite);
    filter.appendChild(feColorMatrix2);
    filter.appendChild(feBlend);
    filter.appendChild(feBlend2);
    defs.appendChild(filter);
    
    svg.appendChild(g);
    svg.appendChild(defs);

    return svg;
}


function checkmarkSVG() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.classList.add('claimed-icon');
    svg.setAttribute('style', 'display: none;');
    svg.setAttribute('id', 'claimed-icon-svg');
    svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    svg.setAttribute('width', '28');
    svg.setAttribute('height', '28');
    svg.setAttribute('viewBox', '0 0 28 28');
    svg.setAttribute('fill', 'none');

    const gClipPath = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    gClipPath.setAttribute('clip-path', 'url(#clip0_1_1017)');

    const gFilter = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    gFilter.setAttribute('filter', 'url(#filter0_d_1_1017)');

    const pathData = "M7.62222 11.0444L5.44444 13.2222L12.4444 20.2222L28 4.66667L25.8222 2.48889L12.4444 15.8667L7.62222 11.0444ZM24.8889 24.8889H3.11111V3.11111H18.6667V0H3.11111C1.4 0 0 1.4 0 3.11111V24.8889C0 26.6 1.4 28 3.11111 28H24.8889C26.6 28 28 26.6 28 24.8889V12.4444H24.8889V24.8889Z";

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('fill-rule', 'evenodd');
    path.setAttribute('clip-rule', 'evenodd');
    path.setAttribute('d', pathData);
    path.setAttribute('fill', '#35B9C1');

    gFilter.appendChild(path);
    gClipPath.appendChild(gFilter);
    svg.appendChild(gClipPath);

    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');

    const filter = document.createElementNS('http://www.w3.org/2000/svg', 'filter');
    filter.setAttribute('id', 'filter0_d_1_1017');
    filter.setAttribute('x', '-20.9');
    filter.setAttribute('y', '-20.9');
    filter.setAttribute('width', '69.8');
    filter.setAttribute('height', '69.8');
    filter.setAttribute('filterUnits', 'userSpaceOnUse');
    filter.setAttribute('color-interpolation-filters', 'sRGB');

    const feFlood = document.createElementNS('http://www.w3.org/2000/svg', 'feFlood');
    feFlood.setAttribute('flood-opacity', '0');
    feFlood.setAttribute('result', 'BackgroundImageFix');

    const feColorMatrixIn = document.createElementNS('http://www.w3.org/2000/svg', 'feColorMatrix');
    feColorMatrixIn.setAttribute('in', 'SourceAlpha');
    feColorMatrixIn.setAttribute('type', 'matrix');
    feColorMatrixIn.setAttribute('values', '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0');
    feColorMatrixIn.setAttribute('result', 'hardAlpha');

    const feOffset = document.createElementNS('http://www.w3.org/2000/svg', 'feOffset');

    const feGaussianBlur = document.createElementNS('http://www.w3.org/2000/svg', 'feGaussianBlur');
    feGaussianBlur.setAttribute('stdDeviation', '10.45');

    const feComposite = document.createElementNS('http://www.w3.org/2000/svg', 'feComposite');
    feComposite.setAttribute('in2', 'hardAlpha');
    feComposite.setAttribute('operator', 'out');

    const feColorMatrixOut = document.createElementNS('http://www.w3.org/2000/svg', 'feColorMatrix');
    feColorMatrixOut.setAttribute('type', 'matrix');
    feColorMatrixOut.setAttribute('values', '0 0 0 0 0.207843 0 0 0 0 0.72549 0 0 0 0 0.756863 0 0 0 0.4 0');

    const feBlend1 = document.createElementNS('http://www.w3.org/2000/svg', 'feBlend');
    feBlend1.setAttribute('mode', 'normal');
    feBlend1.setAttribute('in2', 'BackgroundImageFix');
    feBlend1.setAttribute('result', 'effect1_dropShadow_1_1017');

    const feBlend2 = document.createElementNS('http://www.w3.org/2000/svg', 'feBlend');
    feBlend2.setAttribute('mode', 'normal');
    feBlend2.setAttribute('in', 'SourceGraphic');
    feBlend2.setAttribute('in2', 'effect1_dropShadow_1_1017');
    feBlend2.setAttribute('result', 'shape');

    filter.appendChild(feFlood);
    filter.appendChild(feColorMatrixIn);
    filter.appendChild(feOffset);
    filter.appendChild(feGaussianBlur);
    filter.appendChild(feComposite);
    filter.appendChild(feColorMatrixOut);
    filter.appendChild(feBlend1);
    filter.appendChild(feBlend2);

    const clipPath = document.createElementNS('http://www.w3.org/2000/svg', 'clipPath');
    clipPath.setAttribute('id', 'clip0_1_1017');

    const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
    rect.setAttribute('width', '28');
    rect.setAttribute('height', '28');
    rect.setAttribute('fill', 'white');

    clipPath.appendChild(rect);

    defs.appendChild(filter);
    defs.appendChild(clipPath);

    svg.appendChild(defs);

    return svg;
}