# -*- coding: utf-8 -*-
"""
Created on Sat Mar 21 18:17:35 2026

@author: Armein Z. R. Langi
"""

import numpy as np
from scipy.stats import norm, expon, weibull_min, uniform
from scipy.special import gamma

# Parameter umum
mean = 10000

# ======================
# 1. Normal Distribution
# ======================
def F_normal(w):
    mu = 10000
    sigma = 1000
    return norm.cdf(w, loc=mu, scale=sigma)

# ======================
# 2. Exponential Distribution
# ======================
def F_exponential(w):
    scale_exp = mean  # mean = scale
    return expon.cdf(w, scale=scale_exp)

# ======================
# 3. Weibull Distribution (k=2)
# ======================
def F_weibull(w):
    k = 2
    scale_weibull = mean / gamma(1 + 1/k)
    return  weibull_min.cdf(w, c=k, scale=scale_weibull)


# ======================
# 4. Uniform Distribution (0, 20000)
# ======================
def F_uniform(w):
    a = 0
    b = 20000
    # di scipy: loc=a, scale=b-a
    return  uniform.cdf(w, loc=a, scale=b-a)
    
# ======================
# Print results
# ======================

models={
    "uniform": F_uniform,
    "normal": F_normal,
    "exp": F_exponential,
    "weibull": F_weibull,
}
garansi=[8500,9000]

for w in garansi:
    print(f"\n=== Garansi {w} ===")
    for name, F in models.items(): 
        claim = F(w)
        print(
            f"{name:>8}, Claim ={claim:.4f}"
        )
