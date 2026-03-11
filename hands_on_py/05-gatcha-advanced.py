
# gatcha_simulator_advanced.py
# Jalankan:
#   pip install streamlit numpy pandas matplotlib pandas
#   streamlit run gatcha_simulator_advanced.py

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import streamlit as st

st.set_page_config(page_title="Advanced Gatcha Simulator", page_icon="🎰", layout="wide")


# =========================================================
# Session state
# =========================================================
def init_state():
    if "balance" not in st.session_state:
        st.session_state.balance = 5000
    if "history_round" not in st.session_state:
        st.session_state.history_round = []
    if "history_try" not in st.session_state:
        st.session_state.history_try = []
    if "round_id" not in st.session_state:
        st.session_state.round_id = 0
    if "global_try_id" not in st.session_state:
        st.session_state.global_try_id = 0


def reset_game(initial_balance: int):
    st.session_state.balance = initial_balance
    st.session_state.history_round = []
    st.session_state.history_try = []
    st.session_state.round_id = 0
    st.session_state.global_try_id = 0


init_state()


# =========================================================
# Core simulation
# =========================================================
def simulate_one_round(balance, n_try, p, cost_per_try, reward_per_win, rng):
    """
    Saldo diupdate setiap try.
    Return:
      round_summary: dict
      try_records: list of dict
    """
    total_required = n_try * cost_per_try
    if balance < total_required:
        return None, None

    balance_before_round = balance
    try_records = []
    outcomes = []
    wins = 0
    losses = 0
    fails_before_success = None
    success_found = 0

    for i in range(1, n_try + 1):
        # biaya langsung dipotong pada saat try dimulai
        balance -= cost_per_try

        is_win = int(rng.random() < p)
        outcomes.append(is_win)

        if is_win == 1:
            wins += 1
            balance += reward_per_win
            if success_found == 0:
                fails_before_success = i - 1
                success_found = 1
        else:
            losses += 1

        st.session_state.global_try_id += 1
        try_records.append({
            "round": st.session_state.round_id + 1,
            "try_in_round": i,
            "global_try": st.session_state.global_try_id,
            "outcome": is_win,                  # 1 menang, 0 kalah
            "balance_after_try": balance,      # ini selalu saldo sesudah try selesai
            "cost_per_try": cost_per_try,
            "reward_per_win": reward_per_win if is_win else 0,
        })

    if fails_before_success is None:
        fails_before_success = n_try

    total_cost = n_try * cost_per_try
    total_revenue = wins * reward_per_win
    net = total_revenue - total_cost

    round_summary = {
        "round": st.session_state.round_id + 1,
        "n_try": n_try,
        "wins": wins,
        "losses": losses,
        "cost": total_cost,
        "revenue": total_revenue,
        "net": net,
        "balance_before_round": balance_before_round,
        "balance_after_round": balance,
        "fails_before_success": fails_before_success,
        "success_found": success_found,
    }

    return round_summary, try_records


def append_round_result(round_summary, try_records):
    st.session_state.round_id += 1
    st.session_state.balance = round_summary["balance_after_round"]
    st.session_state.history_round.append(round_summary)
    st.session_state.history_try.extend(try_records)


def get_dataframes():
    df_round = pd.DataFrame(st.session_state.history_round)
    df_try = pd.DataFrame(st.session_state.history_try)
    return df_round, df_try


# =========================================================
# Theory helpers
# =========================================================
def expected_value_per_try(p, cost_per_try, reward_per_win):
    return p * reward_per_win - cost_per_try


def expected_balance_trajectory(initial_balance, n_steps, p, cost_per_try, reward_per_win):
    ev = expected_value_per_try(p, cost_per_try, reward_per_win)
    x = np.arange(0, n_steps + 1)
    y = initial_balance + ev * x
    return x, y


def truncated_fail_probs(p, n_try):
    """
    Distribusi jumlah gagal sebelum sukses pertama,
    ditruncate pada n_try:
      k = 0..n_try-1: P(K=k)= (1-p)^k p
      k = n_try:     P(K=n_try)= (1-p)^n_try  (tidak sukses sama sekali)
    """
    probs = []
    for k in range(n_try):
        probs.append(((1 - p) ** k) * p)
    probs.append((1 - p) ** n_try)
    return np.arange(0, n_try + 1), np.array(probs)


