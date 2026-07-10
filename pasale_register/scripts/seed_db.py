#!/usr/bin/env python3
import os
import sys
import json
import argparse
import hashlib
from html.parser import HTMLParser

class BhatbhateniParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.card_depth = 0
        self.capture_name = False
        self.capture_price = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        class_name = attrs_dict.get('class', '')
        
        if tag == 'div' and 'product-card' in class_name:
            self.current_product = {'source': 'bhatbhateni'}
            self.card_depth = 1
        elif self.current_product is not None:
            if tag == 'div':
                self.card_depth += 1
            if tag == 'div' and 'product-name' in class_name:
                self.capture_name = True
            elif tag == 'div' and 'product-price' in class_name:
                self.capture_price = True

    def handle_endtag(self, tag):
        if self.current_product is not None:
            if tag == 'div':
                self.card_depth -= 1
                if self.card_depth == 0:
                    if 'name' in self.current_product and 'sellingPrice' in self.current_product:
                        self.products.append(self.current_product)
                    self.current_product = None
            if self.capture_name and tag == 'div':
                self.capture_name = False
            if self.capture_price and tag == 'div':
                self.capture_price = False

    def handle_data(self, data):
        if self.current_product is not None:
            if self.capture_name:
                name = data.strip()
                if name:
                    self.current_product['name'] = name
            elif self.capture_price:
                price_str = data.replace('Rs.', '').replace('NPR', '').replace(',', '').strip()
                try:
                    self.current_product['sellingPrice'] = float(price_str)
                except ValueError:
                    pass


class DarazParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.item_depth = 0
        self.capture_name = False
        self.capture_price = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        class_name = attrs_dict.get('class', '')
        
        if tag == 'div' and 'c2-item' in class_name:
            self.current_product = {'source': 'daraz'}
            self.item_depth = 1
        elif self.current_product is not None:
            if tag == 'div':
                self.item_depth += 1
            
            if tag == 'a' and 'title-link' in class_name:
                self.capture_name = True
            elif tag == 'span' and 'price-val' in class_name:
                self.capture_price = True

    def handle_endtag(self, tag):
        if self.current_product is not None:
            if tag == 'div':
                self.item_depth -= 1
                if self.item_depth == 0:
                    if 'name' in self.current_product and 'sellingPrice' in self.current_product:
                        self.products.append(self.current_product)
                    self.current_product = None
            if self.capture_name and tag == 'a':
                self.capture_name = False
            if self.capture_price and tag == 'span':
                self.capture_price = False

    def handle_data(self, data):
        if self.current_product is not None:
            if self.capture_name:
                name = data.strip()
                if name:
                    self.current_product['name'] = name
            elif self.capture_price:
                price_str = data.replace('Rs.', '').replace('NPR', '').replace(',', '').strip()
                try:
                    self.current_product['sellingPrice'] = float(price_str)
                except ValueError:
                    pass


def generate_ean13(source, name):
    # Deterministic generation using MD5 of source + name
    hasher = hashlib.md5()
    hasher.update(f"{source}_{name}".encode('utf-8'))
    hash_hex = hasher.hexdigest()
    hash_int = int(hash_hex, 16)
    nine_digits = f"{hash_int % 1000000000:09d}"
    barcode_data = "977" + nine_digits
    
    # EAN-13 Checksum calculation
    odd_sum = sum(int(barcode_data[i]) for i in range(0, 12, 2))
    even_sum = sum(int(barcode_data[i]) for i in range(1, 12, 2))
    total_sum = odd_sum + 3 * even_sum
    checksum = (10 - (total_sum % 10)) % 10
    
    return barcode_data + str(checksum)


