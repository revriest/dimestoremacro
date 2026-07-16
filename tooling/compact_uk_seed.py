import argparse
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any


LOW_VALUE_TOKENS = {
    "flesh only",
    "weighed with shells",
    "new zealand",
    "edible portion",
    "with skin and bones",
    "with skin and bone",
    "without skin and bones",
    "without skin and bone",
    "as purchased",
}

CORE_PATTERNS = [
    "chicken", "turkey", "beef", "steak", "mince", "pork", "bacon", "ham",
    "salmon", "tuna", "cod", "haddock", "prawn", "shrimp", "sardine", "mackerel",
    "egg", "egg white", "yoghurt", "yogurt", "milk", "cheese", "cottage cheese",
    "rice", "oat", "porridge", "bread", "pasta", "potato", "sweet potato", "bean",
    "lentil", "chickpea", "banana", "apple", "orange", "berry", "grape", "avocado",
    "broccoli", "spinach", "carrot", "tomato", "pepper", "onion", "cabbage", "kale",
    "olive oil", "butter", "peanut butter", "nuts", "almond", "walnut", "chia",
    "baked beans", "cereal", "weetabix", "weet-bix", "granola", "soup", "sandwich",
]

MUST_KEEP_PATTERNS = [
    "chicken breast", "chicken thigh", "beef mince", "ground beef", "lean beef",
    "pork", "bacon", "ham", "salmon", "tuna", "cod", "haddock", "prawn", "shrimp",
    "egg", "egg white", "milk", "yoghurt", "yogurt", "cottage cheese", "cheddar",
    "rice", "oat", "porridge", "bread", "wholemeal", "whole wheat", "pasta",
    "potato", "sweet potato", "baked beans", "chickpea", "lentil", "black beans",
    "banana", "apple", "orange", "strawberry", "blueberry", "grape", "avocado",
    "broccoli", "spinach", "carrot", "tomato", "cucumber", "onion", "olive oil", "butter",
]

CATEGORY_RULES = {
    "protein": [
        "chicken", "turkey", "beef", "steak", "mince", "pork", "bacon", "ham", "sausage",
        "salmon", "tuna", "cod", "haddock", "sardine", "mackerel", "prawn", "shrimp", "fish",
        "egg", "lamb",
    ],
    "dairy_eggs": [
        "milk", "yoghurt", "yogurt", "cheese", "cream", "butter", "egg", "custard",
    ],
    "carbs": [
        "rice", "oat", "porridge", "bread", "pasta", "potato", "noodle", "quinoa", "cereal",
        "weetabix", "weet-bix", "granola", "bagel", "flour", "barley",
    ],
    "produce": [
        "apple", "banana", "orange", "berry", "grape", "mango", "pear", "melon", "avocado",
        "broccoli", "spinach", "carrot", "tomato", "cucumber", "pepper", "onion", "cabbage",
        "kale", "lettuce", "courgette", "zucchini", "pea", "bean", "lentil", "chickpea",
    ],
    "fats_sauces": [
        "olive oil", "oil", "mayonnaise", "mayo", "sauce", "dressing", "spread", "peanut butter",
        "almond butter", "nuts", "almond", "walnut", "seed", "chia", "flax",
    ],
}

CATEGORY_TARGETS = {
    "protein": 170,
    "dairy_eggs": 80,
    "carbs": 130,
    "produce": 150,
    "fats_sauces": 40,
}

COMMON_FOOD_TOKENS = {
    "chicken", "turkey", "beef", "mince", "minced", "steak", "pork", "bacon", "ham",
    "salmon", "tuna", "cod", "haddock", "mackerel", "sardine", "prawn", "shrimp", "fish",
    "egg", "white", "milk", "yoghurt", "yogurt", "cheese", "cheddar", "cottage",
    "rice", "oat", "porridge", "bread", "pasta", "potato", "beans", "lentil", "chickpea",
    "banana", "apple", "orange", "berry", "grape", "avocado", "broccoli", "spinach", "carrot",
    "tomato", "cucumber", "onion", "pepper", "olive", "oil", "butter", "peanut", "almond",
    "walnut", "chia", "quinoa", "cereal", "weetabix", "weet bix", "granola", "soup", "sauce",
}

