within OptimalBackupHeaterIntegration.Subsystems;
model HRPIDForOpeEnv
   "PID for Heating Rod based on operational envelope of heat pump"
  extends
    BESMod.Systems.Hydraulical.Control.BaseClasses.SystemWithThermostaticValveControl;
    parameter OptimalBackupHeaterIntegration.Models.HRLocation hr_location
    "Location of heating rod" annotation (Evaluate=true);
parameter Boolean use_opeEncControl;
  replaceable parameter BESMod.Systems.Hydraulical.Control.RecordsCollection.BivalentHeatPumpControlDataDefinition
    bivalentControlData constrainedby
    BESMod.Systems.Hydraulical.Control.RecordsCollection.BivalentHeatPumpControlDataDefinition(
      final TOda_nominal=generationParameters.TOda_nominal,
      TSup_nominal=generationParameters.TSup_nominal[1],
      TSetRoomConst=sum(transferParameters.TDem_nominal)/transferParameters.nParallelDem)
    annotation (choicesAllMatching=true, Placement(transformation(extent={{-112,
            -16},{-90,6}})));
    BESMod.Systems.Hydraulical.Control.Components.OnOffController.ConstantHysteresisTimeBasedHR
    DHWOnOffContoller(
    Hysteresis=bivalentControlData.dTHysDHW,
    dt_hr=bivalentControlData.dtHeaRodDHW,
    addSet_dt_hr=1)   annotation (choicesAllMatching=true, Placement(
        transformation(extent={{-128,78},{-112,94}})));

    BESMod.Systems.Hydraulical.Control.Components.OnOffController.ConstantHysteresisTimeBasedHR
    BufferOnOffController(
    Hysteresis=bivalentControlData.dTHysBui,
    dt_hr=bivalentControlData.dtHeaRodBui,
    addSet_dt_hr=1)       annotation (choicesAllMatching=true, Placement(
        transformation(extent={{-128,34},{-112,48}})));
  replaceable parameter BESMod.Systems.Hydraulical.Control.RecordsCollection.HeatPumpSafetyControl
    safetyControl
    annotation (choicesAllMatching=true,Placement(transformation(extent={{200,30},{220,50}})));

  replaceable
    BESMod.Systems.Hydraulical.Control.Components.DHWSetControl.BaseClasses.PartialTSet_DHW_Control
    TSet_DHW constrainedby
    BESMod.Systems.Hydraulical.Control.Components.DHWSetControl.BaseClasses.PartialTSet_DHW_Control(
      final T_DHW=distributionParameters.TDHW_nominal) annotation (choicesAllMatching=true,
      Placement(transformation(extent={{-216,66},{-192,90}})));
  BESMod.Systems.Hydraulical.Control.Components.HeatingCurve heatingCurve(
    TRoomSet=bivalentControlData.TSetRoomConst,
    GraHeaCurve=bivalentControlData.gradientHeatCurve,
    THeaThres=bivalentControlData.TSetRoomConst,
    dTOffSet_HC=bivalentControlData.dTOffSetHeatCurve)
    annotation (Placement(transformation(extent={{-212,18},{-190,40}})));
  Modelica.Blocks.MathBoolean.Or HRBufactive(nu=2) annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={67,17})));
  Modelica.Blocks.Logical.Or HP_active
                                      annotation (Placement(transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={27,91})));
  replaceable
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController
    HP_nSet_Controller annotation (choicesAllMatching=true, Placement(
        transformation(extent={{82,64},{112,92}})));
  Modelica.Blocks.Logical.Switch switch1
    annotation (Placement(transformation(extent={{-5,-5},{5,5}},
        rotation=0,
        origin={63,73})));
  Modelica.Blocks.Sources.Constant const_dT_loading1(k=0) annotation (Placement(
        transformation(
        extent={{4,-4},{-4,4}},
        rotation=180,
        origin={14,58})));

  Modelica.Blocks.MathBoolean.Or
                             DHWHysOrLegionella(nu=3)
    "Use the HR if the HP reached its limit" annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={-83,71})));
  AixLib.Controls.HeatPump.SafetyControls.SafetyControl securityControl(
    final minRunTime=safetyControl.minRunTime,
    final minLocTime=safetyControl.minLocTime,
    final maxRunPerHou=safetyControl.maxRunPerHou,
    final use_opeEnv=safetyControl.use_opeEnv,
    final use_opeEnvFroRec=false,
    final dataTable=AixLib.DataBase.HeatPump.EN14511.Vitocal200AWO201(
        tableUppBou=[-20,50; -10,60; 30,60; 35,55]),
    final tableUpp=safetyControl.tableUpp,
    final use_minRunTime=safetyControl.use_minRunTime,
    final use_minLocTime=safetyControl.use_minLocTime,
    final use_runPerHou=safetyControl.use_runPerHou,
    final dTHystOperEnv=safetyControl.dT_opeEnv,
    final use_deFro=false,
    final minIceFac=0,
    final use_chiller=false,
    final calcPel_deFro=0,
    final pre_n_start=safetyControl.pre_n_start_hp,
    use_antFre=false) annotation (Placement(transformation(
        extent={{-16,-17},{16,17}},
        rotation=0,
        origin={210,81})));
  Modelica.Blocks.Sources.BooleanConstant hp_mode(final k=true) annotation (
      Placement(transformation(
        extent={{-7,-7},{7,7}},
        rotation=0,
        origin={155,69})));
  Modelica.Blocks.Sources.Constant hp_iceFac(final k=1) annotation (Placement(
        transformation(
        extent={{-7,-7},{7,7}},
        rotation=0,
        origin={-181,-85})));

  Modelica.Blocks.Math.Add add_dT_LoadingBuf
    annotation (Placement(transformation(extent={{38,54},{48,64}})));
  Modelica.Blocks.Sources.Constant const_dT_loading2(k=distributionParameters.dTTraDHW_nominal
         + bivalentControlData.dTHysDHW/2) annotation (Placement(transformation(
        extent={{4,-4},{-4,4}},
        rotation=180,
        origin={14,74})));
  Modelica.Blocks.Math.Add add_dT_LoadingDHW
    annotation (Placement(transformation(extent={{36,78},{46,88}})));
  replaceable
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController
    HRPIDControlBuf constrainedby
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController
                    annotation (choicesAllMatching=true, Placement(
        transformation(extent={{102,22},{120,40}})));
  Models.OperationalEnvelopeLimit operationalEnvelopeLimit(dTOpeEnv=
        safetyControl.dT_opeEnv,
    final use_opeEncControl=use_opeEncControl,
                                 table=safetyControl.tableUpp)
    annotation (Placement(transformation(extent={{22,22},{42,42}})));
  Modelica.Blocks.Routing.RealPassThrough realPassThroughBuf
    "Multiply the HR signals to all avaiable options" annotation (Placement(
        transformation(
        extent={{-9,-9},{9,9}},
        rotation=0,
        origin={141,31})));
  Modelica.Blocks.Math.BooleanToReal BufferThreeWayValve annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={-29,-63})));
  Modelica.Blocks.Logical.Not DHWOnToBufferOn annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={-61,-63})));
  Modelica.Blocks.Routing.RealPassThrough realPassThrough1
    "Multiply the HR signals to all avaiable options" annotation (Placement(
        transformation(
        extent={{-9,-9},{9,9}},
        rotation=0,
        origin={-227,-81})));
  replaceable
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController
    HRPIDControlDHW constrainedby
    BESMod.Systems.Hydraulical.Control.Components.HeatPumpNSetController.BaseClasses.PartialHPNSetController
                    annotation (choicesAllMatching=true, Placement(
        transformation(extent={{102,-18},{120,0}})));
  Modelica.Blocks.Routing.RealPassThrough realPassThroughDHW
    "Multiply the HR signals to all avaiable options" annotation (Placement(
        transformation(
        extent={{-9,-9},{9,9}},
        rotation=0,
        origin={141,-9})));
  Modelica.Blocks.MathBoolean.Or HRDHWActive(nu=3) annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={67,-13})));
  Modelica.Blocks.Logical.Switch switchDHWBufHRAfterHP if hr_location ==
    OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump
                                                       annotation (Placement(
        transformation(
        extent={{-5,5},{5,-5}},
        rotation=180,
        origin={39,-23})));
  Modelica.Blocks.Sources.Constant constAddTSetHRDHW(k=bivalentControlData.dTHysDHW
        /2)                                annotation (Placement(transformation(
        extent={{4,-4},{-4,4}},
        rotation=180,
        origin={58,2})));
  Modelica.Blocks.Math.Add addTSetHRDHW
    annotation (Placement(transformation(extent={{80,6},{90,16}})));
  Modelica.Blocks.Sources.Constant constAdddTSetHRBuf(k=0)
                                                     annotation (Placement(
        transformation(
        extent={{4,-4},{-4,4}},
        rotation=180,
        origin={54,30})));
  Modelica.Blocks.Math.Add addTSetHRBuf
    annotation (Placement(transformation(extent={{76,34},{86,44}})));
  Models.CalcControlDeviation calcControlDeviation
    annotation (Placement(transformation(extent={{40,-102},{60,-82}})));
  Modelica.Blocks.MathBoolean.And HRBufactive1(nu=2) if hr_location <>
    OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage
                                                   annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={-25,3})));
  Modelica.Blocks.MathBoolean.And HRDHWActive1(nu=2) if hr_location <>
    OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage
                                                   annotation (Placement(
        transformation(
        extent={{-5,-5},{5,5}},
        rotation=0,
        origin={-33,-17})));
  Modelica.Blocks.MathBoolean.And BlogBufHRIfDHWIsOn(nu=2) if hr_location ==
    OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump
                                                                 annotation (
      Placement(transformation(
        extent={{-3,-3},{3,3}},
        rotation=0,
        origin={81,27})));
