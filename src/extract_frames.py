import cv2
import os

os.makedirs("frames", exist_ok=True)
# Try new location first, then fall back to root for backward compatibility
video_path = "data/videos/cappy.mp4" if os.path.exists("data/videos/cappy.mp4") else "cappy.mp4"
cap = cv2.VideoCapture(video_path)
i = 0
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    cv2.imwrite(f"frames/frame_{i:04d}.jpg", frame)
    i += 1
cap.release()
print(f"Extracted {i} frames.")
