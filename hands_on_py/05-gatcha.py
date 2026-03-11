# app_gatcha_simulator.py
# Jalankan dengan:
# streamlit run app_gatcha_simulator.py

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import streamlit as st


st.set_page_config(page_title="Gatcha Game Simulator", page_icon="🎰", layout="wide")


# =========================
# Helper functions
# =========================
def init_state():
    if "balance" not in st.session_state:
        st.session_state.balance = 5000

    if "round_id" not in st.session_state:
        st.session_state.round_id = 0

    if "history" not in st.session_state:
        st.session_state.history = []


def reset_game(initial_balance: int):
    st.session_state.balance = initial_balance
    st.session_state.round_id = 0
    st.session_state.history = []


def simulate_gatcha(balance: int, bet_amount: int, p_win: float, rng: np.random.Generator):
    """
    bet_amount must be multiple of 100
    cost per try = 100
    reward per win = 1000
    """
    n_tries = bet_amount // 100
    cost = n_tries * 100

    if balance < cost:
        return None

    outcomes = rng.random(n_tries) < p_win  # True=win
    n_wins = int(outcomes.sum())
    revenue = n_wins * 1000
    new_balance = balance - cost + revenue

    return {
        "n_tries": n_tries,
        "cost": cost,
        "wins": n_wins,
        "losses": n_tries - n_wins,
        "revenue": revenue,
        "net": revenue - cost,
        "new_balance": new_balance,
        "outcomes": outcomes.astype(int).tolist(),  # 1=win, 0=lose
    }


def add_history_record(result: dict, balance_before_round: int):
    round_id = st.session_state.round_id + 1

    # summary per round
    st.session_state.history.append({
        "type": "round",
        "round": round_id,
        "trial_in_round": None,
        "global_trial": None,
        "result": None,
        "wins_cumulative": None,
        "balance_before": balance_before_round,
        "balance": result["new_balance"],
        "cost": result["cost"],
        "revenue": result["revenue"],
        "net": result["net"],
        "n_tries": result["n_tries"],
        "wins": result["wins"],
        "losses": result["losses"],
    })

    # detail per try
    prev_trials = sum(
        row.get("n_tries", 0)
        for row in st.session_state.history
        if row["type"] == "round"
    ) - result["n_tries"]

    wins_so_far = 0
    detail_rows = [r for r in st.session_state.history if r["type"] == "detail"]
    if detail_rows:
        wins_so_far = sum(r["result"] for r in detail_rows)

    running_balance = balance_before_round - result["cost"]

    for i, outcome in enumerate(result["outcomes"], start=1):
        global_trial = prev_trials + i
        if outcome == 1:
            running_balance += 1000
            wins_so_far += 1

        st.session_state.history.append({
            "type": "detail",
            "round": round_id,
            "trial_in_round": i,
            "global_trial": global_trial,
            "result": outcome,  # 1 win, 0 lose
            "wins_cumulative": wins_so_far,
            "balance_before": None,
            "balance": running_balance,
            "cost": None,
            "revenue": None,
            "net": None,
            "n_tries": None,
            "wins": None,
            "losses": None,
        })

    st.session_state.round_id = round_id


def build_dataframes():
    df = pd.DataFrame(st.session_state.history)
    if df.empty:
        return pd.DataFrame(), pd.DataFrame()

    df_round = df[df["type"] == "round"].copy()
    df_detail = df[df["type"] == "detail"].copy()
    return df_round, df_detail


# =========================
# Plot functions
# =========================
def plot_balance_timeseries(df_detail: pd.DataFrame, initial_balance: int):
    fig, ax = plt.subplots(figsize=(10, 4))

    if df_detail.empty:
        ax.plot([0], [initial_balance], marker="o")
        ax.set_title("Time Series Saldo")
        ax.set_xlabel("Percobaan ke-")
        ax.set_ylabel("Saldo")
        ax.grid(True, alpha=0.3)
        return fig

    x = [0] + df_detail["global_trial"].tolist()
    y = [initial_balance] + df_detail["balance"].tolist()

    ax.plot(x, y, marker="o")
    ax.set_title("Time Series Saldo")
    ax.set_xlabel("Percobaan ke-")
    ax.set_ylabel("Saldo")
    ax.grid(True, alpha=0.3)
    return fig


def plot_win_loss_history(df_detail: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(10, 4))

    if df_detail.empty:
        ax.set_title("Historical Menang/Kalah")
        ax.set_xlabel("Percobaan ke-")
        ax.set_ylabel("Outcome")
        ax.set_yticks([0, 1])
        ax.set_yticklabels(["Kalah", "Menang"])
        ax.grid(True, alpha=0.3)
        return fig

    x = df_detail["global_trial"].values
    y = df_detail["result"].values

    ax.step(x, y, where="post")
    ax.scatter(x, y, s=30)
    ax.set_title("Historical Menang/Kalah")
    ax.set_xlabel("Percobaan ke-")
    ax.set_ylabel("Outcome")
    ax.set_yticks([0, 1])
    ax.set_yticklabels(["Kalah", "Menang"])
    ax.grid(True, alpha=0.3)
    return fig


def plot_histogram_win_loss(df_detail: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(8, 4))

    if df_detail.empty:
        categories = ["Kalah", "Menang"]
        counts = [0, 0]
    else:
        wins = int(df_detail["result"].sum())
        losses = int((df_detail["result"] == 0).sum())
        categories = ["Kalah", "Menang"]
        counts = [losses, wins]

    ax.bar(categories, counts)
    ax.set_title("Histogram Menang vs Kalah")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, axis="y", alpha=0.3)
    return fig


