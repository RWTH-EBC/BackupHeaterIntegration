import pandas as pd
import os
import pathlib
import logging
import shutil
import itertools
from ebcpy import DymolaAPI, TimeSeriesData
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
from dataclasses import dataclass
#plt.style.use("seaborn")
plt.rcParams.update({"figure.figsize": [15, 8],
                     "font.size": 14})

logger = logging.getLogger(__name__)
logger.setLevel("DEBUG")
from copy import deepcopy


def get_dhw_size(
        profile: str = "M",
        heat_loss_per_day: float = 1.0,
        temperature_set: float = 50,
):
    """
    V_S in m3
    TSet in °C
    TCold in °C
    """
    profile_data = {
        "M": {
            "V_S": 123.417e-3,
            "t_DP": 1,
            "Q_DP": 2.24
        }
    }
    Q_Loss = heat_loss_per_day / 24  # From kWh/d to kWh/h=kW
    _data = profile_data[profile]
    Q_DP = _data["Q_DP"]
    t_DP = _data["t_DP"]
    V_S = _data["V_S"]
    return ((Q_DP - (V_S * 4184 * 1000 / 3600000) * (temperature_set - 40)) / t_DP + Q_Loss) * 1000


_KWH_PLOTS = {"factor": 1/36e5, "offset": 0, "unit": "kWh"}
_N_PLOTS = {"factor": 1, "offset": 0, "unit": "-"}
_KH_PLOTS = {"factor": 1 / 3600, "offset": 0, "unit": "Kh"}
_KH2_PLOTS = {"factor": 1 / 3600, "offset": 0, "unit": "K^2h"}


@dataclass
class StudyParameters:
    building: str
    weather: str
    temp_sup: float
    ope_env: str
    hr_type: str = None
    hr_location: str = None

    def get_name(self):
        if self.hr_type is None and self.hr_location is None:
            return "_".join([self.weather, self.building, self.ope_env, str(self.temp_sup)])
        return "_".join([self.weather, self.building, self.hr_location, self.ope_env, str(self.temp_sup), self.hr_type])

    def get_short_name(self):
        if self.hr_type is None and self.hr_location is None:
            return "_".join([
                self.weather[0].upper(),
                self.building.split("_")[1] + self.building.split("_")[2][0].upper(),
                self.ope_env, str(self.temp_sup)
            ])
        return self.get_name()

    def get_multi_key(self):
        return (
            self.weather,
            self.building,
            self.hr_location,
            self.ope_env,
            self.temp_sup,
            self.hr_type
        )

    def is_valid_case(self):
        if self.building.endswith("_retrofit") and self.temp_sup > 60:
            return False
        return True

    def xs_df(self, df):
        return df.xs(self.weather, level=0).xs(self.building, level=0).xs(self.ope_env, level=1).xs(str(self.temp_sup), level=1)


