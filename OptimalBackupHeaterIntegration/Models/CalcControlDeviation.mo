within OptimalBackupHeaterIntegration.Models;
model CalcControlDeviation
  Modelica.Blocks.Continuous.Integrator integrator
annotation (Placement(transformation(extent={{70,44},{90,64}})));
  Modelica.Blocks.Math.Abs abs1
annotation (Placement(transformation(extent={{36,44},{56,64}})));
  Modelica.Blocks.Continuous.Integrator integrator1
annotation (Placement(transformation(extent={{70,10},{90,30}})));
  Modelica.Blocks.Interfaces.RealOutput IAE "Integral Absolute Error"
annotation (Placement(transformation(extent={{100,30},{120,50}}),
    iconTransformation(extent={{100,80},{120,100}})));
  Modelica.Blocks.Interfaces.RealOutput ISE "Integral Square Error" annotation (
 Placement(transformation(extent={{100,-20},{120,0}}), iconTransformation(
      extent={{100,40},{120,60}})));
  Modelica.Blocks.Math.Feedback feedback
annotation (Placement(transformation(extent={{4,30},{24,50}})));
  Modelica.Blocks.Math.Product product1
                                       "Square the difference"
annotation (Placement(transformation(extent={{38,10},{58,30}})));
  Modelica.Blocks.Interfaces.RealInput uMea "Measured value"
    annotation (Placement(transformation(extent={{-138,-60},{-98,-20}})));
  Modelica.Blocks.Interfaces.RealInput uSet "Set value"
    annotation (Placement(transformation(extent={{-140,40},{-100,80}})));
equation
  connect(abs1.
           y,integrator. u)
annotation (Line(points={{57,54},{68,54}},   color={0,0,127}));
  connect(integrator.
                 y,IAE)  annotation (Line(points={{91,54},{96,54},{96,38},{110,
          38},{110,40}},   color={0,0,127}));
  connect(ISE,integrator1.
                       y)
annotation (Line(points={{110,-10},{100,-10},{100,20},{91,20}},
                                            color={0,0,127}));
  connect(integrator1.u, product1.y)
    annotation (Line(points={{68,20},{59,20}}, color={0,0,127}));
  connect(feedback.y, product1.u2) annotation (Line(points={{23,40},{30,40},{30,
          14},{36,14}}, color={0,0,127}));
  connect(feedback.
               y,abs1. u) annotation (Line(points={{23,40},{24,40},{24,54},{34,
          54}},       color={0,0,127}));
  connect(feedback.y, product1.u1) annotation (Line(points={{23,40},{30,40},{30,
          26},{36,26}}, color={0,0,127}));
  connect(feedback.u2, uMea)
    annotation (Line(points={{14,32},{14,-40},{-118,-40}}, color={0,0,127}));
  connect(uSet, feedback.u1) annotation (Line(points={{-120,60},{0,60},{0,40},{
          6,40}}, color={0,0,127}));
  annotation (Icon(coordinateSystem(preserveAspectRatio=false)), Diagram(
        coordinateSystem(preserveAspectRatio=false)));
end CalcControlDeviation;
