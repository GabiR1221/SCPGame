--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/ViewmodelController
local RS=game:GetService("ReplicatedStorage"); local C={}; C.__index=C
function C.new():any return setmetatable({Enabled=false,Model=nil,Tracks={}},C) end
function C.Enable(self:any,name:string):boolean self:Disable(); local assets=RS:FindFirstChild("ClientAssets"); local folder=if assets then assets:FindFirstChild("Viewmodels") else nil; local source=if folder then folder:FindFirstChild(name) else nil; local camera=workspace.CurrentCamera; if not source or not source:IsA("Model") or not camera then return false end; local model=source:Clone(); for _,v in model:GetDescendants() do if v:IsA("BasePart") then v.CanCollide=false; v.CanTouch=false; v.CanQuery=false; v.CastShadow=false; v.Massless=true end end; local existing=model:FindFirstChildOfClass("AnimationController"); local controller:AnimationController; if existing then controller=existing else controller=Instance.new("AnimationController"); controller.Parent=model end; if not controller:FindFirstChildOfClass("Animator") then local animator=Instance.new("Animator"); animator.Parent=controller end; model.Parent=camera; self.Model=model; self.Enabled=true; return true end
function C.Disable(self:any) local model:Model?=self.Model; if model then model:Destroy() end; self.Model=nil; self.Enabled=false; table.clear(self.Tracks) end
function C.Start(self:any) end
return C
