# app_variabel_acak.py
# Streamlit demo untuk kuliah Minggu 05: Variabel Acak
# Jalankan dengan:
#   streamlit run app_variabel_acak.py

import math
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import streamlit as st

st.set_page_config(
    page_title="Demo Kuliah: Variabel Acak",
    page_icon="🎲",
    layout="wide",
)

# -----------------------------
# Helpers
# -----------------------------
def expected_value(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)
    return np.sum(values * probs)

def variance_value(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)
    mu = expected_value(values, probs)
    return np.sum(((values - mu) ** 2) * probs)

def validate_probs(probs, tol=1e-9):
    return abs(sum(probs) - 1.0) < tol

def plot_cumulative_mean(samples, theoretical_mean, title="Rata-rata Kumulatif"):
    cum_mean = np.cumsum(samples) / np.arange(1, len(samples) + 1)

    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(cum_mean, label="Rata-rata sampel kumulatif")
    ax.axhline(theoretical_mean, linestyle="--", label=f"E[X] teoritis = {theoretical_mean:.4f}")
    ax.set_title(title)
    ax.set_xlabel("Jumlah simulasi")
    ax.set_ylabel("Nilai")
    ax.legend()
    ax.grid(True, alpha=0.3)
    return fig

def plot_pmf_cdf(values, probs):
    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)

    order = np.argsort(values)
    values = values[order]
    probs = probs[order]
    cdf = np.cumsum(probs)

    fig1, ax1 = plt.subplots(figsize=(7, 4))
    ax1.stem(values, probs, basefmt=" ")
    ax1.set_title("PMF / Distribusi Probabilitas")
    ax1.set_xlabel("x")
    ax1.set_ylabel("P(X = x)")
    ax1.grid(True, alpha=0.3)

    fig2, ax2 = plt.subplots(figsize=(7, 4))
    ax2.step(values, cdf, where="post")
    ax2.set_ylim(0, 1.05)
    ax2.set_title("CDF / Distribusi Kumulatif")
    ax2.set_xlabel("x")
    ax2.set_ylabel("P(X ≤ x)")
    ax2.grid(True, alpha=0.3)

    return fig1, fig2

def simulate_discrete(values, probs, n, seed=42):
    rng = np.random.default_rng(seed)
    return rng.choice(values, size=n, p=probs)

def geometric_trials_until_success(p_success, n_users=10000, seed=42):
    rng = np.random.default_rng(seed)
    # geometric memberi jumlah trial sampai sukses, support 1,2,3,...
    return rng.geometric(p_success, size=n_users)

# -----------------------------
# Sidebar
# -----------------------------
st.sidebar.title("🎓 Demo Variabel Acak")
menu = st.sidebar.radio(
    "Pilih demo",
    [
        "Beranda",
        "1. Gacha & Ekspektasi",
        "2. Variansi = Risiko",
        "3. PMF vs CDF",
        "4. Risk-Return Tradeoff",
        "5. Expected Retry Login",
        "6. Custom Distribusi Mahasiswa",
    ],
)

st.sidebar.markdown("---")
seed = st.sidebar.number_input("Random seed", min_value=0, value=42, step=1)

# -----------------------------
# Beranda
# -----------------------------
if menu == "Beranda":
    st.title("🎲 Demo Interaktif: Variabel Acak")
    st.markdown("""
App ini dirancang untuk membantu demonstrasi kuliah tentang:

- **Variabel acak** sebagai pemetaan kejadian menjadi angka
- **Ekspektasi** sebagai rata-rata jangka panjang
- **Variansi** sebagai ukuran risiko/ketidakstabilan
- **PMF dan CDF**
- **Simulasi Python** untuk membangun intuisi

Cocok untuk dipakai saat live lecture, diskusi kelas, atau praktikum mandiri.
""")

    st.info(
        "Struktur demo ini mengikuti tema pada materi Minggu 05: "
        "gacha & loot boxes, law of averages, variansi sebagai risiko, "
        "PMF/CDF, risk-return tradeoff, dan expected latency/retry. "
        ":contentReference[oaicite:1]{index=1}"
    )

    st.subheader("Saran alur presentasi")
    st.markdown("""
1. Mulai dari **Gacha & Ekspektasi**  
2. Lanjut ke **Variansi = Risiko**  
3. Visualisasikan **PMF vs CDF**  
4. Bandingkan dua proyek pada **Risk-Return Tradeoff**  
5. Tutup dengan **Expected Retry Login**
""")

