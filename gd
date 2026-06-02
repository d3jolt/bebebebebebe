<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>Geometry Dash | Школьная версия | Прыгай и собирай монеты</title>
    <style>
        * {
            user-select: none;
            -webkit-tap-highlight-color: transparent;
        }

        body {
            margin: 0;
            min-height: 100vh;
            background: linear-gradient(135deg, #0b2b3f 0%, #1a4f6e 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            font-family: 'Courier New', 'Fira Code', 'Press Start 2P', monospace;
        }

        .game-wrapper {
            background: #0a1a2a;
            border-radius: 40px;
            padding: 20px;
            box-shadow: 0 20px 35px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.1);
            border: 2px solid #f4c542;
        }

        canvas {
            display: block;
            margin: 0 auto;
            border-radius: 20px;
            box-shadow: 0 8px 20px black;
            cursor: pointer;
            background-color: #0a121f;
        }

        .info-panel {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: #0f212ecc;
            backdrop-filter: blur(6px);
            margin-top: 18px;
            padding: 8px 24px;
            border-radius: 60px;
            color: #ffecb3;
            text-shadow: 0 2px 0 #1a3a4a;
            border: 1px solid #f4b642;
            font-weight: bold;
        }

        .stats {
            display: flex;
            gap: 35px;
            font-size: 22px;
            letter-spacing: 2px;
        }

        .stats span {
            background: #000000aa;
            padding: 5px 14px;
            border-radius: 40px;
            color: #ffdd99;
        }

        button {
            background: #c97e2a;
            border: none;
            font-family: monospace;
            font-weight: bold;
            font-size: 18px;
            padding: 6px 18px;
            border-radius: 60px;
            color: #fff0cc;
            cursor: pointer;
            transition: 0.08s linear;
            box-shadow: 0 4px 0 #6a3e12;
        }

        button:active {
            transform: translateY(2px);
            box-shadow: 0 1px 0 #6a3e12;
        }

        .controls {
            margin-top: 12px;
            background: #000000aa;
            border-radius: 40px;
            padding: 6px 20px;
            font-size: 14px;
            color: #bbe1ff;
        }

        kbd {
            background: #2c2c3a;
            padding: 2px 8px;
            border-radius: 30px;
            font-weight: bold;
            color: #ffcc88;
            margin: 0 4px;
        }

        .game-over-tip {
            position: fixed;
            top: 45%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #111c26dd;
            backdrop-filter: blur(10px);
            border-radius: 48px;
            padding: 18px 36px;
            text-align: center;
            border: 2px solid #f4b642;
            color: #ffe1a0;
            font-size: 26px;
            font-weight: bold;
            white-space: nowrap;
            pointer-events: none;
            font-family: monospace;
        }
    </style>
</head>
<body>
<div>
    <div class="game-wrapper">
        <canvas id="gameCanvas" width="900" height="400"></canvas>
        <div class="info-panel">
            <div class="stats">
                🪙 МОНЕТЫ: <span id="coinCounter">0</span>
                &nbsp;&nbsp;⭐ ОЧКИ: <span id="scoreCounter">0</span>
            </div>
            <button id="resetBtn">🔄 НОВЫЙ ЗАБЕГ</button>
        </div>
        <div class="controls">
            🎮 <kbd>ПРОБЕЛ</kbd> или <kbd>ЛКМ</kbd> — ПРЫЖОК &nbsp;&nbsp;|&nbsp;&nbsp;
            🧩 собери 10 монет для победы! &nbsp;&nbsp;|&nbsp;&nbsp; ⚡ избегай шипов
        </div>
    </div>
</div>

