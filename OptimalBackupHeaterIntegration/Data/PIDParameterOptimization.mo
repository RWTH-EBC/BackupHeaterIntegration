within OptimalBackupHeaterIntegration.Data;
record PIDParameterOptimization
  extends
    BESMod.Systems.RecordsCollection.ParameterStudy.ParameterStudyBaseDefinition;
  parameter Modelica.Units.SI.Temperature TBiv=273.15 - 5
    "Bivalence temperature" annotation (Evaluate=false);
  parameter Real KpHP=0.2
                      "Gain of HP-PID-controller" annotation(Evaluate=false);
  parameter Modelica.Units.SI.Time TiHP=1000
    "Time constant of HP Integrator block" annotation (Evaluate=false);
  parameter Modelica.Units.SI.Time TdHP=0
    "Time constant of HP Derivative block" annotation (Evaluate=false);
  parameter Real KpHR=0.2
                      "Gain of HR-PID-controller" annotation(Evaluate=false);
  parameter Modelica.Units.SI.Time TiHR=1000
    "Time constant of HR Integrator block" annotation (Evaluate=false);
  parameter Modelica.Units.SI.Time TdHR=0
    "Time constant of HR Derivative block" annotation (Evaluate=false);
  parameter Modelica.Units.SI.HeatFlowRate QHRDHW_flow_nominal=100
    "Nominal heat flow rate of heating rod for DHW storage"
    annotation (Evaluate=false);
  parameter Modelica.Units.SI.HeatFlowRate QHRBuf_flow_nominal=700
    "Nominal heat flow rate of heating rod for Buf storage"
    annotation (Evaluate=false);
  parameter Modelica.Units.SI.TemperatureDifference dTHys=8
    "Hysteresis temperature for HR controller";

end PIDParameterOptimization;