# -----------------------------
# 1. Gacha & Ekspektasi
# -----------------------------
elif menu == "1. Gacha & Ekspektasi":
    st.title("1. Gacha & Ekspektasi")

    st.markdown("""
Skenario: item langka bernilai tertentu bisa diperoleh lewat gacha dengan probabilitas tertentu.
Kita ingin membandingkan **nilai harapan** dengan hasil simulasi. Konsep ini sesuai dengan contoh
“Gacha & Loot Boxes” dan “Law of Averages” di materi kuliah. :contentReference[oaicite:2]{index=2}
""")

    col1, col2 = st.columns(2)

    with col1:
        rare_value = st.number_input("Nilai item langka", min_value=0.0, value=1000.0, step=50.0)
        rare_prob = st.slider("Probabilitas item langka", min_value=0.0, max_value=1.0, value=0.05, step=0.01)
        ticket_cost = st.number_input("Biaya 1 kali gacha", min_value=0.0, value=100.0, step=10.0)
        n_sim = st.slider("Jumlah simulasi", min_value=100, max_value=50000, value=10000, step=100)

    with col2:
        values = np.array([rare_value, 0.0])
        probs = np.array([rare_prob, 1 - rare_prob])

        ex = expected_value(values, probs)
        varx = variance_value(values, probs)
        expected_profit_player = ex - ticket_cost
        expected_profit_house = ticket_cost - ex

        st.metric("E[X] hadiah", f"{ex:,.2f}")
        st.metric("Var(X)", f"{varx:,.2f}")
        st.metric("Expected profit pemain", f"{expected_profit_player:,.2f}")
        st.metric("Expected profit bandar", f"{expected_profit_house:,.2f}")

        if expected_profit_player > 0:
            st.success("Secara rata-rata pemain untung.")
        elif expected_profit_player < 0:
            st.error("Secara rata-rata pemain rugi.")
        else:
            st.warning("Game fair secara ekspektasi.")

    samples = simulate_discrete(values, probs, n_sim, seed=seed)
    fig = plot_cumulative_mean(samples, ex, title="Konvergensi Rata-rata Kumulatif ke E[X]")
    st.pyplot(fig)

    st.subheader("Ringkasan")
    st.write(
        pd.DataFrame({
            "Outcome": ["Dapat item langka", "Tidak dapat"],
            "Nilai": values,
            "Probabilitas": probs
        })
    )

