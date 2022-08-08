within OptimalBackupHeaterIntegration.Data;
record BESParameters "Optimal heating rod integration parameters"
  extends BESMod.Systems.RecordsCollection.SystemParametersBaseDataDefinition(
    final use_elecHeating=false,
    THydSup_nominal={328.15},
    TOda_nominal=261.15,
    final filNamWea=Modelica.Utilities.Files.loadResource(
        "modelica://OptimalHeatingRodIntegration/Resources/WeatherData.mos"),
    final TAmbVen=min(TSetZone_nominal),
    final TAmbHyd=min(TSetZone_nominal),
    final TDHWWaterCold=283.15,
    final TSetDHW=328.15,
    final TVenSup_nominal=TSetZone_nominal,
    final TSetZone_nominal=fill(293.15, nZones),
    final nZones=1,
    final use_ventilation=false);

end BESParameters;
