# app_variabel_acak_genz.py
# Jalankan:
#   pip install streamlit numpy pandas matplotlib
#   streamlit run app_variabel_acak_genz.py

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import streamlit as st

st.set_page_config(
    page_title="Week 05 - Variabel Acak",
    page_icon="🎲",
    layout="wide"
)

# =========================
# Helper functions
# =========================
def expected_value(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)
    return np.sum(values * probs)

def variance_value(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)
    mu = expected_value(values, probs)
    return np.sum(((values - mu) ** 2) * probs)

def simulate_discrete(values, probs, n=10000, seed=42):
    rng = np.random.default_rng(seed)
    return rng.choice(values, size=n, p=probs)

def cumulative_mean(samples):
    return np.cumsum(samples) / np.arange(1, len(samples) + 1)

def plot_cumulative_mean(samples, theoretical_mean, title="Rata-rata Kumulatif"):
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(cumulative_mean(samples), label="Rata-rata simulasi")
    ax.axhline(theoretical_mean, linestyle="--", label=f"E[X] teoritis = {theoretical_mean:.2f}")
    ax.set_title(title)
    ax.set_xlabel("Jumlah percobaan")
    ax.set_ylabel("Nilai rata-rata")
    ax.grid(True, alpha=0.3)
    ax.legend()
    return fig

def plot_histogram(samples, title="Histogram", xlabel="Nilai"):
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.hist(samples, bins=30, alpha=0.8)
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Frekuensi")
    ax.grid(True, alpha=0.3)
    return fig

def plot_pmf_cdf(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)

    idx = np.argsort(values)
    values = values[idx]
    probs = probs[idx]
    cdf = np.cumsum(probs)

    fig1, ax1 = plt.subplots(figsize=(7, 4))
    ax1.stem(values, probs, basefmt=" ")
    ax1.set_title("PMF / Probability Mass Function")
    ax1.set_xlabel("x")
    ax1.set_ylabel("P(X=x)")
    ax1.grid(True, alpha=0.3)

    fig2, ax2 = plt.subplots(figsize=(7, 4))
    ax2.step(values, cdf, where="post")
    ax2.set_ylim(0, 1.05)
    ax2.set_title("CDF / Cumulative Distribution Function")
    ax2.set_xlabel("x")
    ax2.set_ylabel("P(X≤x)")
    ax2.grid(True, alpha=0.3)

    return fig1, fig2

def geometric_trials_until_success(p_success, n=10000, seed=42):
    rng = np.random.default_rng(seed)
    return rng.geometric(p_success, size=n)

# =========================
# Sidebar
# =========================
st.sidebar.title("🎓 Lecture Control Panel")
seed = st.sidebar.number_input("Random seed", min_value=0, value=42, step=1)
show_teacher_notes = st.sidebar.checkbox("Tampilkan catatan dosen", value=True)
show_quick_quiz = st.sidebar.checkbox("Tampilkan quick quiz", value=True)

st.sidebar.markdown("---")
st.sidebar.markdown("### Pilih gaya")
mode = st.sidebar.radio(
    "Mode tampilan",
    ["Lecture", "Lab", "Challenge"],
    index=0
)

# =========================
# Header
# =========================
st.title("🎲 Week 05 — Variabel Acak, Ekspektasi, dan Variansi")
st.caption("Interactive Streamlit demo for classroom use")

st.markdown("""
Materi ini menekankan bahwa **variabel acak memetakan dunia acak menjadi angka**,
**ekspektasi** adalah rata-rata jangka panjang, dan **variansi** adalah ukuran risiko atau
“seberapa liar” hasil bisa berfluktuasi. Struktur demo di bawah dibuat mengikuti agenda Minggu 05. :contentReference[oaicite:1]{index=1}
""")

if show_teacher_notes:
    st.info("""
**Narasi pembuka dosen**  
“Hari ini kita belajar berpikir seperti engineer. Bukan sekadar ‘feeling’, tapi memakai **E[X]** dan **Var(X)** untuk membuat keputusan.”
""")

# =========================
# Tabs
# =========================
tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
    "1. Hook: Gacha",
    "2. Law of Averages",
    "3. Variansi = Risiko",
    "4. PMF vs CDF",
    "5. Risk-Return Tradeoff",
    "6. Expected Retry"
])

