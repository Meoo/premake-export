--
--	Premake5 configuration export module
--		Author : Bastien Brunnenstein
--

local p = premake


p.export = p.container.newClass("export", p.project, { "config" })


function p.export.new(mode)
	return p.container.new(p.export, mode)
end



local function cleanBlock(block)
	-- The blocks may have invalid infos reserved for the first ones
	if block.filename then
		block.filename = nil
		block._basedir = block.basedir
		block.basedir = nil
	end
end

-- Forward declaration
local importProject

local function findImportsInBlock(self, block)

	if block.import then

		-- Extract the criteria and the project name, and import the project
		for _, prjName in ipairs(block.import) do
			importProject(self, prjName, block._criteria)
		end
	end

end

function importProject(self, prjName, baseCriteria)
	-- Find the project referenced
	-- You can specify a solution using the format "Solution:Project"
	local completeName
	local solution
	local separatorPos = prjName:find(':')
	if separatorPos then
		completeName = prjName
		local slnName = prjName:sub(0, separatorPos - 1)
		solution = p.global.getSolution(slnName)
		prjName = prjName:sub(separatorPos + 1)
		if not solution then
			error("Solution "..slnName.." does not exists")
		end
	else
		solution = self.solution
		completeName = solution.name..":"..prjName
	end

	-- Only import each project once
	if self.parsedImports[completeName] then
		return
	else
		self.parsedImports[completeName] = true
	end

	-- Find the project
	local project = p.solution.findproject(solution, prjName)
	if not project then
		error("Project "..prjName.." is not in the solution "..solution.name)
	end

	for _, exportScope in ipairs(project.exports) do
		for _, exportBlock in ipairs(exportScope.blocks) do

			-- Copy each block and append the criteria patterns
			local newBlock = table.deepcopy(exportBlock)

			newBlock._criteria.patterns = table.join(newBlock._criteria.patterns, baseCriteria.patterns)
			newBlock._criteria.data = p.criteria._compile(newBlock._criteria.patterns)

			cleanBlock(newBlock)

			table.insert(self.blocks, newBlock)

			-- Recurse
			findImportsInBlock(self, newBlock)
		end
	end

end

premake.override(p.project, "bake", function(base, self)

	-- Store parsed imports to prevent infinite loops
	self.parsedImports = {}

	-- Consider ourself as already imported
	self.parsedImports[self.solution.name..":"..self.name] = true

	-- Retreive blocks from our exports that are marked as "ExportAndUse"
	for exp in p.container.eachChild(self, p.export) do
		if exp.name == "ExportAndUse" then
			for _, block in pairs(exp.blocks) do
				cleanBlock(block)
				table.insert(self.blocks, block)
			end
		end
	end

	-- Copy the blocks before iterating, because the function will be adding new ones
	local blocksCopy = {}
	for k, v in pairs(self.blocks) do
		blocksCopy[k] = v
	end

	-- Start searching for imports
	for _, prjBlock in pairs(blocksCopy) do
		findImportsInBlock(self, prjBlock)
	end

	return base(self)

end)



-- My API
function exportscope(mode)
	if type(mode) == "table" then
		if #mode == 0 then
			-- Disable the export scope, return to the project scope
			return p.api._setContainer(p.export.parent)
		end

		if #mode > 1 then
			error("exportscope cannot take more than one argument", 1)
		end

		mode = mode[1]
	end

	if mode ~= "ExportOnly" and mode ~= "ExportAndUse" then
		error("Allowed arguments for 'exportscope' are ExportOnly and ExportAndUse", 1)
	end

	return p.api._setContainer(p.export, mode)
end

p.api.register {
	name = "import",
	scope = { "config" },
	kind = "list:string",
}
