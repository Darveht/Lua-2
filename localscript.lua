--[[
TÍTULO: Cliente de Chat "WhatsApp del Terror"
UBICACIÓN: StarterPlayer/StarterPlayerScripts

ESTE SCRIPT GESTIONA LA INTERFAZ DE USUARIO (INTRO, SALAS, CHAT),
LA COMUNICACIÓN CON EL SERVIDOR Y MANEJA LOS EFECTOS DE SONIDO.

¡ARREGLO CRÍTICO IMPLEMENTADO!
1. Se eliminó la dependencia de RemoteEvent 'MatchRequest' que causaba el fallo de ejecución.
2. Se verificó y aseguró la lógica de la interfaz y la gestión de salas.
--]]

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local task = task or game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- RemoteEvents (Accedidos de forma segura, el servidor ya los habrá creado)
local RoomListRequest = ReplicatedStorage:WaitForChild("RoomListRequest") 
local RoomAction = ReplicatedStorage:WaitForChild("RoomAction")         
local MessageSend = ReplicatedStorage:WaitForChild("MessageSend")   
local ReportUser = ReplicatedStorage:WaitForChild("ReportUser")     
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate") 

--------------------------------------------------------------------------------
-- 1. CONFIGURACIÓN DE SONIDOS 
--------------------------------------------------------------------------------

-- Roblox Asset IDs para los sonidos
local SOUND_IDS = {
-- 1. Música de Fondo del Intro (Bucle)
IntroMusic = "rbxassetid://9043360237", 
-- 2. Confirmación de Conexión (One-shot)
Connected = "rbxassetid://94059490149743", 
-- 3. Efecto de Escritura
Typing = "rbxassetid://127105730240202",
-- 4. Mensaje Enviado
MessageSent = "rbxassetid://5485567028", 
-- 5. Mensaje Recibido
MessageReceived = "rbxassetid://93931612588862", 
-- 6. Desconocido Entra/Mensaje (Terror)
UnknownEnter = "rbxassetid://130976109",
-- 7. Sonido de Like/Doble Click
Like = "rbxassetid://17520503095",
}

-- ARREGLO DE SONIDO: Se adjunta SoundFolder a PlayerGui para mayor fiabilidad
local SoundFolder = Instance.new("Folder")
SoundFolder.Name = "ClientSounds"
SoundFolder.Parent = PlayerGui 

local sounds = {}
for name, id in pairs(SOUND_IDS) do
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = id
    if name == "IntroMusic" then
        sound.Looped = true
        sound.Volume = 0.5 
    elseif name == "Typing" then
        sound.Volume = 0.4
    elseif name == "Like" then 
        sound.Volume = 0.8
    else
        sound.Volume = 1.0
    end
    sound.Parent = SoundFolder
    sounds[name] = sound
end

local function playSound(name)
    local sound = sounds[name]
    if sound and sound.SoundId ~= "" then
        -- Esperar a que cargue si no lo está
        if not sound.IsLoaded then
            sound.Loaded:Wait()
        end
        
        -- Detener y rebobinar si no está en bucle
        if not sound.Looped and sound.IsPlaying then
            sound:Stop()
        end
        
        sound:Play()
    end
end

--------------------------------------------------------------------------------
-- 2. CONFIGURACIÓN DE ESTILOS Y ESTADO LOCAL
--------------------------------------------------------------------------------

local UI_SIZE = UDim2.new(1, 0, 1, 0)
local CHAT_BG_COLOR = Color3.fromRGB(15, 15, 15)
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local ACCENT_COLOR = Color3.fromRGB(0, 150, 136)
local MY_MESSAGE_COLOR = Color3.fromRGB(0, 70, 70)
local PARTNER_MESSAGE_COLOR = Color3.fromRGB(40, 40, 40)
local UNKNOWN_MESSAGE_COLOR = Color3.fromRGB(130, 0, 0)
local FONT_STYLE = Enum.Font.SourceSans
local FONT_SIZE = 18

local currentPartnerName = nil 
local currentPartnerId = nil 
local currentScreen = "Intro"
local currentRoomId = nil -- Para saber en qué sala está el jugador (solo si es HostWaiting)
local lastClickTime = 0 
local DOUBLE_CLICK_TIME = 0.3 
local lastTypingSoundTime = 0 
local TYPING_THROTTLE = 0.05 

--------------------------------------------------------------------------------
-- 3. CONSTRUCCIÓN DE LA UI PRINCIPAL 
--------------------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HorrorChatGui"
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UI_SIZE
MainFrame.Position = UDim2.new(0, 0, 0, 0)
MainFrame.BackgroundColor3 = CHAT_BG_COLOR
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- ** 3.1. Encabezado del Chat (Con Icono de Perfil) **
local ChatHeader = Instance.new("Frame")
ChatHeader.Name = "ChatHeader"
ChatHeader.Size = UDim2.new(1, 0, 0.08, 0)
ChatHeader.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ChatHeader.BorderSizePixel = 0
ChatHeader.Visible = false
ChatHeader.Parent = MainFrame

local ProfileButton = Instance.new("ImageButton")
ProfileButton.Name = "ProfileButton"
ProfileButton.Size = UDim2.new(0, 50, 0, 50)
ProfileButton.Position = UDim2.new(0, 15, 0.5, 0)
ProfileButton.AnchorPoint = Vector2.new(0, 0.5)
ProfileButton.BackgroundTransparency = 1
ProfileButton.Image = "rbxassetid://13426021678" 
ProfileButton.ScaleType = Enum.ScaleType.Fit
ProfileButton.Parent = ChatHeader
Instance.new("UICorner", ProfileButton).CornerRadius = UDim.new(0.5, 0)

