(* 工业经典案例 02: 道路路口智能交通信号灯顺序控制 *)
PROGRAM TrafficLightControl
VAR
  Car_Present AT %IX0.0 : BOOL := FALSE; (* 地感线圈车辆感应 *)
  Pedestrian  AT %IX0.1 : BOOL := FALSE; (* 行人过街请求按钮 *)
  Light_Red   AT %QX0.0 : BOOL := TRUE;  (* 红灯输出 *)
  Light_Green AT %QX0.1 : BOOL := FALSE; (* 绿灯输出 *)
  Light_Amber AT %QX0.2 : BOOL := FALSE; (* 黄灯输出 *)
  Timer_Pass  : TON;                     (* 通行定时器 *)
END_VAR

(* 交通控制逻辑 *)
IF Car_Present OR Pedestrian THEN
  Light_Red   := FALSE;
  Light_Green := TRUE;
  Timer_Pass(IN := TRUE, PT := T#3000ms);
  
  IF Timer_Pass.Q THEN
    Light_Green := FALSE;
    Light_Amber := TRUE;
  END_IF;
ELSE
  Light_Red   := TRUE;
  Light_Green := FALSE;
  Light_Amber := FALSE;
  Timer_Pass(IN := FALSE, PT := T#3000ms);
END_IF;
END_PROGRAM
