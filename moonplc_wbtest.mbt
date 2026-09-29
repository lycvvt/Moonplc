///|
/// 测试 MoonPLC 顶层统一 Facade API
test "moonplc facade full workflow" {
  let plc = MoonPlc::new("IndustrialUnit_1")

  let st_code =
    #|PROGRAM AutoPackaging
    #|VAR
    #|  Sensor_Box AT %IX0.0 : BOOL := FALSE;
    #|  Pusher_Arm AT %QX0.0 : BOOL := FALSE;
    #|  Box_Counter : INT := 0;
    #|END_VAR
    #|
    #|IF Sensor_Box THEN
    #|  Pusher_Arm := TRUE;
    #|  Box_Counter := Box_Counter + 1;
    #|ELSE
    #|  Pusher_Arm := FALSE;
    #|END_IF;
    #|END_PROGRAM
  plc.load_st(st_code)

  // 初始状态
  plc.cycle(10L)
  assert_eq(plc.get_output_bool("%QX0.0"), false)
  assert_eq(plc.get_var("Box_Counter").to_int(), 0)

  // 传感器检测到物料
  plc.set_input_bool("%IX0.0", true)
  plc.cycle(10L)
  assert_eq(plc.get_output_bool("%QX0.0"), true)
  assert_eq(plc.get_var("Box_Counter").to_int(), 1)

  // 物料离开
  plc.set_input_bool("%IX0.0", false)
  plc.cycle(10L)
  assert_eq(plc.get_output_bool("%QX0.0"), false)
  assert_eq(plc.get_var("Box_Counter").to_int(), 1)

  assert_eq(plc.cycle_count(), 3L)
  assert_eq(plc.current_time_ms(), 30L)
}