local TextContainer = Instance.new("Frame")
TextContainer.Size = UDim2.new(0.6, 0, 1, 0)
TextContainer.Position = UDim2.new(0, 80, 0, 0)
TextContainer.BackgroundTransparency = 1
TextContainer.Parent = ChatHeader

local HeaderText = Instance.new("TextLabel")
HeaderText.Name = "HeaderText"
HeaderText.Size = UDim2.new(1, 0, 0.6, 0)
HeaderText.Text = "WhatsApp del Terror"
HeaderText.TextColor3 = TEXT_COLOR
HeaderText.TextSize = 24
HeaderText.Font = Enum.Font.SourceSansBold
HeaderText.BackgroundTransparency = 1
HeaderText.TextXAlignment = Enum.TextXAlignment.Left
HeaderText.TextYAlignment = Enum.TextYAlignment.Center
HeaderText.Parent = TextContainer

local StatusText = Instance.new("TextLabel")
StatusText.Name = "StatusText"
StatusText.Size = UDim2.new(1, 0, 0.4, 0)
StatusText.Position = UDim2.new(0, 0, 0.6, 0)
StatusText.Text = "En línea"
StatusText.TextColor3 = ACCENT_COLOR
StatusText.TextSize = 16
StatusText.Font = FONT_STYLE
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = TextContainer

-- ** 3.2. Panel de Mensajes (Scroller) **
local ChatScroller = Instance.new("ScrollingFrame")
ChatScroller.Name = "ChatScroller"
ChatScroller.Size = UDim2.new(1, 0, 0.84, 0) 
ChatScroller.Position = UDim2.new(0, 0, 0.08, 0)
ChatScroller.BackgroundColor3 = CHAT_BG_COLOR
ChatScroller.BorderSizePixel = 0
ChatScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
ChatScroller.ScrollBarImageColor3 = ACCENT_COLOR
ChatScroller.Visible = false
ChatScroller.Parent = MainFrame

local ScrollerPadding = Instance.new("UIPadding")
ScrollerPadding.Name = "ScrollerPadding"
ScrollerPadding.PaddingTop = UDim.new(0, 10)
ScrollerPadding.PaddingBottom = UDim.new(0, 10)
ScrollerPadding.PaddingLeft = UDim.new(0, 10)
ScrollerPadding.PaddingRight = UDim.new(0, 10)
ScrollerPadding.Parent = ChatScroller

local MessageLayout = Instance.new("UIListLayout")
MessageLayout.Name = "MessageLayout"
MessageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left 
MessageLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
MessageLayout.SortOrder = Enum.SortOrder.LayoutOrder
MessageLayout.Padding = UDim.new(0, 10)
MessageLayout.Parent = ChatScroller

-- ** 3.3. Panel de Entrada de Texto **
local ChatInputFrame = Instance.new("Frame")
ChatInputFrame.Name = "ChatInputFrame"
ChatInputFrame.Size = UDim2.new(1, 0, 0.08, 0)
ChatInputFrame.Position = UDim2.new(0, 0, 0.92, 0)
ChatInputFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ChatInputFrame.BorderSizePixel = 0
ChatInputFrame.Visible = false
ChatInputFrame.Parent = MainFrame

local InputBox = Instance.new("TextBox")
InputBox.Name = "InputBox"
InputBox.Size = UDim2.new(0.8, -15, 0.6, 0)
InputBox.Position = UDim2.new(0.05, 0, 0.5, 0)
InputBox.AnchorPoint = Vector2.new(0, 0.5)
InputBox.PlaceholderText = "Escribe un mensaje..."
InputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
InputBox.TextColor3 = TEXT_COLOR
InputBox.TextSize = FONT_SIZE
InputBox.Font = FONT_STYLE
InputBox.Parent = ChatInputFrame

local SendButton = Instance.new("TextButton")
SendButton.Name = "SendButton"
SendButton.Size = UDim2.new(0.15, 0, 0.6, 0)
SendButton.Position = UDim2.new(0.95, 0, 0.5, 0)
SendButton.AnchorPoint = Vector2.new(1, 0.5)
SendButton.Text = "Enviar"
SendButton.BackgroundColor3 = ACCENT_COLOR
SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SendButton.TextSize = FONT_SIZE
SendButton.Font = FONT_STYLE
SendButton.Parent = ChatInputFrame

Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 15)
Instance.new("UICorner", SendButton).CornerRadius = UDim.new(0, 15)

--------------------------------------------------------------------------------
-- 4. FUNCIONES Y PANTALLAS PRINCIPALES
--------------------------------------------------------------------------------

local function createReactionEffect(messageBubble, isMe)
    local heart = Instance.new("TextLabel")
    heart.Size = UDim2.new(0, 40, 0, 40)
    heart.Text = "❤️"
    heart.TextSize = 30
    heart.BackgroundTransparency = 1
    heart.ZIndex = 5 
    
    local bubblePosition = messageBubble.AbsolutePosition
    local bubbleSize = messageBubble.AbsoluteSize
    heart.Position = UDim2.new(0, bubblePosition.X + (isMe and bubbleSize.X * 0.1 or bubbleSize.X * 0.9), 0, bubblePosition.Y)
    heart.AnchorPoint = Vector2.new(0.5, 1)
    
    heart.Parent = ScreenGui
    
    local tweenService = game:GetService("TweenService")
    local info = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
    -- Ajustar la posición Y de forma local al contenedor principal para que la animación funcione correctamente
    local goal = {Position = heart.Position - UDim2.new(0, 0, 0.15 * ScreenGui.AbsoluteSize.Y, 0), TextTransparency = 1} 
    
    local tween = tweenService:Create(heart, info, goal)
    tween:Play()
    
    Debris:AddItem(heart, 1.0)
    
    playSound("Like") 
