///|
/// MoonPLC 命令行交互与工业场景仿真器
fn main {
  println("================================================================")
  println("       __  ___                     ____  __    ______           ")
  println("      /  |/  /___  ____  ____     / __ \\/ /   / ____/           ")
  println("     / /|_/ / __ \\/ __ \\/ __ \\   / /_/ / /   / /                ")
  println("    / /  / / /_/ / /_/ / / / /  / ____/ /___/ /___              ")
  println("   /_/  /_/\\____/\\____/_/ /_/  /_/   /_____/\\____/              ")
  println("================================================================")
  println("   IEC 61131-3 Soft PLC Runtime & Structured Text Simulator     ")
  println("   Pure MoonBit Implementation | WebAssembly & Edge Ready       ")
  println("================================================================\n")

  // -------------------------------------------------------------
  // 场景 1：梯形图编译 - 电机启保停自锁控制
  // -------------------------------------------------------------
  println("[SCENARIO 1] Ladder Diagram: Motor Start-Stop Self-Hold Circuit")
  println("----------------------------------------------------------------")
  println("  Logic: Motor_Run := (Start_Btn OR Motor_Run) AND NOT Stop_Btn;")

  let plc1 = @lib.MoonPlc::new("Motor_Controller")

  let b1 = @lib.LadderNode::Leaf(@lib.Contact::NormallyOpen("Start_Btn"))
  let b2 = @lib.LadderNode::Leaf(@lib.Contact::NormallyOpen("Motor_Run"))
  let parallel_start = @lib.LadderNode::Parallel([b1, b2])
  let stop_contact = @lib.LadderNode::Leaf(
    @lib.Contact::NormallyClosed("Stop_Btn"),
  )
  let full_cond = @lib.LadderNode::Series([parallel_start, stop_contact])

  let rung = @lib.Rung::new(1, "Motor Start-Stop Circuit", full_cond, [
    @lib.Coil::Normal("Motor_Run"),
  ])
  let ld = @lib.LadderDiagram::new("Motor_Ladder")
  ld.add_rung(rung)
  plc1.load_ladder(ld)

  println("\n>> Step 1: Initial state (Buttons idle)")
  plc1.set_var("Start_Btn", @lib.PlcValue::Bool(false))
  plc1.set_var("Stop_Btn", @lib.PlcValue::Bool(false))
  plc1.cycle(10L)
  println(
    "   Cycle: " +
    plc1.cycle_count().to_string() +
    " | Motor_Run = " +
    plc1.get_var("Motor_Run").to_string_repr(),
  )

  println("\n>> Step 2: Press [START] Button (Start_Btn = TRUE)")
  plc1.set_var("Start_Btn", @lib.PlcValue::Bool(true))
  plc1.cycle(10L)
  println(
    "   Cycle: " +
    plc1.cycle_count().to_string() +
    " | Motor_Run = " +
    plc1.get_var("Motor_Run").to_string_repr() +
    " [MOTOR STARTED]",
  )

  println("\n>> Step 3: Release [START] Button (Self-holding active)")
  plc1.set_var("Start_Btn", @lib.PlcValue::Bool(false))
  plc1.cycle(10L)
  println(
    "   Cycle: " +
    plc1.cycle_count().to_string() +
    " | Motor_Run = " +
    plc1.get_var("Motor_Run").to_string_repr() +
    " [SELF-LATCH MAINTAINED]",
  )

  println("\n>> Step 4: Press [STOP] Button (Stop_Btn = TRUE)")
  plc1.set_var("Stop_Btn", @lib.PlcValue::Bool(true))
  plc1.cycle(10L)
  println(
    "   Cycle: " +
    plc1.cycle_count().to_string() +
    " | Motor_Run = " +
    plc1.get_var("Motor_Run").to_string_repr() +
    " [MOTOR STOPPED]",
  )

  // -------------------------------------------------------------
  // 场景 2：ST 语言 - 十字路口交通灯与定时器控制
  // -------------------------------------------------------------
  println("\n================================================================")
  println("[SCENARIO 2] Structured Text: Traffic Light Timing Control")
  println("----------------------------------------------------------------")

  let traffic_st =
    #|PROGRAM TrafficLight
    #|VAR
    #|  Sensor_Car  AT %IX0.0 : BOOL := FALSE;
    #|  Light_Red   AT %QX0.0 : BOOL := TRUE;
    #|  Light_Green AT %QX0.1 : BOOL := FALSE;
    #|  Light_Amber AT %QX0.2 : BOOL := FALSE;
    #|  Timer_Pass  : TON;
    #|END_VAR
    #|
    #|IF Sensor_Car THEN
    #|  Light_Green := TRUE;
    #|  Light_Red   := FALSE;
    #|  Timer_Pass(IN := TRUE, PT := T#100ms);
    #|  IF Timer_Pass.Q THEN
    #|    Light_Green := FALSE;
    #|    Light_Amber := TRUE;
    #|  END_IF;
    #|ELSE
    #|  Light_Red   := TRUE;
    #|  Light_Green := FALSE;
    #|  Light_Amber := FALSE;
    #|END_IF;
    #|END_PROGRAM

  let plc2 = @lib.MoonPlc::new("Traffic_Controller")
  plc2.load_st(traffic_st)

  println(">> Initial: No cars detected")
  plc2.cycle(20L)
  println("   %QX0.0 (RED):   " + plc2.get_output_bool("%QX0.0").to_string())
  println("   %QX0.1 (GREEN): " + plc2.get_output_bool("%QX0.1").to_string())
  println("   %QX0.2 (AMBER): " + plc2.get_output_bool("%QX0.2").to_string())

  println("\n>> Car Arrives! Triggering %IX0.0 = TRUE")
  plc2.set_input_bool("%IX0.0", true)
  plc2.cycle(50L) // 50ms (Timer not reached)
  println(
    "   [At 50ms]  RED = " +
    plc2.get_output_bool("%QX0.0").to_string() +
    " | GREEN = " +
    plc2.get_output_bool("%QX0.1").to_string() +
    " | AMBER = " +
    plc2.get_output_bool("%QX0.2").to_string(),
  )

  plc2.cycle(60L) // 累计 110ms >= 100ms (Timer triggers amber switch)
  println(
    "   [At 110ms] RED = " +
    plc2.get_output_bool("%QX0.0").to_string() +
    " | GREEN = " +
    plc2.get_output_bool("%QX0.1").to_string() +
    " | AMBER = " +
    plc2.get_output_bool("%QX0.2").to_string(),
  )

  println("\n================================================================")
  println("MoonPLC execution simulation completed successfully!")
  println("Ready for WebAssembly browser deployment and edge compilation.")
  println("================================================================")
}
