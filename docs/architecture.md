# MuJoCo native / web / Flutter 分层

| 包 | 类型与职责 | 不负责的内容 |
| --- | --- | --- |
| `mujoco` | 纯 Dart 数值接口、native FFI、JS 互操作、资源生命周期、编译后的模型/几何数据 | Flutter、WASM 分发、场景绘制 |
| `mujoco_web` | Flutter 包；锁定版本的官方 JS/WASM 资产及浏览器异步加载 | 业务数值 API、viewer |
| `mujoco_flutter` | Flutter 包；初始化 native/web 后端、导出公共数值 API | 绘制与策略控制 |
| `mujoco_viewer` | Flutter 包；将公共模型几何和数据位姿映射到 Flutter Scene，提供相机与 Widget | Python、直接读写 native 指针、自动替用户控制机器人 |

依赖方向为 `mujoco_viewer → mujoco_flutter → {mujoco, mujoco_web}`；viewer 的实际绘制实现只访问 `mujoco` 的公共模型/数据接口与 Flutter Scene。没有反向依赖。独立数值程序只依赖 `mujoco` 即可。四个包和 examples/viewer 现在由独立 mujoco_dart 仓库的根 pub workspace 管理。

## 初始化与加载

- Native：纯 Dart `MjModel.from_xml_path/from_xml_string` 可以直接使用；Flutter 的 `initialize` 是 no-op。
- Web：`mujoco_web` 加载随 Flutter 发布的 ESM + WASM，`mujoco_flutter` 通过标记为 `@internal` 的内部接入点注册加载结果。初始化完成后公共模型工厂和物理步进保持同步。
- `mujoco` 面向应用只公开 `mujoco.dart`。JS 注册由平台接入包内部完成；生成的 FFI 绑定、native 指针和 JS 后端类不作为公开入口分发。
- Flutter 资产由应用读取 AssetBundle 后显式填入 `MjVfs`；包只负责初始化，不提供 `loadAsset`。包含文件、mesh、纹理的传递依赖需显式提供。原生可读取磁盘路径；显式传入 VFS 时两端都可按虚拟路径加载，Web 不读取宿主磁盘。
- WASM 采用单线程版，无需 COOP/COEP；分发版本与 native 同为 3.12.0。JS 包的 bool 内存视图注册缺陷有窄兼容补丁、可复现脚本和原始/补丁后 SHA-256 记录；WASM 字节不变。

`MjVfs` 是 `mujoco` 暴露的跨平台内存文件系统；native 持有 `mjVFS`，web 持有官方 JS/WASM 的 `MjVFS`。应用可以添加 XML、include、mesh 和 texture 的字节，通过 `from_xml_path(path, vfs: vfs)` 或 `from_xml_string(xml, vfs: vfs)` 编译。文件添加时复制，模型编译后不依赖 VFS 生命周期；VFS 由调用者显式释放。资源只通过显式 `vfs` 提供，不再提供 `assets` 参数。

`MjModel.from_xml_string/from_xml_path` 保留为直观工厂。底层同时公开 `mj_loadXML`、`mj_parseXMLString` → `MjSpec` → `mj_compile`，可独立管理解析和编译；spec 与编译后的 model 生命周期独立，均显式释放。

示例支持 native/web 文件与目录拖放。应用读取完整目录，保留相对路径填入共享 VFS；按路径排序展示 XML 列表，默认加载第一项并允许切换。拖放读取完成后不再依赖平台提供方句柄。

## 数值与显示的数据边界

数值状态由 `MjModel/MjData` 拥有；`mj_step` 只计算物理，`mj_forward` 把积分后的状态同步到 geom 世界位姿。Viewer 只读取编译后的 mesh、材料和 `geom_xpos/geom_xmat`，不重新解析 MJCF、不重复实现关节运动学。Z-up 到 Y-up 的变换只在显示世界根节点进行一次。

model/data 仅通过显式、幂等的 `dispose()` 释放；数组和位姿视图不拥有内存，不单独释放。没有自动作用域跟踪，也没有 detach/promote API。

`geomById/meshById` 返回与平台无关的数据；native 指针与生成的 FFI 绑定保留在 `lib/src` 实现层。数据的实时借用视图在 owner 释放后拒绝访问。公共物理函数拒绝 model/data 不配对的调用。Web 视图每次访问时重新取得 WASM typed array，避免内存增长后持有失效的视图。