def monte_carlo_many_players(
    n_players,
    initial_balance,
    n_rounds,
    n_try_per_round,
    p,
    cost_per_try,
    reward_per_win,
    seed=123
):
    rng = np.random.default_rng(seed)
    final_balances = []
    bankrupt_count = 0

    for _ in range(n_players):
        balance = initial_balance
        for _ in range(n_rounds):
            total_required = n_try_per_round * cost_per_try
            if balance < total_required:
                bankrupt_count += 1
                break

            for _ in range(n_try_per_round):
                balance -= cost_per_try
                if rng.random() < p:
                    balance += reward_per_win

        final_balances.append(balance)

    return np.array(final_balances), bankrupt_count


# =========================================================
# Plot helpers
# =========================================================
def plot_balance_timeseries(df_try, initial_balance):
    fig, ax = plt.subplots(figsize=(9, 4))
    if df_try.empty:
        ax.plot([0], [initial_balance], marker="o")
    else:
        x = [0] + df_try["global_try"].tolist()
        y = [initial_balance] + df_try["balance_after_try"].tolist()
        ax.plot(x, y, marker="o")
    ax.set_title("Time Series Saldo Setelah Tiap Try")
    ax.set_xlabel("Global try")
    ax.set_ylabel("Saldo")
    ax.grid(True, alpha=0.3)
    return fig


def plot_win_loss_timeseries(df_try):
    fig, ax = plt.subplots(figsize=(9, 4))
    if not df_try.empty:
        x = df_try["global_try"].values
        y = df_try["outcome"].values
        ax.step(x, y, where="post")
        ax.scatter(x, y, s=25)
    ax.set_title("Historical Menang/Kalah per Try")
    ax.set_xlabel("Global try")
    ax.set_ylabel("Outcome")
    ax.set_yticks([0, 1])
    ax.set_yticklabels(["Kalah", "Menang"])
    ax.grid(True, alpha=0.3)
    return fig


def plot_hist_win_loss(df_try):
    fig, ax = plt.subplots(figsize=(7, 4))
    if df_try.empty:
        counts = [0, 0]
    else:
        counts = [
            int((df_try["outcome"] == 0).sum()),
            int((df_try["outcome"] == 1).sum())
        ]
    ax.bar(["Kalah", "Menang"], counts)
    ax.set_title("Histogram Menang vs Kalah")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, axis="y", alpha=0.3)
    return fig


def plot_hist_final_balance(df_round):
    fig, ax = plt.subplots(figsize=(7, 4))
    if not df_round.empty:
        balances = df_round["balance_after_round"].values
        bins = min(20, max(5, len(balances)))
        ax.hist(balances, bins=bins)
    ax.set_title("Histogram Saldo Akhir per Round")
    ax.set_xlabel("Saldo akhir")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, alpha=0.3)
    return fig


def plot_fail_before_success_ts(df_round):
    fig, ax = plt.subplots(figsize=(9, 4))
    if not df_round.empty:
        ax.plot(df_round["round"], df_round["fails_before_success"], marker="o")
    ax.set_title("Time Series Gagal Sebelum Sukses Pertama")
    ax.set_xlabel("Round")
    ax.set_ylabel("Jumlah gagal")
    ax.grid(True, alpha=0.3)
    return fig


def plot_fail_before_success_hist_with_theory(df_round, p, n_try):
    fig, ax = plt.subplots(figsize=(8, 4))

    xs, probs = truncated_fail_probs(p, n_try)

    if not df_round.empty:
        vals = df_round["fails_before_success"].astype(int).values
        bins = np.arange(-0.5, n_try + 1.5, 1)
        ax.hist(vals, bins=bins, density=True, alpha=0.6, label="Simulasi")

    ax.plot(xs, probs, marker="o", linestyle="-", label="Teori truncated geometric")
    ax.set_title("Histogram Gagal Sebelum Sukses + Kurva Teori")
    ax.set_xlabel("Jumlah gagal sebelum sukses pertama")
    ax.set_ylabel("Probabilitas / density")
    ax.grid(True, alpha=0.3)
    ax.legend()
    return fig


def plot_expected_vs_actual_balance(df_try, initial_balance, p, cost_per_try, reward_per_win):
    fig, ax = plt.subplots(figsize=(9, 4))

    if df_try.empty:
        actual_x = [0]
        actual_y = [initial_balance]
        n_steps = 0
    else:
        actual_x = [0] + df_try["global_try"].tolist()
        actual_y = [initial_balance] + df_try["balance_after_try"].tolist()
        n_steps = int(df_try["global_try"].max())

    ex, ey = expected_balance_trajectory(initial_balance, n_steps, p, cost_per_try, reward_per_win)

    ax.plot(actual_x, actual_y, marker="o", label="Saldo aktual")
    ax.plot(ex, ey, linestyle="--", label="Ekspektasi saldo")
    ax.set_title("Saldo Aktual vs Ekspektasi")
    ax.set_xlabel("Global try")
    ax.set_ylabel("Saldo")
    ax.grid(True, alpha=0.3)
    ax.legend()
    return fig