class StudyRunner:
    loc_rename = {
        "AfterHeatPump": "After Heat Pump",
        "Storage": "Storage",
        "AfterStorage": "After Storage"
    }
    ctrl_rename = {
        "OnOff": "On/Off",
        "Modulating": "Modulating",
        "Discrete": "Stepwise"
    }

    TSup_nominal = [
        55,
        75
    ]
    operational_envelopes = {
        "high": "[-20,60; -10,70; 40,70]",
        "low": "[-20, 50;-10, 60;30, 60;35,55]"
    }
    heating_rod_locations = [
        "AfterHeatPump",
        "Storage",
        "AfterStorage"
    ]
    heating_rod_types = {
        "OnOff": 1,
        "Modulating": 0,
        "Discrete": 5
    }
    QHRDHW_flow_nominal = get_dhw_size(profile="M", heat_loss_per_day=1.5, temperature_set=50)

    comfort_metric = "dTCom"
    comfort_boundary = 3600 * 73

    outputs = {
        "outputs.hydraulic.generation.WHPel.integral": {**_KWH_PLOTS, "label": "$W_\mathrm{el,HP}$", "rename": "WHPel", "plot": True},
        "outputs.hydraulic.generation.WHRel.integral": {**_KWH_PLOTS, "label": "$W_\mathrm{el,HR}$", "plot": True},
        "outputs.building.dTComHea[1]": {**_KH_PLOTS, "label": "$\Delta T_\mathrm{Comfort}$", "rename": "dTCom", "plot": True},
        "outputs.hydraulic.generation.QHP_flow.integral": {**_KWH_PLOTS, "label": "$\dot{Q}_\mathrm{HP}$", "rename": "QHP", "plot": True},
        "outputs.DHW.Q_flow.integral": {**_KWH_PLOTS, "label": "$\dot{Q}_\mathrm{DHW}$", "rename": "QDHW", "plot": True},
        "outputs.building.QTraGain[1].integral": {**_KWH_PLOTS, "label": "$\dot{Q}_\mathrm{Tra}$", "rename": "QBui", "plot": True},
        "outputs.hydraulic.storage.WelHRDHW.integral": {**_KWH_PLOTS, "label": "$W_\mathrm{el,HR,DHW}$", "plot": True},
        "outputs.hydraulic.storage.WelHRAftBuf.integral": {**_KWH_PLOTS, "label": "$W_\mathrm{el,HR,AftSto}$", "plot": True},
        "outputs.hydraulic.storage.WelHRBufSto.integral": {**_KWH_PLOTS, "label": "$W_\mathrm{el,HR,Sto}$", "plot": True},
        "outputs.hydraulic.storage.QBufLoss.integral": {**_KWH_PLOTS, "label": "$\dot{Q}_\mathrm{Loss,Buf}$", "rename": "QBufLoss", "plot": True},
        "outputs.hydraulic.storage.QDHWLoss.integral": {**_KWH_PLOTS, "label": "$\dot{Q}_\mathrm{Loss,DHW}$", "rename": "QDHWLoss", "plot": True},
        "outputs.hydraulic.generation.WHPel.numSwi": {**_N_PLOTS, "rename": "numSwiHP", "plot": True, "label": "$N_\mathrm{Swi,HP}$"},
        "outputs.hydraulic.generation.WHRel.numSwi": {**_N_PLOTS, "rename": "numSwiHR", "plot": True, "label": "$N_\mathrm{Swi,AftHR}$"},
        "outputs.hydraulic.storage.WelHRDHW.numSwi": {**_N_PLOTS, "rename": "numSwiHRDHW", "plot": True, "label": "$N_\mathrm{Swi,DHW}$"},
        "outputs.hydraulic.storage.WelHRAftBuf.numSwi": {**_N_PLOTS, "rename": "numSwiHRAftBuf", "plot": True, "label": "$N_\mathrm{Swi,HR,Buf}$"},
        "outputs.hydraulic.storage.WelHRBufSto.numSwi": {**_N_PLOTS, "rename": "numSwiHRBuf", "plot": True, "label": "$N_\mathrm{Swi,HR,AftBuf}$"},
        "hydraulic.control.securityControl.operationalEnvelope.ERR": {**_N_PLOTS, "rename": "opeEnvERR", "plot": True, "label": "$N_\mathrm{OE,HP}$"},
        "hydraulic.control.HRPIDControlBuf.IAE": {**_KH_PLOTS, "rename": "IAE_Buf", "label": "$IAE_\mathrm{Buf}$", "plot": True},
        "hydraulic.control.HRPIDControlDHW.IAE": {**_KH_PLOTS, "rename": "IAE_DHW", "label": "$IAE_\mathrm{DHW}$", "plot": True},
        "hydraulic.control.HRPIDControlBuf.ISE": {**_KH2_PLOTS, "rename": "ISE_Buf", "label": "$ISE_\mathrm{Bui}$", "plot": True},
        "hydraulic.control.HRPIDControlDHW.ISE": {**_KH2_PLOTS, "rename": "ISE_DHW", "label": "$ISE_\mathrm{DHW}$", "plot": True},
        "outputs.hydraulic.control.IAE_Bui": {**_KH_PLOTS, "rename": "IAE_Bui", "label": "$IAE_\mathrm{Bui}$", "plot": True},
        "outputs.hydraulic.control.ISE_Bui": {**_KH2_PLOTS, "rename": "ISE_Bui", "label": "$ISE_\mathrm{Bui}$", "plot": True},
        "outputs.hydraulic.generation.WPumpel.integral": {**_KWH_PLOTS, "rename": "", "plot": True},
        "outputs.hydraulic.generation.WPumpel.totalOnTime": {"factor": 1/3600, "offset": 0, "unit": "h", "rename": "timePump", "plot": True},
    }

    calculated_outputs = {
        "Wel": {**_KWH_PLOTS, "label": "$FEC$", "plot": True},
        "SCOP_HP": {**_N_PLOTS, "label": "$SCOP_\mathrm{HP}$", "plot": True},
        "SCOP": {**_N_PLOTS, "label": "$SCOP$", "plot": True},
        "Savings": {"factor": 100, "offset": 0, "label": "Savings", "unit": "%", "plot": True},
        "partHRQ": {"factor": 100, "offset": 0, "label": r"$\alpha_\mathrm{BH}$", "unit": "%", "plot": True},
        "KRel_4.8": {"factor": 1, "offset": 0, "label": r"$R_\mathrm{EGR=4.8}$", "unit": "-", "plot": True},
        "KRel_1": {"factor": 1, "offset": 0, "label": r"$R_\mathrm{EGR=1}$", "unit": "-", "plot": True},
        "KRel_2.1": {"factor": 1, "offset": 0, "label": r"$R_\mathrm{EGR=2.1}$", "unit": "-", "plot": True},
    }

    heating_rod_integrals = [
        "outputs.hydraulic.generation.WHRel.integral",
        "outputs.hydraulic.storage.WelHRDHW.integral",
        "outputs.hydraulic.storage.WelHRAftBuf.integral",
        "outputs.hydraulic.storage.WelHRBufSto.integral"]

    def __init__(self, study_name, use_ope_env_ctrl=True):
        self.basepath = pathlib.Path(r"D:\02_Paper\01_Energies")
        self.target_mos_file = self.basepath.joinpath("heating_rod_integration_study", "OptimalHeatingRodIntegration", "Resources", "WeatherData.mos")
        self.bes_path = pathlib.Path(r"D:\04_git\BESModPaper\BESMod")
        self.dym_api = None
        self.use_ope_env_ctrl = use_ope_env_ctrl
        self.cwd = self.basepath.joinpath("Results", study_name)
        os.makedirs(self.cwd, exist_ok=True)

    def load_excel_setup(self):
        weather_buildings = pd.read_excel(
            self.basepath.joinpath("heating_rod_integration_study", "Scenarios.xlsx"),
            sheet_name="BuildingsAndWeather"
        )
        weather_buildings = weather_buildings.set_index("type")
        wea = ["name", "path", "color", "TOdaNom"]
        weather = weather_buildings.loc[:, wea]
        buildings = weather_buildings.drop(wea, axis=1)
        return weather, buildings

    def _get_study_product(self):
        weather, buildings = self.load_excel_setup()
        return [
            buildings.columns,
            self.heating_rod_locations,
            self.operational_envelopes.keys(),
            self.TSup_nominal,
            list(self.heating_rod_types.keys())
        ]

    def get_cases_for_weather(self, weather, only_valid):
        cases = []
        product = self._get_study_product()
        for bui_typ, hr_loc, ope_env, t_sup, hr_typ in itertools.product(*product):
            case = StudyParameters(
                building=bui_typ,
                hr_type=hr_typ,
                hr_location=hr_loc,
                ope_env=ope_env,
                temp_sup=t_sup,
                weather=weather
            )
            if case.is_valid_case() or (not only_valid):
                if "1" in case.building:
                    cases.append(case)
        return cases

    def run_study(self, recalculate=False):
        self.dym_api = DymolaAPI(
            cd=self.basepath.joinpath("00_DymolaWorkDir"),
            model_name="OptimalHeatingRodIntegration.Cases.Case1",
            packages=[
                self.bes_path.joinpath("BESMod", "package.mo"),
                self.bes_path.joinpath("installed_dependencies", "IBPSA", "IBPSA", "package.mo"),
                self.bes_path.joinpath("installed_dependencies", "AixLib", "AixLib", "package.mo"),
                self.bes_path.joinpath("installed_dependencies", "Buildings", "Buildings", "package.mo"),
                self.bes_path.joinpath("installed_dependencies", "BuildingSystems", "BuildingSystems", "package.mo"),
                self.basepath.joinpath("heating_rod_integration_study", "OptimalHeatingRodIntegration", "package.mo")
            ],
            n_cpu=12,
            show_window=True
        )

        self.dym_api.sim_setup.stop_time = 365 * 86400
        self.dym_api.sim_setup.output_interval = 15 * 60
        self.dym_api.result_names = list(self.dym_api.outputs.keys())
        model_name = self.dym_api.model_name

        if model_name != self.dym_api.model_name:
            self.dym_api.model_name = model_name

        weather, buildings = self.load_excel_setup()

        for wea_typ in weather.index:
            # Copy file:
            shutil.copyfile(
                self.basepath.joinpath(
                    "heating_rod_integration_study",
                    "OptimalHeatingRodIntegration",
                    "Resources",
                    weather.loc[wea_typ, "path"]),
                self.target_mos_file)
            model_names = []
            result_names = []
            cases = self.get_cases_for_weather(weather=wea_typ, only_valid=True)
            for case in cases:
                if not recalculate:
                    if os.path.isfile(self.cwd.joinpath(case.get_name()+".mat")):
                        print("Case %s already simulated. Skipping ..." % case.get_name())
                        continue
                hr_typ_data = self.heating_rod_types[case.hr_type]
                result_names.append(case.get_name())
                QBui_flow_nominal = buildings.loc[case.weather, case.building]
                model_names.append(
                    "OptimalHeatingRodIntegration.Cases.PythonAPIModel("
                    f"\n\t\tzoneParam=OptimalHeatingRodIntegration.Buildings.{case.building}(), "
                    f"\n\t\tdiscretizationStepsHR={hr_typ_data}, "
                    f"\n\t\thr_location=OptimalHeatingRodIntegration.Models.HRLocation.{case.hr_location}, "
                    f"\n\t\ttableUpp={self.operational_envelopes[case.ope_env]}, "
                    f"\n\t\tparameterStudy("
                    f"\n\t\t\tQHRDHW_flow_nominal={self.QHRDHW_flow_nominal}, "  # TODO
                    f"\n\t\t\tQHRBuf_flow_nominal={QBui_flow_nominal}), "  # TODO
                    f"\n\t\tsystemParameters("
                    f"\n\t\t\tQBui_flow_nominal=fill({QBui_flow_nominal}, 1), "
                    f"\n\t\t\tTOda_nominal={round(weather.loc[case.weather, 'TOdaNom'] + 273.15, 2)},"
                    f"\n\t\t\tTHydSup_nominal=fill({round(case.temp_sup + 273.15, 2)}, 1)),"
                    f"\n\t\t\tuse_opeEncControl={'true' if self.use_ope_env_ctrl else 'false'}"
                    "\n\t\t)"
                )

            self.dym_api.logger.info(f"Simulating weather file {wea_typ} with {len(model_names)} combinations")
            self.dym_api.simulate(
                model_names=model_names,  # TODO: Make possible in ebcpy!
                result_file_name=result_names,
                savepath=str(self.cwd),
                return_option="savepath",
                fail_on_error=False
            )
            self.dym_api.logger.info(f"Finished simulation of {len(model_names)} combinations")
        self.dym_api.close()

    def extract_results(self):
        weather, buildings = self.load_excel_setup()
        product = self._get_study_product()

        cols = pd.MultiIndex.from_product([weather.index.tolist()] + product,
                                          names=["Weather", "Building", "HeatingRodLocation",
                                                 "OperationalEnvelope", "SupplyTemperature", "HeatingRodType"]
                                          )
        data = pd.DataFrame(columns=cols)
        for wea_typ in weather.index:
            cases = self.get_cases_for_weather(weather=wea_typ, only_valid=True)
            for idx, case in enumerate(cases):
                import time
                file = self.cwd.joinpath(case.get_name() + ".mat")
                if not os.path.exists(file):
                    data.loc[:, case.get_multi_key()] = np.NAN
                else:
                    t0 = time.time()
                    values = TimeSeriesData(file).to_df().iloc[-1]
                    sec_loa = time.time() - t0
                    for out in self.outputs.keys():
                        if out in values:
                            data.loc[out, case.get_multi_key()] = values[out]
                        else:
                            print(out)
                            data.loc[out, case.get_multi_key()] = np.NAN
                    sec_ext = time.time() - t0 - sec_loa
                    logger.info("Extracted %s of %s files for weather %s. "
                                "Took %s s to load and %s s to extract.",
                                idx + 1, len(cases), wea_typ,
                                round(sec_loa, 2), round(sec_ext, 2))

            data.to_csv(self.cwd.joinpath("Overall_result.csv"))
            logger.info("Extracted data for weather %s", wea_typ)
        return self.cwd.joinpath("Overall_result.csv")

    def load_and_calc_data(self, path_csv):
        df = pd.read_csv(path_csv, header=[0, 1, 2, 3, 4, 5], index_col=[0])
        df = df.fillna(0)
        rename = {k: v["rename"] for k, v in self.outputs.items() if "rename" in v}
        df = df.rename(index=rename)
        eta_HR = 0.97
        df.loc["WHRel"] = df.loc[self.heating_rod_integrals].sum()
        df.loc["QDem"] = df.loc["QBui"] + df.loc["QDHW"]
        df.loc["Wel"] = df.loc["WHPel"] + df.loc["WHRel"]
        df.loc["SCOP"] = df.loc["QDem"] / df.loc["Wel"]
        df.loc["SCOP_HP"] = df.loc["QHP"] / df.loc["WHPel"]
        df.loc["partHRel"] = df.loc["WHRel"] / df.loc["Wel"]
        df.loc["partHRQ"] = df.loc["WHRel"] / df.loc["QDem"] * eta_HR
        for k_EGR in [4.8, 2.1, 1]:
            df.loc[f"KRel_{k_EGR}"] = 1 - df.loc["SCOP_HP"] ** -1 - df.loc["partHRQ"]*((eta_HR * k_EGR) ** -1 - df.loc["SCOP_HP"] ** -1)

        return df

    def get_all_boundary_cases(self):
        weather, buildings = self.load_excel_setup()
        all_cases = []
        for wea in weather.index:
            all_cases.extend(self.get_cases_for_weather(weather=wea, only_valid=False))
        _cases = pd.DataFrame([c.__dict__ for c in all_cases])
        all_cases = []
        for wea in _cases["weather"].unique():
            for bui in _cases["building"].unique():
                if "2" in bui:
                    continue
                for tsup in _cases["temp_sup"].unique():
                    for ope_env in _cases["ope_env"].unique():
                        all_cases.append(StudyParameters(
                                building=bui, weather=wea,
                                temp_sup=tsup, ope_env=ope_env
                        ))
        return all_cases

    def get_plotting_options(self):
        plot_data = {}
        for k, v in {**self.outputs, **self.calculated_outputs}.items():
            plot_data[v.get("rename", k)] = v.copy()
        return plot_data

    def plot(self, path_csv):
        plot_values = self.get_plotting_options()
        cases = self.get_all_boundary_cases()
        df = self.load_and_calc_data(path_csv=path_csv)
        df = df.transpose()
        for case in cases:
            if not case.is_valid_case():
                continue
            _d = case.xs_df(df).copy()
            _d = _d.transpose()
            _d.loc["Savings"] = (_d.loc["Wel"].max() - _d.loc["Wel"]) / _d.loc["Wel"].max()
            _d = _d.transpose()
            _d = _d.reset_index(level=[0, 1])
            _d.index = _d.loc[:, "HeatingRodLocation"] + "_" + _d.loc[:, "HeatingRodType"]
            _d = _d.sort_index()
            # Print maximal savings where comfort is ok:
            comfort_ok = _d.loc[_d[self.comfort_metric] < self.comfort_boundary]
            if comfort_ok.empty:
                print(case.get_name(), "None", 0, 0)
            else:
                idx = comfort_ok.loc[:, "Savings"].argmax()
                idx_name = comfort_ok.index[idx]
                print(case.get_name(), idx_name, comfort_ok.loc[:, "Savings"].max() * 100, comfort_ok.loc[idx_name, "SCOP"])
            for col in _d.columns:
                if col not in plot_values.keys():
                    continue
                col_data = plot_values[col]
                fig, ax = plt.subplots(figsize=(20, 10))
                _d_col = _d.loc[:, col].copy()
                _d_col *= col_data["factor"]
                _d_col += col_data["offset"]
                max = col_data.get("max")
                if max is not None:
                    ax.set_xlim([_d_col.min() * 0.9, max])
                else:
                    try:
                        ax.set_xlim([_d_col.min() * 0.9, _d_col.max() * 1.1])
                    except ValueError:
                        print("ASJKDHASKHD")
                _d_col.plot.barh(ax=ax)
                ax.set_xlabel(f'{col_data.get("label", col)} in {col_data.get("unit", "-")}')
                path = pathlib.Path(path_csv).parent.joinpath(case.get_name())
                os.makedirs(path, exist_ok=True)
                plt.savefig(path.joinpath(f"{col}.png"))
                plt.close("all")

    def plot_mean_temps(self):

        means = {
            "hydraulic.generation.portGen_out[1].h_outflow":
                {"label": "$T_\mathrm{Gen,Out}$", "color": "red", "linestyle": "-", "factor": 1 / 4184, "offset": 0},
            "hydraulic.control.sigBusGen.hp_bus.TConInMea":
                {"label": "$T_\mathrm{HP,In}$", "color": "blue", "linestyle": "-"},
            "hydraulic.distribution.senTBuiSup.T":
                {"label": "$T_\mathrm{Buf,Out}$", "color": "red", "linestyle": "--"},
            "hydraulic.control.sigBusDistr.TStoBufTopMea":
                {"label": "$T_\mathrm{Buf,Top}$", "color": "red", "linestyle": "--"},
            "hydraulic.control.sigBusDistr.TStoBufBotMea":
                {"label": "$T_\mathrm{HP,In}$", "color": "blue", "linestyle": "-"},
            "hydraulic.control.sigBusDistr.TStoDHWTopMea":
               {"label": "$T_\mathrm{DHW,Top}$", "color": "red", "linestyle": "-."},
            "hydraulic.control.sigBusDistr.TStoDHWBotMea":
               {"label": "$T_\mathrm{DHW,Bot}$", "color": "blue", "linestyle": "-."},
            "hydraulic.transfer.rad[1].vol[5].T":
                {"label": "$T_\mathrm{Rad,Out}$", "color": "blue", "linestyle": "--"},
            "hydraulic.transfer.rad[1].vol[1].T":
                {"label": "$T_\mathrm{Rad,In}$", "color": "red", "linestyle": "--"}
        }
        results = {}
        names = {}
        cases = self.get_all_boundary_cases()
        all_cases = []
        for case in cases:
            for hr_type in self.heating_rod_types:
                for hr_loc in self.heating_rod_locations:
                    all_cases.append(StudyParameters(**{k:v for k, v in case.__dict__.items() if v is not None}, hr_location=hr_loc, hr_type=hr_type))
        for case in all_cases:
            if not case.is_valid_case():
                continue
            df = TimeSeriesData(self.cwd.joinpath(case.get_name() + ".mat")).to_df()
            temp_res = {}
            for mean_name, options in means.items():
                temp_res[mean_name] = df.loc[:, mean_name].mean() * options.get("factor", 1) + options.get("offset", -273.15)
            names[case.get_name()] = case.__dict__
            results[case.get_name()] = temp_res
        df = pd.DataFrame(results)
        df = df.transpose()
        df_n = pd.DataFrame(names)
        df_n = df_n.transpose()
        df = pd.concat([df, df_n], axis=1)
        df.to_excel(self.cwd.joinpath("Mean_temperatures.xlsx"))
        return results

    def plot_time_series(self, cases: list, start: float, end: float, scenario: dict, plot_temperatures: dict, temp_names: str):
        import matplotlib
        matplotlib.use("pgf")
        matplotlib.rcParams.update({
            "pgf.texsystem": "pdflatex",
            'font.family': 'serif',
            'text.usetex': True,
            'font.size': 14,
            'pgf.rcfonts': False,
            'hatch.linewidth': 5
        })
        _cases_full = [StudyParameters(**case, **scenario) for case in cases]

        fig, ax = plt.subplots(len(_cases_full), 2, sharex=True, figsize=(13, 12))
        max_w = 0
        max_n = 0
        twinaxes = []
        for idx, case in enumerate(_cases_full):
            df = TimeSeriesData(self.cwd.joinpath(case.get_name() + ".mat")).to_df()
            df.index /= 86400
            df = df.loc[start:end]
            WelHP = df.loc[:, "outputs.hydraulic.generation.WHPel.integral"].copy()
            WelHR = 0
            for hr in self.heating_rod_integrals:
                if hr in df.columns:
                    WelHR += df.loc[:, hr]
            WelHR /= 3600000
            WelHR -= WelHR.iloc[0]
            WelHP /= 3600000
            WelHP -= WelHP.iloc[0]
            Wel = WelHR + WelHP

            if max_w < Wel.max():
                max_w = Wel.max()
            _p = deepcopy(plot_temperatures)
            for val, plot_settings in _p.items():
                offset = plot_settings.pop("offset", 273.15)
                factor = plot_settings.pop("factor", 1)
                ax[idx, 0].plot(df.loc[:, val] * factor - offset, **plot_settings)
            ax[idx, 1].plot(Wel, color="black", linestyle="-", label="$FEC$ in kWh")
            ax[idx, 1].plot(WelHP, color="green", linestyle="-", label="$FEC_\mathrm{HP}$ in kWh")
            ax[idx, 1].plot(WelHR, color="green", linestyle="--", label="$FEC_\mathrm{BH}$ in kWh")
            ax[idx, 1].set_ylabel("$FEC$ in kWh")
            tax = ax[idx, 1].twinx()
            tax.set_ylabel("On/Off-Switches")
            nHP = df.loc[:, "outputs.hydraulic.generation.WHPel.numSwi"]
            if (nHP - nHP.iloc[0]).max() > max_n:
                max_n = (nHP - nHP.iloc[0]).max()
            #tax.plot(nHP - nHP.iloc[0], label="$N_\mathrm{Swi,HP}$", color="gray", linestyle="-")
            nERR = df.loc[:, "hydraulic.control.securityControl.operationalEnvelope.ERR"]
            if (nERR - nERR.iloc[0]).max() > max_n:
                max_n = (nERR - nERR.iloc[0]).max()
            tax.plot(nERR - nERR.iloc[0], label="$N_\mathrm{ERR}$", color="gray", linestyle="--")

            twinaxes.append(tax)
            ax[idx, 0].set_title(self.loc_rename["_".join(list(cases[idx].values()))])
            ax[idx, 1].set_title(self.loc_rename["_".join(list(cases[idx].values()))])

            ax[idx, 0].set_ylabel("$T$ in °C")
        for _ax in ax[:, 1]:
            _ax.set_ylim([0, max_w])
        for tax in twinaxes:
            tax.set_ylim([0, max_n])
        th, tl = twinaxes[0].get_legend_handles_labels()
        h, l = ax[0, 1].get_legend_handles_labels()
        ax[0, 1].legend(h + th, l + tl, loc="lower left", bbox_to_anchor=(0, 1.15), ncol=2)
        ax[0, 0].legend(loc="lower left", bbox_to_anchor=(0, 1.15), ncol=3)

        ax[-1, 0].set_xlabel("Time in d")
        ax[-1, 1].set_xlabel("Time in d")
        fig.align_ylabels()
        plt.savefig(self.cwd.joinpath("_".join([str(v) for v in scenario.values()]) + f"_{temp_names}.pgf"))
        print(self.cwd.joinpath("_".join([str(v) for v in scenario.values()]) + f"_{temp_names}.pgf"))
        plt.close("all")

    def plot_boxplot(self,
                     path_csv, metric, relative,
                     with_markers=True,
                     with_box=True,
                     sort=None,
                     cases=None,
                     ax: plt.Axes = None,
                     set_ylabels: bool = True,
                     set_legend: bool = True
                     ):
        plot_data = self.get_plotting_options()[metric]

        df = self.load_and_calc_data(path_csv=path_csv)
        df = df.transpose()
        df = df.loc[df.loc[:, self.comfort_metric] <= self.comfort_boundary, metric]
        df *= plot_data["factor"]
        df += plot_data["offset"]
        if ax is None:
            fig, ax = plt.subplots(1, 1)
            _return_later = False
        else:
            _return_later = True
        labels = []
        data = []
        if cases is None:
            cases = self.get_all_boundary_cases()
        for case in cases:
            if not case.is_valid_case():
                continue
            try:
                _df = case.xs_df(df)
                if relative:
                    data.append((_df - _df.median()) / _df.median() * 100)
                    print(case.get_name(), data[-1].max(), data[-1].min())
                else:
                    if metric == "Wel":
                        print(case.get_name(), "_".join(_df.index[_df.argmax()]))
                        data.append(_df - _df.median())
                    #elif metric in ["numSwiHP", "opeEnvERR"]:
                    #    data.append(_df - _df.median())
                    else:
                        data.append(_df)
                labels.append(case.get_short_name())
            except KeyError:
                print(f"Could not find case {case.get_name()} in data")
        labels_sorted = []
        data_sorted = []
        if sort:
            if sort == "min":
                min_maxs = [d.min() for d in data]
            elif sort == "max":
                min_maxs = [d.max() for d in data]
            else:
                raise KeyError
            for _, _label, _data in sorted(zip(min_maxs, labels, data)):
                labels_sorted.append(_label)
                data_sorted.append(_data)
            data = data_sorted
            labels = labels_sorted
        if with_box:
            ax.boxplot(data, whis=1e6, vert=0)
        if with_markers:
            for idx, d in enumerate(data):
                _d, legend_elements = self._get_markers_for_combis(d.copy().reset_index())
                for _, row in _d.iterrows():
                    ax.scatter(row[metric], [idx+1], color=row["color"], marker=row["marker"], s=100)
            if set_legend:
                ax.legend(handles=legend_elements, loc="lower left", bbox_to_anchor=(0, 1), ncol=6)
        if not with_box and not with_markers:
            raise ValueError("Not a valid option. Nothing will be plotted...")
        if relative:
            y_label = f"Deviation of {plot_data['label']} in %"
        else:
            y_label = plot_data["label"] + " in " + plot_data["unit"]
        ax.set_xlabel(y_label)
        if not _return_later:
            ax.set_yticklabels(labels, ha="right")
            plt.savefig(path_csv.parent.joinpath(f"boxplots_{metric}_relative_{relative}.png"))
        else:
            return labels

    def _get_markers_for_combis(self, df):
        marker_hr_locaction = {
            "AfterHeatPump": "o",
            "Storage": "^",
            "AfterStorage": "s"
        }
        color_hr_type = {
            "OnOff": "green",
            "Discrete": "blue",
            "Modulating": "red"
        }

        legend_elements = []
        df["marker"] = None
        df["color"] = None
        from matplotlib.patches import Patch
        from matplotlib.lines import Line2D
        for loc, marker in marker_hr_locaction.items():
            df.loc[df["HeatingRodLocation"] == loc, "marker"] = marker
            legend_elements.append(Line2D([0], [0], marker=marker, color='black', label=self.loc_rename[loc],
                                          markerfacecolor='black', markersize=10))
        for typ, color in color_hr_type.items():
            df.loc[df["HeatingRodType"] == typ, "color"] = color
            legend_elements.append(Patch(facecolor=color, edgecolor=color, label=self.ctrl_rename[typ]))
        return df, legend_elements

    def plot_comfort_vs_costs(self, path_csv, metric_costs="Wel", metric_comfort="dTCom"):
        import matplotlib
        #matplotlib.use("pgf")
        #matplotlib.rcParams.update({
        #    "pgf.texsystem": "pdflatex",
        #    'font.family': 'serif',
        #    'text.usetex': True,
        #    'font.size': 14,
        #    'pgf.rcfonts': False,
        #    'hatch.linewidth': 5
        #})
        plot_data = self.get_plotting_options()

        plot_costs = plot_data[metric_costs]
        plot_comfort = plot_data[metric_comfort]
        cases = self.get_all_boundary_cases()

        df = self.load_and_calc_data(path_csv=path_csv)
        df = df.transpose()
        df.loc[:, metric_costs] *= plot_costs["factor"]
        df.loc[:, metric_costs] += plot_costs["offset"]
        df.loc[:, metric_comfort] *= plot_comfort["factor"]
        df.loc[:, metric_comfort] += plot_comfort["offset"]

        savings_comfort_step_vs_mod = []
        savings_costs_step_vs_mod = []

        for case in cases:
            if not case.is_valid_case():
                continue
            fig, ax = plt.subplots(1, 1, figsize=(5, 5))

            _df = case.xs_df(df).copy()
            _df = _df.reset_index()
            _df, legend_elements = self._get_markers_for_combis(_df)

            if np.all(_df.loc[:, "dTCom"] < 73):
                _dis = _df.loc[_df["HeatingRodType"] == "Discrete", metric_costs]
                _mod = _df.loc[_df["HeatingRodType"] == "Modulating", metric_costs]
                _sav = (_dis.values - _mod.values) / _mod.values * 100
                savings_costs_step_vs_mod.extend(list(_sav))
                if np.any(_sav < -500):
                    print(case.get_name())
                _dis = _df.loc[_df["HeatingRodType"] == "Discrete", metric_comfort]
                _mod = _df.loc[_df["HeatingRodType"] == "Modulating", metric_comfort]
                _sav = (_mod.values - _dis.values)
                savings_comfort_step_vs_mod.extend(list(_sav))

            for _, row in _df.iterrows():
                ax.scatter(row[metric_costs], row[metric_comfort], color=row["color"], marker=row["marker"], s=100)

            ax.legend(handles=legend_elements, loc='upper right')
            ax.set_xlabel(plot_costs["label"] + " in " + plot_costs["unit"])
            ax.set_ylabel(plot_comfort["label"] + " in " + plot_comfort["unit"])
            fig.tight_layout()
            plt.savefig(path_csv.parent.joinpath(f"comfort_vs_costs_{case.get_name()}.png"))
            plt.close("all")
        _rel = np.array(savings_comfort_step_vs_mod) / np.array(savings_costs_step_vs_mod)
        print(_rel.mean(), _rel.max(), _rel.min())
        plt.scatter(savings_costs_step_vs_mod, savings_comfort_step_vs_mod, color="blue", s=100)
        plt.xlabel("Deviation of $FEC$ in %")
        plt.ylabel("Comfort difference in Kh")
        plt.show()

        return savings_comfort_step_vs_mod, savings_costs_step_vs_mod

    def plot_temps(self):
        plot_temperatures_1 = {
            "hydraulic.generation.portGen_out[1].h_outflow":
                {"label": "$T_\mathrm{Gen,Out}$", "color": "red", "linestyle": "-", "factor": 1 / 4184, "offset": 0},
            #"hydraulic.control.sigBusGen.hp_bus.TConInMea":
            #    {"label": "$T_\mathrm{HP,In}$", "color": "blue", "linestyle": "-"},
            "hydraulic.distribution.senTBuiSup.T":
                {"label": "$T_\mathrm{Buf,Out}$", "color": "red", "linestyle": "--"},
            #"hydraulic.control.sigBusDistr.TStoBufTopMea":
            #    {"label": "$T_\mathrm{Buf,Top}$", "color": "red", "linestyle": "--"},
            "hydraulic.control.sigBusDistr.TStoBufBotMea":
                {"label": "$T_\mathrm{HP,In}$", "color": "blue", "linestyle": "-"},
            # "hydraulic.control.sigBusDistr.TStoDHWTopMea":
            #    {"label": "$T_\mathrm{DHW,Top}$", "color": "red", "linestyle": "-."},
            # "hydraulic.control.sigBusDistr.TStoDHWBotMea":
            #    {"label": "$T_\mathrm{DHW,Bot}$", "color": "blue", "linestyle": "-."},
            "hydraulic.control.operationalEnvelopeLimit.uppCombiTable1Ds.y[1]":
                {"label": "$T_\mathrm{Max}$", "color": "black", "linestyle": "--", "offset": 0},
            "hydraulic.control.operationalEnvelopeLimit.TSet":
                {"label": "$T_\mathrm{Set}$", "color": "black", "linestyle": "-."},
        }
        plot_temperatures_2 = {
            "hydraulic.control.sigBusGen.hp_bus.TConInMea":
                {"label": "$T_\mathrm{Gen,In}$", "color": "blue", "linestyle": "-"},
            "hydraulic.distribution.storageBuf.layer[4].T":
                {"label": "$T_\mathrm{Buf,Top}$", "color": "red", "linestyle": "-."},
            "hydraulic.distribution.storageBuf.layer[1].T":
                {"label": "$T_\mathrm{Buf,Bot}$", "color": "blue", "linestyle": "-."},
            "hydraulic.transfer.rad[1].vol[5].T":
                {"label": "$T_\mathrm{Rad,Out}$", "color": "blue", "linestyle": "--"},
            "hydraulic.transfer.rad[1].vol[1].T":
                {"label": "$T_\mathrm{Rad,In}$", "color": "red", "linestyle": "--"},
            "outputs.building.TZone[1]":
                {"label": "$T_\mathrm{Room}$", "color": "black", "linestyle": "-"},
        }
        #for hr_type in self.heating_rod_types:
        hr_type = "Modulating"
        scenario = dict(building="Case_1_standard", weather="warm", temp_sup=75, ope_env="low", hr_type=hr_type)
        cases = [{"hr_location": loc} for loc in self.heating_rod_locations]
        self.plot_time_series(start=14.5, end=15.5, scenario=scenario, cases=cases,
                              plot_temperatures=plot_temperatures_1, temp_names="Sto")
        #self.plot_time_series(start=15, end=16, scenario=scenario, cases=cases,
        #                      plot_temperatures=plot_temperatures_2, temp_names="Retu")

    def _plot_multiple_boxplots(self, path_csv, metrics, cases, name, relative=None, xticks=None, xlim=None):
        _n = len(metrics)
        if relative is None:
            relative = [False] * _n
        if cases is None:
            size = 8
        elif len(cases) == 10:
            size = 8
        else:
            size = round(8 * 6 / 10, 0) + 0.5
        fig, ax = plt.subplots(1, _n, sharey=True, figsize=(15, size))
        fig.subplots_adjust(hspace=0, wspace=0)
        for idx, metric in enumerate(metrics):
            if idx == 0:
                labels = self.plot_boxplot(
                    path_csv=path_csv, relative=relative[idx], metric=metric,
                    cases=cases, ax=ax[idx], set_ylabels=True, set_legend=True
                )
            else:
                self.plot_boxplot(
                    path_csv=path_csv, relative=relative[idx], metric=metric,
                    cases=cases, ax=ax[idx], set_ylabels=False, set_legend=False
                )
        ax[0].set_yticklabels(labels * _n, ha="right")
        if xticks is not None:
            if isinstance(xticks[0], list):
                for _ax, ticks, lim in zip(ax, xticks, xlim):
                    _ax.set_xticks(ticks)
                    _ax.set_xlim(lim)
            else:
                for _ax in ax:
                    _ax.set_xticks(xticks)
                    _ax.set_xlim(xlim)

        plt.savefig(path_csv.parent.joinpath(f"boxplots_results_{name}.png"))
        if cases is not None:
            self._plot_multiple_boxplots(
                path_csv=path_csv, metrics=metrics,
                cases=None, name=f"{name}_appendix", relative=relative, xlim=xlim, xticks=xticks)

    def plot_result_boxplots(self, path_csv):

        cases_savings = [
            StudyParameters(weather="warm", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="average", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=75, ope_env="high", building="Case_1_standard"),
            StudyParameters(weather="warm", temp_sup=55, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="warm", temp_sup=55, ope_env="low", building="Case_1_retrofit"),
            StudyParameters(weather="average", temp_sup=55, ope_env="low", building="Case_1_retrofit"),
            StudyParameters(weather="cold", temp_sup=55, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=55, ope_env="low", building="Case_1_retrofit"),
        ][::-1]
        self._plot_multiple_boxplots(
            path_csv=path_csv, cases=cases_savings,
            metrics=["Wel", "SCOP_HP", "opeEnvERR", "partHRQ"],
            name="savings",
            relative=[True, False, False, False],
            xticks=[[-15, 0, 15], [2.5, 3, 3.5], [0, 1000, 2000], [0, 20, 40]],
            xlim=[[-20, 20], [2, 4], [0, 2500], [0, 40]]
        )

        cases_comfort = [
            StudyParameters(weather="warm", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="average", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=75, ope_env="low", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=75, ope_env="high", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=55, ope_env="high", building="Case_1_standard"),
            StudyParameters(weather="cold", temp_sup=55, ope_env="low", building="Case_1_retrofit"),
        ][::-1]
        # round(8 * 6 / 10, 0) + 0.5))
        prio_bound = self.comfort_boundary
        self.comfort_boundary = 3600 * 1000
        self._plot_multiple_boxplots(
            path_csv=path_csv, cases=cases_comfort,
            metrics=["Wel", "dTCom"],
            name="comfort"
        )
        self.comfort_boundary = prio_bound

        #self._plot_multiple_boxplots(
        #    path_csv=path_csv, cases=None,
        #    metrics=["SCOP", "SCOP_HP"],
        #    name="SCOP"
        #)
        self._plot_multiple_boxplots(
            path_csv=path_csv, cases=cases_savings,
            metrics=["KRel_4.8", "KRel_2.1", "KRel_1"],
            name="EGR",
            xticks=[0.4, 0.5, 0.6, 0.7],
            xlim=[0.35, 0.75]
        )


if __name__ == "__main__":
    STUDY_NAME = "StudyOneYear"
    RUNNER = StudyRunner(study_name=STUDY_NAME, use_ope_env_ctrl=True)
    RUNNER.run_study()
    PATH_CSV = RUNNER.extract_results()
    RUNNER.plot(path_csv=PATH_CSV)
    RUNNER.plot_result_boxplots(path_csv=PATH_CSV)
    RUNNER.plot_comfort_vs_costs(path_csv=PATH_CSV)
    RUNNER.plot_temps()
