(* 工业经典案例 01: 电机自锁起保停控制系统 *)
PROGRAM MotorStartStop
VAR
  Start_Btn AT %IX0.0 : BOOL := FALSE; (* 启动按钮 (常开) *)
  Stop_Btn  AT %IX0.1 : BOOL := FALSE; (* 停止按钮 (常闭输入) *)
  Motor_Run AT %QX0.0 : BOOL := FALSE; (* 电机接触器输出 *)
  Fault_Led AT %QX0.1 : BOOL := FALSE; (* 故障指示灯 *)
END_VAR

(* 梯形图等价自锁逻辑 *)
Motor_Run := (Start_Btn OR Motor_Run) AND NOT Stop_Btn;
END_PROGRAM
