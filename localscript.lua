--!strict
-- Roogle LocalScript: Navegador, Editor, Favoritos e Historial (COMPLETAMENTE RESPONSIVO)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Esperar a que existan los RemoteEvents
local remoteFolder = ReplicatedStorage:WaitForChild("RoogleRemotes")
local getPageEvent = remoteFolder:WaitForChild("GetPage")
local publishPageEvent = remoteFolder:WaitForChild("PublishPage")
local searchPagesEvent = remoteFolder:WaitForChild("SearchPages")

-- CONSTANTES
local SIDE_PANEL_WIDTH = 300 -- Ancho fijo para el panel lateral (mejor usabilidad)
local TOP_BAR_HEIGHT = 60
local MAX_HISTORY_SIZE = 20

-- Almacenamiento local de favoritos e historial
local favorites: { string } = {}
local history: { string } = {}
local currentTab = "favorites"
local panelOpen = false
local currentUrl = ""

-- ====================================================================
-- UI CREACIÓN (RESPONSIVA)
-- ====================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RoogleGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(32, 33, 36)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Barra superior (Fija 60px de altura)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT)
topBar.BackgroundColor3 = Color3.fromRGB(45, 46, 50)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topPadding = Instance.new("UIPadding")
topPadding.PaddingLeft = UDim.new(0, 10)
topPadding.PaddingRight = UDim.new(0, 10)
topPadding.PaddingTop = UDim.new(0, 10)
topPadding.PaddingBottom = UDim.new(0, 10)
topPadding.Parent = topBar

local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.Padding = UDim.new(0, 10)
topLayout.Parent = topBar

-- Logo Roogle
local logo = Instance.new("TextLabel")
logo.Name = "Logo"
logo.Size = UDim2.new(0, 100, 1, 0)
logo.BackgroundTransparency = 1
logo.Text = "Roogle"
logo.TextColor3 = Color3.fromRGB(255, 255, 255)
logo.TextSize = 24
logo.Font = Enum.Font.GothamBold
logo.Parent = topBar

-- Separador (para empujar los botones a la derecha)
local spacer = Instance.new("Frame")
spacer.Name = "Spacer"
spacer.Size = UDim2.new(1, -220, 1, 0) -- Ocupa el espacio restante (ajustado por los botones)
spacer.BackgroundTransparency = 1
spacer.Parent = topBar

-- Barra de búsqueda (DENTRO DEL SPACER)
local searchBar = Instance.new("TextBox")
searchBar.Name = "SearchBar"
searchBar.Size = UDim2.new(1, -90, 1, 0) -- 90px para el botón de búsqueda
searchBar.Position = UDim2.new(0, 0, 0, 0)
searchBar.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
searchBar.BorderSizePixel = 0
searchBar.Text = ""
searchBar.PlaceholderText = "Buscar o ingresar URL…"
searchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBar.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBar.TextSize = 16
searchBar.Font = Enum.Font.Gotham
searchBar.ClearTextOnFocus = false
searchBar.TextXAlignment = Enum.TextXAlignment.Left
searchBar.Parent = spacer

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 8)
searchCorner.Parent = searchBar

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 15)
searchPadding.Parent = searchBar

-- Botón de búsqueda (DENTRO DEL SPACER)
local searchButton = Instance.new("TextButton")
searchButton.Name = "SearchButton"
searchButton.Size = UDim2.new(0, 80, 1, 0)
searchButton.Position = UDim2.new(1, -80, 0, 0) -- Alineado a la derecha del spacer
searchButton.BackgroundColor3 = Color3.fromRGB(26, 115, 232)
searchButton.BorderSizePixel = 0
searchButton.Text = "Buscar"
searchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
searchButton.TextSize = 16
searchButton.Font = Enum.Font.GothamBold
searchButton.Parent = spacer

local searchBtnCorner = Instance.new("UICorner")
searchBtnCorner.CornerRadius = UDim.new(0, 8)
searchBtnCorner.Parent = searchButton

