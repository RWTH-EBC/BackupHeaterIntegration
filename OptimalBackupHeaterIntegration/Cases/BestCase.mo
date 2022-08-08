within OptimalBackupHeaterIntegration.Cases;
model BestCase
  extends OptimalBackupHeaterIntegration.Cases.BaseBES(
    zoneParam=OptimalBackupHeaterIntegration.Buildings.Case_1_standard(),
    discretizationStepsHR=0,
    hr_location=OptimalBackupHeaterIntegration.Models.HRLocation.Storage,
    tableUpp=[-20,50; -10,60; 30,60; 35,55],
    parameterStudy(
      KpHR=0.01,
      TiHR=50,
      QHRDHW_flow_nominal=868.1202000000003,
      QHRBuf_flow_nominal=15523.6),
    systemParameters(
      QBui_flow_nominal=fill(15523.6, 1),
      TOda_nominal=262.65,
      THydSup_nominal=fill(348.15, 1)),
    use_opeEncControl=true);

  annotation (experiment(
      StopTime=1728000,
      Interval=599.999616,
      __Dymola_Algorithm="Dassl"));
end BestCase;