<script>
    (function(){
        // ---------- НАСТРОЙКИ GEOMETRY DASH (упрощённая версия) ----------
        const canvas = document.getElementById('gameCanvas');
        const ctx = canvas.getContext('2d');
        const width = 900;
        const height = 400;
        canvas.width = width;
        canvas.height = height;
        
        // ---- Игрок (квадратик / куб) ----
        const PLAYER_SIZE = 32;
        let player = {
            x: 100,
            y: 0,
            vy: 0,
            isGrounded: true,
            size: PLAYER_SIZE
        };
        
        // гравитация и физика
        const GRAVITY = 1600;        // пикселей/сек²
        const JUMP_FORCE = -520;     // начальная скорость прыжка
        const GROUND_Y = height - 60; // уровень земли
        
        // ---- МИР: препятствия и монеты ----
        let obstacles = [];      // шипы и стены
        let coins = [];
        
        // переменные игры
        let gameActive = true;
        let frameRequest;
        let lastTimestamp = 0;
        let distance = 0;         // условная дистанция (счёт)
        let coinsCollected = 0;
        
        // смещение мира (прокрутка)
        let worldOffset = 0;
        let baseSpeed = 350;      // начальная скорость движения (пикс/сек)
        let currentSpeed = baseSpeed;
        
        // таймеры спавна
        let lastObstacleSpawn = 0;
        let lastCoinSpawn = 0;
        let gameTime = 0;
        
        // эффект прыжка/вспышки
        let jumpFlash = 0;
        
        // ПОБЕДА!
        let victory = false;
        
        // ---- Функции спавна (безобидные препятствия - шипы) ----
        function spawnObstacle(nowTime) {
            // Шип — простое препятствие, размер 25x25
            const type = 'spike';
            const xPos = width + 30;
            obstacles.push({
                x: xPos,
                y: GROUND_Y - 20,   // шип на земле
                width: 28,
                height: 28,
                type: type,
                active: true
            });
        }
        
        function spawnCoin(nowTime) {
            const xPos = width + 40;
            // монета чуть выше земли
            const yPos = GROUND_Y - 38;
            coins.push({
                x: xPos,
                y: yPos,
                width: 20,
                height: 20,
                collected: false
            });
        }
        
        // ---- Сброс игры (без жестокости, только учебный процесс) ----
        function restartGame() {
            gameActive = true;
            victory = false;
            coinsCollected = 0;
            distance = 0;
            worldOffset = 0;
            currentSpeed = baseSpeed;
            gameTime = 0;
            lastObstacleSpawn = 0;
            lastCoinSpawn = 0;
            obstacles = [];
            coins = [];
            
            player.y = GROUND_Y - PLAYER_SIZE;
            player.vy = 0;
            player.isGrounded = true;
            jumpFlash = 0;
            
            updateUI();
            
            // начальные объекты для динамики (спавним пару монет и первый шип через 0.6 сек)
            setTimeout(() => {
                if(gameActive && !victory) {
                    if(obstacles.length === 0) spawnObstacle(gameTime);
                    if(coins.length < 2) spawnCoin(gameTime);
                }
            }, 200);
        }
        
        // ---- Прыжок ----
        function jump() {
            if(!gameActive) return;
            if(victory) return;
            // игрок касается земли
            if(player.y >= GROUND_Y - PLAYER_SIZE - 1 && player.vy >= -50) {
                player.vy = JUMP_FORCE;
                player.isGrounded = false;
                jumpFlash = 0.15;
                // весёлый звуковой эффект (без звука, просто визуально)
            }
        }
        
        // ---- Обновление физики и столкновений ----
        function updateGame(deltaTime) {
            if(!gameActive) return;
            if(victory) return;
            
            // ограничим дельту
            let dt = Math.min(deltaTime, 0.033);
            
            // 1. гравитация и движение игрока
            player.vy += GRAVITY * dt;
            player.y += player.vy * dt;
            
            // коллизия с землёй
            if(player.y >= GROUND_Y - PLAYER_SIZE) {
                player.y = GROUND_Y - PLAYER_SIZE;
                player.vy = 0;
                player.isGrounded = true;
            }
            if(player.y < 0) {
                player.y = 0;
                if(player.vy < 0) player.vy = 0;
            }
            
            // 2. движение мира (скорость)
            let scrollDelta = currentSpeed * dt;
            worldOffset += scrollDelta;
            distance += scrollDelta * 0.1;  // очки дистанции
            
            // 3. движение объектов и удаление за экраном
            for(let i=0; i<obstacles.length; i++) {
                obstacles[i].x -= scrollDelta;
            }
            for(let i=0; i<coins.length; i++) {
                coins[i].x -= scrollDelta;
            }
            
            // удалить вышедшие за левый край
            obstacles = obstacles.filter(obs => obs.x + obs.width > 0);
            coins = coins.filter(c => c.x + c.width > 0 && !c.collected);
            
            // 4. СПАВН: препятствия (шипы) с интервалом
            gameTime += dt;
            let nextObstacleGap = 1.2; // сек
            if(gameTime - lastObstacleSpawn > nextObstacleGap) {
                lastObstacleSpawn = gameTime;
                // не спавним слишком много
                if(obstacles.length < 4) {
                    spawnObstacle(gameTime);
                }
            }
            
            // спавн монет чаще
            let coinGap = 0.85;
            if(gameTime - lastCoinSpawn > coinGap && coins.length < 5) {
                lastCoinSpawn = gameTime;
                spawnCoin(gameTime);
            }
            
            // 5. СТОЛКНОВЕНИЕ С ПРЕПЯТСТВИЯМИ (шипы)
            const playerRect = {
                x: player.x,
                y: player.y,
                w: PLAYER_SIZE,
                h: PLAYER_SIZE
            };
            
            for(let i=0; i<obstacles.length; i++) {
                const obs = obstacles[i];
                const obsRect = {
                    x: obs.x,
                    y: obs.y,
                    w: obs.width,
                    h: obs.height
                };
                if(playerRect.x < obsRect.x + obsRect.w &&
                    playerRect.x + playerRect.w > obsRect.x &&
                    playerRect.y < obsRect.y + obsRect.h &&
                    playerRect.y + playerRect.h > obsRect.y) {
                    // столкновение с шипом — проигрыш
                    gameActive = false;
                    return;
                }
            }
            
            // 6. СБОР МОНЕТ
            for(let i=0; i<coins.length; i++) {
                const coin = coins[i];
                if(coin.collected) continue;
                const coinRect = {
                    x: coin.x,
                    y: coin.y,
                    w: coin.width,
                    h: coin.height
                };
                if(playerRect.x < coinRect.x + coinRect.w &&
                    playerRect.x + playerRect.w > coinRect.x &&
                    playerRect.y < coinRect.y + coinRect.h &&
                    playerRect.y + playerRect.h > coinRect.y) {
                    coin.collected = true;
                    coinsCollected++;
                    distance += 25;   // бонус за монету
                    updateUI();
                    
                    // маленькая вспышка успеха
                    jumpFlash = 0.1;
                    
                    // ПОБЕДА при 10 монетах
                    if(coinsCollected >= 10) {
                        victory = true;
                        gameActive = false; // замораживаем активность
                        return;
                    }
                }
            }
            
            // постепенно увеличиваем скорость для сложности (max 650)
            if(currentSpeed < 650) {
                currentSpeed += 15 * dt;
                if(currentSpeed > 650) currentSpeed = 650;
            }
            
            // динамическое обновление счёта
            updateUI();
        }
        
        // ---- Отрисовка всего (яркая, дружелюбная) ----
        function draw() {
            ctx.clearRect(0, 0, width, height);
            
            // 1. НЕБО и ФОН (градиент)
            const gradSky = ctx.createLinearGradient(0, 0, 0, height);
            gradSky.addColorStop(0, "#0f2e4f");
            gradSky.addColorStop(0.7, "#20507a");
            ctx.fillStyle = gradSky;
            ctx.fillRect(0, 0, width, height);
            
            // облачка (декор)
            ctx.fillStyle = "#cceeff88";
            ctx.shadowBlur = 0;
            ctx.beginPath();
            ctx.ellipse(120 + (worldOffset * 0.2) % 400, 55, 45, 35, 0, 0, Math.PI*2);
            ctx.ellipse(480 + (worldOffset * 0.15) % 600, 80, 55, 40, 0, 0, Math.PI*2);
            ctx.fill();
            
            // земля (травянистая)
            ctx.fillStyle = "#4c8b5e";
            ctx.fillRect(0, GROUND_Y - 8, width, 12);
            ctx.fillStyle = "#6aa67a";
            ctx.fillRect(0, GROUND_Y - 4, width, 8);
            ctx.fillStyle = "#3d6b4a";
            ctx.fillRect(0, GROUND_Y, width, height - GROUND_Y + 5);
            
            // линия травы
            ctx.fillStyle = "#b0d68a";
            for(let i=0; i<15; i++) {
                ctx.fillRect(i*70 + (worldOffset*2)%70, GROUND_Y-12, 4, 12);
            }
            
            // 2. РИСУЕМ МОНЕТЫ (блестящие)
            for(let coin of coins) {
                if(coin.collected) continue;
                ctx.save();
                ctx.shadowBlur = 6;
                ctx.shadowColor = "#f5bc70";
                ctx.beginPath();
                ctx.arc(coin.x + coin.width/2, coin.y + coin.height/2, 12, 0, Math.PI*2);
                ctx.fillStyle = "#ffd966";
                ctx.fill();
                ctx.beginPath();
                ctx.arc(coin.x + coin.width/2, coin.y + coin.height/2, 8, 0, Math.PI*2);
                ctx.fillStyle = "#ffaa33";
                ctx.fill();
                ctx.fillStyle = "#ffec80";
                ctx.font = "bold 16 monospace";
                ctx.fillText("🪙", coin.x+3, coin.y+16);
                ctx.restore();
            }
            
            // 3. РИСУЕМ ПРЕПЯТСТВИЯ (шипы, но в стиле Geometry Dash - треугольники)
            for(let obs of obstacles) {
                ctx.fillStyle = "#d9433e";
                ctx.shadowBlur = 3;
                ctx.beginPath();
                // шип - треугольник вверх
                const leftX = obs.x;
                const baseY = obs.y + obs.height;
                ctx.moveTo(leftX + obs.width/2, obs.y);
                ctx.lineTo(leftX, baseY);
                ctx.lineTo(leftX + obs.width, baseY);
                ctx.fill();
                ctx.fillStyle = "#aa2e2a";
                ctx.beginPath();
                ctx.moveTo(leftX + obs.width/2, obs.y+4);
                ctx.lineTo(leftX+6, baseY-2);
                ctx.lineTo(leftX+obs.width-6, baseY-2);
                ctx.fill();
                // глаза на шипах для "дружелюбного" вида? нет, просто предупреждение
                ctx.fillStyle = "#f08855";
                ctx.fillRect(obs.x+7, obs.y+12, 5, 5);
                ctx.fillRect(obs.x+16, obs.y+12, 5, 5);
            }
            
            // 4. ИГРОК (куб Geometry Dash с динамикой)
            ctx.shadowBlur = 8;
            ctx.shadowColor = "#00000066";
            // эффект прыжка / вспышка
            if(jumpFlash > 0) {
                ctx.fillStyle = "#fffbb0";
                ctx.shadowBlur = 14;
            } else {
                ctx.fillStyle = "#42c5f0";
            }
            ctx.fillRect(player.x, player.y, PLAYER_SIZE, PLAYER_SIZE);
            // лицо куба (весёлое)
            ctx.fillStyle = "#ffffff";
            ctx.fillRect(player.x+8, player.y+10, 6, 6);
            ctx.fillRect(player.x+18, player.y+10, 6, 6);
            ctx.fillStyle = "#231f1b";
            ctx.fillRect(player.x+9, player.y+12, 4, 4);
            ctx.fillRect(player.x+19, player.y+12, 4, 4);
            ctx.fillStyle = "#f4ac42";
            ctx.beginPath();
            ctx.arc(player.x+16, player.y+24, 6, 0, Math.PI);
            ctx.fill();
            
            // динамическая улыбка
            if(player.isGrounded) {
                ctx.fillStyle = "#a5642e";
                ctx.fillRect(player.x+10, player.y+26, 12, 3);
            } else {
                ctx.fillStyle = "#ef7e3a";
                ctx.beginPath();
                ctx.arc(player.x+16, player.y+26, 5, 0.1, Math.PI - 0.1);
                ctx.fill();
            }
            
            // частицы при прыжке
            if(jumpFlash > 0) {
                for(let i=0;i<6;i++) {
                    ctx.fillStyle = `rgba(255,240,100,${jumpFlash*0.8})`;
                    ctx.fillRect(player.x-5+i*4, player.y+PLAYER_SIZE-4, 3, 6);
                }
                jumpFlash -= 0.02;
            }
            
            // 5. ОЧКИ И СЧЁТ НА ЭКРАНЕ
            ctx.font = "bold 24px 'Courier New'";
            ctx.fillStyle = "#fff6d0";
            ctx.shadowBlur = 3;
            ctx.fillText(`⚡ ${Math.floor(distance)}`, width-130, 55);
            ctx.font = "bold 18px monospace";
            ctx.fillStyle = "#ffda99";
            ctx.fillText(`СКОРОСТЬ: ${Math.floor(currentSpeed-300)}%`, width-150, 100);
            
            // 6. ПОБЕДА
            if(victory) {
                ctx.font = "900 42monospace";
                ctx.fillStyle = "#ffe699";
                ctx.shadowBlur = 12;
                ctx.fillText("★ ПОБЕДА! ★", width/2-130, height/2-45);
                ctx.font = "20px monospace";
                ctx.fillStyle = "#f5cb7e";
                ctx.fillText("Ты собрал 10 монет! Нажми НОВЫЙ ЗАБЕГ", width/2-210, height/2+20);
            } else if(!gameActive && !victory) {
                ctx.font = "900 38monospace";
                ctx.fillStyle = "#ffac9e";
                ctx.fillText("GAME OVER", width/2-110, height/2-40);
                ctx.font = "18px monospace";
                ctx.fillStyle = "#ffcf9a";
                ctx.fillText("Нажми кнопку перезапуска", width/2-140, height/2+25);
            }
            
            // индикация монет на экране
            ctx.font = "bold 20px monospace";
            ctx.fillStyle = "#fad974";
            ctx.fillText(`🪙 x ${coinsCollected} / 10`, 22, 52);
            
            // простой туториал (подсказка)
            if(gameActive && !victory && coinsCollected === 0 && distance < 150) {
                ctx.font = "14px monospace";
                ctx.fillStyle = "#caf0ff";
                ctx.fillText("🔹 Нажми ПРОБЕЛ, чтобы прыгать! Избегай шипов 🔹", width/2-200, 65);
            }
        }
        
        function updateUI() {
            document.getElementById('coinCounter').innerText = coinsCollected;
            let displayScore = Math.floor(distance) + (coinsCollected * 25);
            document.getElementById('scoreCounter').innerText = displayScore;
        }
        
        // ---- ГЛАВНЫЙ ЦИКЛ ----
        let lastFrame = 0;
        function gameLoop(nowMs) {
            if(!lastFrame) lastFrame = nowMs;
            let delta = Math.min(0.033, (nowMs - lastFrame) / 1000);
            if(delta <= 0.01) {
                lastFrame = nowMs;
                draw();
                requestAnimationFrame(gameLoop);
                return;
            }
            lastFrame = nowMs;
            
            if(gameActive && !victory) {
                updateGame(delta);
            }
            draw();
            requestAnimationFrame(gameLoop);
        }
        
        // ---- Обработка ВВОДА (безопасные события) ----
        function handleJump(e) {
            // предотвращаем прокрутку страницы и случайные клики
            if(e.type === 'keydown') {
                if(e.code === 'Space' || e.code === 'ArrowUp') {
                    e.preventDefault();
                    jump();
                }
                // клавиша R для рестарта (дополнительно)
                if(e.code === 'KeyR') {
                    e.preventDefault();
                    restartGame();
                }
            } else if(e.type === 'click') {
                // клик по canvas — прыжок
                if(e.target === canvas || canvas.contains(e.target)) {
                    e.preventDefault();
                    jump();
                }
            }
        }
        
        function attachEvents() {
            window.addEventListener('keydown', handleJump);
            canvas.addEventListener('click', (e) => {
                e.preventDefault();
                jump();
            });
            // блокируем контекстное меню на канвасе
            canvas.addEventListener('contextmenu', (e) => e.preventDefault());
            document.getElementById('resetBtn').addEventListener('click', () => {
                restartGame();
            });
        }
        
        // ---- ИНИЦИАЛИЗАЦИЯ ----
        function init() {
            restartGame();
            attachEvents();
            gameLoop(0);
        }
        
        init();
    })();
</script>
</body>
</html>
```