OBSCURE_PENALTY_TOKENS = {
    "arrowhead", "bacha", "cassareep", "salsify", "carob", "frumenty", "offal meal",
}

REQUIRED_QUERY_GROUPS = [
    ["chicken breast"],
    ["chicken thigh", "chicken legs"],
    ["beef mince", "minced beef", "ground beef"],
    ["lean beef", "beef steak"],
    ["pork"],
    ["bacon"],
    ["ham"],
    ["salmon"],
    ["tuna"],
    ["cod"],
    ["haddock"],
    ["prawn", "shrimp"],
    ["egg white", "egg whites"],
    ["eggs", "egg"],
    ["milk"],
    ["yoghurt", "yogurt"],
    ["cottage cheese"],
    ["cheddar"],
    ["rice"],
    ["oat", "porridge oats"],
    ["wholemeal bread", "whole wheat bread", "bread"],
    ["pasta"],
    ["potato"],
    ["sweet potato"],
    ["baked beans"],
    ["chickpea", "chickpeas"],
    ["lentil", "lentils"],
    ["banana"],
    ["apple"],
    ["orange"],
    ["strawberry", "strawberries"],
    ["blueberry", "blueberries"],
    ["avocado"],
    ["broccoli"],
    ["spinach"],
    ["carrot", "carrots"],
    ["tomato", "tomatoes"],
    ["cucumber"],
    ["onion", "onions"],
    ["olive oil", "oil olive"],
    ["butter"],
]


def extract_macros(entry: dict[str, Any]) -> dict[str, float]:
    nested = entry.get("macros")
    if isinstance(nested, dict):
        return {
            "calories": max(0.0, to_float(nested.get("calories", 0))),
            "protein_g": max(0.0, to_float(nested.get("protein_g", 0))),
            "fat_g": max(0.0, to_float(nested.get("fat_g", 0))),
            "carbs_g": max(0.0, to_float(nested.get("carbs_g", 0))),
        }

    # Legacy schema support (used by older region files).
    return {
        "calories": max(0.0, to_float(entry.get("calories_per_100g", 0))),
        "protein_g": max(0.0, to_float(entry.get("protein_per_100g", 0))),
        "fat_g": max(0.0, to_float(entry.get("fat_per_100g", 0))),
        "carbs_g": max(0.0, to_float(entry.get("carbs_per_100g", 0))),
    }


