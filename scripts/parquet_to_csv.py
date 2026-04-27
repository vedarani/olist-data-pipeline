import pandas as pd
import os
from pathlib import Path

def convert_parquet_to_csv():
    """
    Convert each Parquet folder in output/ to a single CSV file in output_csv/
    """
    # Paths
    input_dir = Path("output")
    output_dir = Path("output_csv")
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(exist_ok=True)
    
    # Get all subdirectories in output/
    parquet_folders = [d for d in input_dir.iterdir() if d.is_dir()]
    
    print(f"Found {len(parquet_folders)} Parquet folders to convert:")
    
    for folder in parquet_folders:
        print(f"\nConverting {folder.name}...")
        
        try:
            # Read all Parquet files in the folder (handles partitioned data)
            df = pd.read_parquet(folder)
            
            # Create output CSV path
            csv_path = output_dir / f"{folder.name}.csv"
            
            # Write to CSV
            df.to_csv(csv_path, index=False)
            
            print(f"  ✓ Created {csv_path} ({len(df):,} rows)")
            
        except Exception as e:
            print(f"  ✗ Error converting {folder.name}: {e}")
    
    print(f"\nConversion complete! CSV files saved to: {output_dir}")

if __name__ == "__main__":
    convert_parquet_to_csv()
