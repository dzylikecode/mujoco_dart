"""MuJoCo Python 基础示例。

这个例子只使用老版本 MuJoCo Python binding 中最基础、最稳定的 API：

    MjModel.from_xml_string
    MjData
    mj_forward
    mj_step

运行：

    python py_demo/basic.py
"""

import mujoco


# MJCF 是 MuJoCo 使用的模型描述格式。
# 这里创建一个最简单的单摆，并通过 motor 对关节施加控制量。
MODEL_XML = """
<mujoco model="basic_pendulum">
  <option timestep="0.002" gravity="0 0 -9.81"/>

  <worldbody>
    <geom name="floor" type="plane" size="2 2 0.1"/>

    <body name="pendulum" pos="0 0 1">
      <joint
        name="hinge"
        type="hinge"
        axis="0 1 0"
        damping="0.05"
      />
      <geom
        name="pole"
        type="capsule"
        fromto="0 0 0 0 0 -0.8"
        size="0.04"
        mass="1"
      />
    </body>
  </worldbody>

  <actuator>
    <motor name="hinge_motor" joint="hinge" gear="1"/>
  </actuator>
</mujoco>
"""


def main():
    print("MuJoCo version:", getattr(mujoco, "__version__", "unknown"))

    # MjModel 保存编译后的静态模型。
    model = mujoco.MjModel.from_xml_string(MODEL_XML)

    # MjData 保存某一次仿真的动态状态。
    # 同一个 model 可以创建多个相互独立的 data。
    data = mujoco.MjData(model)

    print("model.nq =", model.nq, "  # qpos 的长度")
    print("model.nv =", model.nv, "  # qvel/qacc 的长度")
    print("model.nu =", model.nu, "  # ctrl 的长度")

    # 设置初始关节角度。qpos 是 NumPy 数组，并直接映射 MuJoCo 内存。
    data.qpos[0] = 0.4

    # 修改 qpos/qvel 后，调用 forward 重新计算派生结果；
    # 它不会推进仿真时间。
    mujoco.mj_forward(model, data)

    print("\ninitial state")
    print("time =", data.time)
    print("qpos =", data.qpos.copy())
    print("qvel =", data.qvel.copy())

    # ctrl 对应 actuator 的输入。这里 motor 只有一个，所以 ctrl 长度为 1。
    data.ctrl[0] = 0.1

    step_count = 1000
    for step in range(step_count):
        # mj_step 会计算动力学，并把仿真推进一个 model.opt.timestep。
        mujoco.mj_step(model, data)

        if step % 100 == 0:
            print(
                "step={:4d} time={:.3f} qpos={:.6f} qvel={:.6f}".format(
                    step,
                    data.time,
                    data.qpos[0],
                    data.qvel[0],
                )
            )

    print("\nfinal state")
    print("time =", data.time)
    print("qpos =", data.qpos.copy())
    print("qvel =", data.qvel.copy())
    print("qacc =", data.qacc.copy())
    print("ctrl =", data.ctrl.copy())


if __name__ == "__main__":
    main()
