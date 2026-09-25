#!/usr/bin/env python3
"""
OpenFoodFacts Offline-Datenbank Builder

Laedt den vollstaendigen OFF CSV-Export herunter, filtert auf Deutschland
und erstellt eine kompakte SQLite-Datenbank mit FTS5-Volltextindex.

Ausgabe: foods_de.sqlite.gz + version.json in OFF_OUTPUT_DIR (Standard: ./off).
Gedacht fuer einen woechentlichen Cronjob auf einem Webserver, dessen
Verzeichnis die App als Basis-URL der Offline-Datenbank kennt.
"""

import csv
import gzip
import json
import logging
import os
import sqlite3
import sys
import tempfile
import urllib.request
from datetime import date
from pathlib import Path

# OFF CSV hat sehr grosse Felder (Zutatenlisten, Additive etc.)
csv.field_size_limit(10 * 1024 * 1024)  # 10 MB

# Konfiguration
CSV_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
OUTPUT_DIR = Path(os.environ.get("OFF_OUTPUT_DIR", "off"))
WORK_DIR = Path(tempfile.gettempdir()) / "off-builder"
DB_NAME = "foods_de.sqlite"
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"

# CSV-Spaltennamen (OFF Export)
COL_CODE = "code"
COL_PRODUCT_NAME = "product_name"
COL_BRANDS = "brands"
COL_COUNTRIES = "countries_tags"
COL_ENERGY_KCAL = "energy-kcal_100g"
COL_PROTEINS = "proteins_100g"
COL_CARBS = "carbohydrates_100g"
COL_FAT = "fat_100g"
COL_FIBER = "fiber_100g"
COL_SUGARS = "sugars_100g"
COL_SATURATED_FAT = "saturated-fat_100g"
COL_SALT = "salt_100g"
COL_SERVING_SIZE = "serving_size"
COL_IMAGE_URL = "image_front_small_url"

logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
log = logging.getLogger(__name__)


def download_csv(dest: Path) -> Path:
    """Laedt den komprimierten CSV-Export herunter."""
    gz_path = dest / "products.csv.gz"
    if gz_path.exists():
        log.info("CSV-Datei existiert bereits: %s", gz_path)
        return gz_path

    log.info("Lade CSV herunter: %s", CSV_URL)
    urllib.request.urlretrieve(CSV_URL, gz_path)
    size_mb = gz_path.stat().st_size / (1024 * 1024)
    log.info("Download abgeschlossen: %.1f MB", size_mb)
    return gz_path


def safe_float(value: str) -> float:
    """Konvertiert einen String sicher in float, gibt 0.0 bei Fehler zurueck."""
    if not value or value.strip() == "":
        return 0.0
    try:
        return float(value.replace(",", "."))
    except (ValueError, TypeError):
        return 0.0