end

local function handleDoubleClick(messageBubble, isMe)
    local currentTime = tick()
    if currentTime - lastClickTime < DOUBLE_CLICK_TIME then
        createReactionEffect(messageBubble, isMe)
        lastClickTime = 0
    else
        lastClickTime = currentTime
    end
end

-- Función para crear la etiqueta de texto del mensaje
local function createMessageText(parent, isUnknown)
    local MessageLabel = Instance.new("TextLabel")
    MessageLabel.Name = "MessageLabel"
    MessageLabel.Size = UDim2.new(1, 0, 0, 0) 
    MessageLabel.Text = ""
    MessageLabel.TextColor3 = TEXT_COLOR
    MessageLabel.TextSize = FONT_SIZE
    MessageLabel.Font = FONT_STYLE
    MessageLabel.BackgroundTransparency = 1
    MessageLabel.TextWrapped = true
    MessageLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    MessageLabel.AutomaticSize = Enum.AutomaticSize.Y
    
    if isUnknown then
        MessageLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
        MessageLabel.TextSize = FONT_SIZE + 2
        MessageLabel.Font = Enum.Font.SourceSansBold
    end
    
    local TextSizeConstraint = Instance.new("UISizeConstraint")
    TextSizeConstraint.MinSize = Vector2.new(0, 0)
    -- Limitar el ancho al 80% del Scroller
    TextSizeConstraint.MaxSize = Vector2.new(ChatScroller.AbsoluteSize.X * 0.8, math.huge) 
    TextSizeConstraint.Parent = MessageLabel
    
    MessageLabel.Parent = parent
    return MessageLabel
end

local function addMessage(senderName, messageText)
    local isMe = (senderName == Player.Name)
    local isUnknown = (senderName == "Desconocido")
    local timestamp = os.date("%H:%M")
    
    -- 1. Marco contenedor del mensaje (ocupa el 100% del ancho del Scroller)
    local MessageContainer = Instance.new("Frame")
    MessageContainer.Name = "MessageContainer"
    MessageContainer.BackgroundTransparency = 1
    MessageContainer.AutomaticSize = Enum.AutomaticSize.Y
    MessageContainer.Size = UDim2.new(1, 0, 0, 0) 
    MessageContainer.Parent = ChatScroller
    -- Usar LayoutOrder para asegurar el orden correcto al agregar
    MessageContainer.LayoutOrder = MessageLayout.AbsoluteContentSize.Y 
    
    local BubbleLayout = Instance.new("UIListLayout")
    BubbleLayout.HorizontalAlignment = isMe and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
    BubbleLayout.Padding = UDim.new(0, 0)
    BubbleLayout.Parent = MessageContainer
    
    -- 2. Burbuja de Contenido 
    local BubbleContent = Instance.new("Frame")
    BubbleContent.Name = "BubbleContent"
    
    BubbleContent.BackgroundColor3 = isMe and MY_MESSAGE_COLOR or (isUnknown and UNKNOWN_MESSAGE_COLOR or PARTNER_MESSAGE_COLOR)
    
    BubbleContent.AutomaticSize = Enum.AutomaticSize.XY 
    BubbleContent.Size = UDim2.new(0, 0, 0, 0)
    BubbleContent.Parent = MessageContainer
    
    Instance.new("UICorner", BubbleContent).CornerRadius = UDim.new(0, 10)
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.PaddingTop = UDim.new(0, 8)
    UIPadding.PaddingBottom = UDim.new(0, 8)
    UIPadding.PaddingLeft = UDim.new(0, 15)
    UIPadding.PaddingRight = UDim.new(0, 15)
    UIPadding.Parent = BubbleContent
    
    local UIList = Instance.new("UIListLayout")
    UIList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    UIList.Padding = UDim.new(0, -5)
    UIList.Parent = BubbleContent
    
    -- Mensaje del Sistema no tiene Sender Label
    if not isMe and senderName ~= "Sistema" and not isUnknown then
        local SenderLabel = Instance.new("TextLabel")
        SenderLabel.Size = UDim2.new(1, 0, 0, 18)
        SenderLabel.Text = senderName
        SenderLabel.TextColor3 = ACCENT_COLOR
        SenderLabel.TextSize = 14
        SenderLabel.Font = Enum.Font.SourceSansBold
        SenderLabel.BackgroundTransparency = 1
        SenderLabel.TextXAlignment = Enum.TextXAlignment.Left
        SenderLabel.Parent = BubbleContent
    end
    
    local MessageLabel = createMessageText(BubbleContent, isUnknown)
    MessageLabel.Text = messageText
    
    -- Frame para la hora 
    local TimeFrame = Instance.new("Frame")
    TimeFrame.Size = UDim2.new(1, 0, 0, 16)
    TimeFrame.BackgroundTransparency = 1
    TimeFrame.Parent = BubbleContent
    
    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Size = UDim2.new(0, 50, 1, 0)
    TimeLabel.Position = UDim2.new(1, -5, 0, 0)
    TimeLabel.AnchorPoint = Vector2.new(1, 0)
    TimeLabel.Text = timestamp
    TimeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    TimeLabel.TextSize = 12
    TimeLabel.Font = FONT_STYLE
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    TimeLabel.Parent = TimeFrame
    
    -- Conexión de Doble Click/Toque
    BubbleContent.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            handleDoubleClick(BubbleContent, isMe)
        end
    end)
    
    
    -- Asegurar el desplazamiento al final
    -- Usar un pequeño retraso para que el layout se actualice
    task.wait() 
    ChatScroller.CanvasSize = UDim2.new(0, 0, 0, MessageLayout.AbsoluteContentSize.Y + 20) 
    ChatScroller.CanvasPosition = Vector2.new(0, ChatScroller.CanvasSize.Offset.Y)
