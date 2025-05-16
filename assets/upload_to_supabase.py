import os
import csv
import json
from supabase import create_client

# Supabase 클라이언트 초기화
supabase_url = "https://sevdrykubdoynryfahjm.supabase.co"
supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNldmRyeWt1YmRveW5yeWZhaGptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MzgzMTU3MSwiZXhwIjoyMDU5NDA3NTcxfQ._5C_RrX3tBxn2YwFuo6WQnt98FOfcfD6mCy6RnTgNrA"
supabase = create_client(supabase_url, supabase_key)

def get_existing_ids():
    try:
        response = supabase.table('multilang_cards').select('id').execute()
        return set(item['id'] for item in response.data)
    except Exception as e:
        print(f"Error fetching existing IDs: {str(e)}")
        return set()

def read_csv_file(file_path):
    data = []
    with open(file_path, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            # 모든 필드가 있는지 확인
            required_fields = ['id', 'title_ko', 'title_en', 'title_ja', 'title_zh', 'title_es',
                             'story_ko', 'story_en', 'story_ja', 'story_zh', 'story_es',
                             'q1_ko', 'q1_en', 'q1_ja', 'q1_zh', 'q1_es',
                             'q2_ko', 'q2_en', 'q2_ja', 'q2_zh', 'q2_es']
            
            if not all(field in row for field in required_fields):
                print(f"Warning: Row {row.get('id', 'unknown')} is missing required fields")
                continue
                
            # ID를 정수로 변환
            try:
                row['id'] = int(row['id'])
            except ValueError:
                print(f"Warning: Invalid ID format in row: {row.get('id', 'unknown')}")
                continue
                
            data.append(row)
    return data

def upload_to_supabase(data):
    success_count = 0
    error_count = 0
    
    for row in data:
        try:
            # upsert: id가 있으면 업데이트, 없으면 삽입
            result = supabase.table('multilang_cards').upsert(row).execute()
            success_count += 1
            print(f"Successfully processed row with ID: {row['id']}")
        except Exception as e:
            error_count += 1
            print(f"Error processing row with ID {row['id']}: {str(e)}")
    
    print(f"\nUpload summary:")
    print(f"Successfully processed: {success_count} rows")
    print(f"Failed to process: {error_count} rows")
    
    return error_count == 0

if __name__ == "__main__":
    csv_path = "multilang_cards_final_449_to_480.csv"
    
    # CSV 파일 읽기
    print("Reading CSV file...")
    data = read_csv_file(csv_path)
    
    if not data:
        print("No valid data found in CSV file")
        exit(1)
    
    # 데이터 업로드
    print(f"Processing {len(data)} rows...")
    if upload_to_supabase(data):
        print("All records processed successfully!")
    else:
        print("Some records failed to process. Please check the logs above.") 