set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local kind = get_config("kind") or "static"
add_repositories("local-repo xmake_repo")
add_requires("mujoco 3.12.0", {
  system = false,
  configs = {
    shared = kind == "shared",
    merge_static = kind == "static",
    export_c_api = kind == "static"
  }
})

set_languages("c++20")
---------------------------------------------------------
--- Export: download mujoco and copy to dist/
---------------------------------------------------------
target("api_export")
  set_kind("phony")
  add_packages("mujoco")
  after_build(function(target)
    local outputdir = path.join(os.projectdir(), "dist/include")
    os.mkdir(outputdir)
    local pkg = target:pkg("mujoco")
    if pkg then
      local installdir = pkg:installdir()
      os.cp(path.join(installdir, "include/**"), outputdir)
    end
  end)

-- The local package recipe builds the library; this target only exports it.
target("mujoco_dart")
  set_kind("phony")
  add_packages("mujoco")
  on_install(function(target)
    local pkgdir = target:pkg("mujoco"):installdir()
    local windows = target:is_plat("windows", "mingw")
    local directory = kind == "shared" and windows and "bin" or "lib"
    local pattern
    if kind == "static" then
      pattern = target:is_plat("windows") and "lib/mujoco.lib" or "lib/libmujoco.a"
    elseif windows then
      pattern = "bin/*.dll"
    elseif target:is_plat("macosx", "iphoneos") then
      pattern = "lib/*.dylib"
    else
      pattern = "lib/*.so*"
    end
    local libraries = os.files(path.join(pkgdir, pattern))
    assert(#libraries > 0, "MuJoCo package contains no matching library: " .. pattern)
    local destination = path.join(target:installdir(), directory)
    os.mkdir(destination)
    for _, library in ipairs(libraries) do
      os.vcp(library, destination)
    end
  end)

for _, file in ipairs(os.files("example/*.cpp")) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_packages("mujoco")
end
