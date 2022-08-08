within OptimalBackupHeaterIntegration.Cases;
model WorstCase
  extends OptimalBackupHeaterIntegration.Cases.BaseBES(
    zoneParam=BESMod.Examples.BAUSimStudy.Buildings.Case_1_standard(),
    discretizationStepsHR=1,
    hr_location=OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump,

    tableUpp=[-20,45; -10,55; 0,60; 40,60],
    parameterStudy(QHRDHW_flow_nominal=0, QHRBuf_flow_nominal=15278.4),
    systemParameters(
      QBui_flow_nominal=fill(15278.4, 1),
      TOda_nominal=261.05,
      THydSup_nominal(displayUnit="K") = (fill(343.15, 1))));

end WorstCase;
