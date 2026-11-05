#include <mujoco/mujoco.h>
#include <iostream>

int main(int argc, char** argv) {
  std::cout << "MuJoCo version: " << mj_version() << std::endl;
  std::cout << "MuJoCo version string: " << mj_versionString() << std::endl;
  return 0;
}