# -----------------------------
# 2. Variansi = Risiko
# -----------------------------
elif menu == "2. Variansi = Risiko":
    st.title("2. Variansi = Risiko")

    st.markdown("""
Dua sistem bisa punya **rata-rata sama**, tetapi pengalaman pengguna sangat berbeda bila
variansinya berbeda. Ini sesuai dengan contoh **server latency** pada materi. :contentReference[oaicite:3]{index=3}
""")

    st.subheader("Bandingkan dua server")

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("### Server A (stabil)")
        a_low = st.number_input("Latency rendah A", value=45.0)
        a_high = st.number_input("Latency tinggi A", value=55.0)
        a_prob_low = st.slider("P(latency rendah A)", 0.0, 1.0, 0.5, 0.01)

        vals_a = np.array([a_low, a_high])
        probs_a = np.array([a_prob_low, 1 - a_prob_low])

    with col2:
        st.markdown("### Server B (volatile)")
        b_low = st.number_input("Latency normal B", value=20.0)
        b_high = st.number_input("Latency spike B", value=80.0)
        b_prob_low = st.slider("P(latency normal B)", 0.0, 1.0, 0.5, 0.01)

        vals_b = np.array([b_low, b_high])
        probs_b = np.array([b_prob_low, 1 - b_prob_low])

    ex_a = expected_value(vals_a, probs_a)
    var_a = variance_value(vals_a, probs_a)

    ex_b = expected_value(vals_b, probs_b)
    var_b = variance_value(vals_b, probs_b)

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("E[A]", f"{ex_a:.2f} ms")
    c2.metric("Var(A)", f"{var_a:.2f}")
    c3.metric("E[B]", f"{ex_b:.2f} ms")
    c4.metric("Var(B)", f"{var_b:.2f}")

    n = st.slider("Jumlah observasi simulasi", 100, 20000, 3000, 100)
    sample_a = simulate_discrete(vals_a, probs_a, n, seed=seed)
    sample_b = simulate_discrete(vals_b, probs_b, n, seed=seed + 1)

    fig_a, ax_a = plt.subplots(figsize=(8, 4))
    ax_a.hist(sample_a, bins=20, alpha=0.7)
    ax_a.set_title("Histogram Latency Server A")
    ax_a.set_xlabel("Latency (ms)")
    ax_a.set_ylabel("Frekuensi")
    ax_a.grid(True, alpha=0.3)
    st.pyplot(fig_a)

    fig_b, ax_b = plt.subplots(figsize=(8, 4))
    ax_b.hist(sample_b, bins=20, alpha=0.7)
    ax_b.set_title("Histogram Latency Server B")
    ax_b.set_xlabel("Latency (ms)")
    ax_b.set_ylabel("Frekuensi")
    ax_b.grid(True, alpha=0.3)
    st.pyplot(fig_b)

    if abs(ex_a - ex_b) < 1e-6:
        if var_a < var_b:
            st.info("Rata-rata sama, tetapi Server A lebih stabil karena variansinya lebih kecil.")
        elif var_b < var_a:
            st.info("Rata-rata sama, tetapi Server B lebih stabil karena variansinya lebih kecil.")
        else:
            st.info("Rata-rata dan variansi keduanya sama.")
    else:
        st.info("Perhatikan bahwa tidak hanya rata-rata yang penting; variansi juga memengaruhi pengalaman.")

# -----------------------------
# 3. PMF vs CDF
# -----------------------------
elif menu == "3. PMF vs CDF":
    st.title("3. PMF vs CDF")

    st.markdown("""
Materi minggu ini juga menekankan visualisasi **PMF** dan **CDF** untuk variabel acak diskrit,
dengan CDF sebagai “loading bar” probabilitas yang tidak pernah turun. :contentReference[oaicite:4]{index=4}
""")

    st.write("Contoh distribusi diskrit sederhana.")
    x1 = st.number_input("x1", value=0.0)
    x2 = st.number_input("x2", value=1.0)
    x3 = st.number_input("x3", value=2.0)

    p1 = st.slider("p1", 0.0, 1.0, 0.2, 0.01)
    p2 = st.slider("p2", 0.0, 1.0, 0.5, 0.01)
    p3 = 1.0 - p1 - p2

    values = np.array([x1, x2, x3], dtype=float)
    probs = np.array([p1, p2, p3], dtype=float)

    if np.any(probs < 0):
        st.error("p1 + p2 harus <= 1.")
    else:
        st.write(pd.DataFrame({"x": values, "P(X=x)": probs}))
        fig1, fig2 = plot_pmf_cdf(values, probs)
        c1, c2 = st.columns(2)
        with c1:
            st.pyplot(fig1)
        with c2:
            st.pyplot(fig2)

        st.latex(r"E[X] = \sum_x x \, P(X=x)")
        st.latex(r"Var(X) = E[X^2] - (E[X])^2")
        st.write(f"**E[X] = {expected_value(values, probs):.4f}**")
        st.write(f"**Var(X) = {variance_value(values, probs):.4f}**")

