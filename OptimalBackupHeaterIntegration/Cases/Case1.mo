within OptimalBackupHeaterIntegration.Cases;
model Case1
  extends OptimalBackupHeaterIntegration.Cases.BaseBES(
    use_opeEncControl=true,
    zoneParam=OptimalBackupHeaterIntegration.Buildings.Case_1_retrofit(),
    discretizationStepsHR=1,
    hr_location=OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump,

    tableUpp=[-20,50; -10,60; 30,60; 35,55],
    parameterStudy(QHRDHW_flow_nominal=2000, QHRBuf_flow_nominal=5619.32),
    systemParameters(
      QBui_flow_nominal=fill(5619.32, 1),
      TOda_nominal=261.05,
      THydSup_nominal=fill(348.15, 1)));

  annotation (experiment(
      StopTime=2592000,
      Interval=900,
      __Dymola_Algorithm="Dassl"));
end Case1;
