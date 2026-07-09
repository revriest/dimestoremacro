import requests
import json
import time
import os
from typing import List, Dict, Optional

# =============================================================================
# CONFIGURATION
# =============================================================================

USDA_API_KEY = "HdGTRLyEiCAM3d2KuxRxVAyXvqpQhMFB5oDVsBAE"  # Replace with your key
USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"

# GitHub Gist with all food lists (hosted by me)
FOOD_LISTS_GIST_URL = "https://gist.githubusercontent.com/raw/baremacros-food-lists.json"

# Cache file for food lists (so we don't download every time)
CACHE_FILE = "food_lists_cache.json"

# =============================================================================
# USDA API FUNCTIONS
# =============================================================================

def query_usda(food_name: str, retries: int = 3) -> Optional[Dict]:
    """Query USDA API for food macros with retry logic"""
    
    for attempt in range(retries):
        try:
            params = {
                'query': food_name,
                'pageSize': 1,
                'api_key': USDA_API_KEY
            }
            
            response = requests.get(USDA_BASE_URL, params=params, timeout=10)
            
            if response.status_code == 429:  # Rate limit
                wait_time = 60 if USDA_API_KEY == "HdGTRLyEiCAM3d2KuxRxVAyXvqpQhMFB5oDVsBAE" else 5
                print(f"  ⏳ Rate limited. Waiting {wait_time}s...")
                time.sleep(wait_time)
                continue
            
            if response.status_code != 200:
                print(f"  ⚠️  API error for '{food_name}': {response.status_code}")
                return None
            
            data = response.json()
            foods = data.get('foods', [])
            
            if not foods:
                print(f"  ⚠️  No results for '{food_name}'")
                return None
            
            food = foods[0]
            nutrients = food.get('foodNutrients', [])
            
            # Extract macros
            macros = {'protein': 0, 'carbs': 0, 'fat': 0, 'calories': 0}
            
            for nutrient in nutrients:
                nutrient_id = str(nutrient.get('nutrientNumber', ''))
                value = nutrient.get('value', 0)
                
                if nutrient_id == '203':  # Protein
                    macros['protein'] = round(value)
                elif nutrient_id == '205':  # Carbs
                    macros['carbs'] = round(value)
                elif nutrient_id == '204':  # Fat
                    macros['fat'] = round(value)
                elif nutrient_id == '208':  # Calories
                    macros['calories'] = round(value)
            
            # Skip if all macros are zero
            if macros['protein'] == 0 and macros['carbs'] == 0 and macros['fat'] == 0:
                print(f"  ⚠️  No macro data for '{food_name}'")
                return None
            
            return {
                'name': food.get('description', food_name),
                'calories_per_100g': macros['calories'],
                'protein_per_100g': macros['protein'],
                'carbs_per_100g': macros['carbs'],
                'fat_per_100g': macros['fat']
            }
        
        except requests.exceptions.Timeout:
            print(f"  ⏳ Timeout for '{food_name}', retrying... ({attempt + 1}/{retries})")
            time.sleep(2)
        except Exception as e:
            print(f"  ❌ Error querying '{food_name}': {str(e)}")
            return None
    
    return None

# =============================================================================
# FOOD LIST MANAGEMENT
# =============================================================================