# -----------------------------
# 4. Risk-Return Tradeoff
# -----------------------------
elif menu == "4. Risk-Return Tradeoff":
    st.title("4. Risk-Return Tradeoff")

    st.markdown("""
Ini mengikuti skenario dua proyek pada materi:
- Proyek A stabil
- Proyek B volatil  
Mahasiswa diminta menghitung **E[X]**, **Var(X)**, mensimulasikan hasil, dan mendiskusikan
apakah ekspektasi tinggi selalu lebih baik. :contentReference[oaicite:5]{index=5}
""")

    st.subheader("Parameter proyek")

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("### Proyek A")
        a_gain = st.number_input("Untung A", value=10000.0, step=1000.0)
        a_gain_p = st.slider("P(untung A)", 0.0, 1.0, 0.90, 0.01)
        a_loss = st.number_input("Rugi A", value=-1000.0, step=500.0)

    with col2:
        st.markdown("### Proyek B")
        b_gain = st.number_input("Untung B", value=50000.0, step=1000.0)
        b_gain_p = st.slider("P(untung B)", 0.0, 1.0, 0.30, 0.01)
        b_loss = st.number_input("Rugi B", value=-10000.0, step=500.0)

    vals_a = np.array([a_gain, a_loss], dtype=float)
    probs_a = np.array([a_gain_p, 1 - a_gain_p], dtype=float)

    vals_b = np.array([b_gain, b_loss], dtype=float)
    probs_b = np.array([b_gain_p, 1 - b_gain_p], dtype=float)

    ex_a = expected_value(vals_a, probs_a)
    var_a = variance_value(vals_a, probs_a)
    ex_b = expected_value(vals_b, probs_b)
    var_b = variance_value(vals_b, probs_b)

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("E[A]", f"{ex_a:,.2f}")
    c2.metric("Var(A)", f"{var_a:,.2f}")
    c3.metric("E[B]", f"{ex_b:,.2f}")
    c4.metric("Var(B)", f"{var_b:,.2f}")

    n_runs = st.slider("Jumlah simulasi proyek", 100, 20000, 5000, 100)
    init_capital = st.number_input("Modal awal untuk cek bangkrut", value=20000.0, step=1000.0)

    sim_a = simulate_discrete(vals_a, probs_a, n_runs, seed=seed)
    sim_b = simulate_discrete(vals_b, probs_b, n_runs, seed=seed + 7)

    bankrupt_a = np.sum(init_capital + sim_a < 0)
    bankrupt_b = np.sum(init_capital + sim_b < 0)

    c5, c6 = st.columns(2)
    c5.metric("Bangkrut A", int(bankrupt_a))
    c6.metric("Bangkrut B", int(bankrupt_b))

    fig_a, ax_a = plt.subplots(figsize=(8, 4))
    ax_a.hist(sim_a, bins=30, alpha=0.7)
    ax_a.set_title("Histogram Hasil Proyek A")
    ax_a.set_xlabel("Profit/Loss")
    ax_a.set_ylabel("Frekuensi")
    ax_a.grid(True, alpha=0.3)
    st.pyplot(fig_a)

    fig_b, ax_b = plt.subplots(figsize=(8, 4))
    ax_b.hist(sim_b, bins=30, alpha=0.7)
    ax_b.set_title("Histogram Hasil Proyek B")
    ax_b.set_xlabel("Profit/Loss")
    ax_b.set_ylabel("Frekuensi")
    ax_b.grid(True, alpha=0.3)
    st.pyplot(fig_b)

    st.subheader("Interpretasi")
    if ex_b > ex_a and var_b > var_a:
        st.warning("Proyek B memberi ekspektasi lebih tinggi, tetapi dengan risiko lebih besar.")
    elif ex_a > ex_b and var_a < var_b:
        st.success("Proyek A unggul baik dari sisi ekspektasi maupun kestabilan.")
    else:
        st.info("Gunakan E[X] dan Var(X) bersama-sama, bukan salah satu saja.")