end

local function getProfilePicture(userId)
    -- Asegurar que userId sea numérico y válido
    if type(userId) ~= "number" or userId <= 0 then 
        return "rbxassetid://13426021678" -- Fallback placeholder
    end
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size100x100 
    local content, _ = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
    return content
end

local function switchScreen(state, partnerName, partnerId)
    currentScreen = state
    local IntroScreen = MainFrame:FindFirstChild("IntroScreen")
    local RoomSelectScreen = MainFrame:FindFirstChild("RoomSelectScreen") 
    local ProfileScreen = MainFrame:FindFirstChild("ProfileScreen")
    local ReportScreen = MainFrame:FindFirstChild("ReportScreen")
    
    local ChatScreenElements = {ChatHeader, ChatScroller, ChatInputFrame}
    
    -- Ocultar todo
    if IntroScreen then IntroScreen.Visible = false end
    if RoomSelectScreen then RoomSelectScreen.Visible = false end
    if ProfileScreen then ProfileScreen.Visible = false end
    if ReportScreen then ReportScreen.Visible = false end
    for _, element in pairs(ChatScreenElements) do element.Visible = false end
    
    -- Mostrar el estado deseado
    if state == "Intro" then
        if IntroScreen then IntroScreen.Visible = true end
        if IntroScreen and IntroScreen.PlayButton then
            IntroScreen.PlayButton.Text = "JUGAR (Buscar Sala)"
            IntroScreen.PlayButton.Active = true
        end
        
        -- Limpiar el chat cuando se vuelve al Intro
        for _, message in pairs(ChatScroller:GetChildren()) do
            if message:IsA("Frame") and message.Name == "MessageContainer" then
                message:Destroy()
            end
        end
        
        -- Reiniciar estados de sala/partida
        currentRoomId = nil
        
        -- Música del Intro/Espera
        playSound("IntroMusic")
        
    elseif state == "RoomSelect" then 
        if RoomSelectScreen then RoomSelectScreen.Visible = true end
        
        -- Música del Intro/Espera (asegurar que siga sonando)
        if not sounds.IntroMusic.IsPlaying then playSound("IntroMusic") end
        
        -- Solicitar lista de salas disponibles
        RoomListRequest:FireServer()
        
    elseif state == "HostWaiting" then 
        if RoomSelectScreen then 
            RoomSelectScreen.Visible = true 
            local WaitingLabel = RoomSelectScreen:FindFirstChild("WaitingLabel")
            if WaitingLabel then
                WaitingLabel.Text = "Sala Creada: Esperando a que alguien se una..."
            end
        end
        
        -- Música del Intro/Espera (asegurar que siga sonando)
        if not sounds.IntroMusic.IsPlaying then playSound("IntroMusic") end
        
    else
        -- Detener la música cuando se sale del intro/espera para entrar al chat
        if sounds.IntroMusic.IsPlaying then
            sounds.IntroMusic:Stop()
        end
    end
    
    if state == "Chat" then
        currentPartnerName = partnerName 
        currentPartnerId = partnerId
        
        for _, element in pairs(ChatScreenElements) do element.Visible = true end
        
        HeaderText.Text = partnerName or "Error"
        ProfileButton.Active = true 
        
        if partnerId and partnerId > 0 then
            -- Actualizar foto de perfil con el UserID
            ProfileButton.Image = getProfilePicture(partnerId)
        end
        
    elseif state == "Profile" then
        if ProfileScreen then ProfileScreen.Visible = true end
        
        if ProfileScreen and ProfileScreen.UsernameText then
            ProfileScreen.UsernameText.Text = currentPartnerName or "Usuario Desconocido"
        end
        
        if currentPartnerId and currentPartnerId > 0 and ProfileScreen and ProfileScreen.ProfileImage then
            ProfileScreen.ProfileImage.Image = getProfilePicture(currentPartnerId)
        elseif ProfileScreen and ProfileScreen.ProfileImage then
            ProfileScreen.ProfileImage.Image = "rbxassetid://13426021678" -- Fallback
        end
        
    elseif state == "Report" then
        if ReportScreen then ReportScreen.Visible = true end
        if ReportScreen and ReportScreen.ReportTitle then
            ReportScreen.ReportTitle.Text = "Reportar a " .. (currentPartnerName or "Usuario")
        end
    end
end

--------------------------------------------------------------------------------
-- 5. PANTALLAS ADICIONALES (Intro, Salas, Perfil y Reporte)
--------------------------------------------------------------------------------