-- Botones de acción derecha (Flujo horizontal)
local actionButtons = Instance.new("Frame")
actionButtons.Name = "ActionButtons"
actionButtons.Size = UDim2.new(0, 200, 1, 0) -- Tamaño para contener 3 botones
actionButtons.BackgroundTransparency = 1
actionButtons.Parent = topBar

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionLayout.Padding = UDim.new(0, 10)
actionLayout.Parent = actionButtons

-- Botón de publicar
local publishButton = Instance.new("TextButton")
publishButton.Name = "PublishButton"
publishButton.Size = UDim2.new(0, 80, 1, 0)
publishButton.BackgroundColor3 = Color3.fromRGB(52, 168, 83)
publishButton.BorderSizePixel = 0
publishButton.Text = "Publicar"
publishButton.TextColor3 = Color3.fromRGB(255, 255, 255)
publishButton.TextSize = 12
publishButton.Font = Enum.Font.GothamBold
publishButton.Parent = actionButtons

local publishBtnCorner = Instance.new("UICorner")
publishBtnCorner.CornerRadius = UDim.new(0, 6)
publishBtnCorner.Parent = publishButton

-- Botón para agregar a favoritos
local addFavButton = Instance.new("TextButton")
addFavButton.Size = UDim2.new(0, 30, 1, 0)
addFavButton.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
addFavButton.BorderSizePixel = 0
addFavButton.Text = "★"
addFavButton.TextColor3 = Color3.fromRGB(255, 200, 0)
addFavButton.TextSize = 18
addFavButton.Font = Enum.Font.GothamBold
addFavButton.Parent = actionButtons

local addFavCorner = Instance.new("UICorner")
addFavCorner.CornerRadius = UDim.new(0, 6)
addFavCorner.Parent = addFavButton

-- Botón de menú (hamburguesa)
local menuButton = Instance.new("TextButton")
menuButton.Name = "MenuButton"
menuButton.Size = UDim2.new(0, 30, 1, 0)
menuButton.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
menuButton.BorderSizePixel = 0
menuButton.Text = "☰"
menuButton.TextColor3 = Color3.fromRGB(255, 255, 255)
menuButton.TextSize = 20
menuButton.Font = Enum.Font.GothamBold
menuButton.Parent = actionButtons

local menuBtnCorner = Instance.new("UICorner")
menuBtnCorner.CornerRadius = UDim.new(0, 6)
menuBtnCorner.Parent = menuButton

-- Frame de contenido (Ocupa el espacio restante)
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -TOP_BAR_HEIGHT)
contentFrame.Position = UDim2.new(0, 0, 0, TOP_BAR_HEIGHT)
contentFrame.BackgroundColor3 = Color3.fromRGB(32, 33, 36)
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame

-- Contenedores de vistas
local homePage = Instance.new("ScrollingFrame")
homePage.Name = "HomePage"
homePage.Size = UDim2.new(1, 0, 1, 0)
homePage.BackgroundColor3 = Color3.fromRGB(32, 33, 36)
homePage.BorderSizePixel = 0
homePage.ScrollBarThickness = 8
homePage.Visible = true
homePage.Parent = contentFrame

-- (Elementos de la página de inicio)
local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, -40, 0, 80)
homeTitle.Position = UDim2.new(0.5, 0, 0, 40)
homeTitle.AnchorPoint = Vector2.new(0.5, 0)
homeTitle.BackgroundTransparency = 1
homeTitle.Text = "Bienvenido a Roogle"
homeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
homeTitle.TextSize = 48
homeTitle.Font = Enum.Font.GothamBold
homeTitle.Parent = homePage

local homeDesc = Instance.new("TextLabel")
homeDesc.Size = UDim2.new(1, -40, 0, 40)
homeDesc.Position = UDim2.new(0.5, 0, 0, 130)
homeDesc.AnchorPoint = Vector2.new(0.5, 0)
homeDesc.BackgroundTransparency = 1
homeDesc.Text = "El navegador web de Roblox. Crea y explora páginas con código Lua."
homeDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
homeDesc.TextSize = 20
homeDesc.Font = Enum.Font.Gotham
homeDesc.TextWrapped = true
homeDesc.Parent = homePage