equation

  if hr_location == OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump
       then
    connect(HRPIDControlBuf.T_Meas, sigBusGen.THeaRodMea);
    connect(HRPIDControlDHW.T_Meas, sigBusDistr.TStoDHWTopMea);
  elseif hr_location == OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage
       then
    connect(HRPIDControlBuf.T_Meas, sigBusDistr.TBuiSupMea);
    connect(HRPIDControlDHW.T_Meas, sigBusDistr.TStoDHWTopMea);
  else
    connect(HRPIDControlBuf.T_Meas, sigBusDistr.TStoBufTopMea);
    connect(HRPIDControlDHW.T_Meas, sigBusDistr.TStoDHWTopMea);
  end if;

  connect(BufferOnOffController.T_Top, sigBusDistr.TStoBufTopMea) annotation (
      Line(points={{-128.8,45.9},{-316,45.9},{-316,-166},{4,-166},{4,-100},{1,-100}},
        color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(DHWOnOffContoller.T_Top, sigBusDistr.TStoDHWTopMea) annotation (Line(
        points={{-128.8,91.6},{-222,91.6},{-222,92},{-314,92},{-314,-166},{1,
          -166},{1,-100}},
        color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(heatingCurve.TSet, BufferOnOffController.T_Set) annotation (Line(
        points={{-188.9,29},{-120,29},{-120,33.3}}, color={0,0,127}));

  connect(DHWOnOffContoller.T_bot, sigBusDistr.TStoDHWTopMea) annotation (Line(
        points={{-128.8,82},{-134,82},{-134,92},{-314,92},{-314,-166},{1,-166},
          {1,-100}},
        color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(HP_active.y, HP_nSet_Controller.HP_On) annotation (Line(points={{32.5,
          91},{70,91},{70,78},{79,78}}, color={255,0,255}));
  connect(TSet_DHW.TSet_DHW, DHWOnOffContoller.T_Set) annotation (Line(points={{-190.8,
          78},{-120,78},{-120,77.2}},         color={0,0,127}));
  connect(sigBusDistr, TSet_DHW.sigBusDistr) annotation (Line(
      points={{1,-100},{-2,-100},{-2,-152},{-292,-152},{-292,77.88},{-216,77.88}},
      color={255,204,51},
      thickness=0.5), Text(
      string="%first",
      index=-1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));

  connect(securityControl.sigBusHP, sigBusGen.hp_bus) annotation (Line(
      points={{192,69.27},{180,69.27},{180,106},{184,106},{184,-30},{-152,-30},{
          -152,-99}},
      color={255,204,51},
      thickness=0.5), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(securityControl.modeOut, sigBusGen.hp_bus.modeSet)
    annotation (Line(points={{227.333,77.6},{268,77.6},{268,-136},{-152,-136},{
          -152,-99}},                        color={255,0,255}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(securityControl.modeSet, hp_mode.y) annotation (Line(points={{191.867,
          77.6},{168,77.6},{168,69},{162.7,69}}, color={255,0,255}));
  connect(securityControl.nOut, sigBusGen.hp_bus.nSet) annotation (Line(
        points={{227.333,84.4},{264,84.4},{264,-132},{-152,-132},{-152,-99}},
                                         color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(hp_iceFac.y, sigBusGen.hp_bus.iceFacMea) annotation (Line(
        points={{-173.3,-85},{-156.65,-85},{-156.65,-99},{-152,-99}},
                      color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(HP_nSet_Controller.n_Set, securityControl.nSet) annotation (Line(
        points={{113.5,78},{144,78},{144,84.4},{191.867,84.4}}, color={0,0,127}));
  connect(BufferOnOffController.HP_On, HP_active.u2) annotation (Line(points={{-110.88,
          45.9},{-38,45.9},{-38,87},{21,87}},    color={255,0,255}));
  connect(DHWOnOffContoller.HP_On, HP_active.u1) annotation (Line(points={{-110.88,
          91.6},{-32,91.6},{-32,91},{21,91}},    color={255,0,255}));
  connect(DHWHysOrLegionella.y, switch1.u2) annotation (Line(points={{-77.25,71},
          {-20,71},{-20,73},{57,73}},             color={255,0,255}));

  connect(DHWOnOffContoller.Auxilliar_Heater_On, DHWHysOrLegionella.u[1])
    annotation (Line(points={{-110.88,82},{-92,82},{-92,69.8333},{-88,69.8333}},
                                                                        color={
          255,0,255}));
  connect(DHWOnOffContoller.HP_On, DHWHysOrLegionella.u[2]) annotation (Line(
        points={{-110.88,91.6},{-92,91.6},{-92,71},{-88,71}},
        color={255,0,255}));
  connect(TSet_DHW.y, DHWHysOrLegionella.u[3]) annotation (Line(points={{-190.8,
          71.04},{-92.4,71.04},{-92.4,72.1667},{-88,72.1667}}, color={255,0,255}));
  connect(BufferOnOffController.T_bot, sigBusDistr.TStoBufTopMea) annotation (
      Line(points={{-128.8,37.5},{-136,37.5},{-136,38},{-142,38},{-142,46},{
          -314,46},{-314,-166},{2,-166},{2,-100},{1,-100}},
                               color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(HP_nSet_Controller.IsOn, sigBusGen.hp_bus.onOffMea) annotation (Line(
        points={{88,61.2},{88,-30},{-152,-30},{-152,-99}}, color={255,0,255}),
      Text(
      string="%second",
      index=1,
      extent={{-3,-6},{-3,-6}},
      horizontalAlignment=TextAlignment.Right));
  connect(const_dT_loading2.y,add_dT_LoadingDHW. u2) annotation (Line(points={{18.4,74},
          {24,74},{24,80},{35,80}},                  color={0,0,127}));
  connect(heatingCurve.TSet, add_dT_LoadingBuf.u1) annotation (Line(points={{
          -188.9,29},{4,29},{4,62},{37,62}}, color={0,0,127}));
  connect(add_dT_LoadingDHW.u1, TSet_DHW.TSet_DHW) annotation (Line(points={{35,
          86},{14,86},{14,84},{-8,84},{-8,78},{-190.8,78}}, color={0,0,127}));
  connect(add_dT_LoadingBuf.y, switch1.u3) annotation (Line(points={{48.5,59},{
          54,59},{54,69},{57,69}}, color={0,0,127}));
  connect(add_dT_LoadingDHW.y, switch1.u1) annotation (Line(points={{46.5,83},{
          51.25,83},{51.25,77},{57,77}}, color={0,0,127}));
  connect(const_dT_loading1.y, add_dT_LoadingBuf.u2) annotation (Line(points={{
          18.4,58},{26,58},{26,56},{37,56}}, color={0,0,127}));
  connect(operationalEnvelopeLimit.sigBusHP, sigBusGen.hp_bus) annotation (Line(
      points={{21.9,31.9},{21.9,32},{6,32},{6,-30},{-152,-30},{-152,-99}},
      color={255,204,51},
      thickness=0.5), Text(
      string="%second",
      index=1,
      extent={{-3,-6},{-3,-6}},
      horizontalAlignment=TextAlignment.Right));
  connect(switch1.y, operationalEnvelopeLimit.TSet) annotation (Line(points={{68.5,
          73},{72,73},{72,50},{16,50},{16,30},{21,30}}, color={0,0,127}));
  connect(operationalEnvelopeLimit.TSetHeatPump, HP_nSet_Controller.T_Set)
    annotation (Line(points={{43,38},{72,38},{72,86.4},{79,86.4}}, color={0,0,127}));

  connect(HP_nSet_Controller.T_Meas, sigBusGen.hp_bus.TConOutMea) annotation (
      Line(points={{97,61.2},{97,-30},{-152,-30},{-152,-99}}, color={0,0,127}),
      Text(
      string="%second",
      index=1,
      extent={{-3,-6},{-3,-6}},
      horizontalAlignment=TextAlignment.Right));
  connect(realPassThroughBuf.u, HRPIDControlBuf.n_Set)
    annotation (Line(points={{130.2,31},{120.9,31}}, color={0,0,127}));
  connect(BufferThreeWayValve.y, sigBusDistr.uThrWayVal) annotation (Line(
        points={{-23.5,-63},{-2,-63},{-2,-62},{1,-62},{1,-100}},
                                             color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(DHWHysOrLegionella.y, DHWOnToBufferOn.u) annotation (Line(points={{-77.25,
          71},{-56,71},{-56,-52},{-72,-52},{-72,-63},{-67,-63}},
                                                         color={255,0,255}));
  connect(DHWOnToBufferOn.y, BufferThreeWayValve.u) annotation (Line(points={{-55.5,
          -63},{-35,-63}},                             color={255,0,255}));
  connect(heatingCurve.TOda, weaBus.TDryBul) annotation (Line(points={{-214.2,
          29},{-237,29},{-237,2}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(BufferOnOffController.T_oda, weaBus.TDryBul) annotation (Line(points=
          {{-120,48.84},{-120,48},{-237,48},{-237,2}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-3,-6},{-3,-6}},
      horizontalAlignment=TextAlignment.Right));
  connect(DHWOnOffContoller.T_oda, weaBus.TDryBul) annotation (Line(points={{
          -120,94.96},{-120,102},{-237,102},{-237,2}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-3,6},{-3,6}},
      horizontalAlignment=TextAlignment.Right));
  connect(weaBus.TDryBul, realPassThrough1.u) annotation (Line(
      points={{-237,2},{-237.8,2},{-237.8,-81}},
      color={255,204,51},
      thickness=0.5), Text(
      string="%first",
      index=-1,
      extent={{-3,6},{-3,6}},
      horizontalAlignment=TextAlignment.Right));
  connect(realPassThrough1.y, sigBusGen.hp_bus.TOdaMea) annotation (Line(points=
         {{-217.1,-81},{-217.1,-99},{-152,-99}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-3,-6},{-3,-6}},
      horizontalAlignment=TextAlignment.Right));
  connect(realPassThroughDHW.u, HRPIDControlDHW.n_Set)
    annotation (Line(points={{130.2,-9},{120.9,-9}}, color={0,0,127}));
  connect(HRDHWActive.y, HRPIDControlDHW.IsOn) annotation (Line(points={{72.75,-13},
          {84,-13},{84,-26},{105.6,-26},{105.6,-19.8}}, color={255,0,255}));
  connect(HRDHWActive.y, HRPIDControlDHW.HP_On) annotation (Line(points={{72.75,
          -13},{84,-13},{84,-9},{100.2,-9}}, color={255,0,255}));

  connect(realPassThroughDHW.y, sigBusDistr.uHRStoDHW) annotation (Line(points={
          {150.9,-9},{154,-9},{154,-30},{1,-30},{1,-100}}, color={0,0,127}),
      Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(realPassThroughBuf.y, sigBusDistr.uHRAftBuf) annotation (Line(points={
          {150.9,31},{154,31},{154,-30},{1,-30},{1,-100}}, color={0,0,127}),
      Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(realPassThroughBuf.y, sigBusDistr.uHRStoBuf) annotation (Line(points={
          {150.9,31},{154,31},{154,-30},{1,-30},{1,-100}}, color={0,0,127}),
      Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(switchDHWBufHRAfterHP.u1, realPassThroughDHW.y) annotation (Line(
        points={{45,-19},{54,-19},{54,-30},{154,-30},{154,-9},{150.9,-9}},
        color={0,0,127}));
  connect(switchDHWBufHRAfterHP.u3, realPassThroughBuf.y) annotation (Line(
        points={{45,-27},{45,-30},{152,-30},{152,31},{150.9,31}}, color={0,0,127}));
  connect(switchDHWBufHRAfterHP.u2, DHWHysOrLegionella.y) annotation (Line(
        points={{45,-23},{54,-23},{54,-30},{-56,-30},{-56,70},{-77.25,70},{-77.25,
          71}}, color={255,0,255}));
  connect(switchDHWBufHRAfterHP.y, sigBusGen.hr_on) annotation (Line(points={{33.5,
          -23},{26,-23},{26,-30},{-152,-30},{-152,-99}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));

  connect(addTSetHRDHW.u1, TSet_DHW.TSet_DHW) annotation (Line(points={{79,14},
          {-16,14},{-16,78},{-190.8,78}}, color={0,0,127}));
  connect(constAddTSetHRDHW.y, addTSetHRDHW.u2)
    annotation (Line(points={{62.4,2},{74,2},{74,8},{79,8}}, color={0,0,127}));
  connect(constAdddTSetHRBuf.y, addTSetHRBuf.u2) annotation (Line(points={{58.4,
          30},{70,30},{70,36},{75,36}}, color={0,0,127}));
  connect(addTSetHRBuf.y, HRPIDControlBuf.T_Set) annotation (Line(points={{86.5,
          39},{86.5,36.4},{100.2,36.4}}, color={0,0,127}));
  connect(addTSetHRBuf.u1, heatingCurve.TSet) annotation (Line(points={{75,42},
          {-28,42},{-28,29},{-188.9,29}}, color={0,0,127}));
  connect(HRPIDControlDHW.ISE, outBusCtrl.ISE_DHW) annotation (Line(points={{120.9,
          -4.5},{120.9,6},{224,6},{224,0},{240,0}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(HRPIDControlDHW.IAE, outBusCtrl.IAE_DHW) annotation (Line(points={{120.9,
          -0.9},{130,-0.9},{130,2},{222,2},{222,0},{240,0}}, color={0,0,127}),
      Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(HRPIDControlBuf.ISE, outBusCtrl.ISE_Buf) annotation (Line(points={{120.9,
          35.5},{120.9,46},{194,46},{194,0},{240,0}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(HRPIDControlBuf.IAE, outBusCtrl.IAE_Buf) annotation (Line(points={{120.9,
          39.1},{120.9,38},{126,38},{126,16},{256,16},{256,0},{240,0}}, color={0,
          0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(calcControlDeviation.uMea, buiMeaBus.TZoneMea[1]) annotation (Line(
        points={{38.2,-96},{32,-96},{32,-28},{24,-28},{24,20},{46,20},{46,44},{
          52,44},{52,56},{65,56},{65,103}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(calcControlDeviation.uSet, useProBus.TZoneSet[1]) annotation (Line(
        points={{38,-86},{30,-86},{30,20},{-58,20},{-58,60},{-98,60},{-98,74},{
          -106,74},{-106,72},{-119,72},{-119,103}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{-6,3},{-6,3}},
      horizontalAlignment=TextAlignment.Right));
  connect(calcControlDeviation.IAE, outBusCtrl.IAE_Bui) annotation (Line(points=
         {{61,-83},{100,-83},{100,-32},{222,-32},{222,0},{240,0}}, color={0,0,
          127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));
  connect(calcControlDeviation.ISE, outBusCtrl.ISE_Bui) annotation (Line(points=
         {{61,-87},{104,-87},{104,-62},{106,-62},{106,-44},{256,-44},{256,0},{
          240,0}}, color={0,0,127}), Text(
      string="%second",
      index=1,
      extent={{6,3},{6,3}},
      horizontalAlignment=TextAlignment.Left));

  if hr_location <> OptimalBackupHeaterIntegration.Models.HRLocation.AfterStorage
       then

  connect(DHWOnOffContoller.HP_On, HRDHWActive1.u[1]) annotation (Line(points={
          {-110.88,91.6},{-110.88,90},{-92,90},{-92,16},{-44,16},{-44,-17.875},
          {-38,-17.875}}, color={255,0,255}));
  connect(HRBufactive1.u[1], BufferOnOffController.HP_On) annotation (Line(
        points={{-30,2.125},{-30,2},{-84,2},{-84,46},{-104,46},{-104,54},{
          -110.88,54},{-110.88,45.9}}, color={255,0,255}));
  connect(operationalEnvelopeLimit.HeatingRodOn, HRBufactive1.u[2]) annotation (
     Line(points={{43,30},{48,30},{48,2},{-14,2},{-14,-6},{-34,-6},{-34,3.875},
          {-30,3.875}}, color={255,0,255}));
  connect(operationalEnvelopeLimit.HeatingRodOn, HRDHWActive1.u[2]) annotation (
     Line(points={{43,30},{48,30},{48,2},{-14,2},{-14,-6},{-44,-6},{-44,-16.125},
          {-38,-16.125}}, color={255,0,255}));
  connect(HRBufactive1.y, HRBufactive.u[2]) annotation (Line(points={{-19.25,3},
          {-18,3},{-18,17.875},{62,17.875}}, color={255,0,255}));
  connect(HRDHWActive1.y, HRDHWActive.u[3]) annotation (Line(points={{-27.25,
            -17},{-12,-17},{-12,-11.8333},{62,-11.8333}},
                                                        color={255,0,255}));
    connect(HRDHWActive.u[2], TSet_DHW.y) annotation (Line(points={{62,-13},{-12,
          -13},{-12,-30},{-56,-30},{-56,71.04},{-190.8,71.04}},           color=
         {255,0,255}));
  connect(BufferOnOffController.Auxilliar_Heater_On, HRBufactive.u[1])
    annotation (Line(points={{-110.88,37.5},{-16,37.5},{-16,16.125},{62,16.125}},
        color={255,0,255}));
  connect(HRDHWActive.u[1], DHWOnOffContoller.Auxilliar_Heater_On) annotation (
      Line(points={{62,-14.1667},{-12,-14.1667},{-12,-30},{-56,-30},{-56,82},{
            -110.88,82}},                                     color={255,0,255}));
  else
   connect(HRDHWActive.u[3], TSet_DHW.y) annotation (Line(points={{62,-11.8333},
            {-12,-11.8333},{-12,-30},{-56,-30},{-56,71.04},{-190.8,71.04}},
                                                                          color=
         {255,0,255}));
   connect(operationalEnvelopeLimit.HeatingRodOn, HRBufactive.u[1]) annotation (
      Line(points={{43,30},{48,30},{48,16.125},{62,16.125}}, color={255,0,255}));
  connect(operationalEnvelopeLimit.HeatingRodOn, HRDHWActive.u[1]) annotation (
      Line(points={{43,30},{48,30},{48,-14.1667},{62,-14.1667}}, color={255,0,255}));
  connect(BufferOnOffController.Auxilliar_Heater_On, HRBufactive.u[2])
    annotation (Line(points={{-110.88,37.5},{-16,37.5},{-16,17.875},{62,17.875}},
        color={255,0,255}));
  connect(HRDHWActive.u[2], DHWOnOffContoller.Auxilliar_Heater_On) annotation (
      Line(points={{62,-13},{-12,-13},{-12,-30},{-56,-30},{-56,82},{-110.88,82}},
                                                              color={255,0,255}));
  end if;
  connect(addTSetHRDHW.y, HRPIDControlDHW.T_Set) annotation (Line(points={{90.5,
          11},{90.5,10},{94,10},{94,-3.6},{100.2,-3.6}}, color={0,0,127}));

  if hr_location <> OptimalBackupHeaterIntegration.Models.HRLocation.AfterHeatPump
       then
    connect(HRBufactive.y, HRPIDControlBuf.HP_On) annotation (Line(points={{72.75,
          17},{86,17},{86,31},{100.2,31}}, color={255,0,255},
      pattern=LinePattern.Dash));
    connect(HRBufactive.y, HRPIDControlBuf.IsOn) annotation (Line(points={{72.75,17},
          {105.6,17},{105.6,20.2}}, color={255,0,255},
      pattern=LinePattern.Dash));
  end if;
  connect(DHWOnToBufferOn.y, BlogBufHRIfDHWIsOn.u[1]) annotation (Line(points={{-55.5,
          -63},{-68,-63},{-68,-44},{0,-44},{0,8},{28,8},{28,26.475},{78,26.475}},
                    color={255,0,255}));
  connect(HRBufactive.y, BlogBufHRIfDHWIsOn.u[2]) annotation (Line(points={{72.75,
          17},{72.75,24},{78,24},{78,27.525}}, color={255,0,255}));
  connect(BlogBufHRIfDHWIsOn.y, HRPIDControlBuf.HP_On) annotation (Line(
      points={{84.45,27},{92,27},{92,31},{100.2,31}},
      color={255,0,255},
      pattern=LinePattern.Dash));
  connect(BlogBufHRIfDHWIsOn.y, HRPIDControlBuf.IsOn) annotation (Line(
      points={{84.45,27},{98,27},{98,14},{105.6,14},{105.6,20.2}},
      color={255,0,255},
      pattern=LinePattern.Dash));
    annotation (Diagram(graphics={
        Rectangle(
          extent={{106,-20},{128,-28}},
          lineColor={0,0,127},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid,
          lineThickness=1),
        Rectangle(
          extent={{-240,100},{-50,60}},
          lineColor={238,46,47},
          lineThickness=1),
        Text(
          extent={{-234,94},{-140,128}},
          lineColor={238,46,47},
          lineThickness=1,
          textString="DHW Control"),
        Rectangle(
          extent={{-240,58},{-50,14}},
          lineColor={0,140,72},
          lineThickness=1),
        Text(
          extent={{-216,-16},{-122,18}},
          lineColor={0,140,72},
          lineThickness=1,
          textString="Buffer Control"),
        Rectangle(
          extent={{0,100},{132,52}},
          lineColor={28,108,200},
          lineThickness=1),
        Text(
          extent={{4,122},{108,102}},
          lineColor={28,108,200},
          lineThickness=1,
          textString="Heat Pump Control"),
        Rectangle(
          extent={{0,46},{168,-42}},
          lineColor={162,29,33},
          lineThickness=1),
        Text(
          extent={{4,-38},{108,-58}},
          lineColor={162,29,33},
          lineThickness=1,
          textString="Heating Rod Control"),
        Rectangle(
          extent={{138,100},{240,52}},
          lineColor={28,108,200},
          lineThickness=1),
        Text(
          extent={{138,122},{242,102}},
          lineColor={28,108,200},
          lineThickness=1,
          textString="Heat Pump Safety"),
        Rectangle(
          extent={{106,18},{128,10}},
          lineColor={0,0,127},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid,
          lineThickness=1),
        Text(
          extent={{108,18},{126,10}},
          lineColor={0,0,127},
          textString="Internal"),
        Text(
          extent={{108,-20},{126,-28}},
          lineColor={0,0,127},
          textString="Internal")}));
end HRPIDForOpeEnv;
