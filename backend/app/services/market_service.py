"""
Market intelligence service.

Pulls from the market_prices table. In this environment there's no live
Agmarknet/API key configured, so the table is populated with clearly
labeled demo data (`is_demo = TRUE`) via the seed script. Swapping in a
live source later just means writing new rows with `is_demo = FALSE` —
the rest of the app doesn't need to change.
"""
from app.db import query_all, query_one


def get_prices_for_crop(crop_id: int):
    rows = query_all(
        """SELECT market_name, price_per_quintal, recorded_date, is_demo
           FROM market_prices
           WHERE crop_id = %s
           ORDER BY recorded_date DESC
           LIMIT 10""",
        (crop_id,),
    )
    return rows


def get_price_trend(crop_id: int, market_name: str):
    rows = query_all(
        """SELECT price_per_quintal, recorded_date FROM market_prices
           WHERE crop_id = %s AND market_name = %s
           ORDER BY recorded_date ASC""",
        (crop_id, market_name),
    )
    if len(rows) < 2:
        return "Insufficient data"
    if rows[-1]["price_per_quintal"] > rows[0]["price_per_quintal"]:
        return "Increasing"
    if rows[-1]["price_per_quintal"] < rows[0]["price_per_quintal"]:
        return "Decreasing"
    return "Stable"


def get_market_summary(crop_id: int):
    prices = get_prices_for_crop(crop_id)
    if not prices:
        return None

    latest_by_market = {}
    for row in prices:
        if row["market_name"] not in latest_by_market:
            latest_by_market[row["market_name"]] = row

    best_market = max(latest_by_market.values(), key=lambda r: r["price_per_quintal"])
    trend = get_price_trend(crop_id, best_market["market_name"])

    return {
        "markets": list(latest_by_market.values()),
        "best_market": best_market["market_name"],
        "best_price": float(best_market["price_per_quintal"]),
        "trend": trend,
    }


def check_target_price(user_id: int, crop_id: int, current_price: float):
    target = query_one(
        "SELECT * FROM target_prices WHERE user_id = %s AND crop_id = %s AND achieved = FALSE",
        (user_id, crop_id),
    )
    if target and current_price >= float(target["target_price"]):
        return target
    return None
