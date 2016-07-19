--------------------------------------------------------------------------------
-- Class processes that can be attached to process organelles
--------------------------------------------------------------------------------
class 'Process'

INPUT_CONCENTRATION_WEIGHT = 4
OUTPUT_CONCENTRATION_WEIGHT = 0.1

MAX_EXPECTED_PROCESS_ATP_COST = 30

-- Constructor
--
-- @param basicRate
-- How many times in a second, at maximum, the process will transform input to output
--
-- @param parentMicrobe
-- The microbe from which to take input compounds and to which to deposit output compounds
--
-- @param inputCompounds
-- A dictionary of used compoundIds as keys and amounts as values
--
-- @param outputCompounds
-- A dictionary of produced compoundIds as keys and amounts as values
--
function Process:__init(basicRate, inputCompounds, outputCompounds) end


function Process:updateFactors(parentMicrobe) end

-- Run the process for a given amount of time
--
-- @param milliseconds
-- The simulation time
--
function Process:produce(milliseconds, capacityFactor, parentMicrobe, storageTarget)
    return 0
end

function Process:storage()
    return storage
end

function Process:load(storage) end

--------------------------------------------------------------------------------
-- Class for Organelles capable of producing compounds
--------------------------------------------------------------------------------
class 'ProcessOrganelle' (Organelle)

PROCESS_CAPACITY_UPDATE_INTERVAL = 1000

-- Constructor
function ProcessOrganelle:__init()
    Organelle.__init(self)
    self.originalColour = ColourValue(1,1,1,1)
    -- self.processes = {}
    self.colourChangeFactor = 1.0
    self.capacityIntervalTimer = PROCESS_CAPACITY_UPDATE_INTERVAL
end

-- Adds a process to the processing organelle
-- The organelle will distribute its capacity between processes
--
-- @param process
-- The process to add
function ProcessOrganelle:addProcess(process)
    -- table.insert(self.processes, process)
end


-- Overridded from Organelle:onAddedToMicrobe
function ProcessOrganelle:onAddedToMicrobe(microbe, q, r, rotation)
    Organelle.onAddedToMicrobe(self, microbe, q, r, rotation)
    microbe:addProcessOrganelle(self)
end

-- Overridded from Organelle:onRemovedFromMicrobe
function ProcessOrganelle:onRemovedFromMicrobe(microbe, q, r)
    microbe:removeProcessOrganelle(self)
    Organelle.onRemovedFromMicrobe(self, microbe, q, r)
end

-- Private function used to update colour of organelle based on how full it is
function ProcessOrganelle:_updateColourDynamic(factorProduct)
    -- Scaled Factor Product (using a sigmoid to accommodate that factor will be low)
    local SFP = (1/(0.4+2^(-factorProduct*128*self.colourChangeFactor))-0.5)
    self._colour = ColourValue(0.6 + (self.originalColour.r-0.6)*SFP,
                               0.6 + (self.originalColour.g-0.6)*SFP,
                               0.6 + (self.originalColour.b-0.6)*SFP, 1) -- Calculate colour relative to how close the organelle is to have enough input compounds to produce
end


-- Called by Microbe:update
--
-- Produces compounds for the process at intervals
--
-- @param microbe
-- The microbe containing the organelle
--
-- @param logicTime
-- The time since the last call to update()
function ProcessOrganelle:update(microbe, logicTime)
    Organelle.update(self, microbe, logicTime)
end


-- Override from Organelle:setColour
function ProcessOrganelle:setColour(colour)
end


function ProcessOrganelle:storage()
    local storage = Organelle.storage(self)
    storage:set("capacityIntervalTimer", self.capacityIntervalTimer)
    storage:set("originalColour", self.originalColour)
    storage:set("colourChangeFactor", self.colourChangeFactor)

    return storage
end


