--[[
TÍTULO: Servidor de Matchmaking y Terror "WhatsApp del Terror"
UBICACIÓN: ServerScriptService
 
ESTE SCRIPT GESTIONA LA LÓGICA DE SALAS, MATCHMAKING, CHAT Y EL TERROR DEL DESCONOCIDO.
--]]
 
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService") -- Asegurar que HttpService esté disponible
 
--------------------------------------------------------------------------------
-- 1. CONFIGURACIÓN INICIAL: CREACIÓN DE REMOTE EVENTS
--------------------------------------------------------------------------------
 
-- Función para crear o encontrar un RemoteEvent
local function setupRemote(name)
    local remote = ReplicatedStorage:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = ReplicatedStorage
    end
    return remote
end
 
-- REMOTES ACTUALIZADOS PARA GESTIÓN DE SALAS
local RoomListRequest = setupRemote("RoomListRequest") -- Cliente -> Servidor (Pedir lista de salas)
local RoomAction = setupRemote("RoomAction")           -- Cliente -> Servidor (Crear/Unirse)
local MessageSend = setupRemote("MessageSend")         -- Cliente -> Servidor (Enviar chat)
local ReportUser = setupRemote("ReportUser")           -- Cliente -> Servidor (Reportar)
local ClientUpdate = setupRemote("ClientUpdate")       -- Servidor -> Cliente (Actualizaciones)
 
--------------------------------------------------------------------------------
-- 2. VARIABLES Y ESTADO DEL JUEGO (MODIFICADO PARA SALAS)
--------------------------------------------------------------------------------
 
-- { [RoomId] = {HostId, GuestId, Status="Waiting"/"Chatting", HostName, GuestName, CreatedAt=tick()} }
local Rooms = {} 
 
-- Mapeo rápido: { [UserId] = RoomId }
local PlayerRoomMap = {} 
 
-- { [PlayerId1] = PlayerId2, [PlayerId2] = PlayerId1 } (Ambos son UserIds)
local ActiveSessions = {} 
 
-- Lista de mensajes de terror para el "Desconocido"
local UnknownMessages = {
"¿Están seguros de que son solo ustedes dos? Miren bien el chat.",
"Les dije que no debían iniciar ese chat. Ahora es muy tarde.",
"Puedo verlos a través de sus pantallas. Sus caras están asustadas.",
"Su compañero miente. Yo estoy más cerca que él/ella.",
"El mensaje anterior NO lo escribió tu amigo. Fui yo.",
"El tiempo se agota. La batería no durará para siempre.",
"No te fíes del silencio. Nunca es silencio.",
"Deja de escribir. Cierra el chat. AHORA.",
"¿Ves esa sombra detrás de ti?",
}
 
--------------------------------------------------------------------------------
-- 3. FUNCIONES DE SERVIDOR
--------------------------------------------------------------------------------
 
-- Genera un ID de sala simple
local function getRoomId()
    return "room_" .. tostring(math.random(10000, 99999))
end
 
-- Notifica a un cliente con un estado y datos
local function notifyClient(player, status, partnerName, message)
    local success, err = pcall(function()
        -- El tercer argumento siempre es el nombre del remitente (o partner), 
        -- y el cuarto es el mensaje o, en el caso de "Connected", el UserID del compañero.
        ClientUpdate:FireClient(player, status, partnerName or "", message or "")
    end)
    if not success then
        warn("Error al notificar al cliente " .. player.Name .. " (" .. status .. "): " .. tostring(err))
    end
end