local loadingFrame = Instance.new("Frame")
loadingFrame.Name = "LoadingFrame"
loadingFrame.Size = UDim2.new(1, 0, 1, 0)
loadingFrame.BackgroundColor3 = Color3.fromRGB(32, 33, 36)
loadingFrame.BorderSizePixel = 0
loadingFrame.Visible = false
loadingFrame.ZIndex = 10
loadingFrame.Parent = contentFrame

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0, 300, 0, 50)
loadingText.Position = UDim2.new(0.5, -150, 0.5, -50)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Cargando..."
loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
loadingText.TextSize = 32
loadingText.Font = Enum.Font.GothamBold
loadingText.Parent = loadingFrame

local loadingSpinner = Instance.new("Frame")
loadingSpinner.Size = UDim2.new(0, 60, 0, 60)
loadingSpinner.Position = UDim2.new(0.5, -30, 0.5, 10)
loadingSpinner.BackgroundColor3 = Color3.fromRGB(26, 115, 232)
loadingSpinner.BorderSizePixel = 0
loadingSpinner.Parent = loadingFrame

local spinnerCorner = Instance.new("UICorner")
spinnerCorner.CornerRadius = UDim.new(1, 0)
spinnerCorner.Parent = loadingSpinner

local webFrame = Instance.new("ScrollingFrame")
webFrame.Name = "WebFrame"
webFrame.Size = UDim2.new(1, 0, 1, 0)
webFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
webFrame.BorderSizePixel = 0
webFrame.ScrollBarThickness = 8
webFrame.Visible = false
webFrame.Parent = contentFrame

-- Editor Frame
local editorFrame = Instance.new("Frame")
editorFrame.Name = "EditorFrame"
editorFrame.Size = UDim2.new(1, 0, 1, 0)
editorFrame.BackgroundColor3 = Color3.fromRGB(32, 33, 36)
editorFrame.BorderSizePixel = 0
editorFrame.Visible = false
editorFrame.Parent = contentFrame

local editorPadding = Instance.new("UIPadding")
editorPadding.PaddingAll = UDim.new(0, 20)
editorPadding.Parent = editorFrame

local editorLayout = Instance.new("UIListLayout")
editorLayout.Padding = UDim.new(0, 10)
editorLayout.Parent = editorFrame

local editorTitle = Instance.new("TextLabel")
editorTitle.Size = UDim2.new(1, 0, 0, 30)
editorTitle.BackgroundTransparency = 1
editorTitle.Text = "Editor de Páginas - Roogle"
editorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
editorTitle.TextSize = 24
editorTitle.Font = Enum.Font.GothamBold
editorTitle.Parent = editorFrame

local urlGroup = Instance.new("Frame")
urlGroup.Size = UDim2.new(1, 0, 0, 40)
urlGroup.BackgroundTransparency = 1
urlGroup.Parent = editorFrame

local urlLabel = Instance.new("TextLabel")
urlLabel.Size = UDim2.new(0, 80, 1, 0)
urlLabel.Position = UDim2.new(0, 0, 0, 0)
urlLabel.BackgroundTransparency = 1
urlLabel.Text = "URL:"
urlLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
urlLabel.TextSize = 18
urlLabel.Font = Enum.Font.Gotham
urlLabel.TextXAlignment = Enum.TextXAlignment.Left
urlLabel.Parent = urlGroup

local urlInput = Instance.new("TextBox")
urlInput.Name = "UrlInput"
urlInput.Size = UDim2.new(1, -90, 1, 0)
urlInput.Position = UDim2.new(0, 90, 0, 0)
urlInput.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
urlInput.BorderSizePixel = 0
urlInput.Text = ""
urlInput.PlaceholderText = "ejemplo: mipagina"
urlInput.TextColor3 = Color3.fromRGB(255, 255, 255)
urlInput.TextSize = 16
urlInput.Font = Enum.Font.Gotham
urlInput.TextXAlignment = Enum.TextXAlignment.Left
urlInput.Parent = urlGroup