-- ** 5.1. Intro Screen Setup **
local IntroScreen = Instance.new("Frame")
IntroScreen.Name = "IntroScreen"
IntroScreen.Size = UDim2.new(1, 0, 1, 0)
IntroScreen.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
IntroScreen.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0.2, 0)
TitleLabel.Position = UDim2.new(0.5, 0, 0.15, 0)
TitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
TitleLabel.Text = "WHATSAPP DEL TERROR"
TitleLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
TitleLabel.TextSize = 40
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = IntroScreen

local StoryText = Instance.new("TextLabel")
StoryText.Size = UDim2.new(0.8, 0, 0.4, 0)
StoryText.Position = UDim2.new(0.5, 0, 0.5, 0)
StoryText.AnchorPoint = Vector2.new(0.5, 0.5)
StoryText.Text = "Historia: Dos jugadores se conectan a un chat privado. Si se detecta un tercero, un 'Desconocido' se une automáticamente al grupo. ¡No le respondas si quieres vivir!\n\n(Crea o únete a una sala con un amigo o un desconocido.)"
StoryText.TextColor3 = TEXT_COLOR
StoryText.TextSize = 20
StoryText.TextWrapped = true
StoryText.BackgroundTransparency = 1
StoryText.TextXAlignment = Enum.TextXAlignment.Center
StoryText.TextYAlignment = Enum.TextYAlignment.Center
StoryText.Parent = IntroScreen

local PlayButton = Instance.new("TextButton")
PlayButton.Name = "PlayButton"
PlayButton.Size = UDim2.new(0.6, 0, 0.1, 0)
PlayButton.Position = UDim2.new(0.5, 0, 0.85, 0)
PlayButton.AnchorPoint = Vector2.new(0.5, 0.5)
PlayButton.Text = "JUGAR (Buscar Sala)"
PlayButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
PlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayButton.TextSize = 28
PlayButton.Font = Enum.Font.SourceSansBold
PlayButton.Parent = IntroScreen
Instance.new("UICorner", PlayButton).CornerRadius = UDim.new(0, 10)

-- ** 5.2. Room Select Screen Setup **
local RoomSelectScreen = Instance.new("Frame")
RoomSelectScreen.Name = "RoomSelectScreen"
RoomSelectScreen.Size = UDim2.new(1, 0, 1, 0)
RoomSelectScreen.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
RoomSelectScreen.Visible = false
RoomSelectScreen.Parent = MainFrame

