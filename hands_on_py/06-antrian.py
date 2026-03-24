import numpy as np
import matplotlib.pyplot as plt
# -*- coding: utf-8 -*-
n_plgn = 100
selang = 60
tiba_selang_rata = 10
lyn_selang_rata = 7

tiba_selang  = np.random.exponential`(tiba_selang_rata, n_plgn)

print("rata-rata selang tiba: ",sum(tiba_selang)/len(tiba_selang))
tiba_waktu = np.cumsum(tiba_selang)

lyn_selang =  np.random.exponential(lyn_selang_rata, len(tiba_selang))

print("rata-rata selang layanan: ",sum(lyn_selang)/len(lyn_selang))

lyn_start = np.zeros(len(tiba_selang))
lyn_finish = np.zeros(len(tiba_selang))

idx_pelanggan=list(range(len(tiba_selang)))
for i in idx_pelanggan :
    if i == 0:
        lyn_start[i] = tiba_waktu[i]
    else:
        lyn_start[i] = max(tiba_waktu[i], lyn_finish[i - 1])
    lyn_finish[i] = lyn_start[i] + lyn_selang[i]

waiting_duration = lyn_start - tiba_waktu

print("rata-rata antrian: ",sum(waiting_duration)/len(waiting_duration))
system = lyn_finish - tiba_waktu

print("rata-rata total layanan: ",sum(waiting_duration+lyn_selang)/len(waiting_duration+lyn_selang))

fig, ([ax11, ax12], [ax21, ax22],[ax31, ax32]) = plt.subplots(3,2)
ax11.eventplot(tiba_waktu)
ax21.eventplot(lyn_start)
ax31.eventplot(lyn_finish)
ax22.bar(idx_pelanggan, lyn_selang)
ax12.bar(idx_pelanggan, waiting_duration)
ax32.bar(idx_pelanggan, waiting_duration + lyn_selang)
plt.tight_layout()
plt.show()
                                                              