local urlCorner = Instance.new("UICorner")
urlCorner.CornerRadius = UDim.new(0, 8)
urlCorner.Parent = urlInput

local urlPadding = Instance.new("UIPadding")
urlPadding.PaddingLeft = UDim.new(0, 10)
urlPadding.Parent = urlInput

local codeLabel = Instance.new("TextLabel")
codeLabel.Size = UDim2.new(1, 0, 0, 30)
codeLabel.BackgroundTransparency = 1
codeLabel.Text = "Código Lua (Debe retornar una tabla con 'title' y 'content'):"
codeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
codeLabel.TextSize = 18
codeLabel.Font = Enum.Font.Gotham
codeLabel.TextXAlignment = Enum.TextXAlignment.Left
codeLabel.Parent = editorFrame

local codeInput = Instance.new("TextBox")
codeInput.Name = "CodeInput"
codeInput.Size = UDim2.new(1, 0, 1, -175) -- Ocupa el espacio restante
codeInput.BackgroundColor3 = Color3.fromRGB(40, 42, 45)
codeInput.BorderSizePixel = 0
codeInput.Text = ""
codeInput.PlaceholderText = "-- Escribe tu código Lua aquí\nreturn {\n  title = \"Mi Página\",\n  content = \"Hola mundo\"\n}"
codeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
codeInput.TextSize = 14
codeInput.Font = Enum.Font.Code
codeInput.TextXAlignment = Enum.TextXAlignment.Left
codeInput.TextYAlignment = Enum.TextYAlignment.Top
codeInput.MultiLine = true
codeInput.ClearTextOnFocus = false
codeInput.Parent = editorFrame

local codeCorner = Instance.new("UICorner")
codeCorner.CornerRadius = UDim.new(0, 8)
codeCorner.Parent = codeInput

local codePadding = Instance.new("UIPadding")
codePadding.PaddingLeft = UDim.new(0, 10)
codePadding.PaddingTop = UDim.new(0, 10)
codePadding.Parent = codeInput

local publishPageBtn = Instance.new("TextButton")
publishPageBtn.Name = "PublishPageBtn"
publishPageBtn.Size = UDim2.new(0, 150, 0, 45)
publishPageBtn.BackgroundColor3 = Color3.fromRGB(52, 168, 83)
publishPageBtn.BorderSizePixel = 0
publishPageBtn.Text = "Publicar Página"
publishPageBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
publishPageBtn.TextSize = 18
publishPageBtn.Font = Enum.Font.GothamBold
publishPageBtn.Parent = editorFrame

local publishPageCorner = Instance.new("UICorner")
publishPageCorner.CornerRadius = UDim.new(0, 8)
publishPageCorner.Parent = publishPageBtn

-- Panel lateral (Responsivo: 300px ancho, se desliza)
local sidePanel = Instance.new("Frame")
sidePanel.Name = "SidePanel"
sidePanel.Size = UDim2.new(0, SIDE_PANEL_WIDTH, 1, -TOP_BAR_HEIGHT)
sidePanel.Position = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT) -- Fuera de pantalla inicialmente
sidePanel.BackgroundColor3 = Color3.fromRGB(45, 46, 50)
sidePanel.BorderSizePixel = 0
sidePanel.ZIndex = 5
sidePanel.Parent = mainFrame

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingAll = UDim.new(0, 10)
panelPadding.Parent = sidePanel

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 10)
sideLayout.Parent = sidePanel

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundTransparency = 1
titleBar.Parent = sidePanel

local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1, -40, 1, 0)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "Menú"
panelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
panelTitle.TextSize = 20
panelTitle.Font = Enum.Font.GothamBold
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Parent = titleBar