# =========================
# TAB 1 - Gacha
# =========================
with tab1:
    st.header("1) The Hook — Gacha & Loot Boxes")
    st.markdown("""
Bagian ini mengikuti hook perkuliahan: membandingkan item bernilai tinggi yang bisa dibeli langsung
vs dicoba lewat gacha untuk memperkenalkan variabel acak dan ekspektasi. :contentReference[oaicite:2]{index=2}
""")

    c1, c2 = st.columns([1, 1])

    with c1:
        rare_value = st.number_input("Nilai item langka", min_value=0.0, value=1000.0, step=50.0)
        ticket_cost = st.number_input("Biaya satu kali gacha", min_value=0.0, value=100.0, step=10.0)
        rare_prob = st.slider("Probabilitas dapat item langka", 0.0, 1.0, 0.05, 0.01)

    with c2:
        values = np.array([rare_value, 0.0])
        probs = np.array([rare_prob, 1 - rare_prob])
        ex = expected_value(values, probs)
        varx = variance_value(values, probs)

        st.metric("E[X] hadiah", f"{ex:,.2f}")
        st.metric("Var(X)", f"{varx:,.2f}")
        st.metric("Expected profit pemain", f"{ex - ticket_cost:,.2f}")
        st.metric("Expected profit bandar", f"{ticket_cost - ex:,.2f}")

        if ex > ticket_cost:
            st.success("Secara matematis pemain diuntungkan.")
        elif ex < ticket_cost:
            st.error("Secara matematis bandar diuntungkan.")
        else:
            st.warning("Permainan fair secara ekspektasi.")

    df = pd.DataFrame({
        "Outcome": ["Dapat item langka", "Gagal dapat item"],
        "Nilai": values,
        "Probabilitas": probs
    })
    st.dataframe(df, use_container_width=True)

    if show_quick_quiz:
        st.warning("Quick quiz: kalau E[X] = 50 tapi biaya tiket = 100, apakah game ini fair?")

# =========================
# TAB 2 - Law of Averages
# =========================
with tab2:
    st.header("2) Live Coding — The Law of Averages")
    st.markdown("""
Di agenda kuliah, bagian ini meminta simulasi gacha 10.000 kali dan memplot rata-rata kumulatif
agar terlihat konvergensi ke nilai harapan. :contentReference[oaicite:3]{index=3}
""")

    n_sim = st.slider("Jumlah simulasi", 100, 50000, 10000, 100)
    rare_value = st.number_input("Nilai hadiah langka", min_value=0.0, value=1000.0, step=50.0, key="law_rare")
    rare_prob = st.slider("P(hadiah langka)", 0.0, 1.0, 0.05, 0.01, key="law_prob")

    values = np.array([rare_value, 0.0])
    probs = np.array([rare_prob, 1 - rare_prob])
    ex = expected_value(values, probs)
    samples = simulate_discrete(values, probs, n=n_sim, seed=seed)

    st.metric("Ekspektasi teoretis", f"{ex:,.2f}")
    st.metric("Rata-rata simulasi", f"{samples.mean():,.2f}")

    st.pyplot(plot_cumulative_mean(samples, ex, title="Konvergensi Rata-rata Kumulatif ke E[X]"))

    if show_teacher_notes:
        st.info("""
**Poin dosen**  
E[X] bukan berarti hasil yang pasti muncul sekali main.  
E[X] adalah rata-rata jangka panjang bila eksperimen diulang sangat banyak kali.
""")

