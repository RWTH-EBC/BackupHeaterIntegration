within OptimalBackupHeaterIntegration.Models;
model OperationalEnvelopeLimit
  Modelica.Blocks.Math.UnitConversions.To_degC toDegCT_flow_ev annotation (
      extent=[-88,38; -76,50], Placement(transformation(extent={{-72,18},{-60,30}})));
  AixLib.Controls.Interfaces.VapourCompressionMachineControlBus
                                                sigBusHP
    "Bus-connector for the heat pump"
    annotation (Placement(transformation(extent={{-118,-16},{-84,14}})));
  Modelica.Blocks.Tables.CombiTable1Ds uppCombiTable1Ds(
    table=table,
    smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments,
    final tableOnFile=false)
    annotation (Placement(transformation(extent={{-48,14},{-28,34}})));
  Modelica.Blocks.Interfaces.RealOutput TSetHeatPump
    "Connector of Real output signal containing input signal u in another unit"
    annotation (Placement(transformation(extent={{100,50},{120,70}})));
  Modelica.Blocks.Interfaces.RealInput TSet
    "Connector of Real output signal containing input signal u in another unit"
    annotation (Placement(transformation(extent={{-120,-30},{-100,-10}})));
  Modelica.Blocks.Nonlinear.VariableLimiter variableLimiter
    annotation (Placement(transformation(extent={{20,6},{40,26}})));
  Modelica.Blocks.Math.UnitConversions.From_degC
                                               toDegCT_flow_ev1
                                                               annotation (
      extent=[-88,38; -76,50], Placement(transformation(extent={{-22,18},{-10,30}})));
  Modelica.Blocks.Sources.Constant             toDegCT_flow_ev2(k=273.15)
                                                               annotation (
      extent=[-88,38; -76,50], Placement(transformation(extent={{-30,-8},{-18,4}})));
  Modelica.Blocks.Logical.Hysteresis   hysteresis(uLow=Modelica.Constants.eps*
        10, uHigh=dTOpeEnv/2) if use_opeEncControl
    annotation (Placement(transformation(extent={{58,-30},{78,-10}})));
  Modelica.Blocks.Interfaces.BooleanOutput HeatingRodOn
    "Connector of Real output signal containing input signal u in another unit"
    annotation (Placement(transformation(extent={{100,-30},{120,-10}})));
  Modelica.Blocks.Sources.Constant constdTOpeEnvConst(k=dTOpeEnv) annotation (
      extent=[-88,38; -76,50], Placement(transformation(extent={{-22,40},{-10,
            52}})));
  Modelica.Blocks.Math.Add addDTOpeEnv(k1=-1) annotation (extent=[-88,38; -76,
        50], Placement(transformation(extent={{0,18},{12,30}})));
  parameter Real dTOpeEnv "Constant output value";
  parameter Boolean use_opeEncControl;
  parameter Real table[:,:]=fill(
      0.0,
      0,
      2) "Table matrix (grid = first column; e.g., table=[0, 0; 1, 1; 2, 4])";
  Modelica.Blocks.Math.Add deltaSetLimit(k2=-1) annotation (extent=[-88,38; -76,
        50], Placement(transformation(extent={{34,-14},{46,-26}})));
  Modelica.Blocks.Sources.BooleanConstant      toDegCT_flow_ev4(final k=false)
    if not use_opeEncControl                                   annotation (
      extent=[-88,38; -76,50], Placement(transformation(extent={{0,-60},{20,-40}})));
equation
  connect(sigBusHP.TEvaInMea,toDegCT_flow_ev. u) annotation (Line(
      points={{-100.915,-0.925},{-86,-0.925},{-86,24},{-73.2,24}},
      color={255,204,51},
      thickness=0.5), Text(
      string="%first",
      index=-1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(toDegCT_flow_ev.y, uppCombiTable1Ds.u)
    annotation (Line(points={{-59.4,24},{-50,24}}, color={0,0,127}));
  connect(uppCombiTable1Ds.y[1], toDegCT_flow_ev1.u)
    annotation (Line(points={{-27,24},{-23.2,24}}, color={0,0,127}));
  connect(TSet, variableLimiter.u) annotation (Line(points={{-110,-20},{0,-20},{
          0,16},{18,16}}, color={0,0,127}));
  connect(toDegCT_flow_ev2.y, variableLimiter.limit2) annotation (Line(points={{
          -17.4,-2},{-6,-2},{-6,8},{18,8}}, color={0,0,127}));
  connect(variableLimiter.y, TSetHeatPump) annotation (Line(points={{41,16},{70,
          16},{70,60},{110,60}}, color={0,0,127}));
  connect(hysteresis.y, HeatingRodOn)
    annotation (Line(points={{79,-20},{110,-20}}, color={255,0,255}));
  connect(toDegCT_flow_ev1.y, addDTOpeEnv.u2) annotation (Line(points={{-9.4,24},
          {-8,24},{-8,20},{-6,20},{-6,20.4},{-1.2,20.4}}, color={0,0,127}));
  connect(addDTOpeEnv.y, variableLimiter.limit1)
    annotation (Line(points={{12.6,24},{18,24}}, color={0,0,127}));
  connect(constdTOpeEnvConst.y, addDTOpeEnv.u1) annotation (Line(points={{-9.4,
          46},{-4,46},{-4,27.6},{-1.2,27.6}}, color={0,0,127}));
  connect(hysteresis.u, deltaSetLimit.y)
    annotation (Line(points={{56,-20},{46.6,-20}}, color={0,0,127}));
  connect(TSet, deltaSetLimit.u1) annotation (Line(points={{-110,-20},{16,-20},
          {16,-23.6},{32.8,-23.6}}, color={0,0,127}));
  connect(variableLimiter.y, deltaSetLimit.u2) annotation (Line(points={{41,16},
          {48,16},{48,-6},{26,-6},{26,-16.4},{32.8,-16.4}}, color={0,0,127}));
  connect(toDegCT_flow_ev4.y, HeatingRodOn) annotation (Line(points={{21,-50},{
          40,-50},{40,-48},{90,-48},{90,-20},{110,-20}}, color={255,0,255}));
  annotation (Icon(coordinateSystem(preserveAspectRatio=false)), Diagram(
        coordinateSystem(preserveAspectRatio=false)));
end OperationalEnvelopeLimit;