def plot_monte_carlo_hist(final_balances):
    fig, ax = plt.subplots(figsize=(8, 4))
    if len(final_balances) > 0:
        bins = min(30, max(10, int(np.sqrt(len(final_balances)))))
        ax.hist(final_balances, bins=bins)
    ax.set_title("Monte Carlo: Distribusi Saldo Akhir Banyak Player")
    ax.set_xlabel("Saldo akhir")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, alpha=0.3)
    return fig


def plot_phase_diagram(cost_per_try, reward_per_win):
    ps = np.linspace(0, 1, 101)
    evs = ps * reward_per_win - cost_per_try

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(ps, evs)
    ax.axhline(0, linestyle="--")
    fair_p = cost_per_try / reward_per_win if reward_per_win > 0 else np.nan
    if np.isfinite(fair_p):
        ax.axvline(fair_p, linestyle=":")
    ax.set_title("Phase Diagram: p vs Expected Profit per Try")
    ax.set_xlabel("p(win)")
    ax.set_ylabel("EV per try")
    ax.grid(True, alpha=0.3)
    return fig


# =========================================================
# Sidebar
# =========================================================
with st.sidebar:
    st.header("Pengaturan")

    initial_balance_input = st.number_input("Saldo awal", min_value=0, value=5000, step=100)
    p = st.slider("Probabilitas menang p", 0.0, 1.0, 0.10, 0.01)
    cost_per_try = st.number_input("Harga per taruhan", min_value=1, value=100, step=10)
    reward_per_win = st.number_input("Hadiah per menang", min_value=0, value=1000, step=100)
    n_try_per_round = st.slider("Jumlah try per round", 1, 50, 10, 1)

    use_fixed_seed = st.checkbox("Gunakan seed tetap", value=False)
    seed_value = st.number_input("Seed", min_value=0, value=42, step=1) if use_fixed_seed else None

    st.markdown("---")
    if st.button("Reset Game", use_container_width=True):
        reset_game(initial_balance_input)

    if st.button("Set Saldo ke Saldo Awal", use_container_width=True):
        st.session_state.balance = initial_balance_input

    st.markdown("---")
    ev_try = expected_value_per_try(p, cost_per_try, reward_per_win)
    st.metric("Expected value per try", f"{ev_try:,.2f}")
    fair_p = (cost_per_try / reward_per_win) if reward_per_win > 0 else np.nan
    st.metric("p fair", "∞" if not np.isfinite(fair_p) else f"{fair_p:.3f}")


# =========================================================
# RNG
# =========================================================
rng = np.random.default_rng(seed_value) if use_fixed_seed else np.random.default_rng()


# =========================================================
# Actions first, so metrics below are always updated after trial
# =========================================================
action_col1, action_col2 = st.columns([1, 1])

with action_col1:
    if st.button("TRY 🎲", use_container_width=True):
        round_summary, try_records = simulate_one_round(
            st.session_state.balance,
            n_try_per_round,
            p,
            cost_per_try,
            reward_per_win,
            rng
        )
        if round_summary is None:
            st.error("Saldo tidak cukup untuk menjalankan round ini.")
        else:
            append_round_result(round_summary, try_records)
            st.success(
                f"Round {round_summary['round']} selesai | "
                f"Menang {round_summary['wins']} / {round_summary['n_try']} | "
                f"Net {round_summary['net']:+,} | "
                f"Saldo akhir {round_summary['balance_after_round']:,}"
            )

with action_col2:
    auto_rounds = st.number_input("Run banyak round", min_value=1, value=10, step=1)
    if st.button("RUN AUTO", use_container_width=True):
        done = 0
        for _ in range(auto_rounds):
            round_summary, try_records = simulate_one_round(
                st.session_state.balance,
                n_try_per_round,
                p,
                cost_per_try,
                reward_per_win,
                rng
            )
            if round_summary is None:
                break
            append_round_result(round_summary, try_records)
            done += 1
        st.info(f"Berhasil menjalankan {done} round.")


# =========================================================
# Updated metrics after actions
# =========================================================
df_round, df_try = get_dataframes()

total_wins = int(df_try["outcome"].sum()) if not df_try.empty else 0
total_tries = int(len(df_try)) if not df_try.empty else 0
empirical_p = total_wins / total_tries if total_tries > 0 else 0.0

st.title("🎰 Advanced Gatcha Simulator")