# -----------------------------
# 5. Expected Retry Login
# -----------------------------
elif menu == "5. Expected Retry Login":
    st.title("5. Expected Retry Login")

    st.markdown("""
Materi juga menyinggung expected cost / expected latency dari retry logic login:
jika peluang gagal login tertentu, berapa rata-rata jumlah percobaan sampai sukses?
Ini mengarah ke distribusi geometrik. :contentReference[oaicite:6]{index=6}
""")

    p_fail = st.slider("Probabilitas gagal login", 0.0, 0.99, 0.20, 0.01)
    p_success = 1 - p_fail
    n_users = st.slider("Jumlah user simulasi", 100, 50000, 10000, 100)

    theoretical_mean = 1 / p_success if p_success > 0 else np.inf
    trials = geometric_trials_until_success(p_success, n_users=n_users, seed=seed)
    sample_mean = trials.mean()

    c1, c2 = st.columns(2)
    c1.metric("Rata-rata teoretis trial", f"{theoretical_mean:.4f}")
    c2.metric("Rata-rata simulasi", f"{sample_mean:.4f}")

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.hist(trials, bins=np.arange(1, min(trials.max(), 30) + 2) - 0.5, alpha=0.7)
    ax.set_title("Distribusi Jumlah Percobaan sampai Login Sukses")
    ax.set_xlabel("Jumlah trial")
    ax.set_ylabel("Frekuensi")
    ax.grid(True, alpha=0.3)
    st.pyplot(fig)

    st.latex(r"E[X] = \frac{1}{p_{\text{sukses}}}")

# -----------------------------
# 6. Custom Distribusi Mahasiswa
# -----------------------------
elif menu == "6. Custom Distribusi Mahasiswa":
    st.title("6. Custom Distribusi Mahasiswa")

    st.markdown("""
Mode ini berguna untuk diskusi kelas atau tugas mini:
mahasiswa bisa merancang sendiri distribusi hadiah / skor / outcome,
lalu melihat **E[X]**, **Var(X)**, PMF, CDF, dan simulasi konvergensi.
Ini juga cocok untuk ide tugas “Digital Casino”. :contentReference[oaicite:7]{index=7}
""")

    n_outcomes = st.slider("Jumlah outcome", 2, 6, 3)

    values = []
    probs = []

    cols = st.columns(2)
    with cols[0]:
        st.markdown("### Nilai outcome")
        for i in range(n_outcomes):
            values.append(st.number_input(f"Nilai x{i+1}", value=float(i * 10), key=f"vx{i}"))

    with cols[1]:
        st.markdown("### Probabilitas outcome")
        remaining = 1.0
        for i in range(n_outcomes - 1):
            p = st.slider(
                f"p{i+1}",
                0.0,
                float(remaining),
                min(0.2, float(remaining)),
                0.01,
                key=f"px{i}",
            )
            probs.append(p)
            remaining -= p
        probs.append(remaining)
        st.write(f"p{n_outcomes} otomatis = {remaining:.2f}")

    values = np.array(values, dtype=float)
    probs = np.array(probs, dtype=float)

    st.write(pd.DataFrame({"x": values, "P(X=x)": probs}))

    ex = expected_value(values, probs)
    varx = variance_value(values, probs)

    c1, c2 = st.columns(2)
    c1.metric("E[X]", f"{ex:.4f}")
    c2.metric("Var(X)", f"{varx:.4f}")

    fig1, fig2 = plot_pmf_cdf(values, probs)
    col1, col2 = st.columns(2)
    with col1:
        st.pyplot(fig1)
    with col2:
        st.pyplot(fig2)

    n_sim = st.slider("Jumlah simulasi", 100, 50000, 5000, 100, key="custom_nsim")
    samples = simulate_discrete(values, probs, n_sim, seed=seed)
    fig3 = plot_cumulative_mean(samples, ex, title="Konvergensi Rata-rata Kumulatif")
    st.pyplot(fig3)

    st.subheader("Kode konsep")
    st.code(
        "E[X] = sum(x * p for x, p in zip(values, probs))\n"
        "Var(X) = sum((x - E[X])**2 * p for x, p in zip(values, probs))",
        language="python"
    )