def normalize_name(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def compute_calories_from_macros(protein_g: float, fat_g: float, carbs_g: float) -> float:
    return (4.0 * protein_g) + (9.0 * fat_g) + (4.0 * carbs_g)


def to_float(value: Any) -> float:
    try:
        return float(value)
    except Exception:
        return 0.0


def sanitize_entry(entry: dict[str, Any]) -> dict[str, Any] | None:
    name = str(entry.get("name", "")).strip()
    macros = extract_macros(entry)
    if not name:
        return None

    protein = macros["protein_g"]
    fat = macros["fat_g"]
    carbs = macros["carbs_g"]
    calories = macros["calories"]

    computed = compute_calories_from_macros(protein, fat, carbs)
    if (calories == 0 and computed > 0) or abs(calories - computed) > 60:
        calories = computed

    if calories == 0 and protein == 0 and fat == 0 and carbs == 0:
        return None

    aliases = entry.get("search_aliases", [])
    clean_aliases: list[str] = []
    if isinstance(aliases, list):
        seen = set()
        for alias in aliases:
            if not isinstance(alias, str):
                continue
            raw = alias.strip()
            norm = normalize_name(raw)
            if not norm or norm in seen or norm == normalize_name(name):
                continue
            seen.add(norm)
            clean_aliases.append(raw)

    name_norm = normalize_name(name)
    # Add UK/US spelling alias so both "yoghurt" and "yogurt" searches work.
    if "yogurt" in name_norm and all("yoghurt" not in normalize_name(a) for a in clean_aliases):
        clean_aliases.append(name.replace("Yogurt", "Yoghurt").replace("yogurt", "yoghurt"))
    if "yoghurt" in name_norm and all("yogurt" not in normalize_name(a) for a in clean_aliases):
        clean_aliases.append(name.replace("Yoghurt", "Yogurt").replace("yoghurt", "yogurt"))

    out = {
        "name": name,
        "macros": {
            "calories": int(round(calories)),
            "protein_g": round(protein, 1),
            "fat_g": round(fat, 1),
            "carbs_g": round(carbs, 1),
        },
    }
    if clean_aliases:
        out["search_aliases"] = clean_aliases[:6]
    return out


def category_for(name_norm: str) -> str:
    for category, keys in CATEGORY_RULES.items():
        if any(key in name_norm for key in keys):
            return category
    return "other"


def relevance_score(name: str) -> int:
    norm = normalize_name(name)
    score = 0

    if any(p in norm for p in MUST_KEEP_PATTERNS):
        score += 80

    score += sum(8 for p in CORE_PATTERNS if p in norm)

    words = [w for w in norm.split(" ") if w]
    common_hits = sum(1 for w in words if w in COMMON_FOOD_TOKENS)
    score += (common_hits * 3)

    if any(tok in norm for tok in OBSCURE_PENALTY_TOKENS):
        score -= 22

    if any(token in norm for token in LOW_VALUE_TOKENS):
        score -= 20

    if 2 <= len(words) <= 5:
        score += 8
    elif len(words) > 8:
        score -= 8

    # Slightly de-prioritize many "raw" labels if they are otherwise weak.
    if "raw" in words and common_hits <= 1:
        score -= 4

    return score


def phrase_match(name_norm: str, phrase: str) -> bool:
    tokens = [t for t in normalize_name(phrase).split(" ") if t]
    return all(t in name_norm for t in tokens)


def group_matches(name_norm: str, group: list[str]) -> bool:
    return any(phrase_match(name_norm, candidate) for candidate in group)


def best_variant(entries: list[dict[str, Any]]) -> dict[str, Any]:
    def variant_score(e: dict[str, Any]) -> tuple[int, int]:
        name = str(e.get("name", ""))
        score = relevance_score(name)

        aliases = e.get("search_aliases", [])
        alias_count = len(aliases) if isinstance(aliases, list) else 0
        score += min(alias_count, 4)

        macros = e.get("macros", {}) if isinstance(e.get("macros"), dict) else {}
        cals = to_float(macros.get("calories", 0))
        # Avoid selecting obvious outliers as representative.
        if cals > 900:
            score -= 6

        return score, -len(name)

    return sorted(entries, key=variant_score, reverse=True)[0]


def compact_dataset(rows: list[dict[str, Any]], target: int) -> list[dict[str, Any]]:
    sanitized = []
    exact_seen = set()

    for row in rows:
        if not isinstance(row, dict):
            continue
        clean = sanitize_entry(row)
        if clean is None:
            continue

        macros = clean["macros"]
        sig = (
            normalize_name(clean["name"]),
            macros["calories"],
            macros["protein_g"],
            macros["fat_g"],
            macros["carbs_g"],
        )
        if sig in exact_seen:
            continue
        exact_seen.add(sig)
        sanitized.append(clean)

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in sanitized:
        grouped[normalize_name(item["name"])].append(item)

    unique_items = [best_variant(group) for group in grouped.values()]

    scored = []
    for item in unique_items:
        name_norm = normalize_name(item["name"])
        scored.append((relevance_score(item["name"]), category_for(name_norm), item))

    scored.sort(key=lambda x: (x[0], -len(x[2]["name"])), reverse=True)

    picked: list[dict[str, Any]] = []
    picked_norms = set()

    # Pass 1: add high-confidence must-keep items, but cap this phase so we do
    # not crowd out diversity and required query groups.
    must_keep_cap = min(max(target // 2, 150), 260)
    for _, _, item in scored:
        norm = normalize_name(item["name"])
        if norm in picked_norms:
            continue
        if len(picked) >= must_keep_cap:
            break
        if any(p in norm for p in MUST_KEEP_PATTERNS) and relevance_score(item["name"]) >= 45:
            picked.append(item)
            picked_norms.add(norm)

    # Pass 1b: force presence of crucial search groups.
    for group in REQUIRED_QUERY_GROUPS:
        already_present = any(group_matches(normalize_name(p["name"]), group) for p in picked)
        if already_present:
            continue

        for _, _, item in scored:
            norm = normalize_name(item["name"])
            if norm in picked_norms:
                continue
            if group_matches(norm, group):
                picked.append(item)
                picked_norms.add(norm)
                break

    # Pass 2: category-balanced fill.
    counts = defaultdict(int)
    for item in picked:
        counts[category_for(normalize_name(item["name"]))] += 1

    for score, category, item in scored:
        if len(picked) >= target:
            break
        norm = normalize_name(item["name"])
        if norm in picked_norms:
            continue

        # Prefer filling under-target categories first.
        cat_target = CATEGORY_TARGETS.get(category, 0)
        if category != "other" and counts[category] < cat_target:
            picked.append(item)
            picked_norms.add(norm)
            counts[category] += 1
            continue

        # If all category targets are broadly satisfied, allow best remaining items.
        remaining_core_capacity = sum(
            max(CATEGORY_TARGETS[c] - counts[c], 0) for c in CATEGORY_TARGETS
        )
        remaining_slots = target - len(picked)
        if category == "other" and score < 55:
            continue

        if remaining_core_capacity < remaining_slots or score >= 45:
            picked.append(item)
            picked_norms.add(norm)
            counts[category] += 1

    # Pass 3: hard fill to target from highest remaining scores.
    if len(picked) < target:
        for _, category, item in scored:
            if len(picked) >= target:
                break
            norm = normalize_name(item["name"])
            if norm in picked_norms:
                continue
            picked.append(item)
            picked_norms.add(norm)
            counts[category] += 1

    # Pass 4: enforce required groups even after ranking/trim pressure.
    def find_best_for_group(group: list[str]) -> dict[str, Any] | None:
        for _, _, candidate in scored:
            if group_matches(normalize_name(candidate["name"]), group):
                return candidate
        return None

    required_missing = []
    for group in REQUIRED_QUERY_GROUPS:
        if not any(group_matches(normalize_name(p["name"]), group) for p in picked):
            required_missing.append(group)

    if required_missing and picked:
        # Replace lowest-scoring non-required entries first.
        picked.sort(key=lambda x: relevance_score(x["name"]))
        for group in required_missing:
            replacement = find_best_for_group(group)
            if replacement is None:
                continue
            replacement_norm = normalize_name(replacement["name"])
            if replacement_norm in {normalize_name(p["name"]) for p in picked}:
                continue

            replace_idx = -1
            for i, existing in enumerate(picked):
                existing_norm = normalize_name(existing["name"])
                protects_required = any(
                    group_matches(existing_norm, g) for g in REQUIRED_QUERY_GROUPS
                )
                if not protects_required:
                    replace_idx = i
                    break

            if replace_idx >= 0:
                picked[replace_idx] = replacement

    # Final deterministic order for stable diffs.
    # Deduplicate in case replacements introduced accidental duplicates.
    deduped = []
    seen_norms = set()
    for item in picked:
        norm = normalize_name(item["name"])
        if norm in seen_norms:
            continue
        seen_norms.add(norm)
        deduped.append(item)

    deduped.sort(key=lambda x: normalize_name(x["name"]))
    return deduped[:target]


def summarize(rows: list[dict[str, Any]]) -> dict[str, int]:
    out: dict[str, int] = defaultdict(int)
    for row in rows:
        out[category_for(normalize_name(row.get("name", "")))] += 1
    return dict(out)


def load_rows(path: Path) -> list[dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return [row for row in data if isinstance(row, dict)]
    return []


def main() -> None:
    parser = argparse.ArgumentParser(description="Compact UK food seed to high-value entries")
    parser.add_argument("--input", required=True, help="Input UK seed JSON")
    parser.add_argument("--output", required=True, help="Output compact UK seed JSON")
    parser.add_argument("--target", type=int, default=600, help="Target entry count")
    parser.add_argument(
        "--fallback",
        default="assets/data/foods_us.json",
        help="Optional fallback JSON for filling crucial common-food gaps",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    rows = load_rows(input_path)

    fallback_path = Path(args.fallback)
    if fallback_path.exists():
        rows.extend(load_rows(fallback_path))

    compacted = compact_dataset(rows, target=args.target)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(compacted, f, ensure_ascii=False, indent=2)

    print(f"Input rows: {len(rows)}")
    print(f"Output rows: {len(compacted)}")
    print(f"Category mix: {summarize(compacted)}")
    print(f"Wrote: {output_path}")


if __name__ == "__main__":
    main()