# =========================
# TAB 3 - Variansi = Risiko
# =========================
with tab3:
    st.header("3) Deep Dive — Variansi = Risiko")
    st.markdown("""
Agenda kuliah memakai contoh dua server: rata-rata sama, tetapi salah satunya lebih “ganas”
karena spike yang besar. Itulah intuisi variansi sebagai risiko atau ketidakstabilan. :contentReference[oaicite:4]{index=4}
""")

    colA, colB = st.columns(2)

    with colA:
        st.subheader("Server A — Stabil")
        a_vals = np.array([
            st.number_input("Latency A1", value=45.0),
            st.number_input("Latency A2", value=55.0)
        ])
        a_p1 = st.slider("P(A1)", 0.0, 1.0, 0.5, 0.01)
        a_probs = np.array([a_p1, 1 - a_p1])

    with colB:
        st.subheader("Server B — Volatil")
        b_vals = np.array([
            st.number_input("Latency B1", value=20.0),
            st.number_input("Latency B2", value=80.0)
        ])
        b_p1 = st.slider("P(B1)", 0.0, 1.0, 0.5, 0.01)
        b_probs = np.array([b_p1, 1 - b_p1])

    ex_a, var_a = expected_value(a_vals, a_probs), variance_value(a_vals, a_probs)
    ex_b, var_b = expected_value(b_vals, b_probs), variance_value(b_vals, b_probs)

    m1, m2, m3, m4 = st.columns(4)
    m1.metric("E[A]", f"{ex_a:.2f} ms")
    m2.metric("Var(A)", f"{var_a:.2f}")
    m3.metric("E[B]", f"{ex_b:.2f} ms")
    m4.metric("Var(B)", f"{var_b:.2f}")

    n_obs = st.slider("Jumlah observasi", 100, 20000, 3000, 100)
    sim_a = simulate_discrete(a_vals, a_probs, n_obs, seed=seed)
    sim_b = simulate_discrete(b_vals, b_probs, n_obs, seed=seed + 1)

    c1, c2 = st.columns(2)
    with c1:
        st.pyplot(plot_histogram(sim_a, "Histogram Latency Server A", "Latency (ms)"))
    with c2:
        st.pyplot(plot_histogram(sim_b, "Histogram Latency Server B", "Latency (ms)"))

    if var_a < var_b:
        st.success("Server A lebih stabil karena variansinya lebih kecil.")
    elif var_b < var_a:
        st.success("Server B lebih stabil karena variansinya lebih kecil.")
    else:
        st.info("Kedua server punya tingkat sebaran yang sama.")

# =========================
# TAB 4 - PMF vs CDF
# =========================
with tab4:
    st.header("4) Micro-Lecture — PMF vs CDF")
    st.markdown("""
Agenda pertemuan kedua menyebutkan visual step-plot untuk PMF/CDF, dengan penekanan bahwa
CDF tidak pernah turun karena probabilitas kumulatif hanya bertambah atau tetap. :contentReference[oaicite:5]{index=5}
""")

    x1 = st.number_input("x1", value=0.0)
    x2 = st.number_input("x2", value=1.0)
    x3 = st.number_input("x3", value=2.0)

    p1 = st.slider("p1", 0.0, 1.0, 0.2, 0.01)
    p2 = st.slider("p2", 0.0, 1.0, 0.5, 0.01)
    p3 = 1.0 - p1 - p2

    if p3 < 0:
        st.error("p1 + p2 harus <= 1.")
    else:
        values = np.array([x1, x2, x3])
        probs = np.array([p1, p2, p3])

        st.dataframe(pd.DataFrame({"x": values, "P(X=x)": probs}), use_container_width=True)

        fig1, fig2 = plot_pmf_cdf(values, probs)
        c1, c2 = st.columns(2)
        with c1:
            st.pyplot(fig1)
        with c2:
            st.pyplot(fig2)

        st.latex(r"E[X] = \sum_x x \cdot P(X=x)")
        st.latex(r"Var(X) = E[X^2] - (E[X])^2")
        st.write(f"**E[X] = {expected_value(values, probs):.4f}**")
        st.write(f"**Var(X) = {variance_value(values, probs):.4f}**")