local RoomsBack = Instance.new("TextButton")
RoomsBack.Name = "RoomsBack"
RoomsBack.Size = UDim2.new(0, 50, 0, 50)
RoomsBack.Position = UDim2.new(0, 10, 0, 10)
RoomsBack.Text = "<-"
RoomsBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RoomsBack.TextColor3 = TEXT_COLOR
RoomsBack.TextSize = 24
RoomsBack.Font = Enum.Font.SourceSansBold
RoomsBack.Parent = RoomSelectScreen
RoomsBack.MouseButton1Click:Connect(function() switchScreen("Intro") end) 
    Instance.new("UICorner", RoomsBack).CornerRadius = UDim.new(0, 10)
    
    local WaitingLabel = Instance.new("TextLabel")
    WaitingLabel.Name = "WaitingLabel"
    WaitingLabel.Size = UDim2.new(1, 0, 0.1, 0)
    WaitingLabel.Position = UDim2.new(0.5, 0, 0.05, 0)
    WaitingLabel.AnchorPoint = Vector2.new(0.5, 0)
    WaitingLabel.Text = "SALAS DISPONIBLES (Desliza para ver)"
    WaitingLabel.TextColor3 = TEXT_COLOR
    WaitingLabel.TextSize = 24
    WaitingLabel.TextWrapped = true
    WaitingLabel.BackgroundTransparency = 1
    WaitingLabel.TextXAlignment = Enum.TextXAlignment.Center
    WaitingLabel.TextYAlignment = Enum.TextYAlignment.Center
    WaitingLabel.Parent = RoomSelectScreen
    
    local RoomScroller = Instance.new("ScrollingFrame")
    RoomScroller.Name = "RoomScroller"
    RoomScroller.Size = UDim2.new(0.9, 0, 0.7, 0)
    RoomScroller.Position = UDim2.new(0.5, 0, 0.5, 0)
    RoomScroller.AnchorPoint = Vector2.new(0.5, 0.5)
    RoomScroller.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    RoomScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
    RoomScroller.ScrollBarImageColor3 = ACCENT_COLOR
    RoomScroller.Parent = RoomSelectScreen
    Instance.new("UICorner", RoomScroller).CornerRadius = UDim.new(0, 10)
    
    local RoomLayout = Instance.new("UIListLayout")
    RoomLayout.Name = "RoomLayout"
    RoomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    RoomLayout.Padding = UDim.new(0, 10)
    RoomLayout.Parent = RoomScroller
    
    local CreateRoomButton = Instance.new("TextButton")
    CreateRoomButton.Name = "CreateRoomButton"
    CreateRoomButton.Size = UDim2.new(0.6, 0, 0.08, 0)
    CreateRoomButton.Position = UDim2.new(0.5, 0, 0.93, 0)
    CreateRoomButton.AnchorPoint = Vector2.new(0.5, 0.5)
    CreateRoomButton.Text = "CREAR NUEVA SALA"
    CreateRoomButton.BackgroundColor3 = ACCENT_COLOR
    CreateRoomButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CreateRoomButton.TextSize = 24
    CreateRoomButton.Font = Enum.Font.SourceSansBold
    CreateRoomButton.Parent = RoomSelectScreen
    Instance.new("UICorner", CreateRoomButton).CornerRadius = UDim.new(0, 10)
    
    CreateRoomButton.MouseButton1Click:Connect(function()
        CreateRoomButton.Text = "Creando..."
        CreateRoomButton.Active = false
        RoomAction:FireServer("Create")
    end)
    
    
    -- Función para dibujar las salas
    local function updateRoomList(roomsTable)
        for _, child in pairs(RoomScroller:GetChildren()) do
            if child:IsA("Frame") and child.Name == "RoomEntry" then
                child:Destroy()
            end
        end
        
        if #roomsTable == 0 then
            WaitingLabel.Text = "No hay salas disponibles.\n¡Sé el primero en crear una!"
        else
            WaitingLabel.Text = "SALAS DISPONIBLES (Desliza para ver)"
        end
        
        for _, roomData in ipairs(roomsTable) do
            local roomEntry = Instance.new("Frame")
            roomEntry.Name = "RoomEntry"
            roomEntry.Size = UDim2.new(1, 0, 0, 60)
            roomEntry.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            roomEntry.Parent = RoomScroller
            Instance.new("UICorner", roomEntry).CornerRadius = UDim.new(0, 8)
            
            local HostName = Instance.new("TextLabel")
            HostName.Size = UDim2.new(0.7, -10, 1, 0)
            HostName.Position = UDim2.new(0, 10, 0, 0)
            HostName.AnchorPoint = Vector2.new(0, 0)
            HostName.Text = "Sala de: " .. roomData.HostName
            HostName.TextColor3 = TEXT_COLOR
            HostName.TextSize = 20
            HostName.Font = Enum.Font.SourceSansBold
            HostName.BackgroundTransparency = 1
            HostName.TextXAlignment = Enum.TextXAlignment.Left
            HostName.Parent = roomEntry
            
            local JoinButton = Instance.new("TextButton")
            JoinButton.Size = UDim2.new(0.25, 0, 0.8, 0)
            JoinButton.Position = UDim2.new(1, -10, 0.5, 0)
            JoinButton.AnchorPoint = Vector2.new(1, 0.5)
            JoinButton.Text = "UNIRSE"
            JoinButton.BackgroundColor3 = ACCENT_COLOR
            JoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            JoinButton.TextSize = 18
            JoinButton.Font = FONT_STYLE
            JoinButton.Parent = roomEntry
            Instance.new("UICorner", JoinButton).CornerRadius = UDim.new(0, 6)
            
            JoinButton.MouseButton1Click:Connect(function()
                JoinButton.Text = "Uniéndose..."
                JoinButton.Active = false
                RoomAction:FireServer("Join", roomData.Id)
                -- El botón se reactivará si el switchScreen a "Chat" o "Intro" (en caso de error) ocurre.
            end)
        end
        
        -- Ajustar CanvasSize para el ScrollingFrame
        RoomScroller.CanvasSize = UDim2.new(0, 0, 0, RoomLayout.AbsoluteContentSize.Y + 10)
    end
    
    -- ** 5.3. Profile Screen Setup **
    local ProfileScreen = Instance.new("Frame")
    ProfileScreen.Name = "ProfileScreen"
    ProfileScreen.Size = UDim2.new(1, 0, 1, 0)
    ProfileScreen.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ProfileScreen.Visible = false
    ProfileScreen.Parent = MainFrame
    
    local ProfileBack = Instance.new("TextButton")
    ProfileBack.Size = UDim2.new(0, 50, 0, 50)
    ProfileBack.Position = UDim2.new(0, 10, 0, 10)
    ProfileBack.Text = "<-"
    ProfileBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ProfileBack.TextColor3 = TEXT_COLOR
    ProfileBack.TextSize = 24
    ProfileBack.Font = Enum.Font.SourceSansBold
    ProfileBack.Parent = ProfileScreen
    ProfileBack.MouseButton1Click:Connect(function() switchScreen("Chat", currentPartnerName, currentPartnerId) end) 
        Instance.new("UICorner", ProfileBack).CornerRadius = UDim.new(0, 10)
        
        local ProfileImage = Instance.new("ImageLabel")
        ProfileImage.Name = "ProfileImage"
        ProfileImage.Size = UDim2.new(0.4, 0, 0.3, 0)
        ProfileImage.Position = UDim2.new(0.5, 0, 0.3, 0)
        ProfileImage.AnchorPoint = Vector2.new(0.5, 0.5)
        ProfileImage.BackgroundTransparency = 1
        ProfileImage.Image = "rbxassetid://13426021678" -- Placeholder
        ProfileImage.Parent = ProfileScreen
        Instance.new("UICorner", ProfileImage).CornerRadius = UDim.new(0.5, 0)
        
        local UsernameText = Instance.new("TextLabel")
        UsernameText.Name = "UsernameText"
        UsernameText.Size = UDim2.new(1, 0, 0.05, 0)
        UsernameText.Position = UDim2.new(0.5, 0, 0.5, 0)
        UsernameText.AnchorPoint = Vector2.new(0.5, 0)
        UsernameText.Text = "Usuario"
        UsernameText.TextColor3 = TEXT_COLOR
        UsernameText.TextSize = 28
        UsernameText.Font = Enum.Font.SourceSansBold
        UsernameText.BackgroundTransparency = 1
        UsernameText.Parent = ProfileScreen
        
        local FollowButton = Instance.new("TextButton")
        FollowButton.Name = "FollowButton"
        FollowButton.Size = UDim2.new(0.3, 0, 0.07, 0)
        FollowButton.Position = UDim2.new(0.5, 0, 0.65, 0)
        FollowButton.AnchorPoint = Vector2.new(0.5, 0.5)
        FollowButton.Text = "Seguir (Ficticio)"
        FollowButton.BackgroundColor3 = ACCENT_COLOR
        FollowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        FollowButton.TextSize = 20
        FollowButton.Parent = ProfileScreen
        Instance.new("UICorner", FollowButton).CornerRadius = UDim.new(0, 10)
        FollowButton.MouseButton1Click:Connect(function() 
            FollowButton.Text = "Siguiendo..."
            task.wait(1)
            FollowButton.Text = "Seguir (Ficticio)"
        end)
        
        local ReportProfileButton = Instance.new("TextButton")
        ReportProfileButton.Name = "ReportProfileButton"
        ReportProfileButton.Size = UDim2.new(0.4, 0, 0.07, 0)
        ReportProfileButton.Position = UDim2.new(0.5, 0, 0.75, 0)
        ReportProfileButton.AnchorPoint = Vector2.new(0.5, 0.5)
        ReportProfileButton.Text = "Reportar Usuario"
        ReportProfileButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        ReportProfileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ReportProfileButton.TextSize = 20
        ReportProfileButton.Parent = ProfileScreen
        Instance.new("UICorner", ReportProfileButton).CornerRadius = UDim.new(0, 10)
        ReportProfileButton.MouseButton1Click:Connect(function() switchScreen("Report", currentPartnerName, currentPartnerId) end)
            
            -- ** 5.4. Report Screen Setup **
            local ReportScreen = Instance.new("Frame")
            ReportScreen.Name = "ReportScreen"
            ReportScreen.Size = UDim2.new(1, 0, 1, 0)
            ReportScreen.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            ReportScreen.Visible = false
            ReportScreen.Parent = MainFrame
            
            local ReportBack = Instance.new("TextButton")
            ReportBack.Size = UDim2.new(0, 50, 0, 50)
            ReportBack.Position = UDim2.new(0, 10, 0, 10)
            ReportBack.Text = "<-"
            ReportBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            ReportBack.TextColor3 = TEXT_COLOR
            ReportBack.TextSize = 24
            ReportBack.Font = Enum.Font.SourceSansBold
            ReportBack.Parent = ReportScreen
            ReportBack.MouseButton1Click:Connect(function() switchScreen("Profile", currentPartnerName, currentPartnerId) end)
                Instance.new("UICorner", ReportBack).CornerRadius = UDim.new(0, 10)
                
                local ReportTitle = Instance.new("TextLabel")
                ReportTitle.Name = "ReportTitle"
                ReportTitle.Size = UDim2.new(1, 0, 0.1, 0)
                ReportTitle.Position = UDim2.new(0.5, 0, 0.05, 0)
                ReportTitle.AnchorPoint = Vector2.new(0.5, 0)
                ReportTitle.Text = "Reportar a Usuario"
                ReportTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
                ReportTitle.TextSize = 30
                ReportTitle.Font = Enum.Font.SourceSansBold
                ReportTitle.BackgroundTransparency = 1
                ReportTitle.Parent = ReportScreen
                
                local reasonFrame = Instance.new("Frame")
                reasonFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
                reasonFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
                reasonFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                reasonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                reasonFrame.Parent = ReportScreen
                Instance.new("UICorner", reasonFrame).CornerRadius = UDim.new(0, 15)
                Instance.new("UIListLayout", reasonFrame).Padding = UDim.new(0, 10)
                
                local UIPaddingReport = Instance.new("UIPadding")
                UIPaddingReport.PaddingTop = UDim.new(0, 10)
                UIPaddingReport.PaddingBottom = UDim.new(0, 10)
                UIPaddingReport.PaddingLeft = UDim.new(0, 10)
                UIPaddingReport.PaddingRight = UDim.new(0, 10)
                UIPaddingReport.Parent = reasonFrame
                
                -- Opciones de Reporte
                local reasons = {"Acoso/bullying", "Contenido inapropiado", "Trampas/exploits", "Spam", "Otros"}
                local selectedReason = nil
                
                for _, reason in ipairs(reasons) do
                    local button = Instance.new("TextButton")
                    button.Size = UDim2.new(1, 0, 0, 40)
                    button.Text = reason
                    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                    button.TextColor3 = TEXT_COLOR
                    button.TextSize = 18
                    button.Font = FONT_STYLE
                    button.Parent = reasonFrame
                    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
                    
                    button.MouseButton1Click:Connect(function()
                        selectedReason = reason
                        for _, child in ipairs(reasonFrame:GetChildren()) do
                            if child:IsA("TextButton") and child.Name ~= "SubmitReportButton" then
                                child.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            end
                        end
                        button.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
                    end)
                end
                
                local SubmitReportButton = Instance.new("TextButton")
                SubmitReportButton.Name = "SubmitReportButton"
                SubmitReportButton.Size = UDim2.new(0.6, 0, 0.07, 0)
                SubmitReportButton.Position = UDim2.new(0.5, 0, 0.85, 0)
                SubmitReportButton.AnchorPoint = Vector2.new(0.5, 0.5)
                SubmitReportButton.Text = "Enviar Reporte"
                SubmitReportButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
                SubmitReportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                SubmitReportButton.TextSize = 24
                SubmitReportButton.Font = Enum.Font.SourceSansBold
                SubmitReportButton.Parent = ReportScreen
                Instance.new("UICorner", SubmitReportButton).CornerRadius = UDim.new(0, 10)
                
                SubmitReportButton.MouseButton1Click:Connect(function()
                    if not selectedReason then
                        SubmitReportButton.Text = "¡Selecciona una razón!"
                        SubmitReportButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                        task.wait(1)
                        SubmitReportButton.Text = "Enviar Reporte"
                        SubmitReportButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
                        return
                    end
                    
                    ReportUser:FireServer(currentPartnerName, selectedReason)
                end)
                
                
                --------------------------------------------------------------------------------
                -- 6. MANEJADORES DE EVENTOS
                --------------------------------------------------------------------------------
                
                -- Click en el botón de Jugar (Ahora va a la selección de salas)
                PlayButton.MouseButton1Click:Connect(function()
                    PlayButton.Text = "Cargando Salas..."
                    PlayButton.Active = false
                    
                    switchScreen("RoomSelect") 
                end)
                
                -- Click en el icono de Perfil (EN CABECERA)
                ProfileButton.MouseButton1Click:Connect(function()
                    if currentScreen == "Chat" and currentPartnerName and currentPartnerId then
                        switchScreen("Profile", currentPartnerName, currentPartnerId)
                    end
                end)
                
                -- Manejar sonido de escritura
                InputBox:GetPropertyChangedSignal("Text"):Connect(function()
                    if currentScreen == "Chat" and InputBox.Text ~= "" then
                        local currentTime = tick()
                        if currentTime - lastTypingSoundTime > TYPING_THROTTLE then
                            playSound("Typing")
                            lastTypingSoundTime = currentTime
                        end
                    end
                end)
                
                -- Envío de mensaje
                local function sendMessage()
                    local message = InputBox.Text
                    if message:match("^%s*$") then return end
                    
                    MessageSend:FireServer(message)
                    InputBox.Text = "" -- Limpiar texto
                    
                    playSound("MessageSent")
                end
                
                InputBox.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Return then
                        sendMessage()
                    end
                end)
                SendButton.MouseButton1Click:Connect(sendMessage)
                
                -- Listener para las actualizaciones del servidor
                ClientUpdate.OnClientEvent:Connect(function(status, senderName, message)
                    if status == "Connected" then
                        
                        local partnerId = tonumber(message) 
                        
                        if partnerId and partnerId > 0 then
                            print("[CLIENT] Conexión Exitosa con UserID: " .. partnerId)
                            playSound("Connected") 
                            switchScreen("Chat", senderName, partnerId)
                            addMessage("Sistema", "¡Conexión exitosa! Ahora estás en un chat con: "..senderName..".")
                        else
                            warn("[CLIENT ERROR] No se recibió un UserID válido al conectar. Volviendo a Intro.")
                            switchScreen("Intro") -- Volver a Intro en caso de error crítico
                        end
                        
                    elseif status == "RoomListUpdate" then 
                        local success, roomsTable = pcall(HttpService.JSONDecode, HttpService, message)
                        if success and typeof(roomsTable) == "table" then
                            updateRoomList(roomsTable)
                        else
                            warn("[CLIENT] Error al decodificar la lista de salas.")
                            updateRoomList({})
                        end
                        -- Reactivar botón de crear sala
                        if CreateRoomButton.Text ~= "CREAR NUEVA SALA" then
                            CreateRoomButton.Text = "CREAR NUEVA SALA"
                            CreateRoomButton.Active = true
                        end
                        
                    elseif status == "RoomStatusUpdate" then 
                        if senderName == "HostWaiting" then
                            -- El jugador acaba de crear una sala y está esperando
                            currentRoomId = message -- Asumiendo que el servidor envía el RoomId o HostName aquí.
                            switchScreen("HostWaiting")
                        end
                        
                    elseif status == "NewMessage" then
                        
                        addMessage(senderName, message)
                        
                        if senderName == Player.Name then
                            -- Mensaje propio
                        elseif senderName == "Desconocido" then
                            playSound("UnknownEnter") 
                        else
                            playSound("MessageReceived")
                        end
                        
                    elseif status == "Disconnected" then
                        -- Mostrar el mensaje de desconexión antes de cambiar de pantalla
                        addMessage("Sistema", message or "¡Tu compañero se ha desconectado! La sesión ha terminado. Vuelve a Intentarlo.")
                        -- Esperar un momento para que el usuario lea
                        task.wait(1.5)
                        switchScreen("Intro")
                        
                    elseif status == "ReportSent" then
                        local submitBtn = ReportScreen:FindFirstChild("SubmitReportButton")
                        if submitBtn then
                            submitBtn.Text = "¡REPORTE ENVIADO!"
                            submitBtn.BackgroundColor3 = ACCENT_COLOR
                            task.wait(1.5)
                        end
                        switchScreen("Profile", currentPartnerName, currentPartnerId)
                    end
                end)
                
                -- Solicitar lista de salas cada 5 segundos para mantenerla actualizada
                task.spawn(function()
                    while task.wait(5) do
                        if currentScreen == "RoomSelect" then
                            RoomListRequest:FireServer()
                        end
                    end
                end)
                
                -- Iniciar con la pantalla de introducción
                switchScreen("Intro")
                
                