`MujocoViewer(model:, states:, initialState:, controller:)` 消费 `Stream<MjSceneState>`，不再接收 data 或通过 onTick 驱动物理。`MjSceneState` 是纯 Dart、无指针、拥有内存的不可变位姿快照；数值对象没有内置通知。Viewer 合并多次状态更新，在自己的下一帧只应用最新状态。Widget 管理订阅和默认创建的 controller；外部 controller 由调用者管理。示例使用独立定时器推进物理、批量发布快照，暂停/单步/重置沿用相同状态流；定时器仍在 UI isolate。`examples/viewer/lib/simulation.dart` 仅为示例内部的播放控制，不属于任何包的公开 API。停止状态生产并卸载 Widget 后，再释放外部 controller、data 和 model。

Viewer 通过 `onStats` 按约一秒窗口输出渲染 tick FPS 与平均帧间隔；`maxFrameRate` 只限制渲染。相机操作通过 controller 的 `orbit`、`camera` 和 `frameModel()` 提供，`focusOn(x:, y:, z:)` 使用 MuJoCo Z-up 坐标。

## 本次移除与保留

- 删除 MuJoCo Python backend、`python.dart`、`Mujoco.useNativeApi` 以及 Python passive viewer。
- 移除这四个包的 `py_embed` 依赖。Torch 等其他 Cave 包继续保留各自的 Python 支持。
- 本仓库 examples/viewer 示例改为使用这四个包，不再有私有 native 指针渲染适配。
- 按用户要求，robot_engine 旧 viewer 示例注释保留、暂不迁移成 Flutter 应用；CLI 暂只支持 headless。数值调用改用默认 native 后端。

## 验证与限制

已验证 Linux x64 native 与 Chromium Web：数值步进、资源释放、控制数组、传感器、VFS 模型资产、mesh 与共享 Viewer。原生 AOT 资产裁剪脚本验证了“使用原生调用时打包库、未使用时移除库”。

单元/回归测试：核心包 20 项、Flutter 资产接入 1 项、Viewer 15 项、实验应用 13 项；浏览器 smoke 另有物理/数组/元数据/VFS/绘制检查。浏览器测试入口和日志位于示例 `examples/viewer/tool/web_smoke_app.dart`、`examples/viewer/tool/run_web_smoke.mjs`、`examples/viewer/docs/web_smoke_result.json`。

尚未实现完整原生 MuJoCo viewer 的所有功能。非平面纹理、cube/skybox、原模型照明、hfield/flex/tendon、接触力箭头等仍待扩展；无限地面使用覆盖视锥、随相机移动的网格，并按纹理周期对齐；模型的物理位姿不变。地面已接入模型编译后的 2D 纹理与 texrepeat/texuniform，不再强制覆盖颜色或添加厚度。没有站立策略或稳定控制器，机器人按 Run 后可能倒地。数值循环仍在调用者 isolate；后续可把 native 数值放到独立 isolate、Web 数值放到 worker，再通过位姿快照同步 Viewer。其他 native 平台尚未实机验证。

补充验证：常规实验应用也通过 `flutter build web --wasm`，Chromium 确认实际加载 `main.dart.wasm` 与 MuJoCo WASM，仿真时间正常推进且无未捕获异常。数值/Flutter 回归测试全部通过，四个包和实验应用的严格静态分析通过。

robot_engine 仅做旧入口停用与 native 默认后端兼容：受影响文件静态分析通过。CLI `--help` 的运行检查被已有 `horizon_robotics_can` 的 Linux ARM64-only 构建钩子阻止；x64 主机需要该硬件包的 HAL mock，本次未修改硬件层。没有声称在当前主机完成真实机器人策略或 headless CLI 运行验证。

拖放验证：Chromium 中实际拖入文件夹，检查相对 include/mesh、默认第一项 XML 和侧栏切换到第二项，未发现运行时异常。截图与结果为 `examples/viewer/docs/drop_preview.png` 和 `drop_smoke_result.json`。

地面纹理：`MjGeomInfo` 提供基础色纹理索引及重复参数，`MjTextureInfo` 复制编译后的像素和颜色空间。Viewer 在本地 XY 平面按 MuJoCo 3.12 classic 的 UV 规则采样，保留 geom 的位姿；线性色彩在上传到 Scene 前转换为 sRGB，贴图使用 mipmap 过滤。纹理按 controller 缓存，释放时清理节点和缓存引用。