-- Limpia una sala específica y notifica si el compañero está presente
local function cleanupRoom(roomId, disconnectingUserId)
    local room = Rooms[roomId]
    if not room then return end
    
    local hostId = room.HostId
    local guestId = room.GuestId
    
    local partnerId = nil
    
    -- Determinar quién se va y quién queda
    if hostId == disconnectingUserId then
        partnerId = guestId
    elseif guestId == disconnectingUserId then
        partnerId = hostId
    end
    
    local partner = Players:GetPlayerByUserId(partnerId)
    
    if room.Status == "Chatting" then
        -- Limpiar ActiveSessions
        ActiveSessions[hostId] = nil
        ActiveSessions[guestId] = nil
        
        -- Si queda un compañero, notificarle que ha sido desconectado
        if partner then
            notifyClient(partner, "Disconnected", nil, "Tu compañero se ha desconectado.")
        end
        
        -- La sala de chat se elimina
        Rooms[roomId] = nil
        
    elseif room.Status == "Waiting" then
        -- Si era el Host que se iba y había un Guest (aunque GuestId debería ser nil si está Waiting, 
        -- este bloque maneja la situación por seguridad si se unen rápidamente y el host sale)
        
        if partner and partnerId == guestId then
            -- Si el que se fue era el Host y el Guest queda, el Guest toma la sala.
            room.HostId = guestId
            room.HostName = partner.Name
            room.GuestId = nil
            room.GuestName = nil
            -- Notificar al nuevo Host que ahora está esperando
            notifyClient(partner, "RoomStatusUpdate", "HostWaiting", room.HostName)
            
        else
            -- Si la sala queda totalmente vacía
            Rooms[roomId] = nil
        end
    end
    
    -- Limpiar mapeo
    PlayerRoomMap[hostId] = nil
    PlayerRoomMap[guestId] = nil
    
    -- Forzar una actualización de la lista de salas para todos los clientes
    RoomListRequest:FireAllClients("Update") 
end
 
-- Lógica para la acción de sala (Crear o Unirse)
RoomAction.OnServerEvent:Connect(function(player, action, roomId)
    local userId = player.UserId
    local playerName = player.Name
    
    if PlayerRoomMap[userId] then 
        warn(string.format("[SERVER] %s ya está en una sala: %s. Ignorando acción %s.", playerName, PlayerRoomMap[userId], action))
        return 
    end
    
    if action == "Create" then
        local newId = getRoomId()
        Rooms[newId] = {
        HostId = userId,
        HostName = playerName,
        GuestId = nil,
        GuestName = nil,
        Status = "Waiting",
        CreatedAt = tick(),
        NextUnknownTime = 0 -- Se inicializa al entrar al chat
        }
        PlayerRoomMap[userId] = newId
        print(string.format("[SERVER] Sala creada: %s por %s", newId, playerName))
        -- El mensaje es el HostName, el cliente lo usa para el mensaje de espera
        notifyClient(player, "RoomStatusUpdate", "HostWaiting", playerName) 
        RoomListRequest:FireAllClients("Update") -- Actualizar lista
        
    elseif action == "Join" and roomId and Rooms[roomId] and Rooms[roomId].Status == "Waiting" then
        local room = Rooms[roomId]
        
        -- Si el jugador intenta unirse a su propia sala (que no debería ocurrir con la UI)
        if room.HostId == userId then 
            notifyClient(player, "Disconnected", nil, "No puedes unirte a tu propia sala.") -- Feedback al cliente
            return 
        end
        
        -- ¡Match encontrado!
        room.GuestId = userId
        room.GuestName = playerName
        room.Status = "Chatting"
        PlayerRoomMap[userId] = roomId
        
        local partner = Players:GetPlayerByUserId(room.HostId)
        
        if partner then
            print(string.format("[SERVER] MATCH HECHO en %s: %s y %s", roomId, room.HostName, room.GuestName))
            
            -- Establecer sesión usando UserIds
            ActiveSessions[room.HostId] = room.GuestId
            ActiveSessions[room.GuestId] = room.HostId
            
            -- Inicializar timer de terror
            room.NextUnknownTime = tick() + math.random(25, 45) 
            
            -- Notificar a ambos clientes que están conectados. 
            -- message = UserID del compañero
            notifyClient(player, "Connected", room.HostName, tostring(room.HostId)) 
            notifyClient(partner, "Connected", room.GuestName, tostring(room.GuestId))
            
            RoomListRequest:FireAllClients("Update") -- Actualizar lista
        else
            -- Si el host se desconectó
            warn("[SERVER] Intento de unirse a sala cuyo host se desconectó. Limpiando sala.")
            cleanupRoom(roomId, room.HostId)
            -- Darle la sala al nuevo jugador si es posible, o notificar error. Aquí lo volvemos al RoomSelect.
            notifyClient(player, "Disconnected", nil, "El host se desconectó justo antes de unirte.")
        end
        
    end
end)
 
