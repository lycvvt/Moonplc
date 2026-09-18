(* 工业经典案例 05: 水箱恒温闭环 PID 控制系统 *)
PROGRAM TemperatureControl
VAR
  Temp_SP       : REAL := 65.0;            (* 目标设定温度: 65.0°C *)
  Temp_PV       AT %IW0 : REAL := 20.0;    (* 现场 PT100 传感器采集温度 *)
  Heater_Output AT %QW0 : REAL := 0.0;     (* 可控硅加热器输出功率 (0~100%) *)
  Cooling_Valve AT %QX0.0 : BOOL := FALSE; (* 应急冷却电磁阀 *)
  Temp_Alarm    AT %QX0.1 : BOOL := FALSE; (* 超温上限报警灯 *)
END_VAR

(* 超温安全连锁保护 *)
IF Temp_PV > 80.0 THEN
  Temp_Alarm := TRUE;
  Cooling_Valve := TRUE;
  Heater_Output := 0.0;
ELSE
  Temp_Alarm := FALSE;
  Cooling_Valve := FALSE;
END_IF;
END_PROGRAM