local closePanel = Instance.new("TextButton")
closePanel.Size = UDim2.new(0, 30, 1, 0)
closePanel.Position = UDim2.new(1, -30, 0, 0)
closePanel.BackgroundTransparency = 1
closePanel.Text = "✕"
closePanel.TextColor3 = Color3.fromRGB(255, 255, 255)
closePanel.TextSize = 20
closePanel.Font = Enum.Font.GothamBold
closePanel.Parent = titleBar

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, 0, 0, 40)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = sidePanel

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.Parent = tabsFrame

local favoritesTab = Instance.new("TextButton")
favoritesTab.Size = UDim2.new(0.5, -3, 1, 0)
favoritesTab.BackgroundColor3 = Color3.fromRGB(26, 115, 232)
favoritesTab.BorderSizePixel = 0
favoritesTab.Text = "★ Favoritos"
favoritesTab.TextColor3 = Color3.fromRGB(255, 255, 255)
favoritesTab.TextSize = 14
favoritesTab.Font = Enum.Font.GothamBold
favoritesTab.Parent = tabsFrame

local favTabCorner = Instance.new("UICorner")
favTabCorner.CornerRadius = UDim.new(0, 6)
favTabCorner.Parent = favoritesTab

local historyTab = Instance.new("TextButton")
historyTab.Size = UDim2.new(0.5, -3, 1, 0)
historyTab.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
historyTab.BorderSizePixel = 0
historyTab.Text = "⏱ Historial"
historyTab.TextColor3 = Color3.fromRGB(255, 255, 255)
historyTab.TextSize = 14
historyTab.Font = Enum.Font.GothamBold
historyTab.Parent = tabsFrame

local histTabCorner = Instance.new("UICorner")
histTabCorner.CornerRadius = UDim.new(0, 6)
histTabCorner.Parent = historyTab

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, 0, 1, -110) -- Ocupa el espacio restante
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.Parent = sidePanel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = listFrame

-- ====================================================================
-- LÓGICA DE FUNCIONES
-- ====================================================================

-- Función para mostrar loading
local function showLoading()
    loadingFrame.Visible = true
    homePage.Visible = false
    webFrame.Visible = false
    editorFrame.Visible = false
end

-- Función para ocultar loading
local function hideLoading()
    loadingFrame.Visible = false
end

-- Función para limpiar webFrame
local function clearWebFrame()
    for _, child in ipairs(webFrame:GetChildren()) do
        if not child:IsA("UICorner") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

-- Función para renderizar página
local function renderPage(pageData: { [string]: any } | nil)
    clearWebFrame()
    webFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Resetear color de fondo
    
    local yPos = 20
    local frameWidth = webFrame.AbsoluteSize.X - 40 -- Ancho para contenido
    
    if not pageData then
        webFrame.BackgroundColor3 = Color3.fromRGB(255, 240, 240)
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Size = UDim2.new(1, -40, 0, 100)
        errorLabel.Position = UDim2.new(0, 20, 0, yPos)
        errorLabel.BackgroundTransparency = 1
        errorLabel.Text = "Error: Página no encontrada o inválida."
        errorLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
        errorLabel.TextSize = 24
        errorLabel.Font = Enum.Font.GothamBold
        errorLabel.Parent = webFrame
        yPos = yPos + 110
    else
        -- 1. Título
        if pageData.title then
            local titleLabel = Instance.new("TextLabel")
            titleLabel.Size = UDim2.new(1, -40, 0, 50)
            titleLabel.Position = UDim2.new(0, 20, 0, yPos)
            titleLabel.BackgroundTransparency = 1
            titleLabel.Text = pageData.title
            titleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            titleLabel.TextSize = 32
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Parent = webFrame
            yPos = yPos + 60
        end
        
        -- 2. Contenido (Texto wrapped y tamaño dinámico)
        if pageData.content then
            local contentLabel = Instance.new("TextLabel")
            contentLabel.Name = "Content"
            contentLabel.BackgroundTransparency = 1
            contentLabel.Text = pageData.content
            contentLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
            contentLabel.TextSize = 18
            contentLabel.Font = Enum.Font.Gotham
            contentLabel.TextXAlignment = Enum.TextXAlignment.Left
            contentLabel.TextYAlignment = Enum.TextYAlignment.Top
            contentLabel.TextWrapped = true
            contentLabel.Parent = webFrame
            
            -- Calcular tamaño de texto
            local textSize = game:GetService("TextService"):GetTextSize(
            pageData.content,
            18,
            Enum.Font.Gotham,
            Vector2.new(frameWidth, 10000)
            )
            
            contentLabel.Size = UDim2.new(1, -40, 0, textSize.Y + 20) -- +20 padding
            contentLabel.Position = UDim2.new(0, 20, 0, yPos)
            yPos = yPos + textSize.Y + 30
        end
    end
    
    -- 3. Ajustar CanvasSize
    RunService.Heartbeat:Wait()
    webFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)