def main():
    parser = argparse.ArgumentParser(description="Pasale Register Catalog Seeding Tool")
    path_default_bb = os.path.join(os.path.dirname(__file__), "../assets/mock_html/bhatbhateni.html")
    path_default_dz = os.path.join(os.path.dirname(__file__), "../assets/mock_html/daraz.html")
    path_default_out = os.path.join(os.path.dirname(__file__), "../assets/seeded_products.json")

    parser.add_argument("--bhatbhateni-file", default=path_default_bb, help="Path to Bhatbhateni mock HTML")
    parser.add_argument("--daraz-file", default=path_default_dz, help="Path to Daraz mock HTML")
    parser.add_argument("--output", default=path_default_out, help="Path to write the output JSON catalog")
    parser.add_argument("--markup", type=float, default=15.0, help="Default markup percentage")
    parser.add_argument("--dry-run", action="store_true", help="Print products without saving to file or uploading")
    parser.add_argument("--upload", action="store_true", help="Upload the catalog to Firestore")
    parser.add_argument("--credentials", help="Path to Firestore service account credentials JSON")

    args = parser.parse_args()

    products = []

    # Parse Bhatbhateni
    if os.path.exists(args.bhatbhateni_file):
        bb_path = args.bhatbhateni_file
        print(f"Parsing Bhatbhateni mock HTML from: {bb_path}")
        with open(bb_path, "r", encoding="utf-8") as f:
            html_content = f.read()
        bb_parser = BhatbhateniParser()
        bb_parser.feed(html_content)
        products.extend(bb_parser.products)
    else:
        bb_path = args.bhatbhateni_file
        print(f"Warning: Bhatbhateni mock file not found at: {bb_path}")

    # Parse Daraz
    if os.path.exists(args.daraz_file):
        dz_path = args.daraz_file
        print(f"Parsing Daraz mock HTML from: {dz_path}")
        with open(dz_path, "r", encoding="utf-8") as f:
            html_content = f.read()
        dz_parser = DarazParser()
        dz_parser.feed(html_content)
        products.extend(dz_parser.products)
    else:
        dz_path = args.daraz_file
        print(f"Warning: Daraz mock file not found at: {dz_path}")

    # Process and build final list
    final_products = []
    for p in products:
        selling_price = p['sellingPrice']
        cost_price = round(selling_price / (1.0 + args.markup / 100.0), 2)
        barcode = generate_ean13(p['source'], p['name'])
        
        product_doc = {
            "id": barcode,
            "name": p['name'],
            "barcode": barcode,
            "sellingPrice": selling_price,
            "costPrice": cost_price,
            "markup": args.markup
        }
        final_products.append(product_doc)

    print(f"Scraped and processed {len(final_products)} products.")

    # Validation check
    for p in final_products:
        expected_selling = round(p['costPrice'] * (1.0 + p['markup'] / 100.0), 2)
        diff = abs(p['sellingPrice'] - expected_selling)
        if diff > 0.01:
            print(f"Warning: pricing invariant mismatch for {p['name']}: cost={p['costPrice']}, markup={p['markup']}, calculated selling={expected_selling}, original selling={p['sellingPrice']}")

    if args.dry_run:
        print("\nDry Run Results:")
        print(json.dumps(final_products, indent=2))
        return

    # Write output to local JSON
    out_dir = os.path.dirname(args.output)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(final_products, f, indent=2)
    print(f"Seeded products catalog saved to: {args.output}")

    # Optional Upload to Firestore
    if args.upload:
        try:
            import firebase_admin
            from firebase_admin import credentials
            from firebase_admin import firestore

            if not firebase_admin._apps:
                if args.credentials:
                    cred = credentials.Certificate(args.credentials)
                    firebase_admin.initialize_app(cred)
                else:
                    firebase_admin.initialize_app()
            
            db = firestore.client()
            batch = db.batch()
            for p in final_products:
                doc_ref = db.collection('products').document(p['barcode'])
                batch.set(doc_ref, p)
            batch.commit()
            print(f"Successfully uploaded {len(final_products)} products to Firestore.")
        except ImportError:
            print("Error: firebase-admin library is not installed. Please run 'pip install firebase-admin' to support upload.")
            sys.exit(1)
        except Exception as e:
            print(f"Error uploading to Firestore: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()
