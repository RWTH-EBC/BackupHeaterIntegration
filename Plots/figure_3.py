import os
import pathlib
import matplotlib
import matplotlib.pyplot as plt
matplotlib.use("pgf")
matplotlib.rcParams.update({
    "pgf.texsystem": "pdflatex",
    'font.family': 'serif',
    'text.usetex': True,
    'pgf.rcfonts': False,
    'hatch.linewidth': 5
})
import numpy as np
import pandas as pd
from io import StringIO
from scipy.io import loadmat



def _load_mos(path):
    sep = "\t"
    __irr_name = "__irrelevant"
    with open(path, "r") as file:
        lines = file.readlines()
    idx = 0
    for idx, line in enumerate(lines):
        if line.startswith("double") or line.startswith("#"):
            continue
        else:
            break
    mapping = pd.read_excel(pathlib.Path(__file__).parents[1].joinpath("MapMOS.xlsx"), sheet_name="Map")
    names = mapping["name"].to_dict()
    names = [v if v != "-" else f"{__irr_name}_{k}" for k, v in names.items()]
    lines_content = lines[idx:]
    lines_content.insert(0, sep.join(names))
    df = pd.read_csv(StringIO("\n".join(lines_content)), sep=sep)
    df = df.set_index("time")
    return df


def plot_motivation(complex=False):

    T_water_cold = 10
    T_dhw = 60
    delta_T_min_HE = 5
    T_Amb_min = -20
    T_Amb_max = 20
    T_room = 20
    T_Biv = -2
    dTOpeEnv = 5

    radiators = np.array([
        [75, -14.4],
        [55, -14.4],
        [75, -12.1],
        [55, -12.1],
        [75, -10.5],
        [55, -10.5],
    ])

    # Create fig:
    fig, ax = plt.subplots(nrows=2, ncols=1, sharex=True, gridspec_kw={'height_ratios': [1, 4]})

    def _lines_for_rad(rad, heat_thres):
        return np.array([rad[1], heat_thres]), np.array([rad[0], heat_thres])

    def _lines_between_rads(rad1, rad2):
        return np.array([rad1[1], rad2[1]]), np.array([rad1[0], rad2[0]])

    def _get_extended_lines(rad, heat_thres, t_min):
        x, y = _lines_for_rad(rad, heat_thres)
        model = np.polyfit(x, y, deg=1)
        x = np.array([t_min, rad[1]])
        return x, model[0] * x + model[1]

    # Building demand
    ax[1].plot(*_lines_for_rad(radiators[1, :], T_room),
               color="red", label="$T_\mathrm{Rad,Sup}$")
    ax[1].plot(*_lines_for_rad(radiators[4, :], T_room),
               color="red")
    #ax[1].plot(*_lines_between_rads(radiators[1, :], radiators[0, :]),
    #           color="red")
    #ax[1].plot(*_lines_between_rads(radiators[0, :], radiators[4, :]),
    #           color="red")
    ax[1].plot(*_get_extended_lines(radiators[1, :], T_room, T_Amb_min),
               color="red", linestyle="--")
    ax[1].plot(*_get_extended_lines(radiators[4, :], T_room, T_Amb_min),
               color="red", linestyle="--")
    ax[1].plot([T_Amb_min, T_room],
               [T_dhw] * 2,
               color="blue",
               linestyle="-",
               label="$T_\mathrm{DHW}$")
    ax[1].scatter(
        radiators[:, 1],
        radiators[:, 0],
        marker="x",
        s=100,
        color="red",
        label="$T_\mathrm{Rad,Nom}$"
    )

    # Antilegionelle
    # ax[1].plot([T_Amb_min, T_Amb_max], [T_Anti_Leg, T_Anti_Leg], color="red", label="$T_\mathrm{TWW}$")
    if complex:
        ax[1].plot([T_Amb_min, T_Amb_max], [T_water_cold + delta_T_min_HE, T_water_cold + delta_T_min_HE],
                   color="blue",
                   linestyle="-",
                   label="$T_\mathrm{RL, TWWS}$")

    # operational envelope:
    _op_env_200A = np.array([
        [-20, 50],
        [-10, 60],
        [30, 60],
        [35, 55]
    ])
    _op_env_250A = np.array([
        [-20, 60],
        [-10, 70 ],
        [30, 70]
    ])
    ax[1].plot(_op_env_250A[:, 0], _op_env_250A[:, 1], marker="^", linestyle="-",  color="black", label="$T_\mathrm{OE,High}$")
    ax[1].plot(_op_env_200A[:, 0], _op_env_200A[:, 1], marker="^", linestyle="--", color="black", label="$T_\mathrm{OE,Low}$")
    ax[1].plot(_op_env_200A[:, 0], _op_env_200A[:, 1] - dTOpeEnv, marker="^", linestyle="-.", color="gray",
               label="$T_\mathrm{OE,Low} - \Delta T_\mathrm{OE}$")

    #ax[1].plot([-20, 20], [35, 75], marker="^", linestyle="-", color="black")

    # Get scenario
    import seaborn as sns  # for nicer graphics
    _w_path = pathlib.Path(__file__).parents[1].joinpath("OptimalHeatingRodIntegration", "Resources")
    df_p = _load_mos(path=_w_path.joinpath("TRY2015_522361130393_Jahr_City_Potsdam.mos"))
    sns.kdeplot(df_p["TDryBul"], ax=ax[0], legend=False, color="green", linestyle="-",
                label="Potsdam (P)")
    df_m = _load_mos(path=_w_path.joinpath("TRY2010_12_Somm_City_Mannheim.mos"))
    sns.kdeplot(df_m["TDryBul"], ax=ax[0], legend=False, color="red", linestyle="-",
                label="Mannheim (M)")
    df_f = _load_mos(path=_w_path.joinpath("TRY2010_11_Wint_City_Fichtelberg.mos"))
    sns.kdeplot(df_f["TDryBul"], ax=ax[0], legend=False, color="blue", linestyle="-",
                label="Fichtelberg (F)")
    ax[0].set_ylabel("$p$ in %")
    vals = ax[0].get_yticks()
    ax[0].set_yticklabels([str(int(val * 100)) for val in vals])
    ax[0].tick_params(
        axis='x',  # changes apply to the x-axis
        which='both',  # both major and minor ticks are affected
        bottom=False,  # ticks along the bottom edge are off
        top=False,  # ticks along the top edge are off
        labelbottom=False)
    # Frosting
    x_ticks = list(np.arange(T_Amb_min, T_Amb_max + 20, 10))
    x_tick_labels = [str(x_tick) for x_tick in x_ticks]
    ax[1].axvline(T_Biv, color="black")
    minor_x_tick_labels = []
    minor_x_ticks = []
    minor_x_ticks.append(T_Biv)
    minor_x_tick_labels.append("$T_\mathrm{Biv}$")
    for t, name in zip(
            [-14.4, -12.1, -10.5], ["F", "P", "M"]):#"$T_\mathrm{Oda,Nom,P}$", "$T_\mathrm{Oda,Nom,M}$"]):
        #if t != -14.4:
        #    continue
        minor_x_ticks.append(t)
        minor_x_tick_labels.append(name)
    #ax[1].minorticks_on()
    ax[1].tick_params(axis='x', which='minor', bottom=True, labelbottom=True, pad=20)
    ax[1].set_xticks(x_ticks)
    ax[1].set_xticklabels(x_tick_labels)
    ax[1].set_xticks(minor_x_ticks, minor=True)
    ax[1].set_xticklabels(minor_x_tick_labels, minor=True)
    # ax[0].set_xticks([])

    ax[1].set_ylabel("$T_\mathrm{Demand}$ in °C")
    ax[1].set_xlabel("$T_\mathrm{Oda}$ in °C")
    # Shrink current axis by 20%
    #box = ax[1].get_position()
    #ax[1].set_position([box.x0, box.y0, box.width * 0.8, box.height])
    #box = ax[0].get_position()
    #ax[0].set_position([box.x0, box.y0, box.width * 0.8, box.height])
    # Put a legend to the right of the current axis
    # ax[1].legend(loc='center left', bbox_to_anchor=(1, 0.5), framealpha=1, edgecolor="black", labelspacing=0.6)
    # ax[0].legend(loc='center left', bbox_to_anchor=(1, 0.5), framealpha=1, edgecolor="black")
    ax[1].set_xlim((-20, 20))
    ax[1].set_ylim([40, 90])
    ax[0].legend(loc="upper left", bbox_to_anchor=(1.01, 1), edgecolor="black", borderaxespad=0.)
    ax[1].legend(loc="upper left", bbox_to_anchor=(1.01, 1), edgecolor="black", borderaxespad=0.)

    #plt.subplots_adjust(hspace=0.1, right=0.7)
    fig.align_ylabels()
    fig.tight_layout()
    plt.savefig(pathlib.Path(__file__).parent.joinpath("Figure_3.pgf"))


if __name__ == '__main__':
    plot_motivation(complex=False)