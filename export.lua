--
--  Premake5 configuration export extension
--    Author : Bastien Brunnenstein
--

local p = premake


p.export = p.container.newClass("export", p.project, { "config" })


function p.export.new(mode)
  return p.container.new(p.export, mode)
end



-- Copy a block, only deep-copying the criteria
local function copyBlock(object)
  local clone = {}

  for k, v in pairs(object) do
    if k == "_criteria" then
      clone[k] = table.deepcopy(v)
    else
      clone[k] = v
    end
  end

  return clone
end

local function cleanBlock(block)
  -- The blocks may have invalid infos reserved for the first ones
  if block.filename then
    block.filename = nil
    block._basedir = block.basedir
    block.basedir = nil
  end
end

-- Filter utils
local function prepareFilter(filter)
  return filter:lower():gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1"):gsub("%*", ".*")
end

local function prepareFilters(filters)
  for k, v in ipairs(filters) do
    filters[k] = prepareFilter(v)
  end
end

local function matchFilters(name, filters)
  if name == "**" then return true end
  local name = name:lower()
  for _, filter in ipairs(filters) do
    if name:match(filter) then return true end
  end
  return false
end

-- Forward declaration
local importProject

local function findImportsInBlock(self, block)

  if block.import then

    -- Extract the criteria and the project name, and import the project
    for _, entry in ipairs(block.import) do
      for prjName, filters in pairs(entry) do
        prepareFilters(filters)
        importProject(self, prjName, filters, block._criteria)
      end
    end
  end

end

function importProject(self, prjName, filters, baseCriteria)

  local sln = self.solution
  local prj = p.solution.findproject(sln, prjName)
  if not prj then
    error("Project "..prjName.." is not in the solution "..sln.name, 0)
  end

  self.parsedImports[prjName] = self.parsedImports[prjName] or {}
  local parsed = self.parsedImports[prjName]

  for exp in p.container.eachChild(prj, p.export) do

    -- Only import each block once
    if not table.contains(parsed, exp.name)

    -- Only import if the filters matches
    and  matchFilters(exp.name, filters) then

      table.insert(parsed, exp.name)

      for _, expBlock in ipairs(exp.blocks) do

        -- Copy each block and append the criteria patterns
        local newBlock = copyBlock(expBlock)

        newBlock._criteria.patterns = table.join(newBlock._criteria.patterns, baseCriteria.patterns)
        newBlock._criteria.data = p.criteria._compile(newBlock._criteria.patterns)

        cleanBlock(newBlock)

        table.insert(self.blocks, newBlock)

        -- Recurse
        findImportsInBlock(self, newBlock)
      end

    end
  end

end

premake.override(p.project, "bake", function(base, self)

  -- Store parsed imports to prevent infinite loops
  self.parsedImports = {}

  -- Consider ourself as already imported
  local ourExports = {}
  for exp in p.container.eachChild(self, p.export) do
    table.insert(ourExports, exp.name)
  end
  self.parsedImports[self.name] = ourExports

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
function export(name)
  if type(name) == "table" then
    if #name == 0 then
      -- Disable the export scope, return to the project scope
      return p.api._setContainer(p.export.parent)
    end

    if #name > 1 then
      error("export cannot take more than one argument", 1)
    end

    name = name[1]
  end

  if type(name) ~= "string" then
    error("export argument must be a string", 1)
  end

  if name == "" then
    -- Disable the export scope, return to the project scope
    return p.api._setContainer(p.export.parent)
  end

  -- FIXME We need to use our magic instead of "*" because of premake's legacy code
  if name == "*" then
    name = "**"
  end

  return p.api._setContainer(p.export, name)
end

p.api.register {
  name = "import",
  scope = { "config" },
  kind = "list:keyed:list:string",
}
