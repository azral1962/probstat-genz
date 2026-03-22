import math

M = 100000
c = 5
g = 10
prices = [12, 13.5, 15]
warranties = [8000, 9000]


def market_share(p, w):
    A = math.exp(-0.25 * p + 0.00015 * w)
    return A / (A + 1.5)


def F_normal(w):
    z = (w - 10000) / 1000
    return 0.5 * (1 + math.erf(z / math.sqrt(2)))


def F_exponential(w):
    return 1 - math.exp(-0.00005 * w)


def F_weibull(w, k=2, eta=11000):
    return 1 - math.exp(- (w / eta) ** k)


def profit_per_unit(p, w, F):
    return p - c - g * F(w)


def total_profit(p, w, F):
    return M * market_share(p, w) * profit_per_unit(p, w, F)


models = {
    "Normal": F_normal,
    "Eksponensial": F_exponential,
    "Weibull": F_weibull,
}

for name, F in models.items():  
    print(f"\n=== {name} ===")
    best = None
    for p in prices:
        for w in warranties:
            claim = F(w)
            share = market_share(p, w)
            unit_profit = profit_per_unit(p, w, F)
            total = total_profit(p, w, F)
            print(
                f"p={p:>4}, w={w:>4}, F={claim:.4f}, share={share:.4f}, "
                f"pi={unit_profit:.4f}, Pi={total:,.2f}"
            )
            if best is None or total > best[-1]:
                best = (p, w, total)
    print(f"Best: p={best[0]}, w={best[1]}, total profit={best[2]:,.2f}")
