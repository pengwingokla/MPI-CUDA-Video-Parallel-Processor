import cv2
import os

os.makedirs("frames", exist_ok=True)
cap = cv2.VideoCapture("cappy.mp4")
i = 0
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    cv2.imwrite(f"frames/frame_{i:04d}.jpg", frame)
    i += 1
cap.release()
print(f"Extracted {i} frames.")
