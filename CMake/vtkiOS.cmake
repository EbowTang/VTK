include(ExternalProject)

# Convenience variables
set(PREFIX_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Prefix)
set(BUILD_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Build)
set(INSTALL_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Install)

# First, determine how to build
if (CMAKE_GENERATOR MATCHES "NMake Makefiles")
  set(VTK_BUILD_COMMAND BUILD_COMMAND nmake)
elseif (CMAKE_GENERATOR MATCHES "Ninja")
  set(VTK_BUILD_COMMAND BUILD_COMMAND ninja)
else()
  set(VTK_BUILD_COMMAND BUILD_COMMAND make)
endif()

# Compile a minimal VTK for its compile tools
macro(compile_vtk_tools)
  ExternalProject_Add(
    vtk-compile-tools
    SOURCE_DIR ${CMAKE_SOURCE_DIR}
    PREFIX ${PREFIX_DIR}/vtk-compile-tools
    BINARY_DIR ${BUILD_DIR}/vtk-compile-tools
    ${VTK_BUILD_COMMAND} vtkCompileTools
    CMAKE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=Release
      -DVTK_BUILD_ALL_MODULES:BOOL=OFF
      -DVTK_Group_Rendering:BOOL=OFF
      -DVTK_Group_StandAlone:BOOL=ON
      -DBUILD_SHARED_LIBS:BOOL=ON
      -DBUILD_EXAMPLES:BOOL=OFF
      -DBUILD_TESTING:BOOL=OFF
  )
endmacro()
compile_vtk_tools()

# Okay, now set options for iOS
set(OPENGL_ES_VERSION "2.0" CACHE STRING "OpenGL ES version (2.0 or 3.0)")
set_property(CACHE OPENGL_ES_VERSION PROPERTY STRINGS 2.0 3.0)

set(IOS_SIMULATOR_ARCHITECTURES "i386;x86_64"
    CACHE STRING "iOS Simulator Architectures")
set(IOS_DEVICE_ARCHITECTURES "arm64;armv7;armv7s"
    CACHE STRING "iOS Device Architectures")

set(CMAKE_FRAMEWORK_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/frameworks"
    CACHE PATH "Framework install path")

# Hide some CMake configs from the user
mark_as_advanced(
  BUILD_SHARED_LIBS
  CMAKE_INSTALL_PREFIX
  CMAKE_OSX_ARCHITECTURES
  CMAKE_OSX_DEPLOYMENT_TARGET
  CMAKE_OSX_ROOT
  VTK_RENDERING_BACKEND
)


# Now cross-compile VTK with custom toolchains
set(ios_cmake_flags
  -DBUILD_SHARED_LIBS:BOOL=OFF
  -DBUILD_TESTING:BOOL=OFF
  -DBUILD_EXAMPLES:BOOL=ON
  -DVTK_RENDERING_BACKEND:STRING=OpenGL2
  -DVTK_Group_Rendering:BOOL=OFF
  -DVTK_Group_StandAlone:BOOL=OFF
  -DVTK_Group_Imaging:BOOL=OFF
  -DVTK_Group_MPI:BOOL=OFF
  -DVTK_Group_Views:BOOL=OFF
  -DVTK_Group_Qt:BOOL=OFF
  -DVTK_Group_Tk:BOOL=OFF
  -DVTK_Group_Web:BOOL=OFF
  -DModule_vtkFiltersCore:BOOL=ON
  -DModule_vtkFiltersModeling:BOOL=ON
  -DModule_vtkFiltersSources:BOOL=ON
  -DModule_vtkFiltersGeometry:BOOL=ON
  -DModule_vtkIOGeometry:BOOL=ON
  -DModule_vtkIOLegacy:BOOL=ON
  -DModule_vtkIOImage:BOOL=ON
  -DModule_vtkIOPLY:BOOL=ON
  -DModule_vtkIOInfovis:BOOL=ON
  -DModule_vtkImagingCore:BOOL=ON
  -DModule_vtkParallelCore:BOOL=ON
  -DModule_vtkRenderingCore:BOOL=ON
  -DModule_vtkRenderingFreeType:BOOL=OFF
)

macro(crosscompile target toolchain_file archs)
  ExternalProject_Add(
    vtk-${target}
    SOURCE_DIR ${CMAKE_SOURCE_DIR}
    PREFIX ${PREFIX_DIR}/vtk-${target}
    BINARY_DIR ${BUILD_DIR}/vtk-${target}
    INSTALL_DIR ${INSTALL_DIR}/vtk-${target}
    DEPENDS vtk-compile-tools
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX:PATH=${INSTALL_DIR}/vtk-${target}
      -DCMAKE_CROSSCOMPILING:BOOL=ON
      #-DCMAKE_OSX_ARCHITECTURES:STRING=${archs}
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_TOOLCHAIN_FILE:FILEPATH=CMake/${toolchain_file}
      -DVTKCompileTools_DIR:PATH=${BUILD_DIR}/vtk-compile-tools
      ${ios_cmake_flags}
  )
endmacro()
crosscompile(ios-simulator
  ios.simulator.toolchain.cmake
  "${IOS_SIMULATOR_ARCHITECTURES}"
 )
crosscompile(ios-device
  ios.device.toolchain.cmake
  "${IOS_DEVICE_ARCHITECTURES}"
)

# Pile it all into a framework
set(VTK_DEVICE_LIBS
    "${INSTALL_DIR}/vtk-ios-device/lib/libvtk*.a")
set(VTK_SIMULATOR_LIBS
    "${INSTALL_DIR}/vtk-ios-simulator/lib/libvtk*.a")
set(VTK_INSTALLED_HEADERS
    "${INSTALL_DIR}/vtk-ios-device/${VTK_INSTALL_INCLUDE_DIR}")
configure_file(CMake/MakeFramework.cmake.in
               ${CMAKE_CURRENT_BINARY_DIR}/CMake/MakeFramework.cmake
               @ONLY)
add_custom_target(vtk-framework ALL COMMAND ${CMAKE_COMMAND} -P
                  ${CMAKE_CURRENT_BINARY_DIR}/CMake/MakeFramework.cmake)
