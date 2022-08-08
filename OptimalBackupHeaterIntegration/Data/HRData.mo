within OptimalBackupHeaterIntegration.Data;
record HRData
  extends
    BESMod.Systems.Hydraulical.Generation.RecordsCollection.HeatingRodBaseDataDefinition(
    discretizationSteps=1,
    dp_nominal=1000,
    V_hr=0.001,
    eta_hr=0.97);
end HRData;
