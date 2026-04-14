local GameObject = CS.UnityEngine.GameObject
local Time = CS.UnityEngine.Time
local Vector2 = CS.UnityEngine.Vector2
local Vector3 = CS.UnityEngine.Vector3
local SceneManager = CS.UnityEngine.SceneManagement.SceneManager
local Player = CS.Player
local Resources = CS.UnityEngine.Resources
local Random = CS.UnityEngine.Random
local Config = CS.Config
local PlayerUtilities = CS.PlayerUtilities

local function tableLength(t)
    local count = 0
    if t ~= nil then    
        for _ in pairs(t) do
            count = count + 1
        end
    end
    return count
end

local function getIndex(tab, val)
    for i, value in ipairs(tab) do
        if value == val then
            return i
        end
    end
    return -1
end

---@class SCPSwaper:CS.Akequ.Base.Room
SCPSwaper = {}
SCPSwaper.round_time = 0
SCPSwaper.menu_time = 0
SCPSwaper.scp_swap = false
SCPSwaper.swaper_status = "Enable"
SCPSwaper.scp_class = nil
SCPSwaper.conn_list = {}
SCPSwaper.conn_list_prior = {}

SCPSwaper.textobject_ = nil

function SCPSwaper:Init()
    if self.main.netEvent.isServer then
        CS.HookManager.Add(self.main.netEvent.gameObject, "changeLockRoundState", function(obj)
            if obj[0] == true then
                self.swaper_status = "Disable"
            else
                self.swaper_status = "Enable"
            end
        end)
        CS.HookManager.Add(self.main.netEvent.gameObject, "onPlayerDisconnected", function(obj)
            if self.swaper_status == "Enable" then
                local conn = obj[0]
                local ply = PlayerUtilities.GetServerPlayer(conn)
                if ply ~= nil then
                    if self.round_time < 300 and ply.playerClass ~= nil then
                        if ply.playerClass:GetType().Name:find("SCP") and ply.playerClass:GetType().Name ~= "SCP0492" then    
                            self.scp_class = ply.playerClass:GetType().Name
                            self.menu_time = 5
                            self.scp_swap = true
                            self.main:SendToEveryone("SwapMenuEnable", self.scp_class)
                        end
                    end
                end
            end
        end) 
    end
    if self.main.netEvent.isClient then    
        local base_ = GameObject.Find("Canvas")

        local swap_button = GameObject("SwapButton")

        swap_button.transform:SetParent(base_.transform, false)
        swap_button.transform.localPosition = Vector3(0, -10, 0)

        local rect = swap_button:AddComponent(typeof(CS.UnityEngine.RectTransform))
        rect.anchorMin = Vector2(0.5, 1)
        rect.anchorMax = Vector2(0.5, 1)
        rect.pivot =  Vector2(0.5, 1)
        rect.sizeDelta =  Vector2(300, 50)

        local button_image = swap_button:AddComponent(typeof(CS.UnityEngine.UI.Image))
        button_image.color = CS.UnityEngine.Color(1, 0, 0, 0.5)

        local button_button = swap_button:AddComponent(typeof(CS.UnityEngine.UI.Button))           

        self.textobject_ = GameObject("SwapText")
        self.textobject_.transform:SetParent(swap_button.transform, false)
        self.textobject_.transform.localPosition = Vector3.zero
        local rt = self.textobject_:AddComponent(typeof(CS.UnityEngine.RectTransform))
        rt.anchorMin =  Vector2(0.5, 1)
        rt.anchorMax =  Vector2(0.5, 1)
        rt.pivot =  Vector2(0.5, 1)
        rt.sizeDelta =  Vector2(500, 50)
        local text_ = self.textobject_:AddComponent(typeof(CS.UnityEngine.UI.Text))
        text_.alignment = CS.UnityEngine.TextAnchor.MiddleCenter
        text_.fontSize = 30
        text_.font = Resources.GetBuiltinResource(typeof(CS.UnityEngine.Font), "Arial.ttf")

        swap_button:GetComponent(typeof(CS.UnityEngine.UI.Button)).onClick:AddListener(function()        
            self:SwapMenuDisable()
            self.main:SendToServer("AddClient")
        end)

        button_button.enabled = false
        button_image.enabled = false
        text_.enabled = false
    end
end

function SCPSwaper:Update()
    if self.main.netEvent.isServer then
        self.round_time = self.round_time + Time.deltaTime
        if self.menu_time <= 0 then
            if self.scp_swap == true then
                self.scp_swap = false
                if tableLength(self.conn_list_prior.Count) > 0 then
                    local random = math.floor(CS.UnityEngine.Random.Range(1, tableLength(self.conn_list_prior) + 1))
                    local ply = PlayerUtilities.GetServerPlayer(self.conn_list_prior[random])
                    if ply ~= nil then
                        ply:SetClass(self.scp_class)
                        if ply.accountName ~= nil then
                            GameObject.FindObjectOfType(typeof(CS.AdminPanel)):ShowAdminMessage("<color=yellow>" .. ply.accountName .. "</color> стал <color=red>" .. self.scp_class .. "</color>", 3)
                        end
                    end
                elseif tableLength(self.conn_list) > 0 then
                    local random = math.floor(CS.UnityEngine.Random.Range(1, tableLength(self.conn_list) + 1))
                    local ply = PlayerUtilities.GetServerPlayer(self.conn_list[random])
                    if ply ~= nil then
                        ply:SetClass(self.scp_class)
                        if ply.accountName ~= nil then
                            GameObject.FindObjectOfType(typeof(CS.AdminPanel)):ShowAdminMessage("<color=yellow>" .. ply.accountName .. "</color> стал <color=red>" .. self.scp_class .. "</color>", 3)
                        end
                    end
                end
                self.main:SendToEveryone("SwapMenuDisable")
                self.conn_list_prior = {}
                self.conn_list = {}
            end
        else
            self.menu_time = self.menu_time - Time.deltaTime
        end
    end
end

--SERVER

function SCPSwaper:AddClient(conn)
    local ply = PlayerUtilities.GetServerPlayer(conn)
    if self.scp_swap == true and ply.playerClass ~= nil then
        if ply.playerClass:GetType().Name == "Spectator" then
            table.insert(self.conn_list_prior, conn)
        else
            table.insert(self.conn_list, conn)
        end
        GameObject.FindObjectOfType(typeof(CS.AdminPanel)):ShowAdminMessage("<color=green>Вы в очереди</color>", 3, ply)
    end
end

--CLIENT

function SCPSwaper:SwapMenuEnable(scp)
    self.scp_swap = true
    self.scp_class = scp

    local swap_button = GameObject.Find("SwapButton")

    local button_button = swap_button:GetComponent(typeof(CS.UnityEngine.UI.Button))
    local button_image = swap_button:GetComponent(typeof(CS.UnityEngine.UI.Image))
    local text_ = self.textobject_:GetComponent(typeof(CS.UnityEngine.UI.Text))

    text_.text = "Стать " .. self.scp_class

    button_button.enabled = true
    button_image.enabled = true
    text_.enabled = true
end

function SCPSwaper:SwapMenuDisable()
    self.scp_swap = false

    local swap_button = GameObject.Find("SwapButton")

    local button_button = swap_button:GetComponent(typeof(CS.UnityEngine.UI.Button))
    local button_image = swap_button:GetComponent(typeof(CS.UnityEngine.UI.Image))
    local text_ = self.textobject_:GetComponent(typeof(CS.UnityEngine.UI.Text))

    button_button.enabled = false
    button_image.enabled = false
    text_.enabled = false
end
return SCPSwaper