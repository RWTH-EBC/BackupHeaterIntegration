within OptimalBackupHeaterIntegration.Models;
model DiscreteHysteresisController "Controller for a discrete device"
  extends
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController;
  parameter Boolean use_ownHys;
  parameter Integer nSteps;
  parameter Modelica.Units.SI.TemperatureDifference dTHys "Hysteresis temperature";
  parameter Real P "Gain of PID-controller";
  parameter Real yMax=1 "Upper limit of output";
  parameter Real yOff=0 "Constant output value if device is turned off";
  parameter Real y_start=0 "Initial value of output";
  parameter Real nMin=0.5 "Lower limit of compressor frequency - default 0.5";
  parameter Real n_opt "Frequency of the heat pump map with an optimal isentropic efficiency. Necessary, as on-off HP will be optimized for this frequency and only used there.";
  parameter Modelica.Units.SI.Time T_I "Time constant of Integrator block";
  parameter Modelica.Units.SI.Time T_D "Time constant of Derivative block";
  parameter Real Ni=0.9 "Ni*Ti is time constant of anti-windup compensation";
  parameter Real Nd=10 "The higher Nd, the more ideal the derivative block";
  Modelica.Blocks.Sources.Constant const(final k=0) "Device turned off"
    annotation (Placement(transformation(extent={{20,-40},{40,-20}})));
  Modelica.Blocks.Logical.Switch onOffSwitch
    annotation (Placement(transformation(extent={{60,-10},{80,10}})));
  Modelica.Blocks.Logical.Hysteresis hysteresis[nSteps](
    each final uLow=0,
    uHigh={dTHys/nSteps*n for n in 1:nSteps},
    each final pre_y_start=false) if nSteps > 1 or (nSteps == 1 and use_ownHys)
    annotation (Placement(transformation(extent={{-40,20},{-20,40}})));
  Modelica.Blocks.Sources.RealExpression realExpression[nSteps](each final y=
        T_Set - T_Meas) if nSteps > 1 or (nSteps == 1 and use_ownHys)
                        "HP turned off"
    annotation (Placement(transformation(extent={{-80,20},{-60,40}})));
  countTrue countTrue1(nSteps=nSteps)
    if nSteps > 1 or (nSteps == 1 and use_ownHys)
    annotation (Placement(transformation(extent={{0,20},{20,40}})));
  Modelica.Blocks.Math.Gain    gain(k=1/nSteps)
    if nSteps > 1 or (nSteps == 1 and use_ownHys)
                                       "Square the difference"
annotation (Placement(transformation(extent={{40,20},{60,40}})));
  BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.LimPID
    PID(
    controllerType=controllerType,
    Ti=T_I,
    final Ni=Ni,
    final k=P,
    final yMax=yMax,
    final yMin=nMin,
    final wp=1,
    final Td=T_D,
    final Nd=Nd,
    final wd=0,
    final initType=Modelica.Blocks.Types.Init.InitialState,
    homotopyType=Modelica.Blocks.Types.LimiterHomotopy.NoHomotopy,
    final strict=false,
    final xi_start=0,
    final xd_start=0,
    final y_start=y_start,
    final limitsAtInit=true) if nSteps == 0
    annotation (Placement(transformation(extent={{-20,-40},{0,-20}})));
  Modelica.Blocks.Logical.And and1 if nSteps == 0
    annotation (Placement(transformation(extent={{-60,-80},{-40,-60}})));
  parameter Modelica.Blocks.Types.SimpleController controllerType=Modelica.Blocks.Types.SimpleController.PI
    "Type of controller";
  Modelica.Blocks.Math.BooleanToReal booleanToReal
    if nSteps == 1 and not use_ownHys
    annotation (Placement(transformation(extent={{-40,54},{-20,74}})));
equation
  connect(const.y,onOffSwitch. u3)
    annotation (Line(points={{41,-30},{50,-30},{50,-8},{58,-8}},
                                                            color={0,0,127}));
  connect(HP_On,onOffSwitch. u2) annotation (Line(points={{-120,0},{58,0}},
                      color={255,0,255}));
  connect(onOffSwitch.y, n_Set)
    annotation (Line(points={{81,0},{110,0}}, color={0,0,127}));
  connect(realExpression.y, hysteresis.u)
    annotation (Line(points={{-59,30},{-42,30}}, color={0,0,127}));
  connect(hysteresis.y, countTrue1.u)
    annotation (Line(points={{-19,30},{-1,30}}, color={255,0,255}));
  connect(countTrue1.y, gain.u)
    annotation (Line(points={{21,30},{38,30}}, color={0,0,127}));
  connect(gain.y, onOffSwitch.u1) annotation (Line(points={{61,30},{72,30},{72,14},
          {58,14},{58,8}}, color={0,0,127}));
  connect(and1.y,PID. IsOn) annotation (Line(points={{-39,-70},{-16,-70},{-16,-42}},
                        color={255,0,255}));
  connect(PID.y, onOffSwitch.u1) annotation (Line(points={{1,-30},{10,-30},{10,8},
          {58,8}}, color={0,0,127}));
  connect(T_Meas, PID.u_m) annotation (Line(points={{0,-120},{0,-50},{-10,-50},{
          -10,-42}}, color={0,0,127}));
  connect(T_Set, PID.u_s) annotation (Line(points={{-120,60},{-80,60},{-80,-30},
          {-22,-30}}, color={0,0,127}));
  connect(HP_On, and1.u1) annotation (Line(points={{-120,0},{-94,0},{-94,-70},{-62,
          -70}}, color={255,0,255}));
  connect(IsOn, and1.u2) annotation (Line(points={{-60,-120},{-60,-94},{-78,-94},
          {-78,-78},{-62,-78}}, color={255,0,255}));
  connect(booleanToReal.u, HP_On) annotation (Line(points={{-42,64},{-90,64},{-90,
          0},{-120,0}}, color={255,0,255}));
  connect(booleanToReal.y, onOffSwitch.u1)
    annotation (Line(points={{-19,64},{58,64},{58,8}}, color={0,0,127}));
  annotation (Icon(graphics={
      Line(points={{-100.0,0.0},{-45.0,0.0}},
        color={0,0,127}),
      Ellipse(lineColor={0,0,127},
        fillColor={255,255,255},
        fillPattern=FillPattern.Solid,
        extent={{-45.0,-10.0},{-25.0,10.0}}),
      Line(points={{-35.0,0.0},{30.0,35.0}},
        color={0,0,127}),
      Line(points={{45.0,0.0},{100.0,0.0}},
        color={0,0,127}),
      Ellipse(lineColor={0,0,127},
        fillColor={255,255,255},
        fillPattern=FillPattern.Solid,
        extent={{25.0,-10.0},{45.0,10.0}})}));
end DiscreteHysteresisController;