end

-- Función para cargar página (invoca el servidor y renderiza)
local function loadPage(url: string)
    url = url:lower() -- Asegurar minúsculas
    if url == "" then return end
    
    currentUrl = url
    showLoading()
    
    -- Agregar al historial inmediatamente
    if url ~= "inicio" and url ~= "tutorial" then
        -- Esto evita spam de historial mientras la página carga
        task.spawn(function()
            task.wait(0.5)
            if searchBar.Text:lower() == currentUrl then
                addToHistory(currentUrl)
            end
        end)
    end
    
    -- Simular carga y pedir al servidor
    local pageData = getPageEvent:InvokeServer(url)
    
    hideLoading()
    homePage.Visible = false
    webFrame.Visible = true
    editorFrame.Visible = false
    
    -- Si el servidor devuelve nil, la página no existe.
    if not pageData then
        -- Mostrar página de error/no encontrado
        renderPage(nil) 
    else
        -- Ejecutar el código Lua devuelto por el servidor
        local success, result = pcall(load(pageData.code))
        
        if success and type(result) == "function" then
            local funcSuccess, data = pcall(result)
            if funcSuccess and typeof(data) == "table" then
                renderPage(data)
            else
                renderPage({title = "Error de Código Lua", content = "El código de la página no retornó una tabla válida. Error: " .. tostring(data)})
            end
        else
            renderPage({title = "Error de Compilación Lua", content = "El código de la página no pudo ser compilado. Error: " .. tostring(result)})
        end
    end
end

