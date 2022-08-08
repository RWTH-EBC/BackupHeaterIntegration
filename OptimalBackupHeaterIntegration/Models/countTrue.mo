within OptimalBackupHeaterIntegration.Models;
model countTrue
  parameter Integer nSteps(min=1);
  Modelica.Blocks.Interfaces.BooleanInput u[nSteps]
    annotation (Placement(transformation(extent={{-120,-10},{-100,10}})));
  Modelica.Blocks.Interfaces.RealOutput y
    annotation (Placement(transformation(extent={{100,-10},{120,10}})));
equation
  y = Modelica.Math.BooleanVectors.countTrue(u);

  annotation (Icon(graphics,
                   coordinateSystem(preserveAspectRatio=false)), Diagram(graphics,
        coordinateSystem(preserveAspectRatio=false)));
end countTrue;
