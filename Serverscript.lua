--!strict
-- RoogleServerScript: Manejo de Páginas, DataStore y Remotes

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PagesDataStore = DataStoreService:GetDataStore("RooglePages_V1")
local RunService = game:GetService("RunService")

-- Admines: Vegetl_t es el administrador
local ADMINS = {
["Vegetl_t"] = true,
}

-- Estructura de datos en memoria: URL -> {url, code, author, timestamp}
local Pages: { [string]: { url: string, code: string, author: string, timestamp: number } } = {}

-- Función para verificar admin
local function isAdmin(player: Player): boolean
    return ADMINS[player.Name] == true
end

-- Configuración de Remotes
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "RoogleRemotes"
remoteFolder.Parent = ReplicatedStorage

local getPageRemote = Instance.new("RemoteFunction")
getPageRemote.Name = "GetPage"
getPageRemote.Parent = remoteFolder

local publishPageRemote = Instance.new("RemoteEvent")
publishPageRemote.Name = "PublishPage"
publishPageRemote.Parent = remoteFolder

local searchPagesRemote = Instance.new("RemoteFunction")
searchPagesRemote.Name = "SearchPages"
searchPagesRemote.Parent = remoteFolder


-- Cargar datos de DataStore
local function loadPages()
    local success, data = pcall(function()
        return PagesDataStore:GetAsync("AllPages")
    end)
    
    if success and data and typeof(data) == "table" then
        Pages = data
        print("Roogle: Páginas cargadas. Total:", #Pages)
    else
        Pages = {}
        warn("Roogle: No se pudieron cargar las páginas o no existen. Se inicializa vacío.")
    end
end

-- Guardar datos en DataStore
local function savePages()
    if RunService:IsStudio() then
        -- No guardar en Studio para evitar colisiones rápidas
        return
    end
    
    local success, err = pcall(function()
        PagesDataStore:SetAsync("AllPages", Pages)
    end)
    
    if success then
        print("Roogle: Páginas guardadas correctamente.")
    else
        warn("Roogle: Error al guardar páginas:", err)
    end
end

-- RemoteFunction: Obtener Página
getPageRemote.OnServerInvoke = function(player: Player, url: string): { url: string, code: string, author: string, timestamp: number } | nil
    if url and Pages[url] then
        return Pages[url]
    end
    return nil
end

-- RemoteFunction: Buscar Páginas (simplificado, devuelve la URL de todas las páginas)
searchPagesRemote.OnServerInvoke = function(player: Player, query: string): { string }
    local results = {}
    local lowerQuery = string.lower(query)
    
    for url, data in pairs(Pages) do
        -- Busca en la URL y en el código de la página (limitado a 500 caracteres para el índice)
        if string.find(string.lower(url), lowerQuery, 1, true) or string.find(string.lower(data.code), lowerQuery, 1, true) then
            table.insert(results, url)
        end
    end
    
    return results
end

-- RemoteEvent: Publicar Página
publishPageRemote.OnServerEvent:Connect(function(player: Player, url: string, code: string)
    -- Solo admins pueden publicar/modificar páginas
    if not isAdmin(player) then
        warn(player.Name .. " intentó publicar sin permiso.")
        return
    end
    
    if not url or not code or url == "" or code == "" then
        warn("Intento de publicación con URL o código vacío.")
        return
    end
    
    local newPage = {
    url = url:lower(), -- Guardar URL en minúsculas para consistencia
    code = code,
    author = player.Name,
    timestamp = os.time()
    }
    
    Pages[newPage.url] = newPage
    print("Roogle: Página '" .. newPage.url .. "' publicada/actualizada por " .. player.Name)
    savePages()
end)


-- Cargar páginas al inicio
loadPages()

-- Guardado periódico cada 5 minutos
if not RunService:IsStudio() then
    while true do
        task.wait(300)
        savePages()
    end
end


