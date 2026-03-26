"""
iOS 상태바를 스크린샷에 추가하고, 기울어진 마케팅 이미지를 교체하는 스크립트
"""
from PIL import Image, ImageDraw, ImageFont
import os

ASSETS = "assets/images"
OUTPUT = "assets/images/final_screenshots"
os.makedirs(OUTPUT, exist_ok=True)

def add_status_bar(img: Image.Image) -> Image.Image:
    """이미지 상단에 iOS 스타일 상태바 추가"""
    w, h = img.size
    bar_h = max(44, int(h * 0.052))  # 화면 높이의 약 5.2%

    # 앱 상단 배경색 샘플링 (상단 픽셀)
    top_color = img.getpixel((w // 2, 2))
    if isinstance(top_color, int):  # grayscale
        top_color = (top_color, top_color, top_color, 255)
    elif len(top_color) == 3:
        top_color = top_color + (255,)

    # 새 캔버스 (상태바 높이만큼 늘림)
    new_img = Image.new("RGBA", (w, h + bar_h), top_color[:3])
    new_img.paste(img.convert("RGBA"), (0, bar_h))

    draw = ImageDraw.Draw(new_img)

    # 텍스트 색상: 배경 밝기에 따라 흰/검 선택
    brightness = 0.299 * top_color[0] + 0.587 * top_color[1] + 0.114 * top_color[2]
    text_color = (30, 30, 30) if brightness > 128 else (255, 255, 255)

    font_size = max(20, bar_h // 2)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", font_size)
        font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", font_size - 2)
    except:
        font = ImageFont.load_default()
        font_small = font

    margin = int(w * 0.045)
    cy = bar_h // 2  # 세로 중앙

    # 왼쪽: 시간
    time_text = "9:41"
    draw.text((margin, cy), time_text, font=font, fill=text_color, anchor="lm")

    # 오른쪽: 배터리 + 와이파이 아이콘 (간단한 도형으로 표현)
    rx = w - margin

    # 배터리 아이콘
    bat_w = int(font_size * 1.4)
    bat_h = int(font_size * 0.7)
    bat_x = rx - bat_w - 4
    bat_y = cy - bat_h // 2
    # 배터리 외곽
    draw.rectangle([bat_x, bat_y, bat_x + bat_w, bat_y + bat_h],
                   outline=text_color, width=2)
    # 배터리 극 (+)
    pole_h = bat_h // 3
    draw.rectangle([bat_x + bat_w + 1, cy - pole_h // 2,
                    bat_x + bat_w + 4, cy + pole_h // 2],
                   fill=text_color)
    # 충전량 (80%)
    fill_w = int((bat_w - 4) * 0.8)
    draw.rectangle([bat_x + 2, bat_y + 2, bat_x + 2 + fill_w, bat_y + bat_h - 2],
                   fill=text_color)

    # 와이파이 아이콘 (3개 호 대신 3개 점으로 단순화)
    wifi_x = bat_x - int(font_size * 1.2)
    wifi_size = int(font_size * 0.9)
    # 와이파이 부채꼴 (단순 삼각형으로)
    for i, (radius, alpha) in enumerate([(wifi_size, 255), (wifi_size * 0.65, 200), (wifi_size * 0.35, 150)]):
        r = int(radius)
        arc_color = text_color + (alpha,) if len(text_color) == 3 else text_color
        draw.arc([wifi_x - r, cy - r // 2, wifi_x + r, cy + r],
                 start=220, end=320, fill=text_color, width=2)

    return new_img.convert("RGB")


def process(src_path: str, out_name: str):
    img = Image.open(src_path)
    result = add_status_bar(img)
    out_path = os.path.join(OUTPUT, out_name)
    result.save(out_path, "PNG", optimize=True)
    print(f"  ✅ {out_name}  ({result.size[0]}x{result.size[1]})")
    return result.size


print("=== iOS 상태바 추가 중 ===\n")

# 좋은 스크린샷: 상태바만 추가
process(f"{ASSETS}/appstore_1.png", "screenshot_1.png")  # 메인 카드
process(f"{ASSETS}/appstore_2.png", "screenshot_2.png")  # 메모 목록
process(f"{ASSETS}/appstore_4.png", "screenshot_4.png")  # 메인 카드 변형
process(f"{ASSETS}/appstore_5.png", "screenshot_5.png")  # 메모 목록 변형

# 기울어진 이미지 → flat 버전으로 교체 후 상태바 추가
print("\n=== 기울어진 이미지 교체 중 ===\n")
process(f"{ASSETS}/[크기변환]3.png", "screenshot_3.png")  # 약속을 지키기 (flat)
process(f"{ASSETS}/[크기변환]1.png", "screenshot_6.png")  # 하나님을 먼저 찾기 (flat)

print("\n=== 완료 ===")
print(f"저장 위치: {OUTPUT}/")
print("\niPad 스크린샷은 iPhone 이미지를 리사이즈합니다...")

# iPad용 리사이즈 (2048x2732 → 실제 제출 시 필요한 크기)
ipad_size = (2048, 2732)
for i, name in enumerate(["screenshot_1.png", "screenshot_2.png",
                            "screenshot_3.png", "screenshot_4.png",
                            "screenshot_5.png", "screenshot_6.png"], 1):
    src = Image.open(os.path.join(OUTPUT, name))
    # 비율 유지하며 iPad 크기에 맞게 패딩
    src_ratio = src.width / src.height
    ipad_ratio = ipad_size[0] / ipad_size[1]

    if src_ratio > ipad_ratio:
        new_w = ipad_size[0]
        new_h = int(ipad_size[0] / src_ratio)
    else:
        new_h = ipad_size[1]
        new_w = int(ipad_size[1] * src_ratio)

    resized = src.resize((new_w, new_h), Image.LANCZOS)
    bg_color = src.getpixel((src.width // 2, 0))[:3] if src.mode == 'RGBA' else src.getpixel((src.width // 2, 0))
    ipad_img = Image.new("RGB", ipad_size, bg_color)
    paste_x = (ipad_size[0] - new_w) // 2
    paste_y = (ipad_size[1] - new_h) // 2
    ipad_img.paste(resized, (paste_x, paste_y))

    ipad_path = os.path.join(OUTPUT, f"ipad_{i}.png")
    ipad_img.save(ipad_path, "PNG")
    print(f"  ✅ ipad_{i}.png  (2048x2732)")

print("\n모든 스크린샷 생성 완료!")