def build_database(csv_gz_path: Path, db_path: Path) -> int:
    """Erstellt die SQLite-Datenbank aus dem CSV-Export."""
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("PRAGMA cache_size=-64000")  # 64 MB Cache

    # Haupttabelle
    conn.execute("""
        CREATE TABLE products (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brand TEXT,
            calories REAL DEFAULT 0,
            protein REAL DEFAULT 0,
            carbs REAL DEFAULT 0,
            fat REAL DEFAULT 0,
            fiber REAL DEFAULT 0,
            sugar REAL DEFAULT 0,
            saturated_fat REAL DEFAULT 0,
            salt REAL DEFAULT 0,
            serving_size TEXT,
            image_url TEXT
        )
    """)

    # FTS5 Volltextindex
    conn.execute("""
        CREATE VIRTUAL TABLE products_fts USING fts5(
            name, brand,
            content=products,
            content_rowid=rowid
        )
    """)

    # Metadaten-Tabelle
    conn.execute("""
        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)

    product_count = 0
    skipped = 0
    batch = []
    batch_size = 5000

    log.info("Lese und filtere CSV...")

    with gzip.open(str(csv_gz_path), "rt", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")

        for row in reader:
            countries = row.get(COL_COUNTRIES, "")
            if "en:germany" not in countries:
                continue

            code = row.get(COL_CODE, "").strip()
            name = row.get(COL_PRODUCT_NAME, "").strip()

            # Produkte ohne Barcode oder Name ueberspringen
            if not code or not name:
                skipped += 1
                continue

            # Produkte ohne Naehrwertangaben ueberspringen
            calories = safe_float(row.get(COL_ENERGY_KCAL, ""))
            if calories <= 0:
                skipped += 1
                continue

            batch.append((
                code,
                name,
                row.get(COL_BRANDS, "").strip() or None,
                calories,
                safe_float(row.get(COL_PROTEINS, "")),
                safe_float(row.get(COL_CARBS, "")),
                safe_float(row.get(COL_FAT, "")),
                safe_float(row.get(COL_FIBER, "")),
                safe_float(row.get(COL_SUGARS, "")),
                safe_float(row.get(COL_SATURATED_FAT, "")),
                safe_float(row.get(COL_SALT, "")),
                row.get(COL_SERVING_SIZE, "").strip() or None,
                row.get(COL_IMAGE_URL, "").strip() or None,
            ))

            if len(batch) >= batch_size:
                conn.executemany(
                    "INSERT OR IGNORE INTO products VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    batch,
                )
                product_count += len(batch)
                batch.clear()
                if product_count % 50000 == 0:
                    log.info("  %d Produkte verarbeitet...", product_count)

    # Rest einfuegen
    if batch:
        conn.executemany(
            "INSERT OR IGNORE INTO products VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            batch,
        )
        product_count += len(batch)

    log.info("Insgesamt %d Produkte eingefuegt (%d uebersprungen)", product_count, skipped)

    # FTS-Index befuellen
    log.info("Befuelle FTS5-Index...")
    conn.execute("""
        INSERT INTO products_fts(rowid, name, brand)
        SELECT rowid, name, brand FROM products
    """)

    # Metadaten schreiben
    today = date.today().isoformat()
    conn.execute("INSERT INTO meta VALUES ('version', ?)", (today,))
    conn.execute("INSERT INTO meta VALUES ('product_count', ?)", (str(product_count),))
    conn.execute("INSERT INTO meta VALUES ('build_date', ?)", (today,))

    conn.commit()

    # Optimieren
    log.info("Optimiere Datenbank...")
    conn.execute("PRAGMA journal_mode=DELETE")
    conn.execute("VACUUM")
    conn.close()

    db_size_mb = db_path.stat().st_size / (1024 * 1024)
    log.info("Datenbank erstellt: %.1f MB, %d Produkte", db_size_mb, product_count)

    return product_count


def compress_database(db_path: Path, gz_path: Path):
    """Komprimiert die Datenbank mit gzip."""
    log.info("Komprimiere Datenbank...")

    with open(str(db_path), "rb") as f_in:
        with gzip.open(str(gz_path), "wb", compresslevel=9) as f_out:
            while True:
                chunk = f_in.read(1024 * 1024)  # 1 MB Chunks
                if not chunk:
                    break
                f_out.write(chunk)

    gz_size_mb = gz_path.stat().st_size / (1024 * 1024)
    log.info("Komprimiert: %.1f MB", gz_size_mb)


def write_version_json(output_dir: Path, product_count: int, gz_path: Path):
    """Schreibt die version.json Datei."""
    version_data = {
        "version": date.today().isoformat(),
        "size_bytes": gz_path.stat().st_size,
        "product_count": product_count,
        "build_date": date.today().isoformat(),
    }

    version_path = output_dir / "version.json"
    with open(str(version_path), "w", encoding="utf-8") as f:
        json.dump(version_data, f, indent=2)

    log.info("version.json geschrieben: %s", version_path)


def main():
    """Hauptprogramm."""
    log.info("=== OpenFoodFacts DB Builder gestartet ===")

    # Arbeitsverzeichnis erstellen
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. CSV herunterladen
    csv_gz_path = download_csv(WORK_DIR)

    # 2. Datenbank erstellen
    db_path = WORK_DIR / DB_NAME
    product_count = build_database(csv_gz_path, db_path)

    if product_count == 0:
        log.error("Keine Produkte gefunden — Abbruch")
        sys.exit(1)

    # 3. Komprimieren
    gz_path = OUTPUT_DIR / f"{DB_NAME}.gz"
    compress_database(db_path, gz_path)

    # 4. version.json schreiben
    write_version_json(OUTPUT_DIR, product_count, gz_path)

    # 5. Unkomprimierte DB ebenfalls bereitstellen (fuer Debugging)
    import shutil
    shutil.copy2(str(db_path), str(OUTPUT_DIR / DB_NAME))

    log.info("=== Fertig ===")
    log.info("Dateien unter: %s", OUTPUT_DIR)
    log.info("  - %s.gz (komprimiert)", DB_NAME)
    log.info("  - %s (unkomprimiert)", DB_NAME)
    log.info("  - version.json")


if __name__ == "__main__":
    main()
