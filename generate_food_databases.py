import requests
import json
import time
from typing import List, Dict, Optional

# USDA API Configuration
USDA_API_KEY = "HdGTRLyEiCAM3d2KuxRxVAyXvqpQhMFB5oDVsBAE"  # Replace with your key from https://fdc.nal.usda.gov/api-key-signup.html
USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"

def query_usda(food_name: str) -> Optional[Dict]:
    """Query USDA API for food macros"""
    params = {
        'query': food_name,
        'pageSize': 1,
        'api_key': USDA_API_KEY
    }
    
    try:
        response = requests.get(USDA_BASE_URL, params=params, timeout=10)
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
        
        # Extract macros (nutrient codes: 203=protein, 205=carbs, 204=fat, 208=calories)
        macros = {
            'protein': 0,
            'carbs': 0,
            'fat': 0,
            'calories': 0
        }
        
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
    
    except Exception as e:
        print(f"  ❌ Error querying '{food_name}': {str(e)}")
        return None

def generate_database(region_code: str, food_list: List[str], output_file: str):
    """Generate food database for a region"""
    print(f"\n🌍 Generating database for: {region_code}")
    print(f"📋 Processing {len(food_list)} foods...")
    
    foods_data = []
    
    for i, food_name in enumerate(food_list, 1):
        print(f"  [{i}/{len(food_list)}] Querying: {food_name}")
        
        food_data = query_usda(food_name)
        if food_data:
            foods_data.append(food_data)
            print(f"    ✅ Added: {food_data['name']}")
        
        # Rate limiting (DEMO_KEY allows 30 requests/hour, 1000/day)
        time.sleep(2)  # 2 seconds between requests
    
    # Save to JSON file
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(foods_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Generated: {output_file}")
    print(f"   📊 Total foods: {len(foods_data)}/{len(food_list)}")
    print(f"   💾 File size: {len(json.dumps(foods_data))} bytes")

# =============================================================================
# FOOD LISTS BY REGION
# =============================================================================

FOOD_LISTS = {
    'us': [
        "Chicken breast", "Ground beef", "Eggs", "Salmon", "Tuna",
        "Turkey breast", "Pork chop", "Bacon", "Shrimp", "Tilapia",
        "Greek yogurt", "Cottage cheese", "Cheddar cheese", "Milk", "Whey protein",
        "White rice", "Brown rice", "Oatmeal", "Whole wheat bread", "Pasta",
        "Quinoa", "Sweet potato", "Potato", "Corn", "Black beans",
        "Peanut butter", "Almonds", "Walnuts", "Cashews", "Chia seeds",
        "Broccoli", "Spinach", "Kale", "Carrots", "Tomato",
        "Avocado", "Banana", "Apple", "Orange", "Blueberries",
        "Strawberries", "Protein bar", "Granola", "Bagel", "Pancake mix",
        "Mac and cheese", "Pizza", "Hot dog", "Hamburger bun", "Tortilla"
    ],
    
    'gb': [
        "Chicken breast", "Beef mince", "Eggs", "Salmon", "Cod",
        "Bacon rashers", "Sausages", "Lamb chop", "Turkey", "Prawns",
        "Cheddar cheese", "Milk", "Greek yoghurt", "Cottage cheese", "Butter",
        "White rice", "Brown rice", "Porridge oats", "Wholemeal bread", "Pasta",
        "Jacket potato", "Baked beans", "Fish and chips", "Shepherd's pie", "Bangers and mash",
        "Marmite", "HP Sauce", "Yorkshire pudding", "Cornish pasty", "Pork pie",
        "Digestive biscuits", "Custard creams", "Jaffa cakes", "Cadbury chocolate", "Walkers crisps",
        "Broccoli", "Carrots", "Peas", "Brussels sprouts", "Cabbage",
        "Apples", "Bananas", "Strawberries", "Oranges", "Blackberries",
        "Tea with milk", "Weetabix", "Muesli", "Full English breakfast", "Roast dinner"
    ],
    
    'ca': [
        "Chicken breast", "Ground beef", "Eggs", "Salmon", "Turkey",
        "Bacon", "Pork chops", "Shrimp", "Cod", "Trout",
        "Cheddar cheese", "Milk", "Greek yogurt", "Cottage cheese", "Cream cheese",
        "White rice", "Brown rice", "Oatmeal", "Whole wheat bread", "Pasta",
        "Quinoa", "Sweet potato", "Potato", "Maple syrup", "Poutine",
        "Tim Hortons coffee", "Nanaimo bars", "Butter tarts", "Tourtière", "Montreal smoked meat",
        "Peanut butter", "Almonds", "Walnuts", "Chia seeds", "Flaxseed",
        "Broccoli", "Carrots", "Spinach", "Kale", "Brussels sprouts",
        "Apples", "Blueberries", "Strawberries", "Cranberries", "Raspberries",
        "Bannock", "Peameal bacon", "Ketchup chips", "Coffee Crisp", "Smarties"
    ],
    
    'au': [
        "Chicken breast", "Beef mince", "Eggs", "Kangaroo", "Lamb chops",
        "Barramundi", "Salmon", "Prawns", "Calamari", "Oysters",
        "Cheddar cheese", "Milk", "Greek yogurt", "Vegemite", "Butter",
        "White rice", "Brown rice", "Oats", "Bread", "Pasta",
        "Sweet potato", "Potato", "Weet-Bix", "Milo", "Tim Tams",
        "Shapes crackers", "Arnott's biscuits", "Anzac biscuits", "Lamington", "Pavlova",
        "Meat pie", "Sausage roll", "Fairy bread", "Chiko roll", "Dim sim",
        "Macadamia nuts", "Almonds", "Peanut butter", "Avocado", "Mango",
        "Broccoli", "Carrots", "Tomato", "Capsicum", "Zucchini",
        "Banana", "Apple", "Orange", "Strawberries", "Kiwi fruit",
        "Bundaberg ginger beer", "Milo drink", "Farmers Union iced coffee", "Jalna yogurt", "Bega cheese"
    ],
    
    'de': [
        "Chicken breast", "Ground pork", "Eggs", "Bratwurst", "Schnitzel",
        "Salmon", "Trout", "Herring", "Sauerbraten", "Leberwurst",
        "Quark", "Milk", "Yogurt", "Käse", "Butter",
        "White rice", "Whole grain bread", "Rye bread", "Spätzle", "Kartoffeln",
        "Sauerkraut", "Red cabbage", "Pretzels", "Black bread", "Pumpernickel",
        "Bratwurst", "Currywurst", "Schnitzel", "Rouladen", "Sauerbraten",
        "Sauerkraut", "Potato salad", "Apple strudel", "Black forest cake", "Lebkuchen",
        "Almonds", "Walnuts", "Sunflower seeds", "Pumpkin seeds", "Hazelnuts",
        "Broccoli", "Carrots", "Cabbage", "Asparagus", "Mushrooms",
        "Apples", "Strawberries", "Cherries", "Plums", "Grapes"
    ],
    
    'fr': [
        "Chicken breast", "Ground beef", "Eggs", "Duck confit", "Foie gras",
        "Salmon", "Trout", "Mussels", "Escargot", "Sea bass",
        "Brie cheese", "Camembert", "Roquefort", "Milk", "Crème fraîche",
        "White rice", "Baguette", "Croissant", "Brioche", "Pain au chocolat",
        "Potato", "Ratatouille", "Quiche", "Coq au vin", "Bouillabaisse",
        "Butter", "Olive oil", "Dijon mustard", "Mayonnaise", "Béarnaise sauce",
        "Almonds", "Walnuts", "Hazelnuts", "Chestnuts", "Pine nuts",
        "Green beans", "Asparagus", "Artichoke", "Mushrooms", "Tomatoes",
        "Apples", "Pears", "Cherries", "Strawberries", "Grapes"
    ],
    
    'es': [
        "Chicken breast", "Ground pork", "Eggs", "Jamón ibérico", "Chorizo",
        "Salmon", "Cod", "Sardines", "Octopus", "Squid",
        "Manchego cheese", "Milk", "Yogurt", "Queso fresco", "Butter",
        "White rice", "Paella rice", "Bread", "Pan con tomate", "Pasta",
        "Potato", "Patatas bravas", "Tortilla española", "Gazpacho", "Paella",
        "Olive oil", "Olives", "Garlic", "Paprika", "Saffron",
        "Almonds", "Walnuts", "Pine nuts", "Hazelnuts", "Pistachios",
        "Tomatoes", "Bell peppers", "Onions", "Garlic", "Spinach",
        "Oranges", "Apples", "Grapes", "Strawberries", "Figs",
        "Churros", "Magdalenas", "Turrón", "Manchego", "Serrano ham"
    ],
    
    'it': [
        "Chicken breast", "Ground beef", "Eggs", "Prosciutto", "Pancetta",
        "Salmon", "Tuna", "Anchovies", "Calamari", "Mussels",
        "Parmesan cheese", "Mozzarella", "Ricotta", "Milk", "Mascarpone",
        "White rice", "Risotto rice", "Pasta", "Bread", "Pizza dough",
        "Potato", "Gnocchi", "Polenta", "Lasagna", "Ravioli",
        "Olive oil", "Tomatoes", "Basil", "Garlic", "Balsamic vinegar",
        "Pine nuts", "Almonds", "Walnuts", "Hazelnuts", "Pistachios",
        "Tomatoes", "Zucchini", "Eggplant", "Peppers", "Spinach",
        "Apples", "Oranges", "Grapes", "Figs", "Strawberries",
        "Tiramisu", "Gelato", "Cannoli", "Panettone", "Biscotti"
    ],
    
    'br': [
        "Chicken breast", "Beef picanha", "Eggs", "Pork ribs", "Linguiça",
        "Salmon", "Tilapia", "Shrimp", "Cod", "Sardines",
        "Queijo minas", "Milk", "Yogurt", "Requeijão", "Cheese bread",
        "White rice", "Black beans", "Farofa", "Cassava", "Polenta",
        "Feijoada", "Moqueca", "Brigadeiro", "Pão de queijo", "Coxinha",
        "Açaí", "Guaraná", "Coconut", "Palm oil", "Olive oil",
        "Brazil nuts", "Cashews", "Peanuts", "Almonds", "Walnuts",
        "Tomatoes", "Peppers", "Okra", "Collard greens", "Yuca",
        "Banana", "Papaya", "Mango", "Passion fruit", "Guava",
        "Tapioca", "Paçoca", "Rapadura", "Cocada", "Beijinho"
    ],
    
    'mx': [
        "Chicken breast", "Ground beef", "Eggs", "Pork carnitas", "Chorizo",
        "Tilapia", "Shrimp", "Salmon", "Cod", "Ceviche",
        "Queso fresco", "Queso Oaxaca", "Milk", "Crema", "Cotija cheese",
        "White rice", "Black beans", "Pinto beans", "Corn tortillas", "Flour tortillas",
        "Tacos", "Enchiladas", "Quesadillas", "Tamales", "Pozole",
        "Avocado", "Salsa", "Jalapeños", "Cilantro", "Lime",
        "Pumpkin seeds", "Sunflower seeds", "Peanuts", "Almonds", "Walnuts",
        "Tomatoes", "Peppers", "Onions", "Tomatillos", "Nopales",
        "Mango", "Papaya", "Pineapple", "Banana", "Guava",
        "Churros", "Tres leches cake", "Flan", "Conchas", "Dulce de leche"
    ],
    
    'in': [
        "Chicken breast", "Lamb", "Eggs", "Paneer", "Fish curry",
        "Dal", "Lentils", "Chickpeas", "Kidney beans", "Mung beans",
        "Milk", "Yogurt", "Ghee", "Paneer", "Butter",
        "Basmati rice", "Brown rice", "Roti", "Naan", "Chapati",
        "Potato", "Cauliflower", "Spinach", "Okra", "Eggplant",
        "Curry", "Biryani", "Tikka masala", "Samosa", "Pakora",
        "Turmeric", "Cumin", "Coriander", "Cardamom", "Garam masala",
        "Almonds", "Cashews", "Pistachios", "Peanuts", "Coconut",
        "Tomatoes", "Onions", "Garlic", "Ginger", "Green chili",
        "Mango", "Banana", "Papaya", "Guava", "Pomegranate",
        "Lassi", "Chai", "Jalebi", "Gulab jamun", "Barfi"
    ],
    
    'nl': [
        "Chicken breast", "Ground beef", "Eggs", "Herring", "Salmon",
        "Stroopwafel", "Gouda cheese", "Edam cheese", "Milk", "Yogurt",
        "White rice", "Brown rice", "Bread", "Rye bread", "Crackers",
        "Potato", "Stamppot", "Bitterballen", "Kroket", "Frikandel",
        "Peanut butter", "Hagelslag", "Speculaas", "Oliebollen", "Poffertjes",
        "Almonds", "Walnuts", "Hazelnuts", "Sunflower seeds", "Pumpkin seeds",
        "Broccoli", "Carrots", "Cabbage", "Kale", "Endive",
        "Apples", "Pears", "Strawberries", "Blueberries", "Oranges",
        "Drop", "Vla", "Hagelslag", "Stroopwafel", "Gevulde koek"
    ],
    
    'se': [
        "Chicken breast", "Ground beef", "Eggs", "Salmon", "Herring",
        "Meatballs", "Reindeer", "Elk", "Pork", "Bacon",
        "Milk", "Yogurt", "Cheese", "Butter", "Filmjölk",
        "White rice", "Brown rice", "Knäckebröd", "Rye bread", "Oats",
        "Potato", "Lingonberries", "Gravlax", "Pickled herring", "Surströmming",
        "Almonds", "Walnuts", "Hazelnuts", "Sunflower seeds", "Pumpkin seeds",
        "Broccoli", "Carrots", "Cabbage", "Kale", "Turnips",
        "Apples", "Pears", "Strawberries", "Blueberries", "Lingonberries",
        "Cinnamon buns", "Prinsesstårta", "Kladdkaka", "Semla", "Pepparkakor"
    ],
    
    'ae': [
        "Chicken breast", "Lamb", "Eggs", "Beef", "Fish",
        "Hummus", "Falafel", "Shawarma", "Kebab", "Kofta",
        "Labneh", "Yogurt", "Milk", "Cheese", "Ghee",
        "White rice", "Basmati rice", "Pita bread", "Flatbread", "Couscous",
        "Dates", "Figs", "Apricots", "Raisins", "Prunes",
        "Tahini", "Olive oil", "Sesame seeds", "Pine nuts", "Pistachios",
        "Chickpeas", "Lentils", "Fava beans", "Black beans", "Kidney beans",
        "Tomatoes", "Cucumbers", "Onions", "Peppers", "Eggplant",
        "Dates", "Figs", "Pomegranate", "Oranges", "Grapes",
        "Baklava", "Kunafa", "Halva", "Turkish delight", "Ma'amoul"
    ],
    
    'sa': [
        "Chicken", "Lamb", "Beef", "Eggs", "Fish",
        "Kabsa", "Shawarma", "Falafel", "Hummus", "Mandi",
        "Labneh", "Yogurt", "Milk", "Cheese", "Ghee",
        "White rice", "Basmati rice", "Pita bread", "Flatbread", "Couscous",
        "Dates", "Figs", "Dried apricots", "Raisins", "Almonds",
        "Tahini", "Olive oil", "Sesame oil", "Pine nuts", "Pistachios",
        "Chickpeas", "Lentils", "Fava beans", "Falafel", "Hummus",
        "Tomatoes", "Cucumbers", "Onions", "Peppers", "Eggplant",
        "Dates", "Figs", "Pomegranate", "Grapes", "Watermelon",
        "Baklava", "Kunafa", "Halva", "Ma'amoul", "Qatayef"
    ],
    
    'eg': [
        "Chicken", "Beef", "Eggs", "Fish", "Lamb",
        "Koshari", "Ful medames", "Falafel", "Molokhia", "Mahshi",
        "Yogurt", "Cheese", "Milk", "Labneh", "Ghee",
        "White rice", "Pita bread", "Flatbread", "Pasta", "Lentils",
        "Fava beans", "Chickpeas", "Lentils", "Black beans", "Kidney beans",
        "Tahini", "Olive oil", "Sesame seeds", "Cumin", "Coriander",
        "Almonds", "Pistachios", "Peanuts", "Sunflower seeds", "Pumpkin seeds",
        "Tomatoes", "Cucumbers", "Onions", "Peppers", "Eggplant",
        "Dates", "Figs", "Oranges", "Grapes", "Watermelon",
        "Basbousa", "Kunafa", "Baklava", "Feteer", "Ma'amoul"
    ],
    
    'za': [
        "Chicken breast", "Beef", "Eggs", "Boerewors", "Biltong",
        "Fish", "Prawns", "Calamari", "Kingklip", "Snoek",
        "Cheddar cheese", "Milk", "Yogurt", "Butter", "Cream",
        "White rice", "Brown rice", "Mieliepap", "Bread", "Rusks",
        "Potato", "Sweet potato", "Butternut", "Pumpkin", "Beans",
        "Bobotie", "Potjiekos", "Sosaties", "Bunny chow", "Vetkoek",
        "Peanuts", "Almonds", "Macadamias", "Cashews", "Sunflower seeds",
        "Tomatoes", "Onions", "Peppers", "Spinach", "Cabbage",
        "Apples", "Oranges", "Bananas", "Grapes", "Pears",
        "Koeksisters", "Melktert", "Peppermint crisp tart", "Rusks", "Biltong"
    ],
    
    'jp': [
        "Chicken breast", "Pork belly", "Eggs", "Salmon", "Tuna",
        "Sushi", "Sashimi", "Tofu", "Edamame", "Tempura",
        "Milk", "Yogurt", "Miso", "Natto", "Tofu",
        "White rice", "Brown rice", "Soba noodles", "Udon noodles", "Ramen",
        "Seaweed", "Miso soup", "Teriyaki", "Yakitori", "Katsu",
        "Sesame seeds", "Sesame oil", "Soy sauce", "Mirin", "Sake",
        "Edamame", "Daikon", "Shiitake mushrooms", "Nori", "Wakame",
        "Cucumber", "Cabbage", "Carrots", "Spinach", "Eggplant",
        "Apples", "Oranges", "Persimmon", "Yuzu", "Strawberries",
        "Mochi", "Dorayaki", "Taiyaki", "Pocky", "Matcha"
    ],
    
    'kr': [
        "Chicken breast", "Pork belly", "Beef", "Eggs", "Fish",
        "Kimchi", "Bulgogi", "Bibimbap", "Galbi", "Samgyeopsal",
        "Tofu", "Soy milk", "Yogurt", "Milk", "Cheese",
        "White rice", "Brown rice", "Japchae noodles", "Ramyeon", "Rice cakes",
        "Kimchi", "Gochujang", "Doenjang", "Soy sauce", "Sesame oil",
        "Sesame seeds", "Pine nuts", "Peanuts", "Almonds", "Walnuts",
        "Spinach", "Bean sprouts", "Radish", "Cucumber", "Seaweed",
        "Apples", "Pears", "Persimmon", "Strawberries", "Grapes",
        "Tteokbokki", "Hotteok", "Bungeoppang", "Yakgwa", "Dasik"
    ],
    
    'generic': [
        "Chicken breast", "Ground beef", "Eggs", "Salmon", "Tuna",
        "Turkey", "Pork", "Shrimp", "Cod", "Tilapia",
        "Milk", "Yogurt", "Cheese", "Cottage cheese", "Protein powder",
        "White rice", "Brown rice", "Oats", "Bread", "Pasta",
        "Quinoa", "Sweet potato", "Potato", "Lentils", "Beans",
        "Peanut butter", "Almonds", "Walnuts", "Cashews", "Chia seeds",
        "Broccoli", "Spinach", "Carrots", "Tomatoes", "Peppers",
        "Banana", "Apple", "Orange", "Berries", "Avocado",
        "Olive oil", "Butter", "Honey", "Dark chocolate", "Protein bar"
    ]
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

def main():
    print("=" * 70)
    print("🌍 FOOD DATABASE GENERATOR FOR BAREMACROS")
    print("=" * 70)
    print(f"\n📊 Regions to process: {len(FOOD_LISTS)}")
    print(f"🔑 Using API Key: {USDA_API_KEY}")
    print("\n⚠️  NOTE: DEMO_KEY is limited to 30 requests/hour")
    print("   Get your free key at: https://fdc.nal.usda.gov/api-key-signup.html")
    
    input("\n Press ENTER to start generation...")
    
    for region_code, food_list in FOOD_LISTS.items():
        output_file = f"foods_{region_code}.json"
        generate_database(region_code, food_list, output_file)
        print(f"\n{'='*70}\n")
    
    print("\n✅ ALL DATABASES GENERATED!")
    print(f"📦 Total files created: {len(FOOD_LISTS)}")
    print("\n📂 Next steps:")
    print("   1. Copy all foods_*.json files to: assets/data/")
    print("   2. Update pubspec.yaml to include them")
    print("   3. Run: flutter clean && flutter build apk --release")

if __name__ == "__main__":
    main()