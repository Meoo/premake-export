# premake-export
Premake5 extension allowing to export and import configuration between projects

## Sample code
```lua
project "AA"
  kind "ConsoleApp"
  files "AA.c"

  defines "TEST_AA"

  import {
    ["BB"] = {"Hello*"}, -- Import Hello1 and Hello2
  }


project "BB"
  kind "StaticLib"
  files "BB.c"

  export "Hello1"
    defines "TEST_BB1"

    -- Nested import in export block
    import {
      ["CC"] = "Anything", -- Will import "*" block
    }

  export "Hello2"
    filter "kind:*App"
      defines "TEST_BB2"

  export {} -- Leave export scope (1)

  defines "I_AM_BB"


project "CC"
  kind "SharedLib"
  files "CC.c"

  export "*"
    defines "TEST_CC1"

    import {
      ["BB"] = "Hello1", -- No infinite loops
      ["CC"] = "Used", -- Reference own export block
    }

  export "Used"
    defines "TEST_CC2"

  export "NeverUsed"
    defines "TEST_CC3"

  export "" -- Leave export scope (2)

  defines "I_AM_CC"
```

## Tokens
If your export blocks include tokens, they will be expanded by the importing project, which will probably result in unexpected behaviours.

## Virtual projects
The virtualproject.lua extension add a `virtualproject` function, you can use it to create projects that are never included in the solution.

It can be useful to create "fake" projects that only contains export blocks. You should never try to link against such projects as the solution will look for non-existing projects.