m1, m2, m3, m4, m5 = st.columns(5)
m1.metric("Saldo sekarang", f"{st.session_state.balance:,}")
m2.metric("Total round", int(st.session_state.round_id))
m3.metric("Total try", total_tries)
m4.metric("Total menang", total_wins)
m5.metric("Win rate aktual", f"{empirical_p:.3f}")

st.markdown(
    f"""
**Konfigurasi aktif**
- harga per taruhan = **{cost_per_try:,}**
- hadiah per menang = **{reward_per_win:,}**
- try per round = **{n_try_per_round}**
- p(win) = **{p:.2f}**
"""
)

# =========================================================
# Time series
# =========================================================
st.subheader("Time Series")
ts1, ts2 = st.columns(2)

with ts1:
    st.pyplot(plot_balance_timeseries(df_try, initial_balance_input))

with ts2:
    st.pyplot(plot_win_loss_timeseries(df_try))

# =========================================================
# Histograms
# =========================================================
st.subheader("Histogram")
h1, h2 = st.columns(2)

with h1:
    st.pyplot(plot_hist_win_loss(df_try))

with h2:
    st.pyplot(plot_hist_final_balance(df_round))

# =========================================================
# Fail before success
# =========================================================
st.subheader("Gagal Sebelum Sukses Pertama")
g1, g2 = st.columns(2)

with g1:
    st.pyplot(plot_fail_before_success_ts(df_round))

with g2:
    st.pyplot(plot_fail_before_success_hist_with_theory(df_round, p, n_try_per_round))

# =========================================================
# Expected balance
# =========================================================
st.subheader("Ekspektasi vs Realisasi Saldo")
st.pyplot(plot_expected_vs_actual_balance(
    df_try,
    initial_balance_input,
    p,
    cost_per_try,
    reward_per_win
))

# =========================================================
# Monte Carlo many players
# =========================================================
st.subheader("Monte Carlo Banyak Player")

mc1, mc2, mc3 = st.columns(3)
n_players = mc1.number_input("Jumlah player", min_value=10, value=500, step=10)
mc_rounds = mc2.number_input("Jumlah round simulasi", min_value=1, value=50, step=1)
mc_seed = mc3.number_input("Seed Monte Carlo", min_value=0, value=123, step=1)

final_balances, bankrupt_count = monte_carlo_many_players(
    n_players=n_players,
    initial_balance=initial_balance_input,
    n_rounds=mc_rounds,
    n_try_per_round=n_try_per_round,
    p=p,
    cost_per_try=cost_per_try,
    reward_per_win=reward_per_win,
    seed=mc_seed
)

mc_a, mc_b, mc_c = st.columns(3)
mc_a.metric("Rata-rata saldo akhir", f"{final_balances.mean():,.2f}")
mc_b.metric("Median saldo akhir", f"{np.median(final_balances):,.2f}")
mc_c.metric("Player gagal lanjut", int(bankrupt_count))

st.pyplot(plot_monte_carlo_hist(final_balances))

# =========================================================
# Phase diagram
# =========================================================
st.subheader("Phase Diagram")
st.pyplot(plot_phase_diagram(cost_per_try, reward_per_win))

# =========================================================
# Tables
# =========================================================
st.subheader("Riwayat Round")
if df_round.empty:
    st.info("Belum ada riwayat.")
else:
    show_round = df_round.copy()
    show_round["success_found"] = show_round["success_found"].map({1: "Ada", 0: "Tidak"})
    show_round = show_round.rename(columns={
        "round": "Round",
        "n_try": "Jumlah Try",
        "wins": "Menang",
        "losses": "Kalah",
        "cost": "Biaya",
        "revenue": "Pemasukan",
        "net": "Net",
        "balance_before_round": "Saldo Awal Round",
        "balance_after_round": "Saldo Akhir Round",
        "fails_before_success": "Gagal Sebelum Sukses Pertama",
        "success_found": "Sukses Ditemukan?"
    })
    st.dataframe(show_round, use_container_width=True)

with st.expander("Riwayat Tiap Try"):
    if df_try.empty:
        st.write("Belum ada detail try.")
    else:
        show_try = df_try.copy()
        show_try["outcome"] = show_try["outcome"].map({1: "Menang", 0: "Kalah"})
        show_try = show_try.rename(columns={
            "round": "Round",
            "try_in_round": "Try dalam Round",
            "global_try": "Global Try",
            "outcome": "Outcome",
            "balance_after_try": "Saldo Setelah Try",
            "cost_per_try": "Biaya Try",
            "reward_per_win": "Hadiah Diterima"
        })
        st.dataframe(show_try, use_container_width=True)