def plot_histogram_final_balance(df_round: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(8, 4))

    if df_round.empty:
        ax.set_title("Histogram Saldo Akhir per Round")
        ax.set_xlabel("Saldo akhir")
        ax.set_ylabel("Frekuensi")
        ax.grid(True, alpha=0.3)
        return fig

    balances = df_round["balance"].values
    n_bins = min(20, max(5, len(balances)))
    ax.hist(balances, bins=n_bins, alpha=0.8)
    ax.set_title("Histogram Saldo Akhir per Round")
    ax.set_xlabel("Saldo akhir")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, alpha=0.3)
    return fig


# =========================
# App
# =========================
init_state()

st.title("🎰 Gatcha Game Simulator")

st.markdown("""
Simulasi sederhana:
- **100** uang taruhan = **1 kali coba**
- **1000** uang taruhan = **10 kali coba**
- Setiap **menang menghasilkan 1000**
- Peluang menang per coba = **p**
""")

with st.sidebar:
    st.header("Pengaturan")

    initial_balance_input = st.number_input(
        "Saldo awal",
        min_value=0,
        value=5000,
        step=100
    )

    p_win = st.slider(
        "Probabilitas menang p",
        min_value=0.0,
        max_value=1.0,
        value=0.10,
        step=0.01
    )

    bet_amount = st.selectbox(
        "Jumlah taruhan",
        options=[100, 200, 300, 400, 500, 1000],
        index=0
    )

    seed_mode = st.checkbox("Gunakan seed tetap", value=False)
    seed_value = None
    if seed_mode:
        seed_value = st.number_input("Seed", min_value=0, value=42, step=1)

    col_sb1, col_sb2 = st.columns(2)
    with col_sb1:
        if st.button("Reset Game", use_container_width=True):
            reset_game(initial_balance_input)
    with col_sb2:
        if st.button("Set Saldo", use_container_width=True):
            st.session_state.balance = initial_balance_input

if seed_mode:
    rng = np.random.default_rng(seed_value)
else:
    rng = np.random.default_rng()

df_round, df_detail = build_dataframes()

total_wins = int(df_detail["result"].sum()) if not df_detail.empty else 0
total_trials = int(len(df_detail)) if not df_detail.empty else 0
empirical_p = total_wins / total_trials if total_trials > 0 else 0.0

m1, m2, m3, m4 = st.columns(4)
with m1:
    st.metric("Saldo sekarang", f"{st.session_state.balance:,}")
with m2:
    st.metric("Total percobaan", total_trials)
with m3:
    st.metric("Total menang", total_wins)
with m4:
    st.metric("Win rate aktual", f"{empirical_p:.3f}")

st.markdown("---")

c1, c2, c3 = st.columns([1, 1, 2])

with c1:
    if st.button("Try", use_container_width=True):
        balance_before_round = st.session_state.balance
        result = simulate_gatcha(
            balance=st.session_state.balance,
            bet_amount=bet_amount,
            p_win=p_win,
            rng=rng
        )

        if result is None:
            st.error("Saldo tidak cukup untuk taruhan ini.")
        else:
            st.session_state.balance = result["new_balance"]
            add_history_record(result, balance_before_round)
            st.success(
                f"{result['n_tries']} coba | menang {result['wins']} | "
                f"kalah {result['losses']} | pemasukan {result['revenue']} | "
                f"net {result['net']:+}"
            )

with c2:
    auto_n = st.number_input("Multi-try rounds", min_value=1, value=10, step=1)
    if st.button("Run Banyak Round", use_container_width=True):
        rounds_done = 0
        for _ in range(auto_n):
            balance_before_round = st.session_state.balance
            result = simulate_gatcha(
                balance=st.session_state.balance,
                bet_amount=bet_amount,
                p_win=p_win,
                rng=rng
            )
            if result is None:
                break
            st.session_state.balance = result["new_balance"]
            add_history_record(result, balance_before_round)
            rounds_done += 1

        st.info(f"Berhasil menjalankan {rounds_done} round.")

with c3:
    st.write(
        f"""
**Status saat ini**
- Taruhan: **{bet_amount}**
- Jumlah coba per round: **{bet_amount // 100}**
- Peluang menang: **{p_win:.2f}**
- Reward per menang: **1000**
"""
    )

df_round, df_detail = build_dataframes()

st.subheader("Time Series")
ts1, ts2 = st.columns(2)

with ts1:
    st.pyplot(plot_balance_timeseries(df_detail, initial_balance_input))

with ts2:
    st.pyplot(plot_win_loss_history(df_detail))

st.subheader("Histogram")
h1, h2 = st.columns(2)

with h1:
    st.pyplot(plot_histogram_win_loss(df_detail))

with h2:
    st.pyplot(plot_histogram_final_balance(df_round))

st.markdown("---")
st.subheader("Riwayat Round")

if df_round.empty:
    st.info("Belum ada riwayat. Tekan tombol Try untuk mulai simulasi.")
else:
    show_df_round = df_round[[
        "round", "n_tries", "wins", "losses", "cost", "revenue", "net", "balance"
    ]].copy()
    show_df_round.columns = [
        "Round", "Jumlah Coba", "Menang", "Kalah", "Biaya", "Pemasukan", "Net", "Saldo Akhir"
    ]
    st.dataframe(show_df_round, use_container_width=True)

with st.expander("Lihat detail setiap percobaan"):
    if df_detail.empty:
        st.write("Belum ada detail percobaan.")
    else:
        show_df_detail = df_detail[[
            "round", "trial_in_round", "global_trial", "result", "wins_cumulative", "balance"
        ]].copy()
        show_df_detail["result"] = show_df_detail["result"].map({1: "Menang", 0: "Kalah"})
        show_df_detail.columns = [
            "Round", "Try dalam Round", "Try Global", "Outcome", "Menang Kumulatif", "Saldo"
        ]
        st.dataframe(show_df_detail, use_container_width=True)