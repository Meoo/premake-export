--
--	Premake5 virtual projects extension
--		Author : Bastien Brunnenstein
--

local p = premake


function virtualproject(name)
	project(name)
	p.api.scope.project.virtual = true
end

premake.override(p.main, "postBake", function(base)
	print "Removing virtual projects..."

	for sln in p.global.eachSolution() do
		local virtualProjects = {}
		local toRemove = {}

		for k, v in ipairs(sln.projects) do
			if v.virtual then
				table.insert(toRemove, k)
				virtualProjects[v.name] = v
			end
		end

		for k, v in ipairs(toRemove) do
			table.remove(sln.projects, v - (k - 1))
		end

		sln.virtualProjects = virtualProjects
	end

	return base()

end)

premake.override(p.solution, "findproject", function(base, self, name)
	return base(self, name) or self.virtualProjects[name]
end)
