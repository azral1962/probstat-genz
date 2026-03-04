import pandas as pd

# 1. Data Historis P2P Lending
data = {
    'Penghasilan': ['Tinggi', 'Rendah', 'Sedang', 'Rendah', 'Tinggi', 'Sedang', 'Rendah'],
    'Status_Rumah': ['Milik', 'Sewa', 'Sewa', 'Sewa', 'Milik', 'Milik', 'Sewa'],
    'Target': ['Lancar', 'Gagal', 'Lancar', 'Gagal', 'Lancar', 'Lancar', 'Gagal']
}
df = pd.DataFrame(data)

def hitung_naive_bayes(data_baru):
    # --- STEP 1: Hitung Prior P(Lancar) dan P(Gagal) ---
    total_data = len(df)
    p_lancar = len(df[df['Target'] == 'Lancar']) / total_data
    p_gagal = len(df[df['Target'] == 'Gagal']) / total_data
    print(p_lancar,p_gagal)
    # --- STEP 2: Hitung Likelihood untuk setiap Fitur ---
    # Kita akan menghitung P(Fitur | Lancar) dan P(Fitur | Gagal)
    
    prob_lancar = p_lancar
    prob_gagal = p_gagal
    
                                                                            
    for kolom, nilai in data_baru.items():
        # Likelihood untuk Lancar
        count_fitur_lancar = len(df[(df[kolom] == nilai) & (df['Target'] == 'Lancar')])
        count_fitur_nilai = len(df[(df[kolom] == nilai)])
        likelihood_lancar = count_fitur_lancar / count_fitur_nilai
        print(kolom, nilai,count_fitur_lancar, likelihood_lancar, count_fitur_nilai)
        prob_lancar *= likelihood_lancar
        
        # Likelihood untuk Gagal
        count_fitur_gagal = len(df[(df[kolom] == nilai) & (df['Target'] == 'Gagal')])
        count_fitur_nilai = len(df[(df[kolom] == nilai)])
        likelihood_gagal = count_fitur_gagal / count_fitur_nilai
        
        print(kolom, nilai,count_fitur_gagal,likelihood_gagal, count_fitur_nilai)
        prob_gagal *= likelihood_gagal
    
    print(prob_lancar, prob_gagal)
    # --- STEP 3: Normalisasi (Agar total probabilitas = 100%) ---
    total_prob = prob_lancar + prob_gagal
    hasil_lancar = (prob_lancar / total_prob) * 100
    hasil_gagal = (prob_gagal / total_prob) * 100
    
    return hasil_lancar, hasil_gagal

# --- UJI COBA ---
# Peminjam baru: Penghasilan Rendah, Status Rumah Sewa
calon_peminjam = {'Penghasilan': 'Rendah', 'Status_Rumah': 'Sewa'}
lancar, gagal = hitung_naive_bayes(calon_peminjam)

print(f"Hasil Analisis Risiko:")
print(f"- Peluang Lancar: {lancar:.2f}%")
print(f"- Peluang Gagal : {gagal:.2f}%")
print(f"Keputusan: {'DITERIMA' if lancar > gagal else 'DITOLAK'}")
