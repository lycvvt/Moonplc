(* 工业经典案例 03: 自动化传送带物料感应与气动推杆分拣系统 *)
PROGRAM ConveyorSorting
VAR
  Sensor_Item AT %IX0.0 : BOOL := FALSE; (* 光电检测传感器 *)
  Belt_Motor  AT %QX0.0 : BOOL := TRUE;  (* 主传送带电机 *)
  Piston_Push AT %QX0.1 : BOOL := FALSE; (* 气动推杆阀门 *)
  Item_Count  : INT := 0;                (* 物料累计计数 *)
  Piston_Timer : TP;                     (* 气缸脉冲定时器 *)
END_VAR

(* 检测到物料时触发气动推杆脉冲 *)
Piston_Timer(IN := Sensor_Item, PT := T#500ms);
Piston_Push := Piston_Timer.Q;

IF Sensor_Item THEN
  Item_Count := Item_Count + 1;
END_IF;
END_PROGRAM
