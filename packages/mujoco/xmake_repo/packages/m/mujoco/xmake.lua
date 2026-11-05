-- Based on xmake-repo a32d7e4ed13b8bbb8563c5cc4ee415fa333fd040.
-- Local changes support a self-contained static archive for later relinking.
package("mujoco")
    set_homepage("https://mujoco.org/")
    set_description("Multi-Joint dynamics with Contact. A general purpose physics simulator.")
    set_license("Apache-2.0")

    set_urls("https://github.com/google-deepmind/mujoco/archive/refs/tags/$(version).tar.gz",
             "https://github.com/google-deepmind/mujoco.git")

    add_versions("3.12.0", "9faa979982c3e924e8aaff3b16983bba3a1ab19c81f4f73178ae9c2ea25e467d")

    add_configs("merge_static", {description = "Merge MuJoCo and its required static dependencies", default = false, type = "boolean"})
    add_configs("export_c_api", {description = "Keep the static C API visible for relinking into a shared library", default = false, type = "boolean"})

    add_configs("simulate", {description = "Build simulate library for MuJoCo", default = false, type = "boolean"})
    add_configs("usd", {description = "Build with OpenUSD", default = false, type = "boolean"})

    add_links("simulate", "mujoco")

    add_deps("cmake")
    if is_subhost("windows") then
        add_deps("pkgconf")
    else
        add_deps("pkg-config")
    end
    add_deps("libccd", {configs = {double_precision = true}})
    add_deps("lodepng", "qhull", "tinyobjloader", "tinyxml2", "trianglemeshdistance", "marchingcubecpp")

    if on_check then
        on_check(function (package)
            local version = package:version()
            if package:is_plat("android") then
                local ndk = package:toolchain("ndk")
                local ndk_sdkver = ndk:config("ndk_sdkver")
                assert(ndk_sdkver and tonumber(ndk_sdkver) > 21, "package(mujoco) require ndk api level > 21")
            end
            if package:gitref() or (version and version:ge("3.5.0")) then
                if not package:check_cxxsnippets({test = [[
                    #include <string_view>
                    void test() {
                        const char xml[] = "x";
                        auto consume = [](std::string_view) {};
                        consume({xml, xml + 1});
                    }
                ]]}, {configs = {languages = "c++20"}}) then
                    raise("package(mujoco >=3.5.0) unsupported current platform: C++20 std::string_view iterator constructor is unavailable")
                end
            end
        end)
    end

    on_load(function (package)
        if package:config("merge_static") then
            assert(not package:config("shared"), "merge_static requires shared=false")
            assert(not package:config("simulate") and not package:config("usd"),
                "merge_static currently supports the core MuJoCo package only")
        end
        if package:gitref() or package:version():ge("3.9.0") then
            package:add("deps", "miniz", {configs = {cmake = true}})
        end
        if package:config("usd") then
            package:add("deps", "usd")
            package:add("defines", "mjUSEUSD")
        end
        if package:config("simulate") then
            package:add("deps", "glfw")
        end

        if not package:config("shared") then
            package:add("defines", "MJ_STATIC")
        end
    end)

    on_install("!wasm and !bsd", function (package)
        if package:dep("qhull"):config("shared") then
            -- TODO: patch cmake target_link_libraries
            raise("package(mujoco) unsupported shared qhull library")
        end

        -- support static build
        io.replace("CMakeLists.txt", "add_library(mujoco SHARED", "add_library(mujoco ", {plain = true})
        -- remove fetch content
        local dependencies = ""
        if package:gitref() or package:version():ge("3.9.0") then
            dependencies = [[
                find_package(miniz CONFIG REQUIRED)
                find_package(tinyobjloader CONFIG REQUIRED)
                add_library(miniz ALIAS miniz::miniz)
                add_library(tinyobjloader ALIAS tinyobjloader::tinyobjloader)
            ]]
        end
        io.replace("CMakeLists.txt", "include(MujocoDependencies)", dependencies, {plain = true})
        -- remove hardcode ccd and dynamic library export macro
        io.replace("CMakeLists.txt", "CCD_STATIC_DEFINE MUJOCO_DLL_EXPORTS", "", {plain = true})
        -- remove unused install target
        io.replace("CMakeLists.txt", "list(APPEND MUJOCO_TARGETS lodepng)", "", {plain = true})
        if package:is_plat("mingw") then
            -- mujoco.rc:23: syntax error
            io.replace("CMakeLists.txt", "set(MUJOCO_RESOURCE_FILES ${CMAKE_CURRENT_SOURCE_DIR}/dist/mujoco.rc)", "", {plain = true})
            -- remove /STACK:16777216
            io.replace("cmake/MujocoLinkOptions.cmake", "if(WIN32)", "if(0)", {plain = true})
            io.replace("simulate/cmake/MujocoLinkOptions.cmake", "if(WIN32)", "if(0)", {plain = true})
        end

        io.replace("cmake/MujocoOptions.cmake", "set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)", "", {plain = true})
        io.replace("simulate/cmake/SimulateOptions.cmake", "set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)", "", {plain = true})

        io.replace("cmake/MujocoOptions.cmake", "-Werror", "", {plain = true})
        io.replace("simulate/cmake/SimulateOptions.cmake", "-Werror", "", {plain = true})

        if package:is_plat("windows") and not package:is_arch64() and
            (package:gitref() or package:version():ge("3.10.0")) then
            -- size_t is 32-bit, but upstream unconditionally uses the 64-bit MSVC intrinsic
            io.replace("src/engine/engine_crossplatform.h",
                "_InterlockedExchangeAdd64((__int64 volatile*)(ptr), (__int64)(val))",
                "_InterlockedExchangeAdd((long volatile*)(ptr), (long)(val))", {plain = true})
        end

        io.replace("src/user/user_mesh.cc", [[#include "qhull_ra.h"]], "#include <libqhull_r/qhull_ra.h>", {plain = true})
        io.replace("src/user/user_mesh.cc",
            "#include <TriangleMeshDistance/include/tmd/TriangleMeshDistance.h>",
            "#include <tmd/TriangleMeshDistance.h>", {plain = true})

        io.replace("CMakeLists.txt", [[target_link_libraries(
  mujoco
  PRIVATE ccd
          lodepng
          qhullstatic_r
          tinyobjloader
          tinyxml2
)]], "", {plain = true})

        local file = io.open("CMakeLists.txt", "a")
        if file then
            file:print([[
                if (BUILD_SHARED_LIBS OR MUJOCO_EXPORT_STATIC_API)
                    target_compile_definitions(mujoco PRIVATE MUJOCO_DLL_EXPORTS)
                    if (NOT BUILD_SHARED_LIBS)
                        target_compile_definitions(mujoco INTERFACE MJ_STATIC)
                    endif()
                else()
                    target_compile_definitions(mujoco PUBLIC MJ_STATIC)
                endif()
                
                find_package(ccd CONFIG REQUIRED)
                include(FindPkgConfig)
                pkg_search_module("lodepng" REQUIRED IMPORTED_TARGET "lodepng")
                find_package(Qhull CONFIG REQUIRED)
                find_package(tinyobjloader CONFIG REQUIRED)
                find_package(tinyxml2 CONFIG REQUIRED)
                pkg_search_module("trianglemeshdistance" REQUIRED IMPORTED_TARGET "trianglemeshdistance")
                pkg_search_module("marchingcubecpp" REQUIRED IMPORTED_TARGET "marchingcubecpp")
                target_link_libraries(mujoco PRIVATE
                    ccd
                    PkgConfig::lodepng
                    Qhull::qhullstatic_r
                    tinyobjloader::tinyobjloader
                    tinyxml2::tinyxml2
                    PkgConfig::trianglemeshdistance
                    PkgConfig::marchingcubecpp
                )
            ]])
            file:close()
        end

        if package:config("simulate") then
        -- remove fetch content
            io.replace("simulate/CMakeLists.txt", "include(SimulateDependencies)", "", {plain = true})
            io.replace("simulate/CMakeLists.txt", "if(NOT TARGET lodepng)", "if(0)", {plain = true})
            io.replace("simulate/CMakeLists.txt",
                "add_library(libmujoco_simulate STATIC $<TARGET_OBJECTS:platform_ui_adapter> $<TARGET_OBJECTS:lodepng>)",
                [[
                    add_library(libmujoco_simulate STATIC $<TARGET_OBJECTS:platform_ui_adapter>)
                    include(FindPkgConfig)
                    pkg_search_module("lodepng" REQUIRED IMPORTED_TARGET "lodepng")
                    find_package(Qhull CONFIG REQUIRED)
                    find_package(glfw3 REQUIRED CONFIG)
                    target_link_libraries(libmujoco_simulate PRIVATE PkgConfig::lodepng Qhull::qhullstatic_r)
                ]], {plain = true})
        end

        local configs = {
            "-DMUJOCO_BUILD_EXAMPLES=OFF",
            "-DMUJOCO_BUILD_TESTS=OFF",
            "-DMUJOCO_BUILD_TESTS_WASM=OFF",
            "-DMUJOCO_SIMULATE_USE_SYSTEM_GLFW=ON",
        }
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DMUJOCO_EXPORT_STATIC_API=" .. (package:config("export_c_api") and "ON" or "OFF"))
        table.insert(configs, "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=" .. (package:config("lto") and "ON" or "OFF"))

        table.insert(configs, "-DMUJOCO_BUILD_SIMULATE=" .. (package:config("simulate") and "ON" or "OFF"))
        table.insert(configs, "-DMUJOCO_WITH_USD=" .. (package:config("usd") and "ON" or "OFF"))

        local opt = {}
        opt.cxflags = {}
        if package:has_tool("cc", "gcc") or package:is_plat("wasm") then
            table.insert(opt.cxflags, "-Wno-error=incompatible-pointer-types")
        end
        if package:is_plat("android", "bsd", "mingw") then
            -- src/engine/engine_util_errmem.c:107:6: error: #error "Thread-safe version of `localtime` is not present in the standard C library"
            table.insert(opt.cxflags, "-D_POSIX_C_SOURCE=200112L")
        end
        import("package.tools.cmake").install(package, configs, opt)

        if package:config("merge_static") then
            import("core.project.target")
            import("utils.archive.merge_staticlib")
            local filename = target.filename("mujoco", "static", {plat = package:plat(), arch = package:arch()})
            local output = package:installdir("lib", filename)
            assert(os.isfile(output), "MuJoCo static archive was not installed: " .. output)
            local archives = {output}
            -- MuJoCo 3.12 embeds TinyObjLoader in obj_decoder.cc. Its external
            -- archive must not be merged again. Qhull's non-reentrant and C++
            -- variants likewise contain symbols that conflict with qhullstatic_r.
            for _, name in ipairs({"libccd", "lodepng", "qhull", "tinyxml2", "miniz"}) do
                local dependency = package:dep(name)
                if dependency then
                    assert(not dependency:config("shared"), "merge_static requires static dependency: " .. name)
                    local fetched = assert(dependency:fetch(), "Missing dependency: " .. name)
                    for _, library in ipairs(table.wrap(fetched.libfiles)) do
                        local extension = path.extension(library)
                        local basename = path.basename(library):gsub("^lib", "")
                        if (extension == ".a" or extension == ".lib") and
                           (name ~= "qhull" or basename == "qhullstatic_r") then
                            table.insert(archives, library)
                        end
                    end
                end
            end
            local temporary = os.tmpfile() .. path.extension(output)
            merge_staticlib(package, temporary, table.unique(archives))
            os.cp(temporary, output)
            os.rm(temporary)
        end
    end)

    on_test(function (package)
        assert(package:has_cfuncs("mjv_defaultCamera", {includes = "mujoco/mujoco.h"}))
        assert(package:has_cfuncs("mj_stackAllocByte", {includes = "mujoco/mujoco.h"}))
    end)