function ProcessOrganelle:load(storage)
    Organelle.load(self, storage)
    self.originalColour =  storage:get("originalColour", ColourValue.White)
    self.capacityIntervalTimer = storage:get("capacityIntervalTimer", 0)
    self.colourChangeFactor = storage:get("colourChangeFactor", 1.0)
    --[[
    local processes = storage:get("processes", {})
    for i = 1,processes:size() do
        local process = Process(0, 0, {},{})
        process:load(processes:get(i))
        self:addProcess(process)
    end
    --]]
end

-------------------------------------------
-- factory functions for process organelles


Organelle.mpCosts["chloroplast"] = 20
Organelle.mpCosts["mitochondrion"] = 20

function OrganelleFactory.make_mitochondrion(data)
    local mito = Organelle()
	local angle = (data.rotation / 60)
	mito:addHex(0, 0)
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	mito:addHex(q, r)

    return mito
end

function OrganelleFactory.make_chloroplast(data)
	local x, y = axialToCartesian(data.q, data.r)
    local chloro = Organelle()
	local angle = (data.rotation / 60)
    if x < 0 then
        angle = angle + 5
    end
	
    chloro:addHex(0, 0)
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	chloro:addHex(q, r)
	q = 0
	r = 1
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	chloro:addHex(q, r)
	
    return chloro
end

function OrganelleFactory.render_mitochondrion(data)
	local x, y = axialToCartesian(data.q, data.r)
	local translation = Vector3(-x, -y, 0)
	local organelleLocation = translation
	
	data.sceneNode[2].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[2], data.colour)
	
	local angle = (data.rotation / 60)
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	x, y = axialToCartesian(q + data.q, r + data.r)
	translation = Vector3(-x, -y, 0)
	organelleLocation = organelleLocation + translation
	data.sceneNode[3].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[3], data.colour)
	
	data.sceneNode[1].meshName = "mitochondrion.mesh"
	organelleLocation = organelleLocation/2
	data.sceneNode[1].transform.position = organelleLocation
	data.sceneNode[1].transform.orientation = Quaternion(Radian(Degree(data.rotation)), Vector3(0, 0, 1))
end

function OrganelleFactory.render_chloroplast(data)
	local x, y = axialToCartesian(data.q, data.r)
	local translation = Vector3(-x, -y, 0)
	local organelleLocation = translation
	
	data.sceneNode[2].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[2], data.colour)
	
	local angle = (data.rotation / 60) + 5
    if x < 0 then
        angle = angle + 7
    end
    
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	x, y = axialToCartesian(q + data.q, r + data.r)
	translation = Vector3(-x, -y, 0)
	organelleLocation = organelleLocation + translation
	data.sceneNode[3].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[3], data.colour)
	
	q = 0
	r = 1
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	x, y = axialToCartesian(q + data.q, r + data.r)
	translation = Vector3(-x, -y, 0)
	organelleLocation = organelleLocation + translation
	data.sceneNode[4].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[4], data.colour)
	
	data.sceneNode[1].meshName = "chloroplast.mesh"
	organelleLocation = organelleLocation/3
	data.sceneNode[1].transform.position = organelleLocation
	data.sceneNode[1].transform.orientation = Quaternion(Radian(Degree(data.rotation)), Vector3(0, 0, 1))
end

function OrganelleFactory.sizeof_mitochondrion(data)
	local hexes = {}
	
	local angle = (data.rotation / 60)
	
	hexes[1] = {["q"]=0, ["r"]=0}
	
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	hexes[2] = {["q"]=q, ["r"]=r}
	
    return hexes
end

function OrganelleFactory.sizeof_chloroplast(data)
	local x, y = axialToCartesian(data.q, data.r)    
	local hexes = {}
	
	local angle = (data.rotation / 60) + 5
    if x < 0 then
        angle = angle + 7
    end
	
	hexes[1] = {["q"]=0, ["r"]=0}
	
	local q = 1
	local r = 0
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	hexes[2] = {["q"]=q, ["r"]=r}
	
	q = 0
	r = 1
	for i=0, angle do
		q, r = rotateAxial(q, r)
	end
	hexes[3] = {["q"]=q, ["r"]=r}
	
    return hexes
end