# =========================
# TAB 5 - Risk Return
# =========================
with tab5:
    st.header("5) Pod Challenge — Risk-Return Tradeoff")
    st.markdown("""
Sesuai agenda, mahasiswa diminta membandingkan dua proyek:
A stabil dan B volatil, menghitung **E[X]**, **Var(X)**, mensimulasikan hasil,
dan melihat apakah proyek dengan ekspektasi lebih tinggi selalu lebih baik. :contentReference[oaicite:6]{index=6}
""")

    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Proyek A")
        a_gain = st.number_input("Untung A", value=10000.0, step=1000.0)
        a_loss = st.number_input("Rugi A", value=-1000.0, step=500.0)
        a_pg = st.slider("P(untung A)", 0.0, 1.0, 0.9, 0.01)

    with col2:
        st.subheader("Proyek B")
        b_gain = st.number_input("Untung B", value=50000.0, step=1000.0)
        b_loss = st.number_input("Rugi B", value=-10000.0, step=500.0)
        b_pg = st.slider("P(untung B)", 0.0, 1.0, 0.3, 0.01)

    vals_a = np.array([a_gain, a_loss])
    probs_a = np.array([a_pg, 1 - a_pg])

    vals_b = np.array([b_gain, b_loss])
    probs_b = np.array([b_pg, 1 - b_pg])

    ex_a, var_a = expected_value(vals_a, probs_a), variance_value(vals_a, probs_a)
    ex_b, var_b = expected_value(vals_b, probs_b), variance_value(vals_b, probs_b)

    mm1, mm2, mm3, mm4 = st.columns(4)
    mm1.metric("E[A]", f"{ex_a:,.2f}")
    mm2.metric("Var(A)", f"{var_a:,.2f}")
    mm3.metric("E[B]", f"{ex_b:,.2f}")
    mm4.metric("Var(B)", f"{var_b:,.2f}")

    n_runs = st.slider("Jumlah simulasi proyek", 100, 20000, 1000, 100)
    init_capital = st.number_input("Modal awal", value=20000.0, step=1000.0)

    sim_a = simulate_discrete(vals_a, probs_a, n_runs, seed=seed)
    sim_b = simulate_discrete(vals_b, probs_b, n_runs, seed=seed + 10)

    bankrupt_a = np.sum(init_capital + sim_a < 0)
    bankrupt_b = np.sum(init_capital + sim_b < 0)

    c1, c2 = st.columns(2)
    with c1:
        st.pyplot(plot_histogram(sim_a, "Histogram Profit/Loss Proyek A", "Profit/Loss"))
        st.metric("Jumlah bangkrut A", int(bankrupt_a))
    with c2:
        st.pyplot(plot_histogram(sim_b, "Histogram Profit/Loss Proyek B", "Profit/Loss"))
        st.metric("Jumlah bangkrut B", int(bankrupt_b))

    st.warning("Diskusi kelas: apakah E[X] tinggi selalu lebih baik jika risiko kebangkrutan juga tinggi?")

# =========================
# TAB 6 - Expected Retry
# =========================
with tab6:
    st.header("6) Studi Kasus — Expected Retry Login")
    st.markdown("""
Materi minggu ini juga memasukkan contoh retry logic login:
jika gagal login dengan probabilitas tertentu, berapa rata-rata jumlah percobaan sampai sukses.
Ini menjadi pengantar ke distribusi geometrik. :contentReference[oaicite:7]{index=7}
""")

    p_fail = st.slider("Probabilitas gagal login", 0.0, 0.99, 0.2, 0.01)
    p_success = 1 - p_fail
    n_users = st.slider("Jumlah user", 100, 50000, 10000, 100)

    if p_success == 0:
        st.error("Kalau peluang sukses 0, user tidak akan pernah login.")
    else:
        trials = geometric_trials_until_success(p_success, n=n_users, seed=seed)
        theoretical_mean = 1 / p_success

        m1, m2 = st.columns(2)
        m1.metric("Rata-rata teoretis trial", f"{theoretical_mean:.4f}")
        m2.metric("Rata-rata simulasi", f"{trials.mean():.4f}")

        fig, ax = plt.subplots(figsize=(8, 4))
        bins = np.arange(1, min(trials.max(), 30) + 2) - 0.5
        ax.hist(trials, bins=bins, alpha=0.8)
        ax.set_title("Distribusi Jumlah Percobaan sampai Sukses")
        ax.set_xlabel("Jumlah trial")
        ax.set_ylabel("Frekuensi")
        ax.grid(True, alpha=0.3)
        st.pyplot(fig)

        st.latex(r"E[X] = \frac{1}{p_{\text{sukses}}}")

# =========================
# Footer
# =========================
st.markdown("---")
st.subheader("💡 Ide penggunaan di kelas")
st.markdown("""
- **Mode Lecture**: dosen jelaskan intuisi sambil ubah slider.
- **Mode Lab**: mahasiswa eksplor parameter sendiri.
- **Mode Challenge**: jadikan mini-project atau exit ticket.
""")

st.code(
"""# contoh konsep inti
E = sum(x * p for x, p in zip(values, probs))
Var = sum((x - E)**2 * p for x, p in zip(values, probs))
""",
language="python"
)