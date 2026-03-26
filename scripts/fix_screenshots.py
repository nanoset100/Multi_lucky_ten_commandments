import os
from PIL import Image

def process_screenshots(input_dir, output_root):
    # 타켓 해상도 설정 (너비, 높이)
    targets = {
        "ios_6_5": (1242, 2688),   # iPhone 6.5" (XS Max, 11 Pro Max 등)
        "ios_6_7": (1290, 2796),   # iPhone 6.7" (14 Pro Max, 15 Pro Max 등)
        "ipad_13": (2048, 2732),   # iPad Pro 12.9" (대체로 세로 기준)
    }

    # 스크린샷 파일 목록 (1.png ~ 6.png 또는 screenshot_1.png ~ screenshot_6.png 대응)
    files = [f for f in os.listdir(input_dir) if f.endswith('.png') and ('screenshot' in f or f[:1].isdigit())]
    
    if not os.path.exists(output_root):
        os.makedirs(output_root)

    for device, size in targets.items():
        device_dir = os.path.join(output_root, device)
        if not os.path.exists(device_dir):
            os.makedirs(device_dir)
        
        print(f"Processing for {device} ({size[0]}x{size[1]})...")

        for filename in files:
            img_path = os.path.join(input_dir, filename)
            with Image.open(img_path) as img:
                w, h = img.size
                
                # 1. 상단 상태 표시줄 제거 (약 100~120px 정도 크롭)
                # Android 상단바 높이는 기기마다 다르지만 보통 100px 내외
                crop_top = 100 
                # 하단 내비바 제거 (약 100px)
                crop_bottom = 100
                
                # 중앙 영역 추출
                left = 0
                top = crop_top
                right = w
                bottom = h - crop_bottom
                
                cropped_img = img.crop((left, top, right, bottom))
                
                # 2. 배경색 추출 (좌측 상단 픽셀 기준)
                bg_color = img.getpixel((0, h // 2)) # 이미지의 중간 왼쪽 픽셀 색상 사용 (보통 그라데이션이므로)
                
                # 3. 새 캔버스 생성 및 이미지 중앙 배치
                new_img = Image.new('RGB', size, bg_color)
                
                # 크기 조정 (너비 맞춤 후 높이가 넘치면 비율 유지하며 축소)
                new_w = size[0]
                new_h = int(cropped_img.height * (new_w / cropped_img.width))
                
                if new_h > size[1]:
                    new_h = size[1]
                    new_w = int(cropped_img.width * (new_h / cropped_img.height))
                
                resized_img = cropped_img.resize((new_w, new_h), Image.LANCZOS)
                
                # 중앙 정렬하여 붙이기
                offset = ((size[0] - new_w) // 2, (size[1] - new_h) // 2)
                new_img.paste(resized_img, offset)
                
                # 저장
                output_path = os.path.join(device_dir, filename)
                new_img.save(output_path)
                print(f"  - Saved: {filename}")

if __name__ == "__main__":
    # 경로 설정
    base_path = r"m:\MyProject777\Multi_lucky_ten_commandments"
    input_screenshots = os.path.join(base_path, "assets", "images", "final_screenshots")
    output_screenshots = os.path.join(base_path, "assets", "images", "processed_screenshots")
    
    # final_screenshots 폴더가 없으면 상위 폴더 시도
    if not os.path.exists(input_screenshots):
        input_screenshots = os.path.join(base_path, "assets", "images")

    process_screenshots(input_screenshots, output_screenshots)
    print("\nAll screenshots processed successfully!")