-- Función para alternar el panel lateral
local function togglePanel()
    panelOpen = not panelOpen
    local targetPosition = panelOpen and UDim2.new(1, -SIDE_PANEL_WIDTH, 0, TOP_BAR_HEIGHT) or UDim2.new(1, 0, 0, TOP_BAR_HEIGHT)
    
    sidePanel:TweenPosition(targetPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    
    if panelOpen then
        updateList()
    end
end

-- Función para agregar a favoritos
local function addToFavorites(url: string)
    url = url:lower()
    for _, fav in ipairs(favorites) do
        if fav == url then return end -- Ya existe
        end
            
            table.insert(favorites, url)
            if panelOpen and currentTab == "favorites" then updateList() end
        end
        
        -- Función para remover de favoritos
        local function removeFromFavorites(url: string)
            url = url:lower()
            for i, fav in ipairs(favorites) do
                if fav == url then
                    table.remove(favorites, i)
                    if panelOpen and currentTab == "favorites" then updateList() end
                    return
                end
            end
        end
        
        -- Función para agregar al historial
        local function addToHistory(url: string)
            url = url:lower()
            if url == "inicio" or url == "tutorial" then return end
            
            for i, item in ipairs(history) do
                if item == url then
                    table.remove(history, i)
                    break
                end
            end
            
            table.insert(history, 1, url)
            
            while #history > MAX_HISTORY_SIZE do
                table.remove(history)
            end
            
            if panelOpen and currentTab == "history" then updateList() end
        end
        
        -- Función para crear entradas de lista
        local function createListItem(url: string, isFavorite: boolean): Frame
            local itemFrame = Instance.new("Frame")
            itemFrame.Size = UDim2.new(1, 0, 0, 40)
            itemFrame.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
            itemFrame.BorderSizePixel = 0
            itemFrame.Parent = listFrame
            
            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 6)
            itemCorner.Parent = itemFrame
            
            local urlButton = Instance.new("TextButton")
            urlButton.Size = UDim2.new(1, -50, 1, 0)
            urlButton.BackgroundTransparency = 1
            urlButton.Text = url
            urlButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            urlButton.TextSize = 14
            urlButton.Font = Enum.Font.Gotham
            urlButton.TextXAlignment = Enum.TextXAlignment.Left
            urlButton.Parent = itemFrame
            
            local urlPadding = Instance.new("UIPadding")
            urlPadding.PaddingLeft = UDim.new(0, 10)
            urlPadding.Parent = urlButton
            
            local actionButton = Instance.new("TextButton")
            actionButton.Size = UDim2.new(0, 30, 0, 30)
            actionButton.Position = UDim2.new(1, -40, 0.5, 0)
            actionButton.AnchorPoint = Vector2.new(0, 0.5)
            actionButton.BackgroundColor3 = Color3.fromRGB(80, 84, 87)
            actionButton.BorderSizePixel = 0
            actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionButton.TextSize = 18
            actionButton.Font = Enum.Font.GothamBold
            actionButton.Parent = itemFrame
            
            local actionCorner = Instance.new("UICorner")
            actionCorner.CornerRadius = UDim.new(0, 6)
            actionCorner.Parent = actionButton
            
            if isFavorite then
                actionButton.Text = "✕"
                actionButton.MouseButton1Click:Connect(function()
                    removeFromFavorites(url)
                end)
            else
                actionButton.Text = "★"
                actionButton.MouseButton1Click:Connect(function()
                    addToFavorites(url)
                    actionButton.Text = "✓" -- Feedback visual
                    actionButton.BackgroundColor3 = Color3.fromRGB(52, 168, 83)
                    task.wait(0.5)
                    actionButton.Text = "★"
                    actionButton.BackgroundColor3 = Color3.fromRGB(80, 84, 87)
                end)
            end
            
            -- Navegar
            urlButton.MouseButton1Click:Connect(function()
                loadPage(url)
                togglePanel()
            end)
            
            return itemFrame
        end
        
        -- Función para actualizar la lista mostrada (favoritos o historial)
        local function updateList()
            -- Limpiar lista actual
            for _, child in ipairs(listFrame:GetChildren()) do
                if not child:IsA("UIListLayout") then
                    child:Destroy()
                end
            end
            
            local items = currentTab == "favorites" and favorites or history
            
            if #items == 0 then
                local emptyLabel = Instance.new("TextLabel")
                emptyLabel.Size = UDim2.new(1, 0, 0, 50)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Text = currentTab == "favorites" and "No tienes páginas favoritas." or "El historial está vacío."
                emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                emptyLabel.TextSize = 16
                emptyLabel.Font = Enum.Font.Gotham
                emptyLabel.Parent = listFrame
            else
                for _, url in ipairs(items) do
                    createListItem(url, currentTab == "favorites").Parent = listFrame
                end
            end
            
            -- Ajustar CanvasSize
            RunService.Heartbeat:Wait()
            listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        end
        
        -- ====================================================================
        -- EVENTOS
        -- ====================================================================
        
        -- Cargar página al iniciar (página de inicio por defecto)
        local function loadInitialPage()
            -- Crear páginas de ejemplo que no se guardan/añaden a historial
            local defaultPages = {
            ["inicio"] = {title = "Página de Inicio", content = "¡Bienvenido a Roogle! Utiliza la barra de búsqueda para navegar. Presiona 'Publicar' para crear tu propia página."},
            ["tutorial"] = {title = "Tutorial de Roogle", content = "Para crear una página, haz clic en 'Publicar'. Necesitas una URL única y código Lua que retorne una tabla con 'title' y 'content'. Solo los administradores pueden publicar actualmente."},
            }
            
            -- Comprobar si se ha solicitado una URL específica al iniciar
            if searchBar.Text ~= "" then
                loadPage(searchBar.Text)
            else
                -- Mostrar página de inicio localmente
                searchBar.Text = "inicio"
                renderPage(defaultPages.inicio)
            end
        end
        
        -- Botón de búsqueda / Enter en barra de búsqueda
        local function handleSearch()
            local url = searchBar.Text
            if url ~= "" then
                if url:lower() == "inicio" then
                    loadInitialPage()
                elseif url:lower() == "tutorial" then
                    loadInitialPage() -- Recargar para mostrar tutorial
                    renderPage({title = "Tutorial de Roogle", content = "Para crear una página, haz clic en 'Publicar'. Necesitas una URL única y código Lua que retorne una tabla con 'title' y 'content'. Solo los administradores pueden publicar actualmente."})
                else
                    loadPage(url)
                end
            end
        end
        
        searchButton.MouseButton1Click:Connect(handleSearch)
        searchBar.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                handleSearch()
            end
        end)
        
        -- Botón de publicar (Mostrar editor)
        publishButton.MouseButton1Click:Connect(function()
            homePage.Visible = false
            webFrame.Visible = false
            editorFrame.Visible = true
        end)
        
        -- Botón de publicar página (en el editor)
        publishPageBtn.MouseButton1Click:Connect(function()
            local url = urlInput.Text:lower()
            local code = codeInput.Text
            
            if url == "" or code == "" then
                -- Usar un TextLabel en lugar de alert()
                local errorLabel = Instance.new("TextLabel")
                errorLabel.Size = UDim2.new(0, 300, 0, 50)
                errorLabel.Position = UDim2.new(0.5, -150, 0.5, -100)
                errorLabel.BackgroundColor3 = Color3.fromRGB(234, 67, 53)
                errorLabel.Text = "¡Error! URL y código no pueden estar vacíos."
                errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                errorLabel.Font = Enum.Font.GothamBold
                errorLabel.Parent = editorFrame
                
                errorLabel:TweenPosition(UDim2.new(0.5, -150, 0.5, -50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
                task.wait(2)
                errorLabel:Destroy()
                return
            end
            
            publishPageEvent:FireServer(url, code)
            
            -- Limpiar campos y volver
            urlInput.Text = ""
            codeInput.Text = ""
            searchBar.Text = url
            editorFrame.Visible = false
            loadPage(url) -- Cargar la página recién publicada
        end)
        
        -- Eventos del panel lateral
        menuButton.MouseButton1Click:Connect(togglePanel)
        closePanel.MouseButton1Click:Connect(togglePanel)
        
        favoritesTab.MouseButton1Click:Connect(function()
            currentTab = "favorites"
            favoritesTab.BackgroundColor3 = Color3.fromRGB(26, 115, 232)
            historyTab.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
            updateList()
        end)
        
        historyTab.MouseButton1Click:Connect(function()
            currentTab = "history"
            historyTab.BackgroundColor3 = Color3.fromRGB(26, 115, 232)
            favoritesTab.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
            updateList()
        end)
        
        addFavButton.MouseButton1Click:Connect(function()
            if currentUrl ~= "" and currentUrl ~= "inicio" and currentUrl ~= "tutorial" then
                addToFavorites(currentUrl)
                
                -- Feedback visual
                addFavButton.BackgroundColor3 = Color3.fromRGB(52, 168, 83)
                task.wait(0.3)
                addFavButton.BackgroundColor3 = Color3.fromRGB(60, 64, 67)
            end
        end)
        
        -- Animación de spinner
        task.spawn(function()
            while true do
                if loadingFrame.Visible then
                    for i = 0, 360, 10 do
                        loadingSpinner.Rotation = i
                        RunService.RenderStepped:Wait()
                    end
                else
                    RunService.Heartbeat:Wait()
                end
            end
        end)
        
        -- Inicialización
        loadInitialPage()
        
        print("Roogle inicializado correctamente con Favoritos/Historial/Editor.")
        
        