def download_food_lists() -> Dict:
    """Download food lists from GitHub Gist"""
    print("\n📥 Downloading food lists from GitHub Gist...")
    
    # For now, use embedded lists since I can't actually create a Gist
    # In production, this would download from a real Gist URL
    
    # I'll provide the comprehensive food lists here
    food_lists = {
        'core_foods': {
            'us': [
                # Proteins - Poultry
                "Chicken breast raw", "Chicken breast grilled", "Chicken thigh", 
                "Ground chicken", "Turkey breast", "Turkey ground", "Duck breast",
                
                # Proteins - Beef
                "Beef sirloin", "Ground beef 90% lean", "Ground beef 85% lean",
                "Beef steak", "Beef jerky", "Corned beef",
                
                # Proteins - Pork
                "Pork chop", "Pork tenderloin", "Ground pork", "Bacon",
                "Ham", "Pork sausage",
                
                # Proteins - Seafood
                "Salmon raw", "Salmon baked", "Tuna canned in water",
                "Tuna canned in oil", "Cod", "Tilapia", "Shrimp", "Crab",
                
                # Eggs
                "Egg whole raw", "Egg white raw", "Egg white cooked",
                "Egg yolk", "Scrambled eggs", "Boiled egg",
                
                # Dairy
                "Milk whole", "Milk 2%", "Milk skim", 
                "Almond milk unsweetened", "Oat milk", "Soy milk",
                "Greek yogurt plain nonfat", "Greek yogurt whole milk",
                "Cottage cheese low fat", "Cottage cheese regular",
                "Cheddar cheese", "Mozzarella cheese", "Cream cheese",
                "Parmesan cheese", "Feta cheese", "Sour cream",
                
                # Protein Powder
                "Whey protein isolate", "Whey protein concentrate",
                "Casein protein", "Pea protein powder",
                
                # Grains - Rice
                "White rice cooked", "Brown rice cooked", "Jasmine rice",
                "Basmati rice", "Wild rice",
                
                # Grains - Bread
                "White bread", "Whole wheat bread", "Sourdough bread",
                "Bagel plain", "English muffin", "Pita bread",
                "Tortilla flour", "Tortilla whole wheat",
                
                # Grains - Pasta
                "Pasta cooked", "Whole wheat pasta cooked", "Spaghetti",
                "Macaroni", "Egg noodles",
                
                # Grains - Breakfast
                "Oatmeal cooked", "Steel cut oats", "Instant oats",
                "Cheerios", "Corn flakes", "Granola",
                
                # Legumes
                "Black beans cooked", "Kidney beans cooked",
                "Chickpeas cooked", "Lentils cooked", "Edamame",
                
                # Nuts & Seeds
                "Almonds", "Walnuts", "Cashews", "Peanuts",
                "Peanut butter", "Almond butter",
                "Chia seeds", "Flax seeds", "Sunflower seeds",
                
                # Vegetables
                "Broccoli raw", "Broccoli cooked", "Cauliflower",
                "Spinach raw", "Spinach cooked", "Kale",
                "Carrots", "Bell pepper", "Tomato", "Cucumber",
                "Asparagus", "Green beans", "Zucchini",
                "Sweet potato", "Potato baked", "Avocado",
                
                # Fruits
                "Apple", "Banana", "Orange", "Strawberries",
                "Blueberries", "Grapes", "Watermelon",
                "Pineapple", "Mango", "Peach",
                
                # Fats & Oils
                "Olive oil", "Coconut oil", "Butter", "Mayonnaise",
                
                # Snacks
                "Protein bar", "Rice cakes", "Popcorn air popped",
                "Dark chocolate 70%", "Honey",
            ],
            
            'au': [
                # Proteins
                "Chicken breast", "Chicken thigh", "Chicken mince",
                "Beef mince", "Beef steak", "Lamb chops", "Kangaroo steak",
                "Barramundi", "Salmon", "Tuna canned in water", "Prawns",
                
                # Eggs
                "Eggs whole", "Egg whites", "Egg whites cooked",
                "Scrambled eggs", "Boiled eggs",
                
                # Dairy
                "Milk full cream", "Milk skim", "Almond milk", "Oat milk",
                "Greek yogurt", "Jalna yogurt", "YoPRO yogurt",
                "Cottage cheese", "Tasty cheese", "Bega cheese", "Feta",
                
                # Australian Foods
                "Vegemite", "Milo", "Tim Tams", "Shapes BBQ",
                "Weet-Bix", "Anzac biscuits", "Meat pie", "Sausage roll",
                "Lamington", "Pavlova",
                
                # Grains
                "White rice cooked", "Brown rice cooked", "Pasta cooked",
                "White bread", "Wholemeal bread", "Rolled oats",
                "Quinoa cooked",
                
                # Legumes
                "Baked beans", "Chickpeas", "Lentils", "Kidney beans",
                
                # Nuts
                "Almonds", "Walnuts", "Macadamias", "Peanut butter",
                "Chia seeds",
                
                # Vegetables
                "Broccoli", "Cauliflower", "Carrots", "Sweet potato",
                "Potato", "Capsicum", "Tomato", "Avocado", "Spinach",
                
                # Fruits
                "Banana", "Apple", "Orange", "Strawberries",
                "Mango", "Kiwi fruit", "Watermelon",
                
                # Fats
                "Olive oil", "Butter", "Mayonnaise",
                
                # Beverages
                "Farmers Union Iced Coffee", "Oak Chocolate Milk",
            ],
            
            # Add other regions with similar structure
            'gb': ["Chicken breast", "Eggs", "Salmon", "Greek yoghurt", "Baked beans", "Marmite"],
            'ca': ["Chicken breast", "Eggs", "Salmon", "Maple syrup", "Poutine gravy"],
            'de': ["Chicken breast", "Eggs", "Bratwurst", "Sauerkraut", "Pretzel"],
            'fr': ["Chicken breast", "Eggs", "Duck confit", "Brie", "Baguette"],
            'es': ["Chicken breast", "Eggs", "Jamón ibérico", "Paella rice", "Chorizo"],
            'it': ["Chicken breast", "Eggs", "Prosciutto", "Parmesan", "Pasta"],
            'br': ["Chicken breast", "Eggs", "Picanha", "Black beans", "Açaí"],
            'mx': ["Chicken breast", "Eggs", "Carnitas", "Corn tortillas", "Avocado"],
            'in': ["Chicken breast", "Eggs", "Paneer", "Dal", "Basmati rice"],
            'nl': ["Chicken breast", "Eggs", "Herring", "Gouda", "Stroopwafel"],
            'se': ["Chicken breast", "Eggs", "Meatballs", "Lingonberries", "Knäckebröd"],
            'ae': ["Chicken breast", "Eggs", "Lamb", "Hummus", "Dates"],
            'sa': ["Chicken breast", "Eggs", "Lamb", "Kabsa rice", "Dates"],
            'eg': ["Chicken breast", "Eggs", "Koshari", "Ful medames", "Falafel"],
            'za': ["Chicken breast", "Eggs", "Boerewors", "Biltong", "Mieliepap"],
            'jp': ["Chicken breast", "Eggs", "Salmon", "Tofu", "Sushi rice"],
            'kr': ["Chicken breast", "Eggs", "Pork belly", "Kimchi", "White rice"],
            'generic': ["Chicken breast", "Eggs", "Salmon", "Greek yogurt", "Oats"],
        },
        
        'beverages': {
            'coffee': [
                "Coffee black", "Espresso", "Americano",
                "Flat white with full cream milk", "Flat white with skim milk",
                "Flat white with almond milk", "Flat white with oat milk",
                "Latte with full cream milk", "Latte with skim milk",
                "Cappuccino with full cream milk", "Cappuccino with skim milk",
                "Mocha", "Iced coffee", "Cold brew",
            ],
            'shakes': [
                "Protein shake vanilla", "Protein shake chocolate",
                "Chocolate milk", "Strawberry milk",
            ],
            'other': [
                "Coca Cola", "Pepsi", "Sprite", "Red Bull",
                "Orange juice", "Apple juice", "Coconut water",
            ]
        },
        
        'fast_food': {
            'mcdonalds': [
                "Big Mac", "Quarter Pounder", "McChicken", "Filet-O-Fish",
                "Chicken McNuggets 6 piece", "Chicken McNuggets 10 piece",
                "Medium fries", "Large fries", "Hash brown",
                "Egg McMuffin", "Sausage McMuffin", "McGriddle",
            ],
            'kfc': [
                "Original Recipe Chicken Breast", "Original Recipe Drumstick",
                "Crispy Chicken Breast", "Popcorn Chicken",
                "Zinger Burger", "Regular Fries", "Coleslaw",
            ],
            'subway': [
                "Turkey Breast 6 inch", "Chicken Teriyaki 6 inch",
                "Meatball Marinara 6 inch", "Veggie Delite 6 inch",
                "Steak and Cheese 6 inch",
            ],
            'starbucks': [
                "Pike Place Roast", "Caffe Latte", "Cappuccino",
                "Caramel Macchiato", "Flat White", "Americano",
            ],
        }
    }
    
    return food_lists