-- Lógica para solicitar la lista de salas disponibles
RoomListRequest.OnServerEvent:Connect(function(player)
    local availableRooms = {}
    
    -- Solo enviar salas en estado "Waiting"
    for id, roomData in pairs(Rooms) do
        if roomData.Status == "Waiting" and Players:GetPlayerByUserId(roomData.HostId) then
            table.insert(availableRooms, {
            Id = id,
            HostName = roomData.HostName,
            -- Debería ser siempre 1 si es "Waiting", pero por seguridad lo mantenemos.
            PlayerCount = 1, 
            Status = roomData.Status
            })
        end
    end
    
    -- Convertir a JSON string para enviarlo como un solo mensaje
    local jsonRooms = HttpService:JSONEncode(availableRooms)
    notifyClient(player, "RoomListUpdate", "Rooms", jsonRooms)
end)
 
-- Lógica para manejar mensajes de chat entre jugadores
MessageSend.OnServerEvent:Connect(function(player, message)
    -- Sanear mensaje
    if not message or message:match("^%s*$") then return end
    
    local senderId = player.UserId
    local receiverId = ActiveSessions[senderId]
    
    -- 1. Envía el mensaje de vuelta al remitente (para que lo muestre)
    notifyClient(player, "NewMessage", player.Name, message)
    
    if receiverId then
        local receiver = Players:GetPlayerByUserId(receiverId)
        
        if receiver then
            -- 2. Envía el mensaje al compañero
            notifyClient(receiver, "NewMessage", player.Name, message)
        end
    end
end)
 
-- Lógica para reportar un usuario
ReportUser.OnServerEvent:Connect(function(player, reportedPlayerName, reason)
    local reporterName = player.Name
    print(string.format("[REPORTE] %s ha reportado a %s por la razón: %s", reporterName, reportedPlayerName, reason))
    
    -- Enviar confirmación al cliente
    notifyClient(player, "ReportSent", nil) 
end)
 
 
-- Lógica del temporizador de mensajes del "Desconocido"
local function handleUnknownMessages(room)
    local player1 = Players:GetPlayerByUserId(room.HostId)
    local player2 = Players:GetPlayerByUserId(room.GuestId)
    
    if player1 and player2 and room.Status == "Chatting" and tick() >= room.NextUnknownTime then
        local message = UnknownMessages[math.random(1, #UnknownMessages)]
        
        print(string.format("[TERROR] Mensaje de Desconocido enviado en sala %s (Host: %s, Guest: %s)", room.HostId, room.HostName, room.GuestName))
        
        -- Se usa el nombre "Desconocido" para que el cliente aplique el sonido de terror
        notifyClient(player1, "NewMessage", "Desconocido", message)
        notifyClient(player2, "NewMessage", "Desconocido", message)
        
        -- Restablecer temporizador con nuevo intervalo
        local duration = math.random(25, 45)
        room.NextUnknownTime = tick() + duration
    end
end
 
-- Bucle principal del servidor
RunService.Stepped:Connect(function()
    for _, room in pairs(Rooms) do
        if room.Status == "Chatting" then
            handleUnknownMessages(room)
        end
    end
end)
 
-- Limpieza de sesiones al salir un jugador
Players.PlayerRemoving:Connect(function(player)
    local userId = player.UserId
    local roomId = PlayerRoomMap[userId]
    
    if roomId then
        cleanupRoom(roomId, userId)
    end
    
    -- Limpiar ActiveSessions si no fue cubierto por cleanupRoom (seguro extra)
    local partnerId = ActiveSessions[userId]
    if partnerId then
        ActiveSessions[userId] = nil
        ActiveSessions[partnerId] = nil
        local partner = Players:GetPlayerByUserId(partnerId)
        if partner then
            notifyClient(partner, "Disconnected", nil, "Tu compañero se ha desconectado.")
        end
    end
    
    PlayerRoomMap[userId] = nil
end)

print("Servidor de Matchmaking y Terror iniciado correctamente.")

