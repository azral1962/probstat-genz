# -*- coding: utf-8 -*-
"""
Created on Tue Mar 24 14:16:19 2026

@author: Armein Z. R. Langi
"""

import numpy as np

cum_freq = {
    1000: 0.10,
    2000: 0.30,
    3000: 0.70,
    4000: 1.00
}

x = np.array(sorted(cum_freq.keys()), dtype=float)
F = np.array([cum_freq[k] for k in x], dtype=float)

def cdf(t):
    return np.interp(t, x, F, left=0.0, right=1.0)

def ppf(u):
    return np.interp(u, F, x)


print(cdf(2500))   # interpolasi linear
print(cdf(500))    # 0
print(cdf(4500))   # 1

u = np.random.rand(10)
samples = ppf(u)