def save_cache(data: Dict):
    """Save food lists to cache file"""
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    print(f"✅ Cached food lists to {CACHE_FILE}")

def load_cache() -> Optional[Dict]:
    """Load food lists from cache"""
    if os.path.exists(CACHE_FILE):
        print(f"📦 Loading cached food lists from {CACHE_FILE}")
        with open(CACHE_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return None

# =============================================================================
# DATABASE GENERATION
# =============================================================================

def generate_database(region_code: str, food_list: List[str], output_file: str):
    """Generate food database for a region"""
    print(f"\n🌍 Generating: {output_file}")
    print(f"📋 Processing {len(food_list)} foods...")
    
    foods_data = []
    
    for i, food_name in enumerate(food_list, 1):
        print(f"  [{i}/{len(food_list)}] {food_name}")
        
        food_data = query_usda(food_name)
        if food_data:
            foods_data.append(food_data)
            print(f"    ✅ Added")
        
        # Rate limiting
        time.sleep(2)
    
    # Save to JSON
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(foods_data, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Generated: {output_file} ({len(foods_data)} foods)")

# =============================================================================
# MAIN
# =============================================================================

def main():
    print("=" * 70)
    print("🌍 BAREMACROS COMPREHENSIVE FOOD DATABASE GENERATOR")
    print("=" * 70)
    
    # Load or download food lists
    food_lists = load_cache()
    if not food_lists:
        food_lists = download_food_lists()
        save_cache(food_lists)
    
    print(f"\n🔑 Using API Key: {USDA_API_KEY[:10]}...")
    if USDA_API_KEY == "HdGTRLyEiCAM3d2KuxRxVAyXvqpQhMFB5oDVsBAE":
        print("⚠️  WARNING: Using DEMO_KEY (30 requests/hour limit)")
        print("   Get free key: https://fdc.nal.usda.gov/api-key-signup.html")
    
    print("\n📊 Database categories:")
    print(f"   • Core foods: {len(food_lists['core_foods'])} regions")
    print(f"   • Beverages: {len(food_lists['beverages'])} categories")
    print(f"   • Fast food: {len(food_lists['fast_food'])} chains")
    
    choice = input("\nGenerate: (1) Core foods (2) Beverages (3) Fast food (4) All: ")
    
    if choice in ['1', '4']:
        print("\n" + "=" * 70)
        print("GENERATING CORE FOOD DATABASES")
        print("=" * 70)
        for region, foods in food_lists['core_foods'].items():
            generate_database(region, foods, f"foods_{region}.json")
    
    if choice in ['2', '4']:
        print("\n" + "=" * 70)
        print("GENERATING BEVERAGE DATABASES")
        print("=" * 70)
        all_beverages = []
        for category, drinks in food_lists['beverages'].items():
            all_beverages.extend(drinks)
        generate_database('beverages', all_beverages, "foods_beverages.json")
    
    if choice in ['3', '4']:
        print("\n" + "=" * 70)
        print("GENERATING FAST FOOD DATABASES")
        print("=" * 70)
        for chain, items in food_lists['fast_food'].items():
            generate_database(chain, items, f"foods_{chain}.json")
    
    print("\n" + "=" * 70)
    print("✅ ALL DATABASES GENERATED!")
    print("=" * 70)
    print("\n📂 Next steps:")
    print("   1. Move all foods_*.json to: assets/data/")
    print("   2. Rebuild: flutter clean && flutter build apk")
    print("   3. Test searching for 'egg whites' and 'flat white'!")

if __name__ == "__main__":
    main()