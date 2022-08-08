within OptimalBackupHeaterIntegration.Cases;
partial model BaseBES
  extends BESMod.Systems.BaseClasses.PartialBuildingEnergySystem(
    redeclare BESMod.Systems.Control.NoControl control,
    redeclare BESMod.Systems.Electrical.DirectGridConnectionSystem electrical,
    redeclare BESMod.Systems.Demand.Building.TEASERThermalZone building(
      oneZoneParam=zoneParam,
      final zoneParam=fill(building.oneZoneParam, building.nZones),
      final ventRate=fill(0, building.nZones),
      final use_verboseEnergyBalance=true,
      final dTComfort(displayUnit="K") = 2,
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial),
    redeclare final BESMod.Systems.Ventilation.NoVentilation
      ventilation,
    redeclare BESMod.Systems.Demand.DHW.DHW DHW(
      use_pressure=true,
      redeclare final
        BESMod.Systems.RecordsCollection.Movers.DefaultMover
        pumpData,
      redeclare final
        BESMod.Systems.Demand.DHW.TappingProfiles.calcmFlowEquDynamic calcmFlow),
    redeclare BESMod.Systems.UserProfiles.TEASERProfiles userProfiles(
      use_dhw=true,
      redeclare BESMod.Systems.Demand.DHW.RecordsCollection.ProfileM DHWProfile,
      use_dhwCalc=false),
    redeclare OptimalBackupHeaterIntegration.Data.PIDParameterOptimization parameterStudy,
    redeclare final package MediumDHW = AixLib.Media.Water,
    redeclare final package MediumZone = AixLib.Media.Air,
    redeclare final package MediumHyd = AixLib.Media.Water,
    redeclare OptimalBackupHeaterIntegration.Data.BESParameters systemParameters,
    redeclare BESMod.Systems.Hydraulical.HydraulicSystem
      hydraulic(
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      redeclare
        OptimalBackupHeaterIntegration.Subsystems.CustomHeatPumpAndHeatingRod
        generation(
        redeclare
          BESMod.Systems.RecordsCollection.Movers.DefaultMover
          pumpData,
        redeclare package Medium_eva = AixLib.Media.Air,
        redeclare
          BESMod.Systems.Hydraulical.Generation.RecordsCollection.DefaultHP
          heatPumpParameters(
          THeaTresh=systemParameters.TSetZone_nominal[1],
          genDesTyp=BESMod.Systems.Hydraulical.Generation.Types.GenerationDesign.BivalentPartParallel,
          QSec_flow_nominal=parameterStudy.QHRBuf_flow_nominal + parameterStudy.QHRDHW_flow_nominal,
          TBiv=parameterStudy.TBiv,
          scalingFactor=hydraulic.generation.heatPumpParameters.QPri_flow_nominal
              /5000,
          useAirSource=true,
          dpCon_nominal=0,
          dpEva_nominal=0,
          use_refIne=false,
          refIneFre_constant=0),
        final use_pressure=true,
        use_heaRod=(hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump),
        redeclare OptimalBackupHeaterIntegration.Data.HRData
                                                           heatingRodParameters(
            discretizationSteps=discretizationStepsHR),
        redeclare model PerDataMainHP =
            AixLib.DataBase.HeatPump.PerformanceData.VCLibMap (
            QCon_flow_nominal=hydraulic.generation.heatPumpParameters.QPri_flow_nominal,
            refrigerant="Propane",
            flowsheet="VIPhaseSeparatorFlowsheet")),
      redeclare Subsystems.HRPIDForOpeEnv control(
        redeclare
          BESMod.Systems.Hydraulical.Control.Components.ThermostaticValveController.ThermostaticValvePIControlled
          thermostaticValveController,
        redeclare
          BESMod.Systems.Hydraulical.Control.RecordsCollection.ThermostaticValveDataDefinition
          thermostaticValveParameters,
        hr_location=hr_location,
        use_opeEncControl=use_opeEncControl,
        redeclare
          BESMod.Systems.Hydraulical.Control.RecordsCollection.DefaultBivHPControl
          bivalentControlData(TBiv=parameterStudy.TBiv),
        redeclare
          BESMod.Systems.Hydraulical.Control.RecordsCollection.DefaultSafetyControl
          safetyControl(final tableUpp=tableUpp),
        redeclare
          BESMod.Systems.Hydraulical.Control.Components.DHWSetControl.ConstTSet_DHW
          TSet_DHW,
        redeclare
          BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.PID_InverterHeatPumpController
          HP_nSet_Controller(
          final P=parameterStudy.KpHP,
          final nMin=hydraulic.control.bivalentControlData.nMin,
          final yMax=1,
          final yOff=0,
          final y_start=0,
          final T_I=parameterStudy.TiHP,
          final T_D=parameterStudy.TdHP),
        redeclare
          OptimalBackupHeaterIntegration.Models.DiscreteHysteresisController
          HRPIDControlBuf(
          use_ownHys=hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage,
          final nSteps=discretizationStepsHR,
          final dTHys=if hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage then
                                                                                                         parameterStudy.dTHys else hydraulic.control.bivalentControlData.dTHysBui + 0.1,
          final P=parameterStudy.KpHR,
          final nMin=0,
          final yMax=1,
          final yOff=0,
          final y_start=0,
          final n_opt=1,
          final T_I=parameterStudy.TiHR,
          final T_D=parameterStudy.TdHR,
          final controllerType=Modelica.Blocks.Types.SimpleController.PI),
        redeclare
          OptimalBackupHeaterIntegration.Models.DiscreteHysteresisController
          HRPIDControlDHW(
          use_ownHys=hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage,
          final nSteps=discretizationStepsHR,
          final dTHys=if hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage then
                                                                                                         parameterStudy.dTHys else hydraulic.control.bivalentControlData.dTHysDHW + 0.1,
          final P=parameterStudy.KpHR,
          final nMin=0,
          final yMax=1,
          final yOff=0,
          final y_start=0,
          final n_opt=1,
          final T_I=parameterStudy.TiHR,
          final T_D=parameterStudy.TdHR,
          final controllerType=Modelica.Blocks.Types.SimpleController.PI)),
      redeclare
        BESMod.Systems.Hydraulical.Distribution.TwoStoDetailedDirectLoading
        distribution(
        QHRAftBuf_flow_nominal=parameterStudy.QHRBuf_flow_nominal,
        use_heatingRodAfterBuffer=hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage,
        discretizationStepsDWHStoHR=discretizationStepsHR,
        discretizationStepsBufStoHR=discretizationStepsHR,
        redeclare
          BESMod.Systems.RecordsCollection.TemperatureSensors.DefaultSensor
          temperatureSensorData,
        redeclare
          BESMod.Systems.RecordsCollection.Valves.DefaultThreeWayValve
          threeWayValveParameters,
        redeclare
          BESMod.Systems.Hydraulical.Distribution.RecordsCollection.BufferStorage.DefaultDetailedStorage
          bufParameters(
          use_hr=hr_location ==OptimalBackupHeaterIntegration.Models.HRLocation.Storage,
          QHR_flow_nominal=parameterStudy.QHRBuf_flow_nominal,
          discretizationStepsHR=discretizationStepsHR,
          dTLoadingHC1=0,
          use_QLos=true,
          QLosPerDay=1.5,
          T_m=338.15),
        redeclare
          BESMod.Systems.Hydraulical.Distribution.RecordsCollection.BufferStorage.DefaultDetailedStorage
          dhwParameters(
          use_hr=hr_location <>OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump,
          QHR_flow_nominal=parameterStudy.QHRDHW_flow_nominal,
          discretizationStepsHR=discretizationStepsHR,
          dTLoadingHC1=10,
          use_QLos=true,
          QLosPerDay=1.5,
          T_m=65 + 273.15),
        redeclare OptimalBackupHeaterIntegration.Data.HRData
          heatingRodAftBufParameters(discretizationSteps=discretizationStepsHR),
        hea(final m_flowTurnOff=hydraulic.distribution.hea.m_flow_nominal*0.1,
            final m_flowTurnOn=hydraulic.distribution.hea.m_flow_nominal*0.15)),
      redeclare
        BESMod.Systems.Hydraulical.Transfer.RadiatorPressureBased
        transfer(
        redeclare
          BESMod.Systems.Hydraulical.Transfer.RecordsCollection.RadiatorTransferData
          radParameters,
        redeclare
          BESMod.Systems.Hydraulical.Transfer.RecordsCollection.SteelRadiatorStandardPressureLossData
          transferDataBaseDefinition,
        redeclare
          BESMod.Systems.RecordsCollection.Movers.DefaultMover
          pumpData)));

  parameter Real tableUpp[:,2]=[-40,70; 40,70] "Upper boundary of envelope"
                                                                           annotation(Evaluate=true);
  parameter OptimalBackupHeaterIntegration.Models.HRLocation hr_location
    "Location of heating rod" annotation (Evaluate=true);
  parameter Integer discretizationStepsHR   "Discretize all heating rods. =0 modulating, =1 in/off, > 1 stepwise"
                                                                                                                 annotation(Evaluate=true);
  parameter Boolean use_opeEncControl;
  parameter AixLib.DataBase.ThermalZones.ZoneBaseRecord zoneParam
    "Building model" annotation(choicesAllMatching=true);

  annotation (experiment(
      StopTime=864000,
      Interval=600,
      __Dymola_Algorithm="Dassl"));
end BaseBES;
